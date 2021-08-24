#!/usr/bin/env python3

import argparse
from sys import stdout,stdin
import math


parser = argparse.ArgumentParser(description="Convert a signed 8bit RAW file to a format usable by Smooth-Player")
parser.add_argument("--mono", default=False, action="store_true")
parser.add_argument("input_file")
args = parser.parse_args()


def read_sample(file):
    left = file.read(1)[0]

    if args.mono:
        right = left
    elif left != None:
        try:
            right = file.read(1)[0]
        except IndexError:
            raise ValueError("Stereo file contains an odd amount of bytes!")

    return left,right

if args.input_file == "-":
    input_file = stdin.buffer
else:
    input_file = open(args.input_file, "rb")

output = []
with input_file:
    try:
        while True:
            left,right = read_sample(input_file)

            output.append(left >> 4 | (right & 0xf0))
    except IndexError:
        pass

    stdout.buffer.write(bytes(output))
