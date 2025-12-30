import { useCallback, useEffect, useRef, useState } from "react";

export type SimconnectStatus = "idle" | "connecting" | "connected" | "disconnected" | "error";

export type SimconnectSnapshot = {
  time: number;
  altitude_ft?: number;
  ias_kt?: number;
  gs_kt?: number;
  mach?: number;
  vs_fpm?: number;
  heading_deg?: number;
  lat?: number;
  lon?: number;
  dep_icao?: string;
  arr_icao?: string;
  flightplan_total_nm?: number;
  flightplan_remaining_nm?: number;
  takeoff_roll_time_utc?: string;
  phase?: string;
  next_wp_id?: string;
  touchdown_fpm?: number;
  fuel_total_kg?: number;
  fuel_burn_kg?: number;
  weight_kg?: number;
};

export type SimconnectBridgeOptions = {
  url?: string;
  autoConnect?: boolean;
  reconnectMs?: number;
};

type BridgeMessage = {
  type?: string;
  payload?: SimconnectSnapshot;
} | SimconnectSnapshot;

const DEFAULT_URL = "ws://127.0.0.1:8383";

export function useSimconnectBridge(options: SimconnectBridgeOptions = {}) {
  const { url = DEFAULT_URL, autoConnect = false, reconnectMs = 3000 } = options;
  const socketRef = useRef<WebSocket | null>(null);
  const reconnectRef = useRef<number | null>(null);
  const shouldReconnectRef = useRef(false);
  const connectTimeoutRef = useRef<number | null>(null);
  const hasEverConnectedRef = useRef(false);

  const [status, setStatus] = useState<SimconnectStatus>("idle");
  const [error, setError] = useState<string | null>(null);
  const [snapshot, setSnapshot] = useState<SimconnectSnapshot | null>(null);
  const [lastUpdated, setLastUpdated] = useState<number | null>(null);

  const clearReconnect = useCallback(() => {
    if (reconnectRef.current !== null) {
      window.clearTimeout(reconnectRef.current);
      reconnectRef.current = null;
    }
  }, []);

  const clearConnectTimeout = useCallback(() => {
    if (connectTimeoutRef.current !== null) {
      window.clearTimeout(connectTimeoutRef.current);
      connectTimeoutRef.current = null;
    }
  }, []);

  const disconnect = useCallback(() => {
    shouldReconnectRef.current = false;
    clearReconnect();
    clearConnectTimeout();
    if (socketRef.current) {
      socketRef.current.close();
      socketRef.current = null;
    }
    setStatus("disconnected");
  }, [clearConnectTimeout, clearReconnect]);

  const connect = useCallback(() => {
    if (socketRef.current) return;
    shouldReconnectRef.current = true;
    setStatus("connecting");
    setError(null);
    clearConnectTimeout();

    const socket = new WebSocket(url);
    socketRef.current = socket;

    socket.onopen = () => {
      hasEverConnectedRef.current = true;
      clearConnectTimeout();
      setStatus("connected");
      setError(null);
    };

    socket.onmessage = (event) => {
      try {
        const data = JSON.parse(String(event.data)) as BridgeMessage;
        const payload = "payload" in data ? data.payload : data;
        if (payload && typeof payload === "object") {
          setSnapshot(payload as SimconnectSnapshot);
          setLastUpdated(Date.now());
        }
      } catch {
        // Ignore non-JSON payloads from early bridge prototypes.
      }
    };

    socket.onerror = () => {
      clearConnectTimeout();
      setStatus("error");
      setError("Bridge connection error.");
    };

    socket.onclose = () => {
      socketRef.current = null;
      clearConnectTimeout();
      if (shouldReconnectRef.current && reconnectMs > 0 && hasEverConnectedRef.current) {
        setStatus("connecting");
        clearReconnect();
        reconnectRef.current = window.setTimeout(connect, reconnectMs);
      } else if (shouldReconnectRef.current && !hasEverConnectedRef.current) {
        setStatus("error");
        setError((current) => current ?? "Bridge not reachable.");
      } else {
        setStatus("disconnected");
      }
    };
    connectTimeoutRef.current = window.setTimeout(() => {
      if (!socketRef.current || socketRef.current.readyState === WebSocket.OPEN) return;
      setStatus("error");
      setError("Bridge connection timed out.");
      socketRef.current.close();
    }, 5000);
  }, [clearConnectTimeout, clearReconnect, reconnectMs, url]);

  useEffect(() => {
    if (!autoConnect) return;
    connect();
    return () => {
      disconnect();
    };
  }, [autoConnect, connect, disconnect]);

  return {
    status,
    error,
    snapshot,
    lastUpdated,
    connect,
    disconnect,
  };
}
