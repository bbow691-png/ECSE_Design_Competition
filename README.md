🥁 ESP32 & Godot Rhythm Game

An open-source, hybrid rhythm game project combining custom ESP32 hardware (piezo drum pads over I2S) with a Godot 4.x game engine frontend. Hit your physical drum kit, stream analog transients via high-speed ADC sampling, and watch the notes fall in sync on your screen!

🛠️ Project Structure
├── src/                      # C++ PlatformIO firmware for the ESP32
├── godot/ecse-design/        # Godot 4.x Game Engine Project
│   ├── scenes/game_scene/    # Gameplay levels, lanes, and UI
│   ├── scripts/              # SongManager, PiezoInput, and Conductor logic
│   └── songs/                # JSON-based custom beatmaps & audio
└── run_instructions.md       # Detailed local setup guide
⚡ Part 1: Hardware Setup & ESP32 Firmware

The ESP32 uses built-in I2S ADC sampling at 20kHz to capture percussive transients from up to 4 piezo drum pads simultaneously, translating analog strikes into MIDI velocity data over USB Serial.

Prerequisites
VS Code with the PlatformIO extension installed
Flashing the ESP32
Open VS Code and use File > Open Folder to select the root folder containing your platformio.ini file.
Wait for PlatformIO to automatically download the required ESP32 toolchains and Arduino frameworks.
Plug your ESP32 into your computer via USB.
Click the Upload and Monitor button on the bottom status bar (or run PlatformIO: Upload and Monitor).
Tap your piezo drums — you should see live symbols popping up in the terminal.
Close the terminal and run stream_audio.py. This will result in meaningful text appearing in your terminal.
🎮 Part 2: Godot Game Engine Setup

The Godot frontend listens to incoming serial/network streams, handles lane input, and manages synchronized audio tracking alongside JSON-driven beatmaps.

Prerequisites
Godot Engine 4.x
Running the Project
Launch Godot Engine and click Import on the Project Manager screen.
Navigate into the repository folder, select the godot/ecse-design/ sub-folder, and select the project.godot file.
Once the editor loads your project, click the Play button (or press F5) in the top right corner.
🎵 Adding Custom Songs & Beatmaps

Songs are loaded dynamically via JSON files processed globally by the SongManager singleton.

To add a new song:

Create a folder inside res://songs/your_song_name/.
Add your audio file and a beatmap.json file structured like this:
json
{
  "title": "Your Song Title",
  "bpm": 120,
  "notes": [
    { "time": 2.0, "pad": 0 },
    { "time": 3.0, "pad": 1 },
    { "time": 4.0, "pad": 2 },
    { "time": 5.0, "pad": 3 }
  ]
}
Trigger the song in your scene script:
gdscript
SongManager.load_and_play_song("res://songs/your_song_name")
📄 License

This project is open-source and available for educational and personal use.