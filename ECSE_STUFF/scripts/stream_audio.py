import serial
import soundcard as sc
import numpy as np
import socket
import re
import threading
import time

PORT = "COM9" # MAKE SURE TO MATCH THIS TO THE PORT YOUR ESP IS CONNECTED TO
BAUD = 921600
SAMPLE_RATE = 22050
CHUNK_SIZE = 256

# UDP config (piezo hits -> Godot). Matches godot/ecse-design/scripts/piezo_input.gd's contract.
UDP_IP = "127.0.0.1"
UDP_PORT = 5005

# Match lines like: HIT:1 (channel only - the game doesn't use hit velocity)
HIT_PATTERN = re.compile(rb'HIT:(\d+)')

# A serial port can only be opened by one process at a time, and the ESP32
# link needs to carry audio out and hit events back at the same time, so both
# directions are handled here in one process instead of splitting them across
# stream_audio.py and bridge.py.


def read_hits(ser, sock, stop_event):
    buf = bytearray()
    while not stop_event.is_set():
        try:
            chunk = ser.read(max(ser.in_waiting, 1))
        except Exception:
            # Port closed out from under us (e.g. main thread errored and
            # exited the `with serial.Serial(...)` block) - exit quietly.
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


def stream_loopback(ser):
    speaker = sc.default_speaker()
    mic = sc.get_microphone(speaker.id, include_loopback=True)
    print(f"Capturing from: {speaker.name}")
    print(f"Sample rate: {SAMPLE_RATE}Hz | Port: {ser.port}")

    with mic.recorder(samplerate=SAMPLE_RATE, channels=2) as recorder:
        while True:
            data = recorder.record(numframes=CHUNK_SIZE)
            data_int16 = (data * 32767).astype(np.int16)
            ser.write(data_int16.tobytes())


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    stop_event = threading.Event()

    # timeout=0.1 bounds the reader thread's blocking read() calls; it has no
    # effect on ser.write() calls made from the main thread below.
    with serial.Serial(PORT, BAUD, timeout=0.1) as ser:
        time.sleep(2)

        reader_thread = threading.Thread(target=read_hits, args=(ser, sock, stop_event), daemon=True)
        reader_thread.start()

        print("Streaming started (audio out + hit events in) — press Ctrl+C to stop")
        stream_loopback(ser)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStreaming stopped")
    except serial.SerialException as e:
        print(f"Serial error: {e}")
