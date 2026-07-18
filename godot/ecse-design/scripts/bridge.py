import serial
import socket
import re
import sys

# Serial config (piezo hits from ESP32)
PORT     = "COM5"       # Change to your ESP32's port
BAUD     = 115200

# UDP config (hits to Godot)
UDP_IP   = "127.0.0.1"
UDP_PORT = 5005

# Match lines like: HIT:1:87
pattern = re.compile(r'HIT:(\d+):(\d+)')

def main():
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1)
    except serial.SerialException as e:
        print(f"Serial error: {e}", file=sys.stderr)
        sys.exit(1)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    print(f"Bridge running — {PORT} → UDP {UDP_PORT}", flush=True)

    while True:
        try:
            line = ser.readline().decode().strip()
            match = pattern.search(line)
            if match:
                channel  = match.group(1)  # "1"-"4"
                velocity = match.group(2)  # "1"-"127"
                packet   = f"{channel}:{velocity}"
                sock.sendto(packet.encode(), (UDP_IP, UDP_PORT))
                print(f"Hit: Piezo {channel} vel={velocity}", flush=True)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            break

if __name__ == "__main__":
    main()