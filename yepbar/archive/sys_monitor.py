#!/usr/bin/env python3
"""
sys_monitor.py - Real-time Linux System Resource Parser for Quickshell
Returns JSON formatted CPU, RAM, Network Bandwidth, and Disk Utilization metrics.
"""

import os
import json
import time

def get_memory_info():
    """Parses /proc/meminfo to calculate used, total, and percentage RAM."""
    try:
        with open('/proc/meminfo', 'r') as f:
            lines = f.readlines()
        info = {line.split(':')[0].strip(): int(line.split(':')[1].split()[0]) for line in lines if ':' in line}
        total_gb = info.get('MemTotal', 0) / (1024 * 1024)
        avail_gb = info.get('MemAvailable', 0) / (1024 * 1024)
        used_gb = total_gb - avail_gb
        percent = round((used_gb / total_gb) * 100) if total_gb > 0 else 0
        return round(used_gb, 1), round(total_gb, 1), percent
    except Exception:
        return 0.0, 0.0, 0

def get_disk_info(path):
    """Parses statvfs for disk space usage on a given mount path."""
    if os.path.exists(path):
        try:
            st = os.statvfs(path)
            total_gb = (st.f_blocks * st.f_frsize) / (1024**3)
            avail_gb = (st.f_bavail * st.f_frsize) / (1024**3)
            used_gb = total_gb - avail_gb
            percent = round((used_gb / total_gb) * 100) if total_gb > 0 else 0
            return {
                'exists': True,
                'used_gb': round(used_gb, 1),
                'total_gb': round(total_gb, 1),
                'percent': percent
            }
        except Exception:
            pass
    return {'exists': False}

def format_bandwidth(bps):
    """Formats raw bytes per second into human-readable network speed strings."""
    if bps >= 10 * 1024 * 1024:
        speed_str = f"{round(bps / (1024 * 1024))}M/s"
    elif bps >= 1024 * 1024:
        speed_str = f"{bps / (1024 * 1024):.1f}M/s"
    elif bps >= 1024:
        speed_str = f"{round(bps / 1024)}K/s"
    else:
        speed_str = f"{round(bps)}B/s"
    return f"{speed_str:>6}"

def get_cpu_and_network():
    """Calculates CPU usage percentage and Network Rx/Tx rates over a 100ms sample interval."""
    try:
        with open('/proc/stat', 'r') as f:
            l1 = f.readline().split()
        rx1, tx1 = 0, 0
        with open('/proc/net/dev', 'r') as f:
            for line in f.readlines()[2:]:
                parts = line.split(':')
                if len(parts) == 2:
                    dev_name = parts[0].strip()
                    if dev_name != 'lo' and not dev_name.startswith(('veth', 'docker')):
                        vals = parts[1].split()
                        rx1 += int(vals[0])
                        tx1 += int(vals[8])

        time.sleep(0.1)

        with open('/proc/stat', 'r') as f:
            l2 = f.readline().split()
        rx2, tx2 = 0, 0
        with open('/proc/net/dev', 'r') as f:
            for line in f.readlines()[2:]:
                parts = line.split(':')
                if len(parts) == 2:
                    dev_name = parts[0].strip()
                    if dev_name != 'lo' and not dev_name.startswith(('veth', 'docker')):
                        vals = parts[1].split()
                        rx2 += int(vals[0])
                        tx2 += int(vals[8])

        t1, i1 = sum(map(int, l1[1:])), int(l1[4])
        t2, i2 = sum(map(int, l2[1:])), int(l2[4])
        dt, di = t2 - t1, i2 - i1
        cpu_pct = round(((dt - di) / dt) * 100) if dt > 0 else 0

        rx_bps = (rx2 - rx1) / 0.1
        tx_bps = (tx2 - tx1) / 0.1

        return cpu_pct, format_bandwidth(rx_bps), format_bandwidth(tx_bps)
    except Exception:
        return 0, "  0B/s", "  0B/s"

def main():
    cpu_pct, net_rx, net_tx = get_cpu_and_network()
    used_ram, total_ram, ram_pct = get_memory_info()

    result = {
        'cpu': cpu_pct,
        'ram_used': used_ram,
        'ram_total': total_ram,
        'ram_pct': ram_pct,
        'net_rx': net_rx,
        'net_tx': net_tx,
        'root_disk': get_disk_info('/'),
        'storage_disk': get_disk_info('/mnt/storage')
    }
    print(json.dumps(result))

if __name__ == '__main__':
    main()
