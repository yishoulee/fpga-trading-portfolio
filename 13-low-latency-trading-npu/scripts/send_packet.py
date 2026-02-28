#!/usr/bin/env python3
import time
import struct
import argparse
from scapy.all import Ether, IP, UDP, sendp, get_if_list

# Configuration
# This is typically 'eth0', 'enp3s0', or 'eno1' on Linux.
# You can check with `ip link` or `ifconfig`.
INTERFACE = "eno1" 

def send_market_data(interface, symbol, price, payload_bytes):
    print(f"Sending packets on {interface}...")
    
    # 1. Construct Payload
    #    Symbol (4 bytes) + Price (4 bytes, Big Endian) + Extra Payload
    symbol_data = symbol.ljust(4, b'\x00') # Ensure 4 bytes, e.g., "0050"
    price_data  = struct.pack('>I', price)
    
    # Total payload = 8 bytes + extra
    udp_payload = symbol_data + price_data + payload_bytes
    
    # 2. Construct Ethernet Frame
    #    - Ethernet Header: dst="ff:ff:ff:ff:ff:ff" (Broadcast)
    #    - IP Header: dst="255.255.255.255" (Broadcast)
    #    - UDP Header: dport=1234 (Target Port)
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / \
          IP(dst="255.255.255.255") / \
          UDP(dport=1234, sport=1234) / \
          udp_payload
    
    print(f"  Symbol: {symbol}")
    print(f"  Price:  {price}")
    print(f"  Length: {len(udp_payload)} bytes")
    
    try:
        while True:
            # sendp() sends at Layer 2, bypassing ARP and IP routing tables
            sendp(pkt, iface=interface, verbose=False)
            # print(".", end="", flush=True) # Reduce I/O for speed
            time.sleep(0.001) # 1000 packets per second (Flood)
    except KeyboardInterrupt:
        print("\nStopped.")
    except PermissionError:
        print("\nError: Operation not permitted. Try running with 'sudo'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Send Market Data UDP Packet to FPGA')
    parser.add_argument('--iface', default=INTERFACE, help=f'Network Interface (default: {INTERFACE})')
    parser.add_argument('--symbol', default='0050', help='Stock Symbol (4 chars)')
    parser.add_argument('--price', type=int, default=100, help='Price (Integer)')
    
    args = parser.parse_args()
    
    # Check valid interfaces
    available = get_if_list()
    if args.iface not in available:
        print(f"Warning: Interface '{args.iface}' not found in {available}")
    
    # Construct dummy payload for the rest of the NPU stream if needed
    payload = b'\x01\x02\x03\x04\x05\x06\x07\x08' 
    
    try:
        send_market_data(args.iface, args.symbol.encode(), args.price, payload)
    except Exception as e:
        print(f"\nError: {e}")
        print("You might need to run with sudo: sudo python3 scripts/send_packet.py")
