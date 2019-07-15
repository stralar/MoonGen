#!/bin/bash

sourceInterface=2
destinationInterface=0
# in seconds
bandwidthInterval=1

for var in "$@"
do
    echo "$var"
    python network_analys.py -p $var -s $sourceInterface -d $destinationInterface --udp -b $bandwidthInterval
done
