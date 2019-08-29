#!/bin/bash


destIPAdress="10.1.3.2"

fileName="ping-psr-t06"


# Paper 5 x 10³
pingMaxCount=5000

# in Seconds
interPacketGap=(0.01 0.05 0.1 0.2 0.5 1.0 1.5 2.0 2.5 3.0 10.0 10.5 11.0)

result=""


for (( i=0; i<${#interPacketGap[@]}; i++ ));
do
    outputFileName="$fileName-i${interPacketGap[i]}.csv"

    rm $outputFileName

    echo "$outputFileName will be finished at $(date +%T --date="@$(echo "$(date '+%s') + ${interPacketGap[i]} * $pingMaxCount" | bc)")"

    # ping "-c $pingMaxCount -i $interPacketGap $destIPAdress"
    pingData=$(sudo ping -c $pingMaxCount -i ${interPacketGap[i]} localhost | tr " " "\n")

    echo "$outputFileName is Finished at $(date +%T)"


    lineString=""
    for string in $pingData:
    do
        #if [ ${string:0:9} == "icmp_seq=" ]
        #then
            #lineString="${string:9}\t"
        #fi
        if [ ${string:0:5} == "time=" ]
        then
            #lineString="$lineString${string:5}"
            echo -e ${string:5} >> $outputFileName
            lineString=""
        fi
    done

    echo "Analysis from $outputFileName is Finished at $(date +%T)"

done

