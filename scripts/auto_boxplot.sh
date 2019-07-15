#!/bin/bash

srcFile=$1

plots="plot "
axisNames="set title 'Test Plot'; set ylabel 'throughtput [Mbps]'; set xlabel 'fixed send rate [Mbps]';"

boxplotConf1="set style data boxplot; set boxwidth 0.2; set pointsize 1; set style boxplot fraction 0.99;"
boxplotConf2="set yrange [0:*]; set ytics nomirror; set xtics nomirror; set style boxplot outliers pointtype 1;"

count=0

for var in "$@"
do

    if [ "$count" -eq 0 ];then
        plots="$plots '$var' using (1):3, "
        count=$(( + 5))
    else
        plots="$plots '$var' using ($count):3, "
        count=$(($count + 5))

    fi

done

gnuplot -p -e "$axisNames $boxplotConf1 $boxplotConf2 $plots"