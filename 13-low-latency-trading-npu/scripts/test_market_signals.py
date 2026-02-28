#!/usr/bin/env python3
import time
import struct
import argparse
import random
from scapy.all import Ether, IP, UDP, sendp, get_if_list

# Configuration
INTERFACE = "eno1" 
SYMBOL = "0050"

def create_packet(symbol, price, payload_bytes):
    # 1. Construct Payload
    symbol_data = symbol.ljust(4, '\x00').encode()
    price_data  = struct.pack('>I', price)
    udp_payload = symbol_data + price_data + payload_bytes
    
    # 2. Construct Ethernet Frame
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / \
          IP(dst="255.255.255.255") / \
          UDP(dport=1234, sport=1234) / \
          udp_payload
    return pkt

def send_burst(interface, count, price_mode, delay):
    print(f"Sending {count} packets. Mode: {price_mode}")
    
    payload = b'\x01\x02\x03\x04\x05\x06\x07\x08'
    
    for i in range(count):
        if price_mode == 'buy':
            # Buy Low: Price < Threshold (100)
            price = random.randint(90, 99)
        elif price_mode == 'sell':
            # Sell High: Price > Threshold (100)
            price = random.randint(101, 110)
        elif price_mode == 'mix':
            price = random.randint(90, 110)
        else: # force specific price
            price = int(price_mode)
            
        pkt = create_packet(SYMBOL, price, payload)
        sendp(pkt, iface=interface, verbose=False)
        
        print(f"Sent Price: {price}")
        if delay > 0:
            time.sleep(delay)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Test Market Signals')
    parser.add_argument('--iface', default=INTERFACE, help=f'Network Interface (default: {INTERFACE})')
    parser.add_argument('--mode', default='mix', help='Mode: buy, sell, mix, or integer price')
    parser.add_argument('--count', type=int, default=100, help='Number of packets')
    parser.add_argument('--delay', type=float, default=0.05, help='Delay between packets (s)')
    
    args = parser.parse_args()
    
    available = get_if_list()
    if args.iface not in available:
        print(f"Warning: Interface '{args.iface}' not found. Available: {available}")
    
    try:
        send_burst(args.iface, args.count, args.mode, args.delay)
    except KeyboardInterrupt:
        print("\nStopped.")
    except Exception as e:
        print(f"\nError: {e}")
        print("Try with sudo.")
