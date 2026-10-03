"""Concorde EFB <-> MSFS SimConnect telemetry bridge.

Talks to SimConnect.dll directly via ctypes, following the pattern Microsoft
documents in the MSFS SDK (and that Volanta / Navigraph / LittleNavMap-style
tools use):

  1. SimConnect_Open
  2. Register ONE data definition holding every SimVar we need
  3. SimConnect_RequestDataOnSimObject(..., PERIOD_SIM_FRAME) -- the sim PUSHES
     a single packed struct every frame; we never poll var-by-var
  4. Drain SimConnect_GetNextDispatch in a dedicated thread, handling
     OPEN / QUIT / EXCEPTION / SIMOBJECT_DATA / SYSTEM_STATE
  5. On QUIT, a broken pipe, or a missed heartbeat: SimConnect_Close and go
     back to step 1. A fresh Open on a closed handle always works, so the
     bridge process itself never needs restarting.

The previous version used the Python-SimConnect wrapper, which issues ~50
blocking request/sleep round-trips per frame on the asyncio thread (stalling
the WebSocket server), never handled QUIT, and wasn't bundled with its
SimConnect.dll by PyInstaller -- the root causes of the unreliability.

WebSocket protocol on ws://localhost:8082 (JSON text frames):

LAN sharing (opt-in, for the phone/tablet app): with SIMBRIDGE_LAN=1 the
server listens on all interfaces. Clients that are NOT on this PC must
connect with ws://<pc-ip>:8082/?code=<SIMBRIDGE_CODE> or they are closed
with code 4401. While LAN sharing is on, a UDP beacon is broadcast every 2s
on port 8083 so the app can find this PC:
  {"app": "concorde-efb-bridge", "v": 1, "port": 8082, "host": "<pc name>"}

  {"type": "status", "simConnected": bool, "receivingData": bool, "message": str}
      sent on client connect, on every state change, and every 2s
  {"type": "telemetry", "timestamp": ..., "basic": {...}, "concorde": {...}, "events": {...}}
      ~25 Hz while the sim is delivering data
"""

import asyncio
import ctypes
import socket
import json
import logging
import os
import struct
import sys
import threading
import time
from ctypes import wintypes
from urllib.parse import parse_qs, urlparse

import websockets

LAN_SHARING = os.environ.get("SIMBRIDGE_LAN") == "1"
PAIRING_CODE = os.environ.get("SIMBRIDGE_CODE", "").strip()
HOST = "0.0.0.0" if LAN_SHARING else "127.0.0.1"
PORT = int(os.environ.get("SIMBRIDGE_PORT", "8082"))
BEACON_PORT = 8083
BEACON_INTERVAL_S = 2.0
APP_NAME = b"Concorde EFB Bridge"
BROADCAST_HZ = 25
HEARTBEAT_INTERVAL_S = 5.0   # how often we ping the sim with RequestSystemState
HEARTBEAT_TIMEOUT_S = 20.0   # no messages at all for this long -> pipe is dead
RECONNECT_DELAY_S = 2.0
STATUS_INTERVAL_S = 2.0

# ---------------------------------------------------------------------------
# Logging: file in %LOCALAPPDATA% (the exe runs without a console window).
# ---------------------------------------------------------------------------
_log_dir = os.path.join(os.environ.get("LOCALAPPDATA", "."), "ConcordeEFB")
os.makedirs(_log_dir, exist_ok=True)
_handlers = [logging.FileHandler(os.path.join(_log_dir, "simbridge.log"), mode="w", encoding="utf-8")]
if sys.stderr is not None:
    _handlers.append(logging.StreamHandler())
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", handlers=_handlers)
logger = logging.getLogger("simbridge")

# ---------------------------------------------------------------------------
# SimConnect constants (SimConnect.h, MSFS SDK)
# ---------------------------------------------------------------------------
S_OK = 0
SIMCONNECT_OBJECT_ID_USER = 0
SIMCONNECT_DATATYPE_FLOAT64 = 4
SIMCONNECT_PERIOD_SIM_FRAME = 3
SIMCONNECT_UNUSED = 0xFFFFFFFF

RECV_ID_EXCEPTION = 1
RECV_ID_OPEN = 2
RECV_ID_QUIT = 3
RECV_ID_SIMOBJECT_DATA = 8
RECV_ID_SYSTEM_STATE = 15

REQ_TELEMETRY = 1
REQ_HEARTBEAT = 2

