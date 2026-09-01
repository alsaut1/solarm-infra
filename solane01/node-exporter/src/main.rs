use axum::{routing::get, Router};
use std::fs;
use std::process::Command;
use std::sync::Arc;
use tokio::sync::Mutex;
use std::time::Duration;

fn grpc_connections() -> usize {
    let output = Command::new("ss")
        .args(["-Htn", "state", "established", "( sport = :10000 )"])
        .output();

    match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).lines().count(),
        Err(_) => 0,
    }
}

fn pubsub_connections() -> usize {
    let output = Command::new("ss")
        .args(["-Htn", "state", "established", "( sport = :8900 )"])
        .output();
    match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).lines().count(),
        Err(_) => 0,
    }
}

fn pubsub_sendq_bytes() -> u64 {
    let output = Command::new("ss")
        .args(["-Htn", "state", "established", "( sport = :8900 )"])
        .output();
    let text = match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(_) => return 0,
    };
    let mut total = 0u64;
    for line in text.lines() {
        if let Some(field) = line.split_whitespace().nth(1) {
            if let Ok(n) = field.parse::<u64>() {
                total += n;
            }
        }
    }
    total
}

fn rpc_connections() -> usize {
    let output = Command::new("ss")
        .args(["-Htn", "state", "established", "( sport = :8899 )"])
        .output();
    match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).lines().count(),
        Err(_) => 0,
    }
}

fn replay_elapsed_us() -> u64 {
    let output = Command::new("tail")
        .args(["-n", "2000", "/home/sol/logs/agave-validator.log"])
        .output();
    let text = match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(_) => return 0,
    };
    let mut sum = 0u64;
    let mut count = 0u64;
    for line in text.lines() {
        if !line.contains("replay-slot-stats") {
            continue;
        }
        for part in line.split_whitespace() {
            if let Some(value) = part.strip_prefix("replay_total_elapsed=") {
                if let Ok(n) = value.trim_end_matches('i').parse::<u64>() {
                    sum += n;
                    count += 1;
                }
            }
        }
    }
    if count == 0 {
        return 0;
    }
    sum / count
}
fn validator_pid() -> Option<String> {
    let output = Command::new("pgrep")
        .args(["-x", "agave-validator"])
        .output()
        .ok()?;

    let text = String::from_utf8_lossy(&output.stdout);
    text.lines().next().map(|s| s.to_string())
}

fn validator_rss_kb() -> u64 {
    let pid = match validator_pid() {
        Some(p) => p,
        None => return 0,
    };

    let path = format!("/proc/{}/status", pid);
    let content = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return 0,
    };

    for line in content.lines() {
        if line.starts_with("VmRSS:") {
            for part in line.split_whitespace() {
                if let Ok(n) = part.parse::<u64>() {
                    return n;
                }
            }
        }
    }
    0
}

fn read_cpu_ticks() -> (u64, u64) {
    let content = match fs::read_to_string("/proc/stat") {
        Ok(c) => c,
        Err(_) => return (0, 0),
    };

    let mut total = 0u64;
    let mut idle = 0u64;

    for line in content.lines() {
        for core in 16..=23 {
            if line.starts_with(&format!("cpu{} ", core)) {
                let nums: Vec<u64> = line
                    .split_whitespace()
                    .skip(1)
                    .filter_map(|s| s.parse().ok())
                    .collect();

                total += nums.iter().sum::<u64>();
                idle += nums.get(3).copied().unwrap_or(0);
            }
        }
    }

    (total, idle)
}

type Shared = Arc<Mutex<f64>>;

async fn cpu_watcher(shared: Shared) {
    let (mut prev_total, mut prev_idle) = read_cpu_ticks();

    loop {
        tokio::time::sleep(Duration::from_secs(1)).await;

        let (total, idle) = read_cpu_ticks();
        let d_total = total.saturating_sub(prev_total);
        let d_idle = idle.saturating_sub(prev_idle);

        if d_total > 0 {
            let busy = (d_total - d_idle) as f64 / d_total as f64 * 100.0;
            *shared.lock().await = busy;
        }

        prev_total = total;
        prev_idle = idle;
    }
}

async fn metrics(axum::extract::State(shared): axum::extract::State<Shared>) -> String {
    let cpu = *shared.lock().await;
    format!(
        "grpc_connections {}\nrpc_connections {}\nreplay_elapsed_us {}\npubsub_connections {}\npubsub_sendq_bytes {}\nvalidator_rss_kb {}\ncpu_geyser_pct {:.2}\n",
        grpc_connections(),
        rpc_connections(),
	replay_elapsed_us(),
        pubsub_connections(),
        pubsub_sendq_bytes(),
        validator_rss_kb(),
        cpu
    )
}

#[tokio::main]
async fn main() {
    let shared: Shared = Arc::new(Mutex::new(0.0));
    tokio::spawn(cpu_watcher(shared.clone()));

    let app = Router::new()
        .route("/metrics", get(metrics))
        .with_state(shared);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:9101")
        .await
        .unwrap();

    println!("слушаю на 0.0.0.0:9101");
    axum::serve(listener, app).await.unwrap();
}
