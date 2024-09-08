#!/bin/sh
set -e
set -x
gpasm -c main.asm
gplink -l -o out.hex main.o
objcopy --input-target=ihex --output-target=binary out.hex /tmp/out
ll /tmp/out | cut -d' ' -f 5 | awk '{print $1/2}'
rm out.cod main.lst main.o
