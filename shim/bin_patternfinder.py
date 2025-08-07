#!/usr/bin/env python3
import argparse
import numpy as np

# proper cli help later
# this program can be used to compare memory dumps to find the exact byte that holds something
# `pattern` is files that should have the byte at the specific value,
# and `anti` is files that should *not* but are otherwise similar

parser = argparse.ArgumentParser()
parser.add_argument(
    "-p", "--pattern",
    nargs='+', type=str, required=True,
    action='append', help="files that should have the byte you're looking for"
)
parser.add_argument(
    "-a", "--anti", "--antipattern",
    nargs='+', type=str, required=True,
    action='append', help="files that *shouldn't* have the byte you're looking for"
)
parser.add_argument(
    "-s", "--swap",
    action='store_true', help="swap pro and anti quickly"
)
args = parser.parse_args()

if args.swap:
    args.pattern, args.anti = args.anti, args.pattern

args.pattern = sum(args.pattern, [])
args.anti = sum(args.anti or [], [])

print(args.pattern, args.anti)


with open(args.pattern[0], "rb") as f:
    data = np.array(list(f.read()))
    matches = np.ones(data.shape, dtype=bool)

for i in args.pattern[1:]:
    with open(i, "rb") as f:
        mydata = np.array(list(f.read()))
        matches = matches * (data == mydata)

for i in args.anti:
    with open(i, "rb") as f:
        mydata = np.array(list(f.read()))
        matches = matches * (data != mydata)

for ind in np.where(matches)[0]:
    print(f"0x{ind:>05x} is always #{data[ind]:>02x}")
