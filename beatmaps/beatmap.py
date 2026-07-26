#!/usr/bin/env python3
"""
osu_to_beatmap.py (Unified Converter & Audio Extractor)

Converts an osu! beatmap (.osz package or a single .osu file) into the
project's rhythm-game JSON format, and can accurately extract its audio.
"""

import argparse
import json
import os
import re
import shutil
import sys
import zipfile

PLAYFIELD_WIDTH = 512


def parse_osu_sections(lines):
    """
    Splits the file lines into named sections (General, Metadata, etc.)
    and returns them as a dict of section_name -> list[str] raw lines.
    """
    sections = {}
    current = None
    for raw_line in lines:
        line = raw_line.rstrip("\r\n")
        if not line:
            continue
        header_match = re.match(r"^\[(\w+)\]$", line)
        if header_match:
            current = header_match.group(1)
            sections[current] = []
            continue
        if current is not None:
            sections[current].append(line)
    return sections


def parse_key_values(lines):
    """Parse 'Key: Value' lines."""
    kv = {}
    for line in lines:
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        kv[key.strip()] = value.strip()
    return kv


class OsuMap:
    """Helper class to hold parsed map metadata."""
    def __init__(self, filename, lines):
        self.filename = filename
        self.sections = parse_osu_sections(lines)
        self.meta = parse_key_values(self.sections.get("Metadata", []))
        self.general = parse_key_values(self.sections.get("General", []))
        
        self.title = self.meta.get("Title", os.path.splitext(os.path.basename(filename))[0])
        self.difficulty_name = self.meta.get("Version", os.path.basename(filename))
        self.audio_filename = self.general.get("AudioFilename", "")


def compute_bpm(timing_point_lines):
    for line in timing_point_lines:
        parts = line.split(",")
        if len(parts) < 2:
            continue
        try:
            beat_length = float(parts[1])
        except ValueError:
            continue
        if beat_length > 0:
            return 60000.0 / beat_length
    return 0.0


def x_to_pad(x, pads):
    x = min(max(x, 0), PLAYFIELD_WIDTH - 1)
    column = int(x / PLAYFIELD_WIDTH * pads)
    return min(max(column, 0), pads - 1) + 1


def estimate_slider_duration_ms(params, timing_point_lines, hit_time_ms, slider_multiplier):
    try:
        repeat_count = int(params[1])
        pixel_length = float(params[2])
    except (IndexError, ValueError):
        return 0.0

    sv_multiplier = 1.0
    beat_length = 500.0
    for line in timing_point_lines:
        parts = line.split(",")
        if len(parts) < 2:
            continue
        try:
            t = float(parts[0])
            bl = float(parts[1])
        except ValueError:
            continue
        if t > hit_time_ms:
            break
        if bl > 0:
            beat_length = bl
            sv_multiplier = 1.0
        else:
            sv_multiplier = -100.0 / bl

    px_per_beat = slider_multiplier * 100.0 * sv_multiplier
    if px_per_beat <= 0:
        return 0.0

    duration_per_slide = (pixel_length / px_per_beat) * beat_length
    return duration_per_slide * repeat_count


def parse_ratio(ratio_str):
    match = re.match(r"^\s*(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)\s*$", ratio_str)
    if not match:
        raise argparse.ArgumentTypeError(f"Invalid ratio '{ratio_str}'")
    a, b = float(match.group(1)), float(match.group(2))
    if a <= 0 or b <= 0:
        raise argparse.ArgumentTypeError("Ratio parts must be positive")
    return (a, b)


def assign_boss_sections(notes, bpm, difficulty_name, section_beats, ratio_override=None):
    if bpm <= 0:
        for note in notes:
            note["boss"] = 0
        return notes

    if ratio_override is not None:
        boss_ratio, player_ratio = ratio_override
    elif "easy" in difficulty_name.lower():
        boss_ratio, player_ratio = (1.0, 1.0)
    else:
        boss_ratio, player_ratio = (3.0, 1.0)

    beat_length_sec = 60.0 / bpm
    boss_len = section_beats * beat_length_sec * boss_ratio
    player_len = section_beats * beat_length_sec * player_ratio
    cycle_len = boss_len + player_len

    for note in notes:
        position_in_cycle = note["time"] % cycle_len
        note["boss"] = 1 if position_in_cycle < boss_len else 0
    return notes


