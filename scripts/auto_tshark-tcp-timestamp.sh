#!/bin/bash


for dir in "$@"
do
    srcFile=$dir
    
    if [ ${srcFile:(-3)} == "erf" ]
        then
            destFile=${srcFile/.erf/.csv}
            
            tshark -r $srcFile -2 -R tcp.flags==0x012 -T fields -e tcp.time_relative > $destFile
        #rm -R $srcFile
    fi
done

