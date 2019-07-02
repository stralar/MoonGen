#!/bin/bash


# username@hostname
serverPC="lars@pc1"
clientPC="lars@pc87"
moonGenPC="lars@86"
dagPC="stratmann@DAG"



srcInterface="3"
destInterface="2"


destIPAdress="10.1.3.3"

moonGenScript="examples/l2-forward-psring-software-latency-rate-txDescs.lua"


iperfExecuteTime="10"
dagExecuteTime=$(($iperfExecuteTime + 10))
moonGenExecuteTime=$((dagExecuteTime + 10))
waitTime=$((moonGenExecuteTime))

#rateList="1 5 10 50 100"
rateList="5 10 50 100"
#rateList="100"
latencyList="0"
ringSizeList="1"
#txDescsList="32 1024"
txDescsList="1024"
rxDescsList="32"
byteSizeListDAG=(1500)
byteSizeListIperf=(1.4)

testDelay="120000 130000 14000 150000"

iperfServerCommand="iperf3 -s"


# Cleaning
ssh lars@pc1 'sudo killall iperf3' &
ssh lars@pc86 'sudo killall MoonGen' &
ssh lars@pc87 'sudo killall iperf3'&

sleep 1


#Initial
ssh lars@pc1 $iperfServerCommand &
sleep 1

for r in $rateList;
do
    for l in $latencyList;
    do
        for q in $ringSizeList;
        do
			for (( i=0; i<${#byteSizeListDAG[@]}; i++ ));
			do
				for tx in $txDescsList;
				do
				    for rx in $rxDescsList;
				    do
				        for d in $testDelay;
				        do
				            echo "iperf-psr-soft-udp-txQ$tx-rxQ$rx-r$r-l$l-q$q-b${byteSizeListDAG[$i]}-pkt_send_delay-$d"

                            moonGenMainCommand="cd MoonGen; sudo ./build/MoonGen $moonGenScript -d $srcInterface $destInterface -r $r $r -l $l $l -q $q $q --delay $d --txDescsValue $tx --rxDescsValue $rx"
                            moonGenTerminateCommand="sudo killall MoonGen"
                            iperfClientCommand="iperf3 -c $destIPAdress -t $iperfExecuteTime -u -l ${byteSizeListIperf[$i]}K -b '$r'M"
                            dagCommad="sudo dagsnap -s $dagExecuteTime -d0 -v -o iperf-psr-soft-udp-txQ$tx-rxQ$rx-r$r-l$l-q$q-b${byteSizeListDAG[$i]}-pkt_send_delay-$d.erf"


                            ssh $moonGenPC $moonGenMainCommand &

                            sleep 5

                            ssh $dagPC $dagCommad &

                            sleep 2

                            ssh $clientPC $iperfClientCommand &


                            sleep $waitTime

                            ssh $moonGenPC $moonGenTerminateCommand &

                            sleep 5
                        done
                    done
				done
			done
        done
    done
done

ssh -t $serverPC 'sudo killall iperf3' &
