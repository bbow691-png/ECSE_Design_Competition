#!/usr/bin/env python3
import argparse
import sys
import os

def parse_osu_file(filepath):
    """
    Given a file path, find the file from the local directory, and return it
    """
    if not filepath.endswith('.osz'):
        raise ValueError(f'File is not a .osz file: {filepath}')

    with open(filepath,'r', encoding='utf-8') as f:
        content = f.read()
        if content == None:
            raise ValueError(f'File has no content or does not exist!: {filepath}')
        """
        There is a bunch of stuff, but the .osz file is just a zip file
        We have audio (mp3), difficulty files in .osz format,
        and also hit audio files in .wav format. Which would be cool for us to use for our purposes.
        Also comes with fanart but, we don't need that currently.
        """
        print(content)


def main():
    parser = argparse.ArgumentParser(description='Parse .osu files. You can choose difficulty using --diffulty [diffulty]. You can list difficulty with --list')
    """
    Basic usage of ArgumentParser from python wiki:
    parser.add_argument('filename')           # positional argument
    parser.add_argument('-c', '--count')      # option that takes a value
    parser.add_argument('-v', '--verbose',
                        action='store_true')  # on/off flag

    This is overkill for this small project, 
    but this is just for my own personal learning as well.
    """
    parser.add_argument('filepath', type=str, help='Path to the .osu file') 
    parser.add_argument('--difficulty',type=str, help='Selects difficulty for filename. See --list')
    parser.add_argument('--list', action='store_true',help='Prints difficulty for filename')
    args = parser.parse_args()
    try:
        parse_osu_file(os.path.dirname(os.path.abspath(args.filepath)))
    except ValueError as e:
        print(e)
    """
    If list, list all arguments
    """

        

if __name__ == '__main__':
    main()