# DC Designs Concorde's 13 physical fuel tanks, mapped to their
# FUELSYSTEM TANK WEIGHT:<index> SimVar index. Reverse-engineered from the
# addon's own model behavior XML (modelbehaviordefs/concorde/dc_designs_instruments.xml),
# where each tank's digital readout gauge reads this exact indexed SimVar.
FUEL_TANK_INDEX = {
    "9": 1, "10": 2, "1": 3, "2": 4, "3": 5, "4": 6,
    "5": 7, "6": 8, "7": 9, "8": 10, "5A": 11, "7A": 12, "11": 13,
}

# (key, SimVar name, units). Units are chosen so values need no conversion.
SIMVARS = [
    ("alt", "PLANE ALTITUDE", "feet"),
    ("ias", "AIRSPEED INDICATED", "knots"),
    ("tas", "AIRSPEED TRUE", "knots"),
    ("gs", "GROUND VELOCITY", "knots"),
    ("hdg", "PLANE HEADING DEGREES MAGNETIC", "degrees"),
    ("vs", "VERTICAL SPEED", "feet per minute"),
    ("pitch", "PLANE PITCH DEGREES", "degrees"),
    ("bank", "PLANE BANK DEGREES", "degrees"),
    ("lat", "PLANE LATITUDE", "degrees"),
    ("lon", "PLANE LONGITUDE", "degrees"),
    ("g", "G FORCE", "gforce"),
    ("gear", "GEAR TOTAL PCT EXTENDED", "percent over 100"),
    ("flaps", "FLAPS HANDLE INDEX", "number"),
    ("zulu", "ZULU TIME", "seconds"),
    ("mach", "AIRSPEED MACH", "mach"),
    ("tat", "TOTAL AIR TEMPERATURE", "celsius"),
    ("cg", "CG PERCENT", "percent over 100"),
    ("tank_left", "FUEL TANK LEFT MAIN LEVEL", "percent over 100"),
    ("tank_right", "FUEL TANK RIGHT MAIN LEVEL", "percent over 100"),
    ("tank_center", "FUEL TANK CENTER LEVEL", "percent over 100"),
    ("tank_center2", "FUEL TANK CENTER2 LEVEL", "percent over 100"),
    ("tank_center3", "FUEL TANK CENTER3 LEVEL", "percent over 100"),
    ("visor", "LEADING EDGE FLAPS LEFT PERCENT", "percent over 100"),
    ("on_ground", "SIM ON GROUND", "bool"),
]
for _i in range(1, 5):
    SIMVARS += [
        (f"ff{_i}", f"TURB ENG FUEL FLOW PPH:{_i}", "pounds per hour"),
        (f"reheat{_i}", f"TURB ENG AFTERBURNER STAGE ACTIVE:{_i}", "number"),
        (f"thr{_i}", f"GENERAL ENG THROTTLE LEVER POSITION:{_i}", "percent"),
    ]
for _tank, _idx in FUEL_TANK_INDEX.items():
    SIMVARS.append((f"tankw_{_tank}", f"FUELSYSTEM TANK WEIGHT:{_idx}", "pounds"))

LB_TO_KG = 0.45359237


def _find_simconnect_dll():
    """SimConnect.dll is looked up next to the exe (PyInstaller bundle), then
    in the installed Python-SimConnect package (dev runs), then the MSFS SDK."""
    candidates = []
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(sys.argv[0])))
    candidates += [os.path.join(base, "SimConnect.dll"), os.path.join(os.path.dirname(sys.executable), "SimConnect.dll")]
    try:
        import importlib.util
        spec = importlib.util.find_spec("SimConnect")
        if spec and spec.origin:
            candidates.append(os.path.join(os.path.dirname(spec.origin), "SimConnect.dll"))
    except Exception:
        pass
    for env in ("MSFS2024_SDK", "MSFS_SDK"):
        if os.environ.get(env):
            candidates.append(os.path.join(os.environ[env], "SimConnect SDK", "lib", "SimConnect.dll"))
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise FileNotFoundError("SimConnect.dll not found. Looked in: " + "; ".join(candidates))


