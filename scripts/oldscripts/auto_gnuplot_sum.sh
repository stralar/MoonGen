#!/bin/bash

srcFile=$1

plots="plot "

for var in "$@"
do

    plots="$plots '$var' using 2:3 with lines , "

done

gnuplot -persist -e "$plots"


