#!/bin/bash

sourceInterface=0
destinationInterface=1
# in seconds
bandwidthInterval=1

pythonScript="$(cd "$(dirname "$0")" ; pwd)/network_analysis.py"

for dir in "$@"
do
    srcFile=$dir

    if [ ${srcFile:(-3)} == "csv" ]
        then

            python $pythonScript -p $srcFile -s $sourceInterface -d $destinationInterface --udp -b $bandwidthInterval
    fi
done