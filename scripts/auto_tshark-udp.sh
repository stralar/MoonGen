#!/bin/bash


for dir in "$@"
do
    srcFile=$dir
    
    if [ ${srcFile:(-3)} == "erf" ]
        then
            destFile=${srcFile/.erf/.csv}
            
            tshark -r $srcFile -T fields -e frame.number -e frame.time_epoch -e erf.flags.cap -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e ip.proto -e frame.len -e ip.id -e ip.fragment > $destFile
        rm -R $srcFile
    fi
done

