#!/bin/bash

srcFile=$1

plots="plot "

for var in "$@"
do

    #plots="$plots '$var' using 2:3 with lines , "
    gnuplot -e "set terminal png size 800,600; set output '${var/.csv/.png}'; plot '$var' using 2:3 w l"
done


#gnuplot -e "set terminal png size 800,600; set output '${srcFile/.csv/.png}'; $plots"
#gnuplot -persist -e "$plots"


