#!/bin/bash

for var in "$@"
do
	outputFileName=${var/.log/.csv}
	echo "$outputFileName"
	lineString=""
	
	array=$(cat "$var" | tr " " "\n")	

	for string in $array:
	do
	        if [ ${string:0:5} == "time=" ]
	        then
		        echo -e ${string:5} >> $outputFileName
        		lineString=""

        	fi
	done
done
