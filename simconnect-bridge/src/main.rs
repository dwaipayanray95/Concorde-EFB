use futures_util::{SinkExt, StreamExt};
use serde::Serialize;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use tokio::net::TcpListener;
use tokio::sync::broadcast;
use tokio::time::{interval, Duration};
use tokio_tungstenite::accept_async;

#[cfg(windows)]
mod simconnect_reader;

#[derive(Clone, Debug, Serialize, Default)]
struct BridgeSnapshot {
  time: u64,
  altitude_ft: Option<f64>,
  ias_kt: Option<f64>,
  gs_kt: Option<f64>,
  mach: Option<f64>,
  vs_fpm: Option<f64>,
  heading_deg: Option<f64>,
  lat: Option<f64>,
  lon: Option<f64>,
  dep_icao: Option<String>,
  arr_icao: Option<String>,
  flightplan_total_nm: Option<f64>,
  flightplan_remaining_nm: Option<f64>,
  takeoff_roll_time_utc: Option<String>,
  phase: Option<String>,
  next_wp_id: Option<String>,
  touchdown_fpm: Option<f64>,
  fuel_total_kg: Option<f64>,
  fuel_burn_kg: Option<f64>,
  weight_kg: Option<f64>,
}

#[derive(Clone, Debug, Serialize)]
struct BridgeMessage<'a> {
  r#type: &'a str,
  payload: &'a BridgeSnapshot,
}

#[derive(Default)]
struct BridgeState {
  snapshot: BridgeSnapshot,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
  let addr: SocketAddr = "127.0.0.1:8383".parse().expect("invalid bind address");
  let listener = TcpListener::bind(addr).await?;
  println!("SimConnect bridge listening on ws://{addr}");

  let state = Arc::new(Mutex::new(BridgeState::default()));
  let (tx, _rx) = broadcast::channel::<String>(128);

  spawn_snapshot_broadcaster(state.clone(), tx.clone());
  spawn_simconnect_reader(state.clone());

  loop {
    let (stream, _) = listener.accept().await?;
    let peer = stream.peer_addr().ok();
    let mut rx = tx.subscribe();
    tokio::spawn(async move {
      let ws_stream = match accept_async(stream).await {
        Ok(s) => s,
        Err(err) => {
          eprintln!("WebSocket accept error: {err}");
          return;
        }
      };
      let (mut ws_write, mut ws_read) = ws_stream.split();

      if let Some(peer) = peer {
        println!("Client connected: {peer}");
      }

      let mut writer_task = tokio::spawn(async move {
        while let Ok(payload) = rx.recv().await {
          if ws_write.send(tokio_tungstenite::tungstenite::Message::Text(payload)).await.is_err() {
            break;
          }
        }
      });

      while let Some(Ok(msg)) = ws_read.next().await {
        if msg.is_close() {
          break;
        }
      }

      writer_task.abort();
      if let Some(peer) = peer {
        println!("Client disconnected: {peer}");
      }
    });
  }
}

fn spawn_snapshot_broadcaster(state: Arc<Mutex<BridgeState>>, tx: broadcast::Sender<String>) {
  tokio::spawn(async move {
    let mut ticker = interval(Duration::from_millis(200));
    loop {
      ticker.tick().await;
      let snapshot = {
        let mut guard = state.lock().expect("state lock");
        guard.snapshot.time = unix_time_ms();
        guard.snapshot.clone()
      };
      let msg = BridgeMessage {
        r#type: "snapshot",
        payload: &snapshot,
      };
      if let Ok(payload) = serde_json::to_string(&msg) {
        let _ = tx.send(payload);
      }
    }
  });
}

fn spawn_simconnect_reader(_state: Arc<Mutex<BridgeState>>) {
  #[cfg(windows)]
  {
    simconnect_reader::spawn(_state);
  }
}

fn unix_time_ms() -> u64 {
  use std::time::{SystemTime, UNIX_EPOCH};
  SystemTime::now()
    .duration_since(UNIX_EPOCH)
    .unwrap_or_default()
    .as_millis() as u64
}
