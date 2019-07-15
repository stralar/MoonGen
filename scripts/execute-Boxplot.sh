#!/bin/bash

filePath=$0
srcFile=$1

python ${filePath/execute-Boxplot.sh/boxplot_data.py} -n $srcFile

srcFile=${srcFile/udp-r/udp-boxplot_summary.csv}

plots="plot "
axisNames="set title 'Test Plot'; set ylabel 'throughtput [Mbps]'; set xlabel 'fixed send rate [Mbps]';"

boxplotConf1="set style data boxplot; set boxwidth 0.2; set pointsize 1; set style boxplot fraction 0.99;"
boxplotConf2="set yrange [0:*]; set ytics nomirror; set xtics nomirror; set style boxplot outliers pointtype 1;"


for i in {1..11}
do
    if [ "$i" -eq 0 ];then
        plots="$plots '$srcFile' using (1):$i, "
    else
        plots="$plots '$srcFile' using ($((i * 5))):$i, "
    fi
done

gnuplot -p -e "$axisNames $boxplotConf1 $boxplotConf2 $plots"