def convert_hit_objects(sections, pads, include_slider_ends, include_spinners):
    hit_object_lines = sections.get("HitObjects", [])
    timing_point_lines = sections.get("TimingPoints", [])
    difficulty = parse_key_values(sections.get("Difficulty", []))
    slider_multiplier = float(difficulty.get("SliderMultiplier", 1.4))

    notes = []
    for line in hit_object_lines:
        parts = line.split(",")
        if len(parts) < 4:
            continue
        try:
            x = float(parts[0])
            time_ms = float(parts[2])
            obj_type = int(parts[3])
        except ValueError:
            continue

        is_circle = bool(obj_type & 1)
        is_slider = bool(obj_type & 2)
        is_spinner = bool(obj_type & 8)
        pad = x_to_pad(x, pads)

        if is_circle:
            notes.append({"time": time_ms / 1000.0, "pad": pad})

        elif is_slider:
            notes.append({"time": time_ms / 1000.0, "pad": pad})
            if include_slider_ends:
                slider_params = [parts[5] if len(parts) > 5 else ""] + parts[6:8]
                duration_ms = estimate_slider_duration_ms(
                    slider_params, timing_point_lines, time_ms, slider_multiplier
                )
                if duration_ms > 0:
                    notes.append({
                        "time": (time_ms + duration_ms) / 1000.0,
                        "pad": pad,
                    })

        elif is_spinner:
            if include_spinners:
                notes.append({"time": time_ms / 1000.0, "pad": pad})

    notes.sort(key=lambda n: n["time"])
    return notes


def convert_osu_file(osu_map, pads, include_slider_ends, include_spinners, boss_section_beats, boss_ratio_override=None):
    bpm = compute_bpm(osu_map.sections.get("TimingPoints", []))
    notes = convert_hit_objects(osu_map.sections, pads, include_slider_ends, include_spinners)

    assign_boss_sections(notes, bpm, osu_map.difficulty_name, boss_section_beats, boss_ratio_override)

    return {
        "source_file": os.path.basename(osu_map.filename),
        "title": osu_map.title,
        "difficulty": osu_map.difficulty_name,
        "tempo_bpm": round(bpm, 2),
        "pads": pads,
        "note_count": len(notes),
        "notes": notes,
    }


