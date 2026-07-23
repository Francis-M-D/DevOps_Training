#!/bin/bash

echo "Enter a Numarical Value between 1 to 10:"
read n
if [ $n -ge 1 -a $n -le 10 ]; then
	echo "Entered value is within the range of 1 to 10"
else
	echo "Value OUT OF RANGE of 1 to 10"
fi
