#!/bin/bash

srcFile=$1

plots="plot "
axisNames="set title 'Test Plot'; set ylabel 'throughtput [Mbps]'; set xlabel 'fixed send rate [Mbps]';"

boxplotConf1="set style data boxplot; set boxwidth 0.5; set pointsize 0.1;"
boxplotConf2="set xtics ('A' 1); set yrange [0:1000]; set ytics nomirror; set xtics nomirror;"



for var in "$@"
do

    plots="$plots '$var' using (1):3, "

done

gnuplot -p -e "$axisNames $boxplotConf1 $boxplotConf2 $plots"