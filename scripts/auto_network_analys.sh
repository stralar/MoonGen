#!/bin/bash

rateList="1 5 10 50 100 500"
latencyList="0"
ringSizeList="1"
byteSizeList="100 500 1500"
txDescsList="32 1024"



for r in $rateList;
do
    for l in $latencyList;
    do
        for q in $ringSizeList;
        do
			for b in $byteSizeList;
			do
				for t in $txDescsList;
				do
				    python network_analys.py -p iperf-psr-udp-txQ$t-r$r-l$l-q$q-b$b.csv -s 2 -d 1 -udp -b 1
				done
			done
        done
    done
done
