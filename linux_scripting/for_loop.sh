#!/bin/bash

echo "Enter a Numerical Value above 0: "
read num
for i in $(seq 1 $num); do
	echo $i
done
