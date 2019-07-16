#!/bin/bash


pythonScript="$(cd "$(dirname "$0")" ; pwd)/network_analysis.py"

for dir in "$@"
do
    srcFile=$dir

    if [ ${srcFile:(-3)} == "csv" ]
        then

            python $pythonScript -p $srcFile -s 2 -d 0 --udp -b 1
    fi
done