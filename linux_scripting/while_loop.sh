#!/bin/bash

echo "Enter a Numerical Value: "
read num
count=1
while [ $count -le $num ]; do
	echo "Count, $count"
	((count++))
done
