import asyncio
import json
import math
import logging
import time
import websockets
from SimConnect import SimConnect, AircraftRequests, Request

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("MSFS_SimConnect_Bridge")

class SimConnectBridge:
    def __init__(self):
        self.sm = None
        self.aq = None
        self.connected = False
        self.missing_vars = set()
        self.custom_requests = {}
        self.last_on_ground = None
        self.touchdown_timer = 0.0
        self.touchdown_data = {
            "isLanding": False,
            "touchdownVS": 0.0,
            "touchdownPitch": 0.0,
            "touchdownGForce": 0.0
        }

    def connect(self):
        try:
            logger.info("Connecting to MSFS SimConnect...")
            # SimConnect() will raise ConnectionError if MSFS is not running
            self.sm = SimConnect()
            self.aq = AircraftRequests(self.sm)
            # Simvars missing from Python-SimConnect's built-in request list,
            # registered manually so gear and reheat indicators still work.
            self.custom_requests = {
                "GEAR_TOTAL_PCT": Request((b'GEAR TOTAL PCT EXTENDED', b'Percent Over 100'), self.sm, _time=50),
                "REHEAT:1": Request((b'TURB ENG AFTERBURNER STAGE ACTIVE:1', b'Number'), self.sm, _time=50),
                "REHEAT:2": Request((b'TURB ENG AFTERBURNER STAGE ACTIVE:2', b'Number'), self.sm, _time=50),
                "REHEAT:3": Request((b'TURB ENG AFTERBURNER STAGE ACTIVE:3', b'Number'), self.sm, _time=50),
                "REHEAT:4": Request((b'TURB ENG AFTERBURNER STAGE ACTIVE:4', b'Number'), self.sm, _time=50),
            }
            self.connected = True
            logger.info("Successfully connected to MSFS SimConnect!")
            self.last_on_ground = None
        except Exception as e:
            self.connected = False
            self.sm = None
            self.aq = None
            logger.debug(f"SimConnect connection attempt failed: {e}")

    def get_var(self, name, default=0.0):
        """Read a simvar, tolerating variables missing from the
        Python-SimConnect request list or transiently returning None."""
        try:
            req = self.custom_requests.get(name) or self.aq.find(name)
            if req is None:
                if name not in self.missing_vars:
                    self.missing_vars.add(name)
                    logger.warning(f"SimVar not available, using default: {name}")
                return default
            value = req.value
            return default if value is None else value
        except OSError:
            # Real SimConnect transport failure — trigger reconnect
            raise
        except Exception as e:
            if name not in self.missing_vars:
                self.missing_vars.add(name)
                logger.warning(f"SimVar read failed, using default: {name} ({e})")
            return default

    def get_telemetry(self):
        if not self.connected or not self.aq:
            return None

        try:
            # Read basic flight telemetry
            alt = self.get_var("PLANE_ALTITUDE")
            ias = self.get_var("AIRSPEED_INDICATED")
            tas = self.get_var("AIRSPEED_TRUE")
            gs = self.get_var("GPS_GROUND_SPEED")
            # SimConnect returns these "degrees" vars in radians — convert
            heading = math.degrees(self.get_var("PLANE_HEADING_DEGREES_MAGNETIC")) % 360.0
            vs = self.get_var("VERTICAL_SPEED")
            pitch = -math.degrees(self.get_var("PLANE_PITCH_DEGREES"))  # sim pitch is negative nose-up
            roll = math.degrees(self.get_var("PLANE_BANK_DEGREES"))
            lat = self.get_var("PLANE_LATITUDE")
            lon = self.get_var("PLANE_LONGITUDE")
            g_force = self.get_var("G_FORCE", 1.0)
            gear = self.get_var("GEAR_TOTAL_PCT")
            flaps = self.get_var("FLAPS_HANDLE_INDEX", 0)

            # Formatted Zulu Time
            zulu_sec = self.get_var("ZULU_TIME")
            z_hours = int(zulu_sec // 3600) % 24
            z_minutes = int((zulu_sec % 3600) // 60)
            z_seconds = int(zulu_sec % 60)
            zulu_str = f"{z_hours:02d}:{z_minutes:02d}:{z_seconds:02d}"

            # Concorde specific variables
            mach = self.get_var("AIRSPEED_MACH")
            tat = self.get_var("TOTAL_AIR_TEMPERATURE")
            cg = self.get_var("CG_PERCENT")
            # Handle fractional vs absolute percentage representation safety
            cg_pct = cg * 100.0 if cg < 1.0 else cg
            
            # Fuel Flow and Burn (Sum of pph converted to kg/h)
            ff1 = self.get_var("TURB_ENG_FUEL_FLOW_PPH:1")
            ff2 = self.get_var("TURB_ENG_FUEL_FLOW_PPH:2")
            ff3 = self.get_var("TURB_ENG_FUEL_FLOW_PPH:3")
            ff4 = self.get_var("TURB_ENG_FUEL_FLOW_PPH:4")
            fuel_burn = (ff1 + ff2 + ff3 + ff4) * 0.45359237  # PPH to kg/h

            # Fuel Tanks Fill Level %
            tank_left = self.get_var("FUEL_TANK_LEFT_MAIN_LEVEL")
            tank_right = self.get_var("FUEL_TANK_RIGHT_MAIN_LEVEL")
            tank_center = self.get_var("FUEL_TANK_CENTER_LEVEL")
            tank_center2 = self.get_var("FUEL_TANK_CENTER2_LEVEL")
            tank_center3 = self.get_var("FUEL_TANK_CENTER3_LEVEL")

            # Reheat active (afterburners stage > 0)
            reheat1 = self.get_var("REHEAT:1") > 0
            reheat2 = self.get_var("REHEAT:2") > 0
            reheat3 = self.get_var("REHEAT:3") > 0
            reheat4 = self.get_var("REHEAT:4") > 0

            # Nose Visor Angle mapping for DC Designs Concorde (Leading Edge Flap percent)
            visor = self.get_var("LEADING_EDGE_FLAPS_LEFT_PERCENT")

            # Landing Touchdown Scorecard Logic
            on_ground = self.get_var("SIM_ON_GROUND", 0)
            
            # Transition: Airborne -> Ground
            if self.last_on_ground == 0 and on_ground == 1:
                self.touchdown_data = {
                    "isLanding": True,
                    "touchdownVS": vs,
                    "touchdownPitch": pitch,
                    "touchdownGForce": g_force
                }
                self.touchdown_timer = time.time()
                logger.info(f"Touchdown Recorded: VS={vs} FPM, Pitch={pitch}°, Gs={g_force}")
            
            self.last_on_ground = on_ground

            # Latch landing summary data on screen for exactly 5 seconds
            if self.touchdown_data["isLanding"] and time.time() - self.touchdown_timer > 5.0:
                self.touchdown_data = {
                    "isLanding": False,
                    "touchdownVS": 0.0,
                    "touchdownPitch": 0.0,
                    "touchdownGForce": 0.0
                }

            return {
                "timestamp": int(time.time()),
                "basic": {
                    "altitude": alt,
                    "ias": ias,
                    "tas": tas,
                    "gs": gs,
                    "heading": heading,
                    "vs": vs,
                    "pitch": pitch,
                    "roll": roll,
                    "latitude": lat,
                    "longitude": lon,
                    "gForce": g_force,
                    "gearPosition": gear,
                    "flapsPosition": flaps,
                    "zuluTime": zulu_str
                },
                "concorde": {
                    "mach": mach,
                    "tat": tat,
                    "cgPct": cg_pct,
                    "cgAftLimit": 59.0,
                    "cgFwdLimit": 52.0,
                    "fuelBurnTotal": fuel_burn,
                    "fuelTanks": {
                        "left": tank_left * 100.0,
                        "right": tank_right * 100.0,
                        "center": tank_center * 100.0,
                        "trimForward": tank_center2 * 100.0,
                        "trimAft": tank_center3 * 100.0
                    },
                    "reheatActive": [reheat1, reheat2, reheat3, reheat4],
                    "snootAngle": visor,
                    "engineRamps": 0.0
                },
                "events": self.touchdown_data
            }
        except Exception as e:
            logger.warning(f"Connection to SimConnect lost: {e}")
            self.connected = False
            return None

async def telemetry_loop(bridge: SimConnectBridge, clients: set):
    """Telemetry polling loop running at ~25Hz (every 40ms)"""
    while True:
        if not bridge.connected:
            bridge.connect()
            if not bridge.connected:
                # Retry connection in 3 seconds if failed
                await asyncio.sleep(3.0)
                continue

        payload = bridge.get_telemetry()
        if payload and clients:
            message = json.dumps(payload)
            # Broadcast to all connected WebSockets
            websockets_tasks = [asyncio.create_task(client.send(message)) for client in clients]
            if websockets_tasks:
                await asyncio.wait(websockets_tasks)

        # 25Hz target speed (1 / 25 = 0.04 seconds)
        await asyncio.sleep(0.04)

async def socket_handler(websocket, clients: set):
    clients.add(websocket)
    logger.info(f"Client connected: {websocket.remote_address}. Active clients: {len(clients)}")
    try:
        async for _ in websocket:
            # We only stream telemetry, ignore incoming client packets
            pass
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        clients.remove(websocket)
        logger.info(f"Client disconnected. Active clients: {len(clients)}")

async def main():
    bridge = SimConnectBridge()
    clients = set()

    # Start WebSocket Server on ws://localhost:8082
    server = await websockets.serve(
        lambda ws: socket_handler(ws, clients), 
        "localhost", 
        8082
    )
    logger.info("WebSocket Telemetry Server running on ws://localhost:8082")

    # Start SimConnect Telemetry Polling Loop
    await telemetry_loop(bridge, clients)

    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bridge terminated by user.")
