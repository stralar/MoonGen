#!/usr/bin/python
'''
    This is a script to measure the Delay from different inter-packet-times on a emulated LTE connection

'''
from scapy.all import *
import random
import time

# The Test from the paper is 5 * 10^3
pingRepeats = 50

destinationIP = "www.google.de"
conf.verb = 0

packet = IP(dst=destinationIP)/ICMP()
reply = sr1(packet)
send_time = time.time()

pkts = rdpcap("tmp.pcap")
roundTripTime = pkts[1].time - pkts[0].time

print((reply[0][0].time - packet.time))

'''
TIMEOUT = 2
conf.verb = 0
for ip in range(0, 256):
    packet = IP(dst="192.168.0." + str(ip), ttl=20)/ICMP()
    reply = sr1(packet, timeout=TIMEOUT)
    if not (reply is None):
         print (reply.dst, "is online")
    else:
         print ("Timeout waiting for %s" % packet[IP].dst)
'''

