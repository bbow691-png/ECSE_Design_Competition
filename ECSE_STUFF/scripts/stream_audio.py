import serial
import soundcard as sc
import numpy as np
import time

PORT = "COM5"
BAUD = 921600
SAMPLE_RATE = 22050
CHUNK_SIZE = 256


#Im not even going to pretend I know whats happening here, this some wild shit
def stream_loopback(port, baud):
    speaker = sc.default_speaker()
    mic = sc.get_microphone(speaker.id, include_loopback=True)
    print(f"Capturing from: {speaker.name}")                #Prints the name of the captured sound device
    print(f"Sample rate: {SAMPLE_RATE}Hz | Port: {port}")   #Prints the captured samplerate and used port
    
    
    with serial.Serial(port, baud, timeout=1) as ser:
        time.sleep(2)
        print("Streaming started — press Ctrl+C to stop")
        with mic.recorder(samplerate=SAMPLE_RATE, channels=2) as recorder:
            while True:
                data = recorder.record(numframes=CHUNK_SIZE)
                data_int16 = (data * 32767).astype(np.int16)
                ser.write(data_int16.tobytes())

#some error or exception handling, idk tbh.
if __name__ == "__main__":
    try:
        stream_loopback(PORT, BAUD)
    except KeyboardInterrupt:
        print("\nStreaming stopped")
    except serial.SerialException as e:
        print(f"Serial error: {e}")
    except Exception as e:
        print(f"Error: {e}")