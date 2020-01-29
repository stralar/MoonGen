#!/bin/bash

# This script execute the Ping command and saves the times
# The optional Parameters are interpacket values

destIPAdress="10.1.3.3"
#destIPAdress="localhost"

fileName="ping-psr-t13"


# Paper 5 x 10³
pingMaxCount=5000

# in Seconds
interPacketGap=()

result=""

if [ $1 ]
then
    for time in "$@"
    do
        interPacketGap+=($time)
    done
else
    interPacketGap+=(0.01 0.2 0.3 2.5 2.6 11.0 10.5 10.6)
fi

for (( i=0; i<${#interPacketGap[@]}; i++ ));
do
    outputFileName="$fileName-i${interPacketGap[i]}.csv"
    outputLogName="$fileName-i${interPacketGap[i]}.log"


    rm $outputFileName

    echo "$outputFileName will be finished at $(date +%T --date="@$(echo "$(date '+%s') + ${interPacketGap[i]} * $pingMaxCount" | bc)")"


    # ping "-c $pingMaxCount -i $interPacketGap $destIPAdress"
    # rand=$(echo "scale=2;$((RANDOM % 100)) / 100" | bc)
    # pingData=$(sudo ping -c $pingMaxCount -i ${interPacketGap[i]} $destIPAdress | tr " " "\n")
	  pingData=$(sudo ping -c $pingMaxCount -i ${interPacketGap[i]} $destIPAdress > $outputLogName)

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


