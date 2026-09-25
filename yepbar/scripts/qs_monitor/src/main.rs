use std::fs;
use std::path::Path;
use std::process::Command;
use std::thread;
use std::time::Duration;

fn get_cpu_temp() -> i32 {
    // Try hwmon entries first
    if let Ok(entries) = fs::read_dir("/sys/class/hwmon") {
        for entry in entries.flatten() {
            let temp_path = entry.path().join("temp1_input");
            if temp_path.exists() {
                if let Ok(content) = fs::read_to_string(&temp_path) {
                    if let Ok(val) = content.trim().parse::<i32>() {
                        if val > 0 {
                            return val / 1000;
                        }
                    }
                }
            }
        }
    }
    // Fallback thermal_zone
    if let Ok(content) = fs::read_to_string("/sys/class/thermal/thermal_zone0/temp") {
        if let Ok(val) = content.trim().parse::<i32>() {
            return val / 1000;
        }
    }
    0
}

fn get_battery_info() -> (i32, String, bool) {
    let mut capacity = 100;
    let mut status = "Unknown".to_string();
    let mut exists = false;

    let bat_paths = ["/sys/class/power_supply/BAT1", "/sys/class/power_supply/BAT0"];
    for p in bat_paths {
        let base = Path::new(p);
        if base.exists() {
            exists = true;
            if let Ok(cap) = fs::read_to_string(base.join("capacity")) {
                if let Ok(val) = cap.trim().parse::<i32>() {
                    capacity = val;
                }
            }
            if let Ok(st) = fs::read_to_string(base.join("status")) {
                status = st.trim().to_string();
            }
            break;
        }
    }
    (capacity, status, exists)
}

fn get_memory_info() -> (f64, f64, i32) {
    if let Ok(content) = fs::read_to_string("/proc/meminfo") {
        let mut total_kb = 0.0;
        let mut avail_kb = 0.0;
        for line in content.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                if parts[0] == "MemTotal:" {
                    total_kb = parts[1].parse::<f64>().unwrap_or(0.0);
                } else if parts[0] == "MemAvailable:" {
                    avail_kb = parts[1].parse::<f64>().unwrap_or(0.0);
                }
            }
        }
        let total_gb = total_kb / (1024.0 * 1024.0);
        let used_gb = (total_kb - avail_kb) / (1024.0 * 1024.0);
        let pct = if total_gb > 0.0 {
            ((used_gb / total_gb) * 100.0).round() as i32
        } else {
            0
        };
        return (
            (used_gb * 10.0).round() / 10.0,
            (total_gb * 10.0).round() / 10.0,
            pct,
        );
    }
    (0.0, 0.0, 0)
}

#[repr(C)]
struct Statvfs {
    f_bsize: libc::c_ulong,
    f_frsize: libc::c_ulong,
    f_blocks: libc::fsblkcnt_t,
    f_bfree: libc::fsblkcnt_t,
    f_bavail: libc::fsblkcnt_t,
    f_files: libc::fsfilcnt_t,
    f_ffree: libc::fsfilcnt_t,
    f_favail: libc::fsfilcnt_t,
    f_fsid: libc::c_ulong,
    f_flag: libc::c_ulong,
    f_namemax: libc::c_ulong,
    __f_spare: [libc::c_int; 6],
}

extern "C" {
    fn statvfs(path: *const libc::c_char, buf: *mut Statvfs) -> libc::c_int;
}

fn get_disk_info(mount_path: &str) -> (bool, f64, f64, i32) {
    if !Path::new(mount_path).exists() {
        return (false, 0.0, 0.0, 0);
    }
    let c_path = std::ffi::CString::new(mount_path).unwrap();
    let mut stat: Statvfs = unsafe { std::mem::zeroed() };
    if unsafe { statvfs(c_path.as_ptr(), &mut stat) } == 0 {
        let block_size = stat.f_frsize as f64;
        let total_bytes = stat.f_blocks as f64 * block_size;
        let avail_bytes = stat.f_bavail as f64 * block_size;
        let used_bytes = total_bytes - avail_bytes;

        let total_gb = total_bytes / (1024.0 * 1024.0 * 1024.0);
        let used_gb = used_bytes / (1024.0 * 1024.0 * 1024.0);
        let pct = if total_gb > 0.0 {
            ((used_gb / total_gb) * 100.0).round() as i32
        } else {
            0
        };
        return (
            true,
            (used_gb * 10.0).round() / 10.0,
            (total_gb * 10.0).round() / 10.0,
            pct,
        );
    }
    (false, 0.0, 0.0, 0)
}

fn format_bandwidth(bps: f64) -> String {
    if bps >= 10.0 * 1024.0 * 1024.0 {
        format!("{:>5}M/s", (bps / (1024.0 * 1024.0)).round() as i64)
    } else if bps >= 1024.0 * 1024.0 {
        format!("{:>5.1}M/s", bps / (1024.0 * 1024.0))
    } else if bps >= 1024.0 {
        format!("{:>5}K/s", (bps / 1024.0).round() as i64)
    } else {
        format!("{:>5}B/s", bps.round() as i64)
    }
}

