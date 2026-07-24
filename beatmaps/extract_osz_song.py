#!/usr/bin/env python3
import zipfile
import shutil
import sys
from pathlib import Path

AUDIO_EXTENSIONS = {'.mp3', '.ogg', '.wav', '.flac', '.m4a'}


def extract_song(osz_path, output_dir=None):
    osz_path = Path(osz_path)
    if not osz_path.exists():
        raise FileNotFoundError(f'File not found: {osz_path}')

    if output_dir is None:
        output_dir = osz_path.parent
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(osz_path, 'r') as zf:
        names = zf.namelist()
        audio_files = [n for n in names if Path(n).suffix.lower() in AUDIO_EXTENSIONS]

        if not audio_files:
            raise FileNotFoundError('No audio file found in the .osz archive.')

        audio_member = audio_files[0]
        target = output_dir / Path(audio_member).name

        with zf.open(audio_member) as src, open(target, 'wb') as dst:
            shutil.copyfileobj(src, dst)

    return target


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python extract_osz_song.py <beatmap.osz> [output_dir]')
        sys.exit(1)

    out = extract_song(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    print(f'Extracted: {out}')
