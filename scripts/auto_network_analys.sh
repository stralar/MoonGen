#!/bin/bash

sourceInterface=2
destinationInterface=0
# in seconds
bandwidthInterval=1
pythonScript="$(cd "$(dirname "$0")" ; pwd)/network_analysis.py"

for var in "$@"
do
    echo "$var"
    python $pythonScript -p $var -s $sourceInterface -d $destinationInterface --udp -b $bandwidthInterval
done
