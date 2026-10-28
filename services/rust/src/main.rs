use std::io::{Read, Write};
use std::net::TcpListener;

fn main() {
    let host = std::fs::read_to_string("/etc/hostname").unwrap_or_default();
    let listener = TcpListener::bind("0.0.0.0:8080").expect("bind :8080");
    println!("rust hue listening on :8080");
    for stream in listener.incoming().flatten() {
        let mut stream = stream;
        let mut buf = [0u8; 1024];
        let _ = stream.read(&mut buf);
        let body = format!(
            r##"{{"lang":"rust","color":"#DEA584","host":"{}"}}"##,
            host.trim()
        );
        let resp = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            body.len(),
            body
        );
        let _ = stream.write_all(resp.as_bytes());
    }
}
