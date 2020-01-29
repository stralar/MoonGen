#!/bin/bash

# This script filtered the .erf file and save the new values in a .csv file
# Then it execute the network analysis Python script
# In the end the .erf file will be deletet

sourceInterface=0
destinationInterface=1
# in seconds
bandwidthInterval=1

pythonScript="$(cd "$(dirname "$0")" ; pwd)/network_analysis.py"



for dir in "$@"
do
    srcFile=$dir
    
    if [ ${srcFile:(-3)} == "erf" ]
        then
            destFile=${srcFile/.erf/.csv}
            
            tshark -r $srcFile -T fields -e frame.number -e frame.time_epoch -e erf.flags.cap -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e ip.proto -e frame.len -e ip.id -e ip.fragment > $destFile
            echo $destFile
            python $pythonScript -p $destFile -s $sourceInterface -d $destinationInterface --udp -b $bandwidthInterval

        rm -R $srcFile
    fi
done