class SimConnectDll:
    def __init__(self, path):
        dll = ctypes.WinDLL(path)
        H = wintypes.HANDLE
        D = wintypes.DWORD
        self.Open = dll.SimConnect_Open
        self.Open.argtypes = [ctypes.POINTER(H), ctypes.c_char_p, wintypes.HWND, D, H, D]
        self.Close = dll.SimConnect_Close
        self.Close.argtypes = [H]
        self.AddToDataDefinition = dll.SimConnect_AddToDataDefinition
        self.AddToDataDefinition.argtypes = [H, D, ctypes.c_char_p, ctypes.c_char_p, D, ctypes.c_float, D]
        self.ClearDataDefinition = dll.SimConnect_ClearDataDefinition
        self.ClearDataDefinition.argtypes = [H, D]
        self.RequestDataOnSimObject = dll.SimConnect_RequestDataOnSimObject
        self.RequestDataOnSimObject.argtypes = [H, D, D, D, D, D, D, D, D]
        self.RequestSystemState = dll.SimConnect_RequestSystemState
        self.RequestSystemState.argtypes = [H, D, ctypes.c_char_p]
        self.GetNextDispatch = dll.SimConnect_GetNextDispatch
        self.GetNextDispatch.argtypes = [H, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(D)]
        self.GetLastSentPacketID = dll.SimConnect_GetLastSentPacketID
        self.GetLastSentPacketID.argtypes = [H, ctypes.POINTER(D)]
        for fn in (self.Open, self.Close, self.AddToDataDefinition, self.ClearDataDefinition,
                   self.RequestDataOnSimObject, self.RequestSystemState, self.GetNextDispatch,
                   self.GetLastSentPacketID):
            fn.restype = ctypes.c_long  # HRESULT


class SimConnectWorker(threading.Thread):
    """Owns the SimConnect connection. Runs forever on its own thread and
    publishes the latest decoded frame + connection state for the server."""

    def __init__(self):
        super().__init__(daemon=True, name="simconnect")
        self.lock = threading.Lock()
        self.latest = None          # dict of raw values by key
        self.latest_at = 0.0
        self.sim_connected = False
        self.message = "Waiting for MSFS"
        self.bad_vars = set()
        self.dll = None
        self.h = wintypes.HANDLE()
        self.define_id = 0
        self.active_vars = []
        self.send_id_to_var = {}
        self.last_rx = 0.0
        self.last_heartbeat = 0.0
        self.rebuild_needed = False

    # ---- state helpers ----
    def _set_state(self, connected, message):
        with self.lock:
            changed = connected != self.sim_connected or message != self.message
            self.sim_connected = connected
            self.message = message
            if not connected:
                self.latest = None
        if changed:
            logger.info("SimConnect state: %s (%s)", "CONNECTED" if connected else "DISCONNECTED", message)

    def snapshot(self):
        with self.lock:
            return self.sim_connected, self.message, self.latest, self.latest_at

    # ---- connection lifecycle ----
    def run(self):
        try:
            path = _find_simconnect_dll()
            self.dll = SimConnectDll(path)
            logger.info("Loaded %s", path)
        except Exception as e:
            logger.error("Cannot load SimConnect.dll: %s", e)
            self._set_state(False, f"SimConnect.dll failed to load: {e}")
            return

        while True:
            try:
                if self._open():
                    self._pump()
            except Exception:
                logger.exception("SimConnect worker error")
            self._close()
            time.sleep(RECONNECT_DELAY_S)

    def _open(self):
        self.h = wintypes.HANDLE()
        hr = self.dll.Open(ctypes.byref(self.h), APP_NAME, None, 0, None, 0)
        if hr != S_OK:
            self._set_state(False, "Waiting for MSFS")
            return False
        self.last_rx = self.last_heartbeat = time.monotonic()
        self._register()
        return True

    def _close(self):
        if self.h:
            try:
                self.dll.Close(self.h)
            except Exception:
                pass
            self.h = wintypes.HANDLE()
        self._set_state(False, "Waiting for MSFS")

    def _register(self):
        """(Re)build the single data definition and subscribe to it."""
        if self.define_id:
            self.dll.ClearDataDefinition(self.h, self.define_id)
        self.define_id += 1
        self.active_vars = [v for v in SIMVARS if v[1] not in self.bad_vars]
        self.send_id_to_var = {}
        pid = wintypes.DWORD()
        for _key, name, unit in self.active_vars:
            self.dll.AddToDataDefinition(self.h, self.define_id, name.encode(), unit.encode(),
                                         SIMCONNECT_DATATYPE_FLOAT64, 0.0, SIMCONNECT_UNUSED)
            if self.dll.GetLastSentPacketID(self.h, ctypes.byref(pid)) == S_OK:
                self.send_id_to_var[pid.value] = name
        hr = self.dll.RequestDataOnSimObject(self.h, REQ_TELEMETRY, self.define_id, SIMCONNECT_OBJECT_ID_USER,
                                             SIMCONNECT_PERIOD_SIM_FRAME, 0, 0, 0, 0)
        if hr != S_OK:
            raise OSError(f"RequestDataOnSimObject failed: 0x{hr & 0xFFFFFFFF:08X}")
        self.rebuild_needed = False

    def _pump(self):
        p_data = ctypes.c_void_p()
        cb = wintypes.DWORD()
        while True:
            # Drain everything queued.
            while True:
                hr = self.dll.GetNextDispatch(self.h, ctypes.byref(p_data), ctypes.byref(cb))
                if hr != S_OK:
                    break  # E_FAIL simply means "queue empty"
                self.last_rx = time.monotonic()
                if not self._handle(p_data.value, cb.value):
                    return  # QUIT

            if self.rebuild_needed:
                self._register()

            now = time.monotonic()
            if now - self.last_heartbeat >= HEARTBEAT_INTERVAL_S:
                self.last_heartbeat = now
                hr = self.dll.RequestSystemState(self.h, REQ_HEARTBEAT, b"Sim")
                if hr != S_OK:
                    logger.warning("Heartbeat send failed (0x%08X) -- reconnecting", hr & 0xFFFFFFFF)
                    return
            if now - self.last_rx > HEARTBEAT_TIMEOUT_S:
                logger.warning("No SimConnect traffic for %.0fs -- reconnecting", now - self.last_rx)
                return
            time.sleep(0.005)

    def _handle(self, ptr, size):
        """Returns False when the sim has quit."""
        recv_id = struct.unpack_from("<I", ctypes.string_at(ptr, 12), 8)[0]
        if recv_id == RECV_ID_OPEN:
            self._set_state(True, "Connected to MSFS")
        elif recv_id == RECV_ID_QUIT:
            logger.info("MSFS sent QUIT")
            return False
        elif recv_id == RECV_ID_EXCEPTION:
            exc, send_id, index = struct.unpack_from("<III", ctypes.string_at(ptr, 24), 12)
            name = self.send_id_to_var.get(send_id)
            if name and name not in self.bad_vars:
                logger.warning("SimVar rejected by sim, dropping it: %s (exception %d)", name, exc)
                self.bad_vars.add(name)
                self.rebuild_needed = True
            else:
                logger.debug("SimConnect exception %d (send %d, index %d)", exc, send_id, index)
        elif recv_id == RECV_ID_SIMOBJECT_DATA:
            raw = ctypes.string_at(ptr, size)
            req_id, _obj, def_id = struct.unpack_from("<III", raw, 12)
            n = len(self.active_vars)
            if req_id == REQ_TELEMETRY and def_id == self.define_id and len(raw) >= 40 + 8 * n:
                values = struct.unpack_from(f"<{n}d", raw, 40)
                frame = {key: val for (key, _n, _u), val in zip(self.active_vars, values)}
                with self.lock:
                    self.latest = frame
                    self.latest_at = time.monotonic()
                    if not self.sim_connected:
                        self.sim_connected, self.message = True, "Connected to MSFS"
        return True


