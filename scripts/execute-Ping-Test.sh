#!/bin/bash


destIPAdress="10.1.3.3"
#destIPAdress="localhost"

fileName="ping-psr-t08"


# Paper 5 x 10³
pingMaxCount=500

# in Seconds
interPacketGap=(0.01 0.1 0.5 1.0 2.0 2.8 3.5 11.0 13.0)

result=""

for (( i=0; i<${#interPacketGap[@]}; i++ ));
do
    outputFileName="$fileName-i${interPacketGap[i]}.csv"

    rm $outputFileName

    echo "$outputFileName will be finished at $(date +%T --date="@$(echo "$(date '+%s') + ${interPacketGap[i]} * $pingMaxCount" | bc)")"


        # ping "-c $pingMaxCount -i $interPacketGap $destIPAdress"
        # rand=$(echo "scale=2;$((RANDOM % 100)) / 100" | bc)
        pingData=$(sudo ping -c $pingMaxCount -i ${interPacketGap[i]} $destIPAdress | tr " " "\n")

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

