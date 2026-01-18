#!/usr/bin/env bash

awk -F, '{print $5}' | tr -d '"' | grep -E '(Byte|EOP)' | sed 's/Byte //g' | tr '\n' ',' | sed 's/EOP,/EOP\n/g' | sed 's/^0x80,//' | sed 's/,EOP//' | sed 's/0x//g'
