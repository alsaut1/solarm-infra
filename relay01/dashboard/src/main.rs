use axum::{extract::Query, response::Html, routing::get, Json, Router};
use serde::{Deserialize, Serialize};
use std::fs;

const CSV: &str = "/home/alsaut/scripts/metrics.csv";
const INDEX: &str = "/home/alsaut/projects/dashboard/static/index.html";

#[derive(Serialize)]
struct Point {
    ts: String,
    conns: u64,
    rpc_conns: u64,
    pubsub_conns: u64,
    pubsub_sendq: u64,
    replay_us: u64,
    rss_kb: u64,
    cpu_pct: f64,
    lag: i64,
    fin: i64,
    delay: i64,
    queue: u64,
    traffic: u64,
}

#[derive(Deserialize)]
struct Params {
    limit: Option<usize>,
    every: Option<usize>,
}

fn read_points(limit: usize, every: usize) -> Vec<Point> {
    let content = match fs::read_to_string(CSV) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };

    let every = if every == 0 { 1 } else { every };

    let lines: Vec<&str> = content.lines().skip(1).collect();
    let want = limit.saturating_mul(every);
    let start = lines.len().saturating_sub(want);

    let mut out = Vec::new();
    for (i, line) in lines[start..].iter().enumerate() {
        if i % every != 0 {
            continue;
        }
        let f: Vec<&str> = line.split(',').collect();
        if f.len() < 16 {
            continue;
        }
        let num = |i: usize| -> i64 { f[i].parse().unwrap_or(0) };
        out.push(Point {
            ts: f[0].to_string(),
            conns: num(1) as u64,
            rss_kb: num(2) as u64,
            cpu_pct: f[3].parse().unwrap_or(0.0),
            lag: num(6) - num(4),
            fin: num(4) - num(5),
            delay: num(4) - num(7),
            queue: num(8) as u64,
            traffic: num(11) as u64,
            rpc_conns: num(12) as u64,
            pubsub_conns: num(13) as u64,
            pubsub_sendq: num(14) as u64,
            replay_us: num(15) as u64,
        });
    }
    out
}

async fn index() -> Html<String> {
    Html(fs::read_to_string(INDEX).unwrap_or_else(|_| "нет файла static/index.html".to_string()))
}

async fn api(Query(p): Query<Params>) -> Json<Vec<Point>> {
    let limit = p.limit.unwrap_or(240).min(5000);
    let every = p.every.unwrap_or(1).max(1);
    Json(read_points(limit, every))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(index))
        .route("/api/metrics", get(api));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:9200")
        .await
        .unwrap();

    println!("дашборд на 0.0.0.0:9200");
    axum::serve(listener, app).await.unwrap();
}
