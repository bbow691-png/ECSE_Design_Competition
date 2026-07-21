import librosa # pip install librosa
import numpy as np
import json

def classify_hit(y, sr, onset_sample, window=2048):
    """Analyze a short snippet after the onset to classify the drum sound."""
    end = min(onset_sample + window, len(y))
    snippet = y[onset_sample:end]
    
    if len(snippet) < 512:  # too short near end of track
        return 4
    
    # Spectral centroid: low value = bassy/kick, high value = bright/hi-hat
    centroid = librosa.feature.spectral_centroid(y=snippet, sr=sr)[0].mean()
    
    # RMS energy: how loud/punchy the hit is
    rms = librosa.feature.rms(y=snippet)[0].mean()
    
    # Zero-crossing rate: hi-hats/cymbals have noisy, high ZCR; kicks are smooth/low
    zcr = librosa.feature.zero_crossing_rate(snippet)[0].mean()
    
    # Simple rule-based classification (tune thresholds by ear/testing)
    if centroid < 1000 and rms > 0.05:
        return 1  # Kick — low frequency, punchy
    elif centroid < 2500 and zcr < 0.15:
        return 2  # Snare — mid-low, moderate noisiness
    elif centroid < 4000:
        return 3  # Tom/clap — mid frequency
    else:
        return 4  # Hi-hat/cymbal — bright, high ZCR


def generate_smart_beatmap(mp3_path, title="Untitled"):
    y, sr = librosa.load(mp3_path)
    
    onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units='frames', backtrack=True)
    onset_times = librosa.frames_to_time(onset_frames, sr=sr)
    onset_samples = librosa.frames_to_samples(onset_frames)
    
    notes = []
    for t, sample in zip(onset_times, onset_samples):
        pad = classify_hit(y, sr, sample)
        notes.append({"time": round(float(t), 3), "pad": pad})
    
    beatmap = {"title": title, "notes": notes}
    
    with open("beatmap.json", "w") as f:
        json.dump(beatmap, f, indent=2)
    
    print(f"Generated {len(notes)} notes")
    return beatmap

generate_smart_beatmap("song1.mp3", title="8bit Dungeon Boss")