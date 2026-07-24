#!/usr/bin/env python3
"""
osu_to_beatmap.py

Converts an osu! beatmap (.osz package or a single .osu file) into the
project's rhythm-game JSON format:

{
    "source_file": "...",
    "tempo_bpm": 165.8,
    "pads": 4,
    "note_count": 153,
    "notes": [
        {"time": 0.07, "pad": 2},
        {"time": 1.155, "pad": 1},
        ...
    ]
}

osu!standard maps don't have lanes — each hit object has a free x/y
position on a 512x384 playfield. This script assigns a pad by dividing
the playfield into `--pads` equal-width vertical columns (the same
technique used by osu-to-mania converters), so hits spread across the
screen become hits spread across your pads.

Sliders and spinners are held notes in osu, not discrete taps. By
default only their START is used as a hit. Use --slider-ends to also
add a note at the end of each slider, and --spinners to add a note at
the start of each spinner.

Requirements: none beyond the Python standard library.

Usage:
    # List the difficulties in a beatmap package
    python osu_to_beatmap.py map.osz --list

    # Convert one difficulty
    python osu_to_beatmap.py map.osz --difficulty Insane -o beatmap.json

    # Convert a single loose .osu file
    python osu_to_beatmap.py song.osu -o beatmap.json

    # Also stage a ready-to-drop-in song folder for the Godot project
    # (writes beatmap.json + song1.mp3 into the given folder)
    python osu_to_beatmap.py map.osz --difficulty Insane --song-folder songs/gravity_falls
"""

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile


PLAYFIELD_WIDTH = 512


def find_osu_files(root_dir):
    """Return paths to all .osu files under root_dir."""
    matches = []
    for dirpath, _dirnames, filenames in os.walk(root_dir):
        for name in filenames:
            if name.lower().endswith(".osu"):
                matches.append(os.path.join(dirpath, name))
    return sorted(matches)


def parse_osu_sections(osu_path):
    """
    Very small .osu parser: splits the file into named sections
    (General, Metadata, Difficulty, TimingPoints, HitObjects, ...)
    and returns them as a dict of path -> list[str] raw lines.
    """
    sections = {}
    current = None
    with open(osu_path, "r", encoding="utf-8-sig") as f:
        for raw_line in f:
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
    """Parse 'Key: Value' lines (General/Metadata/Difficulty sections)."""
    kv = {}
    for line in lines:
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        kv[key.strip()] = value.strip()
    return kv


def get_difficulty_name(osu_path):
    sections = parse_osu_sections(osu_path)
    meta = parse_key_values(sections.get("Metadata", []))
    return meta.get("Version", os.path.basename(osu_path))


def compute_bpm(timing_point_lines):
    """
    The primary BPM is taken from the first uninherited timing point
    (an uninherited point has a positive beatLength, in ms per beat).
    Inherited points (negative beatLength = slider-velocity multiplier)
    are skipped for this purpose.
    """
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
    """Map an osu playfield x-coordinate (0-512) to a pad 1..pads."""
    x = min(max(x, 0), PLAYFIELD_WIDTH - 1)
    column = int(x / PLAYFIELD_WIDTH * pads)
    return min(max(column, 0), pads - 1) + 1


def estimate_slider_duration_ms(params, timing_point_lines, hit_time_ms, slider_multiplier):
    """
    Rough slider duration estimate in ms, using the active inherited
    timing point's SV multiplier (if any) and the base slider multiplier
    from [Difficulty]. Good enough for placing an end-of-slider note;
    not meant to be beat-perfect.

    params: the hit object's extra field list after hitSound
        e.g. ["P|376:256|440:232", "2", "96", ...]
        index 1 = number of slides (repeat count)
        index 2 = pixel length of one slide
    """
    try:
        repeat_count = int(params[1])
        pixel_length = float(params[2])
    except (IndexError, ValueError):
        return 0.0

    # find the most recent timing point at/before hit_time to get its
    # inherited SV multiplier (negative beatLength = -100/multiplier)
    sv_multiplier = 1.0
    beat_length = 500.0  # fallback
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
                extra = parts[5:] if len(parts) > 5 else []
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


def convert_osu_file(osu_path, pads, include_slider_ends, include_spinners):
    sections = parse_osu_sections(osu_path)
    general = parse_key_values(sections.get("General", []))
    meta = parse_key_values(sections.get("Metadata", []))

    bpm = compute_bpm(sections.get("TimingPoints", []))
    notes = convert_hit_objects(sections, pads, include_slider_ends, include_spinners)

    title = meta.get("Title", os.path.splitext(os.path.basename(osu_path))[0])
    version = meta.get("Version", "")
    audio_filename = general.get("AudioFilename", "")

    result = {
        "source_file": os.path.basename(osu_path),
        "title": title,
        "difficulty": version,
        "tempo_bpm": round(bpm, 2),
        "pads": pads,
        "note_count": len(notes),
        "notes": notes,
    }
    return result, audio_filename


