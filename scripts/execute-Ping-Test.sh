#!/bin/bash


destIPAdress="10.1.3.2"

# Paper 5 x 10³
pingMaxCount=5000

# in Seconds
interPacketGap="0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 7.0, 9.0, 10.0, 10.5, 11.0, 12.0"

for i in $interPacketGap;
do
  ping "-c $pingMaxCount -i $interPacketGap $destIPAdress"

done