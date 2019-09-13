#!/bin/bash


pythonScript="$(cd "$(dirname "$0")" ; pwd)/network_analysis.py"


for dir in "$@"
do
    srcFile=$dir
    
    if [ ${srcFile:(-3)} == "erf" ]
        then
            destFile=${srcFile/.erf/.csv}
            
            tshark -r $srcFile -T fields -e frame.number -e frame.time_epoch -e erf.flags.cap -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e ip.proto -e frame.len -e ip.id -e ip.fragment > $destFile
            echo $destFile
            python $pythonScript -p $destFile -s 2 -d 0 --udp -b 1

            # auto_boxplot.sh ${destFile/.csv/_pkts_in_fly.csv}
        rm -R $srcFile
    fi
done

