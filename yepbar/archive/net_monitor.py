#!/usr/bin/env python3
"""
net_monitor.py - NetworkManager Device Status Parser for Quickshell
Returns JSON formatted Wi-Fi, Ethernet, and connection progress states.
"""

import subprocess
import json

def get_network_status():
    """Parses nmcli output to check Wi-Fi, Ethernet, and connecting states."""
    try:
        out = subprocess.check_output(
            ['nmcli', '-t', '-f', 'TYPE,STATE,DEVICE', 'device'],
            text=True,
            stderr=subprocess.DEVNULL
        )
        wifi_connected = False
        eth_connected = False
        net_connecting = False

        for line in out.splitlines():
            parts = line.split(':')
            if len(parts) >= 2:
                dev_type, dev_state = parts[0], parts[1]
                dev_name = parts[2] if len(parts) >= 3 else ""

                if dev_type == 'wifi' and dev_state == 'connected':
                    wifi_connected = True
                elif dev_type == 'ethernet' and dev_state == 'connected' and not dev_name.startswith('veth'):
                    eth_connected = True
                elif 'connecting' in dev_state:
                    net_connecting = True

        return {
            'wifi': wifi_connected,
            'eth': eth_connected,
            'connecting': net_connecting
        }
    except Exception:
        return {'wifi': False, 'eth': False, 'connecting': False}

def main():
    print(json.dumps(get_network_status()))

if __name__ == '__main__':
    main()
