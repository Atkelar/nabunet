#!/bin/bash


#  assembles the bootable NABU PC configuration program
#  z80asm needs to be in the path (TODO: detect version/path/etc...)

# The output file will be called "nabuboot.img" because that is 
# what we expect for the SD card flash update.

z80asm src/main.asm -o output/nabuboot.img -I include -I src

