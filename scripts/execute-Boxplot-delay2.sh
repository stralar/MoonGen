#!/bin/bash

filePath=$0


averagePlot="'$1' using 1 with lines"
variancePlots="plot "
axisNames="set title '$1'; set ylabel 'delay [package]'; set xlabel 'packet nr'; set key off;" # set terminal wxt size 300,600;"

boxplotConf1="set style data boxplot; set boxwidth 0.2; set pointsize 1; set style boxplot fraction 0.99;"
boxplotConf2="set yrange [0:*]; set ytics nomirror; set xtics nomirror; set style boxplot outliers pointtype 1;"


for var in "$@"
do
    echo $var
    variancePlots="$variancePlots '$var' using 3 pointtype 7 pointsize 0.2 lc rgb 'gray', "

done


gnuplot -p -e "$variancePlots $averagePlot"