class TelemetryBuilder:
    """Turns raw SimVar frames into the JSON payload the Flutter app expects."""

    def __init__(self):
        self.last_on_ground = None
        self.touchdown_at = 0.0
        self.touchdown = self._no_touchdown()

    @staticmethod
    def _no_touchdown():
        return {"isLanding": False, "touchdownVS": 0.0, "touchdownPitch": 0.0, "touchdownGForce": 0.0}

    def build(self, f):
        g = lambda k, d=0.0: f.get(k, d)
        vs = g("vs")
        pitch = -g("pitch")  # sim pitch is negative nose-up
        g_force = g("g", 1.0)
        on_ground = 1 if g("on_ground") >= 0.5 else 0

        if self.last_on_ground == 0 and on_ground == 1:
            self.touchdown = {"isLanding": True, "touchdownVS": vs, "touchdownPitch": pitch, "touchdownGForce": g_force}
            self.touchdown_at = time.monotonic()
            logger.info("Touchdown: VS=%.0f fpm, pitch=%.1f, G=%.2f", vs, pitch, g_force)
        self.last_on_ground = on_ground
        if self.touchdown["isLanding"] and time.monotonic() - self.touchdown_at > 5.0:
            self.touchdown = self._no_touchdown()

        zulu = g("zulu")
        zulu_str = f"{int(zulu // 3600) % 24:02d}:{int((zulu % 3600) // 60):02d}:{int(zulu % 60):02d}"
        cg = g("cg")
        return {
            "type": "telemetry",
            "timestamp": int(time.time()),
            "basic": {
                "altitude": g("alt"), "ias": g("ias"), "tas": g("tas"), "gs": g("gs"),
                "heading": g("hdg") % 360.0, "vs": vs, "pitch": pitch, "roll": g("bank"),
                "latitude": g("lat"), "longitude": g("lon"), "gForce": g_force,
                "gearPosition": g("gear"), "flapsPosition": g("flaps"), "zuluTime": zulu_str,
            },
            "concorde": {
                "mach": g("mach"), "tat": g("tat"),
                "cgPct": cg * 100.0 if cg < 1.0 else cg,
                "cgAftLimit": 59.0, "cgFwdLimit": 52.0,
                "fuelBurnTotal": sum(g(f"ff{i}") for i in range(1, 5)) * LB_TO_KG,
                "fuelTanks": {
                    "left": g("tank_left") * 100.0, "right": g("tank_right") * 100.0,
                    "center": g("tank_center") * 100.0, "trimForward": g("tank_center2") * 100.0,
                    "trimAft": g("tank_center3") * 100.0,
                },
                "fuelTanksKg": {t: g(f"tankw_{t}") * LB_TO_KG for t in FUEL_TANK_INDEX},
                "reheatActive": [g(f"reheat{i}") > 0 for i in range(1, 5)],
                "throttlePct": [g(f"thr{i}") for i in range(1, 5)],
                "snootAngle": g("visor"),
                "engineRamps": 0.0,
            },
            "events": {**self.touchdown, "onGround": bool(on_ground)},
        }


