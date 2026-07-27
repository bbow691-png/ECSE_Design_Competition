import serial
import soundcard as sc
import numpy as np
import socket
import re
import threading
import time

PORT = "COM3" # MAKE SURE TO MATCH THIS TO THE PORT YOUR ESP IS CONNECTED TO
BAUD = 921600
SAMPLE_RATE = 22050
CHUNK_SIZE = 256

# UDP config (piezo hits -> Godot). Matches godot/ecse-design/scripts/piezo_input.gd's contract.
UDP_IP = "127.0.0.1"
UDP_PORT = 5005

# Match lines like: HIT:1 (channel only - the game doesn't use hit velocity)
HIT_PATTERN = re.compile(rb'HIT:(\d+)')

def read_hits(ser, sock, stop_event):
    buf = bytearray()
    while not stop_event.is_set():
        try:
            # Safely check if port is open before reading
            if not ser.is_open:
                break

            in_wait = ser.in_waiting if ser.is_open else 0
            chunk = ser.read(max(in_wait, 1))
        except Exception:
            break

        if not chunk:
            continue

        buf.extend(chunk)
        while b"\n" in buf:
            line, _, rest = buf.partition(b"\n")
            buf = bytearray(rest)
            match = HIT_PATTERN.search(line)
            if match:
                channel = match.group(1).decode()
                sock.sendto(channel.encode(), (UDP_IP, UDP_PORT))
                print(f"Hit: Piezo {channel}")


def stream_loopback(ser, stop_event):
    speaker = sc.default_speaker()
    mic = sc.get_microphone(speaker.id, include_loopback=True)
    print(f"Capturing from: {speaker.name}")
    print(f"Sample rate: {SAMPLE_RATE}Hz | Port: {ser.port}")

    with mic.recorder(samplerate=SAMPLE_RATE, channels=2) as recorder:
        while not stop_event.is_set():
            data = recorder.record(numframes=CHUNK_SIZE)
            data_int16 = (data * 32767).astype(np.int16)
            ser.write(data_int16.tobytes())


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    stop_event = threading.Event()
    ser = None
    reader_thread = None

    try:
        ser = serial.Serial(PORT, BAUD, timeout=0.1)
        time.sleep(2)

        reader_thread = threading.Thread(
            target=read_hits, args=(ser, sock, stop_event), daemon=True
        )
        reader_thread.start()

        print("Listening for piezo hits — press Ctrl+C to stop")
        # stream_loopback(ser, stop_event)

        # Keep the main thread alive indefinitely while read_hits() runs in
        # the background. Without this, main() falls straight through to
        # `finally` right after starting the thread (since stream_loopback
        # is disabled) and the program shuts down almost immediately instead
        # of staying up to listen for piezo hits.
        while not stop_event.is_set():
            time.sleep(0.5)

    finally:
        print("\nCleaning up resources...")
        # 1. Signal thread to exit loops
        stop_event.set()

        # 2. Give the thread time to release the serial port
        if reader_thread and reader_thread.is_alive():
            reader_thread.join(timeout=1.0)

        # 3. Explicitly close port and socket safely
        if ser and ser.is_open:
            ser.close()
            print("Serial port closed successfully.")

        sock.close()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Streaming stopped by user.")
    except serial.SerialException as e:
        print(f"Serial error: {e}")