def main():
    parser = argparse.ArgumentParser(
        description="Convert an osu! beatmap (.osz or .osu) into the project's rhythm-game JSON format."
    )
    parser.add_argument("input", help="Path to a .osz package or a single .osu file")
    parser.add_argument(
        "-o", "--output",
        help="Path to the output JSON file (default: <difficulty>_beatmap.json)",
    )
    parser.add_argument(
        "--difficulty",
        help="Difficulty name to convert (case-insensitive substring match, "
             "e.g. 'insane'). Required if the .osz has more than one "
             "difficulty and --list is not used.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List the difficulties available in the .osz and exit",
    )
    parser.add_argument(
        "--pads",
        type=int,
        default=4,
        help="Number of pads/lanes to spread hits across (default: 4)",
    )
    parser.add_argument(
        "--slider-ends",
        action="store_true",
        help="Also emit a note at the end of each slider (approximate timing)",
    )
    parser.add_argument(
        "--spinners",
        action="store_true",
        help="Also emit a note at the start of each spinner",
    )
    parser.add_argument(
        "--song-folder",
        help="If set, also copies the audio as song1.mp3 and writes "
             "beatmap.json into this folder, ready to drop into your "
             "Godot project's res://songs/<name>/ directory",
    )
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    tmp_dir = None
    try:
        if args.input.lower().endswith(".osz"):
            tmp_dir = tempfile.mkdtemp(prefix="osz_")
            with zipfile.ZipFile(args.input) as zf:
                zf.extractall(tmp_dir)
            search_root = tmp_dir
        else:
            search_root = os.path.dirname(os.path.abspath(args.input)) or "."
            if not args.input.lower().endswith(".osu"):
                print("Error: input must be a .osz or .osu file", file=sys.stderr)
                sys.exit(1)

        if args.input.lower().endswith(".osu"):
            osu_files = [args.input]
        else:
            osu_files = find_osu_files(search_root)

        if not osu_files:
            print("Error: no .osu files found", file=sys.stderr)
            sys.exit(1)

        if args.list:
            print("Available difficulties:")
            for path in osu_files:
                print(f"  - {get_difficulty_name(path)}")
            return

        if len(osu_files) == 1:
            chosen = osu_files[0]
        else:
            if not args.difficulty:
                print(
                    "Multiple difficulties found; pass --difficulty to pick one, "
                    "or --list to see options:",
                    file=sys.stderr,
                )
                for path in osu_files:
                    print(f"  - {get_difficulty_name(path)}", file=sys.stderr)
                sys.exit(1)
            wanted = args.difficulty.lower()
            candidates = [
                path for path in osu_files
                if wanted in get_difficulty_name(path).lower()
            ]
            if not candidates:
                print(f"Error: no difficulty matching '{args.difficulty}'", file=sys.stderr)
                sys.exit(1)
            if len(candidates) > 1:
                print(
                    f"Error: '{args.difficulty}' matches multiple difficulties, be more specific:",
                    file=sys.stderr,
                )
                for path in candidates:
                    print(f"  - {get_difficulty_name(path)}", file=sys.stderr)
                sys.exit(1)
            chosen = candidates[0]

        print(f"Converting difficulty: {get_difficulty_name(chosen)}")
        result, audio_filename = convert_osu_file(
            chosen, args.pads, args.slider_ends, args.spinners
        )

        difficulty_slug = re.sub(r"[^a-zA-Z0-9]+", "_", get_difficulty_name(chosen)).strip("_").lower()
        output_path = args.output or f"{difficulty_slug}_beatmap.json"

        with open(output_path, "w") as f:
            json.dump(result, f, indent=2)

        print(f"Tempo: {result['tempo_bpm']} BPM")
        print(f"Notes: {result['note_count']}")
        print(f"Wrote '{output_path}'")

        if args.song_folder:
            os.makedirs(args.song_folder, exist_ok=True)
            dest_json = os.path.join(args.song_folder, "beatmap.json")
            with open(dest_json, "w") as f:
                json.dump(result, f, indent=2)
            print(f"Wrote '{dest_json}'")

            if audio_filename:
                audio_src = os.path.join(os.path.dirname(chosen), audio_filename)
                if os.path.isfile(audio_src):
                    dest_audio = os.path.join(args.song_folder, "song1.mp3")
                    shutil.copyfile(audio_src, dest_audio)
                    print(f"Copied audio to '{dest_audio}'")
                else:
                    print(
                        f"Warning: audio file '{audio_filename}' referenced in the "
                        ".osu but not found; copy your song1.mp3 manually.",
                        file=sys.stderr,
                    )

    finally:
        if tmp_dir:
            shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()