def main():
    parser = argparse.ArgumentParser(description="Convert an osu! beatmap and optionally extract its audio.")
    parser.add_argument("input", help="Path to a .osz package or a single .osu file")
    parser.add_argument("-o", "--output", help="Path to the output JSON file")
    parser.add_argument("--difficulty", help="Difficulty name to convert")
    parser.add_argument("--list", action="store_true", help="List the difficulties available in the .osz")
    parser.add_argument("--pads", type=int, default=4, help="Number of pads/lanes (default: 4)")
    parser.add_argument("--slider-ends", action="store_true", help="Add a note at the end of each slider")
    parser.add_argument("--spinners", action="store_true", help="Add a note at the start of each spinner")
    parser.add_argument("--boss-section-beats", type=float, default=8.0, help="Boss/player chunk length in beats")
    parser.add_argument("--boss-ratio", type=parse_ratio, default=None, help="Override boss:player ratio (e.g. '1:3')")
    parser.add_argument("--song-folder", help="Exports to this folder ready for Godot (beatmap.json + song1.mp3)")
    parser.add_argument("--extract-audio", action="store_true", help="Extract the exact audio file locally with its original name")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        sys.exit(f"Error: file not found: {args.input}")

    maps = []
    is_zip = args.input.lower().endswith(".osz")
    zf = None

    try:
        # 1. Read files into memory (directly from ZIP or disk)
        if is_zip:
            zf = zipfile.ZipFile(args.input)
            osu_names = [n for n in zf.namelist() if n.lower().endswith(".osu")]
            for name in osu_names:
                with zf.open(name) as f:
                    lines = [line.decode("utf-8-sig") for line in f]
                maps.append(OsuMap(name, lines))
        elif args.input.lower().endswith(".osu"):
            with open(args.input, "r", encoding="utf-8-sig") as f:
                lines = f.readlines()
            maps.append(OsuMap(args.input, lines))
        else:
            sys.exit("Error: input must be a .osz or .osu file")

        if not maps:
            sys.exit("Error: no .osu files found")

        # 2. Select the right difficulty
        if args.list:
            print("Available difficulties:")
            for m in maps:
                print(f"  - {m.difficulty_name}")
            return

        if len(maps) == 1:
            chosen = maps[0]
        else:
            if not args.difficulty:
                print("Multiple difficulties found; pass --difficulty to pick one:", file=sys.stderr)
                for m in maps:
                    print(f"  - {m.difficulty_name}", file=sys.stderr)
                sys.exit(1)
                
            wanted = args.difficulty.lower()
            candidates = [m for m in maps if wanted in m.difficulty_name.lower()]
            if not candidates:
                sys.exit(f"Error: no difficulty matching '{args.difficulty}'")
            if len(candidates) > 1:
                print(f"Error: '{args.difficulty}' matches multiple difficulties:", file=sys.stderr)
                for m in candidates:
                    print(f"  - {m.difficulty_name}", file=sys.stderr)
                sys.exit(1)
            chosen = candidates[0]

        # 3. Convert beatmap logic
        print(f"Converting difficulty: {chosen.difficulty_name}")
        result = convert_osu_file(
            chosen, args.pads, args.slider_ends, args.spinners,
            args.boss_section_beats, args.boss_ratio,
        )

        # 4. Handle JSON output
        difficulty_slug = re.sub(r"[^a-zA-Z0-9]+", "_", chosen.difficulty_name).strip("_").lower()
        output_path = args.output or f"{difficulty_slug}_beatmap.json"

        if args.song_folder:
            os.makedirs(args.song_folder, exist_ok=True)
            output_path = os.path.join(args.song_folder, "beatmap.json")

        with open(output_path, "w") as f:
            json.dump(result, f, indent=2)

        boss_count = sum(1 for n in result["notes"] if n["boss"] == 1)
        print(f"Tempo: {result['tempo_bpm']} BPM")
        print(f"Notes: {result['note_count']} ({boss_count} boss / {result['note_count'] - boss_count} player)")
        print(f"Wrote '{output_path}'")

        # 5. Handle Audio Extraction using parsed AudioFilename
        if chosen.audio_filename and (args.song_folder or args.extract_audio):
            # Target path depends on whether we are formatting for Godot or local extraction
            if args.song_folder:
                dest_audio = os.path.join(args.song_folder, "song1.mp3")
            else:
                dest_audio = chosen.audio_filename

            if is_zip:
                # Find matching file in zip (case-insensitive search)
                audio_member = next((n for n in zf.namelist() if n.lower() == chosen.audio_filename.lower()), None)
                if audio_member:
                    with zf.open(audio_member) as src, open(dest_audio, "wb") as dst:
                        shutil.copyfileobj(src, dst)
                    print(f"Extracted audio to '{dest_audio}'")
                else:
                    print(f"Warning: Audio '{chosen.audio_filename}' not found in archive", file=sys.stderr)
            else:
                audio_src = os.path.join(os.path.dirname(os.path.abspath(args.input)), chosen.audio_filename)
                if os.path.isfile(audio_src):
                    shutil.copyfile(audio_src, dest_audio)
                    print(f"Copied audio to '{dest_audio}'")
                else:
                    print(f"Warning: Audio file '{chosen.audio_filename}' not found on disk", file=sys.stderr)

    finally:
        if zf:
            zf.close()

if __name__ == "__main__":
    main()