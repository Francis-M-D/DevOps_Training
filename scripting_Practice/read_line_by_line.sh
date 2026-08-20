#!/bin/bash

src="data/data.txt"

count=1
while read line; do
    echo "$count $line"
    ((count++))
done < $src
