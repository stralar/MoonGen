#!/bin/bash

filePath=$0
srcFile=$1

pythonScript="$(cd "$(dirname "$0")" ; pwd)/boxplot_delay.py"

python $pythonScript -n $srcFile

srcFile=${srcFile/-r/-boxplot_delay.csv}

plots="plot "
axisNames="set title '${srcFile/-boxplot_delay.csv/}'; set ylabel 'delay [package]'; set xlabel 'fixed send rate [Mbps]'; set key off;" # set terminal wxt size 300,600;"

boxplotConf1="set style data boxplot; set boxwidth 0.2; set pointsize 1; set style boxplot fraction 0.99;"
boxplotConf2="set yrange [0:*]; set ytics nomirror; set xtics nomirror; set style boxplot outliers pointtype 1;"


for i in {1..11}
do
    if [ "$i" -eq 1 ];then
        plots="$plots '$srcFile' using (1):$i, "
    else
        plots="$plots '$srcFile' using ($(($((i - 1)) * 5))):$i, "
    fi
done


gnuplot -p -e "$axisNames $boxplotConf1 $boxplotConf2 $plots"