async def main():
    worker = SimConnectWorker()
    worker.start()
    builder = TelemetryBuilder()
    clients = set()

    def status_message():
        connected, message, latest, latest_at = worker.snapshot()
        receiving = latest is not None and time.monotonic() - latest_at < 3.0
        if connected and not receiving:
            message = "Connected to MSFS - waiting for flight (in menu or paused)"
        return json.dumps({"type": "status", "simConnected": connected, "receivingData": receiving, "message": message})

    async def handler(ws):
        # Clients on this PC (the desktop app) are always allowed; anything
        # arriving over the network must present the pairing code.
        remote_ip = (ws.remote_address or ("",))[0] or ""
        is_local = remote_ip.startswith("127.") or remote_ip in ("::1", "::ffff:127.0.0.1")
        if not is_local:
            query = parse_qs(urlparse(ws.request.path).query)
            code = (query.get("code") or [""])[0]
            if not PAIRING_CODE or code != PAIRING_CODE:
                logger.warning("Rejected LAN client %s (bad pairing code)", remote_ip)
                await ws.close(4401, "pairing code required")
                return
            logger.info("LAN client %s paired", remote_ip)
        clients.add(ws)
        logger.info("Client connected (%d total)", len(clients))
        try:
            await ws.send(status_message())
            async for _ in ws:
                pass  # clients only receive
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            clients.discard(ws)
            logger.info("Client disconnected (%d total)", len(clients))

    def broadcast(message):
        # websockets.broadcast never blocks: a slow/dead client can't stall the others.
        if clients:
            websockets.broadcast(clients, message)

    async def beacon():
        """Announce this PC on the local network so the app can find it."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        payload = json.dumps({"app": "concorde-efb-bridge", "v": 1, "port": PORT,
                              "host": socket.gethostname()}).encode()
        while True:
            try:
                sock.sendto(payload, ("255.255.255.255", BEACON_PORT))
            except OSError:
                pass  # no network right now -- keep trying
            await asyncio.sleep(BEACON_INTERVAL_S)

    if LAN_SHARING:
        asyncio.get_running_loop().create_task(beacon())

    async with websockets.serve(handler, HOST, PORT, ping_interval=10, ping_timeout=20, max_queue=4):
        logger.info("WebSocket server on ws://%s:%d (LAN sharing %s)", HOST, PORT, "ON" if LAN_SHARING else "off")
        last_sent_at = 0.0
        last_status = None
        last_status_at = 0.0
        while True:
            _, _, latest, latest_at = worker.snapshot()
            if latest is not None and latest_at != last_sent_at:
                last_sent_at = latest_at
                try:
                    broadcast(json.dumps(builder.build(latest)))
                except Exception:
                    logger.exception("Failed to build telemetry frame")
            status = status_message()
            now = time.monotonic()
            if status != last_status or now - last_status_at >= STATUS_INTERVAL_S:
                broadcast(status)
                last_status, last_status_at = status, now
            await asyncio.sleep(1.0 / BROADCAST_HZ)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bridge terminated by user.")
    except OSError as e:
        # Most likely port 8082 already in use by another bridge instance.
        logger.error("Bridge failed to start: %s", e)
        sys.exit(1)
