#!/bin/bash


# ssh Key should be used
# username@hostname
serverPC="lars@pc1"
clientPC="lars@pc87"
moonGenPC="lars@86"
dagPC="stratmann@DAG"



srcInterface="3"
destInterface="2"


destIPAdress="10.1.3.3"

moonGenScript="examples/l2-forward-psring-software-latency-rate-txDescs.lua"
testName="iperf-psr-soft-udp-"

iperfExecuteTime="10"
dagExecuteTime=$(($iperfExecuteTime + 10))
moonGenExecuteTime=$((dagExecuteTime + 10))
waitTime=$((moonGenExecuteTime))

# List from Bandwidth length to test
rateList="5 10 50 100"
# List from latencies to test
latencyList="0"
# List from RingSize, how much Packages will stay in the ring
ringSizeList="1"


# List form the MTU that should be tested
byteSizeListDAG=(1500)
byteSizeListIperf=(1.4)

iperfServerCommand="iperf3 -s"


# Cleaning
ssh serverPC 'sudo killall iperf3' &
ssh moonGenPC 'sudo killall MoonGen' &
ssh clientPC 'sudo killall iperf3'&

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
                echo "'$testName'r$r-l$l-q$q-b${byteSizeListDAG[$i]}"

                moonGenMainCommand="cd MoonGen; sudo ./build/MoonGen $moonGenScript -d $srcInterface $destInterface -r $r $r -l $l $l -q $q $q"
                moonGenTerminateCommand="sudo killall MoonGen"
                iperfClientCommand="iperf3 -c $destIPAdress -t $iperfExecuteTime -u -l ${byteSizeListIperf[$i]}K -b '$r'M"
                dagCommad="sudo dagsnap -s $dagExecuteTime -d0 -v -o '$testName'r$r-l$l-q$q-b${byteSizeListDAG[$i]}.erf"


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

ssh -t $serverPC 'sudo killall iperf3' &
