#!/bin/bash


for dir in "$@"
do
    srcFile=$dir
    
    if [ ${srcFile:(-3)} == "erf" ]
        then
            destFile=${srcFile/.erf/.csv}
            
            tshark -r $srcFile -T fields -e frame.number -e frame.time_epoch -e erf.flags.cap -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e ip.proto -e tcp.len -e tcp.seq -e tcp.ack > $destFile
        rm -R $srcFile
    fi
done