fn get_cpu_and_net_counters() -> (u64, u64, u64, u64) {
    let mut total_cpu = 0u64;
    let mut idle_cpu = 0u64;
    if let Ok(content) = fs::read_to_string("/proc/stat") {
        if let Some(line) = content.lines().next() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 5 {
                let user: u64 = parts[1].parse().unwrap_or(0);
                let nice: u64 = parts[2].parse().unwrap_or(0);
                let system: u64 = parts[3].parse().unwrap_or(0);
                let idle: u64 = parts[4].parse().unwrap_or(0);
                let iowait: u64 = parts.get(5).and_then(|s| s.parse().ok()).unwrap_or(0);
                let irq: u64 = parts.get(6).and_then(|s| s.parse().ok()).unwrap_or(0);
                let softirq: u64 = parts.get(7).and_then(|s| s.parse().ok()).unwrap_or(0);
                let steal: u64 = parts.get(8).and_then(|s| s.parse().ok()).unwrap_or(0);

                idle_cpu = idle + iowait;
                total_cpu = user + nice + system + idle + iowait + irq + softirq + steal;
            }
        }
    }

    let mut rx_bytes = 0u64;
    let mut tx_bytes = 0u64;
    if let Ok(content) = fs::read_to_string("/proc/net/dev") {
        for line in content.lines().skip(2) {
            if let Some((iface, data)) = line.split_once(':') {
                let name = iface.trim();
                if name != "lo" && !name.starts_with("veth") && !name.starts_with("docker") {
                    let vals: Vec<&str> = data.split_whitespace().collect();
                    if vals.len() >= 9 {
                        rx_bytes += vals[0].parse::<u64>().unwrap_or(0);
                        tx_bytes += vals[8].parse::<u64>().unwrap_or(0);
                    }
                }
            }
        }
    }
    (total_cpu, idle_cpu, rx_bytes, tx_bytes)
}

fn get_network_status() -> (bool, bool, bool) {
    if let Ok(output) = Command::new("nmcli")
        .env("LC_ALL", "C")
        .args(["-t", "-f", "TYPE,STATE,DEVICE", "device"])
        .output()
    {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut wifi = false;
        let mut eth = false;
        let mut connecting = false;

        for line in stdout.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 2 {
                let dev_type = parts[0];
                let dev_state = parts[1];
                let dev_name = if parts.len() >= 3 { parts[2] } else { "" };

                if dev_type == "wifi" && (dev_state == "connected" || dev_state.contains("conect")) {
                    wifi = true;
                } else if dev_type == "ethernet" && (dev_state == "connected" || dev_state.contains("conect")) && !dev_name.starts_with("veth") {
                    eth = true;
                } else if dev_state.contains("connecting") || dev_state.contains("conectando") {
                    connecting = true;
                }
            }
        }
        return (wifi, eth, connecting);
    }
    (false, false, false)
}

fn main() {
    let (t1, i1, rx1, tx1) = get_cpu_and_net_counters();
    thread::sleep(Duration::from_millis(100));
    let (t2, i2, rx2, tx2) = get_cpu_and_net_counters();

    let dt = t2.saturating_sub(t1);
    let di = i2.saturating_sub(i1);
    let cpu_pct = if dt > 0 {
        (((dt - di) as f64 / dt as f64) * 100.0).round() as i32
    } else {
        0
    };

    let rx_bps = (rx2.saturating_sub(rx1) as f64) / 0.1;
    let tx_bps = (tx2.saturating_sub(tx1) as f64) / 0.1;

    let rx_str = format_bandwidth(rx_bps);
    let tx_str = format_bandwidth(tx_bps);

    let (used_ram, total_ram, ram_pct) = get_memory_info();
    let (root_exists, root_used, root_total, root_pct) = get_disk_info("/");
    let (storage_exists, storage_used, storage_total, storage_pct) = get_disk_info("/mnt/storage");
    let (bat_cap, bat_status, bat_exists) = get_battery_info();
    let cpu_temp = get_cpu_temp();
    let (wifi_conn, eth_conn, net_connecting) = get_network_status();

    let output = format!(
        r#"{{"cpu":{},"cpu_temp":{},"ram_used":{},"ram_total":{},"ram_pct":{},"net_rx":"{}","net_tx":"{}","root_disk":{{"exists":{},"used_gb":{},"total_gb":{},"percent":{}}},"storage_disk":{{"exists":{},"used_gb":{},"total_gb":{},"percent":{}}},"battery":{{"exists":{},"capacity":{},"status":"{}"}},"network":{{"wifi":{},"eth":{},"connecting":{}}}}}"#,
        cpu_pct,
        cpu_temp,
        used_ram,
        total_ram,
        ram_pct,
        rx_str,
        tx_str,
        root_exists,
        root_used,
        root_total,
        root_pct,
        storage_exists,
        storage_used,
        storage_total,
        storage_pct,
        bat_exists,
        bat_cap,
        bat_status,
        wifi_conn,
        eth_conn,
        net_connecting
    );

    println!("{}", output);
}
