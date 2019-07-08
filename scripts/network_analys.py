import argparse
import os.path
import csv
import threading
import time

parser = argparse.ArgumentParser(description='Programm create a PIF list')
parser.add_argument('-p', '--path', help='Please give a Data path to the csv File')
parser.add_argument('-s', dest='source_Interface', type=int, help='tx Interface Number from the Source')
parser.add_argument('-d', dest='destination_Interface', type=int,  help='tx Interface Number from the Destination')
parser.add_argument('-ls', dest='lastSend', action='store_true', help='time in Fly for the last sended Package')
parser.add_argument('-fs', dest='firstSend', action='store_true', help='time in Fly for the first sended Package')
parser.add_argument('-nd', dest='noDrop', action='store_true', help='time in Fly, Skip droped packages')
parser.add_argument('--all', dest='all', action='store_true', help='execute all functions')
parser.add_argument('--create-nd', dest='create_nd', action='store_true', help='create a ne file without droped packages')
parser.add_argument('--udp', dest='udp', action='store_true', help='If the Packages are UDP')
parser.add_argument('-b', dest='bandWidthInterval', type=float, help='Set the Bandwidth Interval in sec')

args = parser.parse_args()

filePath = args.path
interfaceSource = args.source_Interface
interfaceDestination = args.destination_Interface
lastSend = args.lastSend
firstSend = args.firstSend
noDrop = args.noDrop
exeAll = args.all
create_nd = args.create_nd


udpTrue = args.udp

bandWidthInterval = args.bandWidthInterval

fileName = ""


# Check File exists
if filePath:
    if not os.path.isfile(filePath):
        print("File does not exist")
        quit()
    else:
        print("File exists")
else:
    print("Please give a Path, -h for Help")
    quit()
    
# Check File is a csv File
if not filePath.endswith('.csv'):
    print("File Type is wrong")
    quit()
else:
    print("File Type is right")
    # get only the tail
    
    try:
        fileName = filePath.split('/')[1]
    except:
        fileName = filePath
    
    # remove the .csv ending
    fileName = fileName[:-4]


# TShark command for TCP packages
# tshark -r file.erf -T fields -e frame.number -e frame.time_epoch -e erf.flags.cap -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e ip.proto -e tcp.len -e tcp.seq -e tcp.ack > file.csv

# TShark command for UDP packages
# tshark -r file.erf -T fields -e frame.number -e frame.time_epoch -e erf.flags.cap -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e ip.proto -e tcp.len -e ip.id > file.csv

# GnuPlot command
# plot 'myFile.csv' using 2:3 with lines
# replot 'myFile.csv' using 2:3 with lines



def pcktInFlyLastSendTCP():

    fileSaveNamePckt = fileName + '_pkts_in_fly_last_send.csv'
    fileSaveNameByte = fileName + '_bytes_in_fly_last_send.csv'
    fileSaveNameLatency = fileName + '_latency_last_send.csv'

    csvArray = []
    with open(filePath, 'r') as csvDataFile:
        csvReader = csv.reader(csvDataFile, delimiter = '\t')
        for row in csvReader:
            csvArray.append(row)

    resultWritePackage = open(fileSaveNamePckt, 'w')
    resultWriteByte = open(fileSaveNameByte, 'w')
    resultWriteLatency = open(fileSaveNameLatency, 'w')
    
    # Save the sequence Number if a package was send one time 
    sequenceSend = []
    
    startTimeStamp = float(csvArray[0][1])
    
    packageInFlyCount = 0
    byteInFlyCount = 0
    
    packageInFly = []

    for i in range(len(csvArray)):
        
        # Exception for the float cast
        try:
            seqNumber = float(csvArray[i][9])
            
            # If the Package is sended for the first time
            if(seqNumber not in sequenceSend and float(csvArray[i][2]) == interfaceSource):

                sourcePckt = csvArray[i]
                
                sequenceSend.append(seqNumber)
                
                timeStampSrc = float(sourcePckt[1]) - startTimeStamp
                
                # Check for a resend package and override the timestamp
                for j in range(i+1, len(csvArray)):
                    # Exception for the float cast
                    try:
                        seqNumber2 = float(csvArray[j][9])
                        if(seqNumber == seqNumber2 and float(csvArray[j][2]) == interfaceSource):
                            timeStampSrc = float(csvArray[j][1]) - startTimeStamp

                    except:
                        pass

                packageInFlyCount += 1
                byteInFlyCount += int(csvArray[i][8])
                 
                packageInFly.append([seqNumber, timeStampSrc, packageInFlyCount, byteInFlyCount])

            # If the Package is arrived
            elif(seqNumber in sequenceSend and float(csvArray[i][2]) == interfaceDestination):

                packageInFlyCount -= 1
                byteInFlyCount -= int(csvArray[i][8])

                for pck in packageInFly:
                    if (float(pck[0]) == seqNumber):
                        packageString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[2]) + "\n"
                        byteString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[3]) + "\n"

                        latency =  (float(csvArray[i][1]) - startTimeStamp) - pck[1]
                        latencyString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(latency) + "\n"

                        # It open and close so the results will be save if we end the script
                        resultWritePackage = open(fileSaveNamePckt, 'a')
                        resultWritePackage.write(packageString)
                        resultWritePackage.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteByte = open(fileSaveNameByte, 'a')
                        resultWriteByte.write(byteString)
                        resultWriteByte.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteLatency = open(fileSaveNameLatency, 'a')
                        resultWriteLatency.write(latencyString)
                        resultWriteLatency.close()

                        packageInFlyCount.remove(pck)
                        break

        except ValueError as e:
            #print "error",e,"on line",i
            pass
                
    print("Finished pcktInFlyLastSendTCP")


def pcktInFlyFirstSendTCP():

    fileSaveNamePckt = fileName + '_pkts_in_fly_first_send.csv'
    fileSaveNameByte = fileName + '_bytes_in_fly_first_send.csv'
    fileSaveNameLatency = fileName + '_latency_first_send.csv'
    csvArray = []
    with open(filePath, 'r') as csvDataFile:
        csvReader = csv.reader(csvDataFile, delimiter = '\t')
        for row in csvReader:
            csvArray.append(row)
            
    resultWritePackage = open(fileSaveNamePckt, 'w')
    resultWriteByte = open(fileSaveNameByte, 'w')
    resultWriteLatency = open(fileSaveNameLatency, 'w')
    
    # Save the sequence Number if a package was send one time 
    sequenceSend = []

    
    startTimeStamp = float(csvArray[0][1])  
    
    packageInFlyCount = 0
    byteInFlyCount = 0
      
    packageInFly = []

    for i in range(len(csvArray)):

        
        # Exception for the float cast
        try:
            seqNumber = float(csvArray[i][9])
            
            # If the Package is sended for the first time
            if(seqNumber not in sequenceSend and float(csvArray[i][2]) == interfaceSource):

                sourcePckt = csvArray[i]
                
                sequenceSend.append(seqNumber)
                
                timeStampSrc = float(sourcePckt[1]) - startTimeStamp
               

                packageInFlyCount += 1
                byteInFlyCount += int(csvArray[i][8])
                 
                packageInFly.append([seqNumber, timeStampSrc, packageInFlyCount, byteInFlyCount])

            # If the Package is arrived
            elif(seqNumber in sequenceSend and float(csvArray[i][2]) == interfaceDestination):


                packageInFlyCount -= 1
                byteInFlyCount -= int(csvArray[i][8])

                for pck in packageInFly:
                    if(float(pck[0]) == seqNumber):

                        packageString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[2]) + "\n"
                        byteString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[3]) + "\n"

                        latency = (float(csvArray[i][1]) - startTimeStamp) - pck[1]
                        latencyString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(latency) + "\n"
                        
                        # It open and close so the results will be save if we end the script
                        resultWritePackage = open(fileSaveNamePckt, 'a')
                        resultWritePackage.write(packageString)
                        resultWritePackage.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteByte = open(fileSaveNameByte, 'a')
                        resultWriteByte.write(byteString)
                        resultWriteByte.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteLatency = open(fileSaveNameLatency, 'a')
                        resultWriteLatency.write(latencyString)
                        resultWriteLatency.close()
                        
                        packageInFly.remove(pck)
                        break

        except ValueError as e:
            #print "error",e,"on line",i
            pass
                
    print("Finished pcktInFlyFirstSendTCP")


def pcktInFlyNoDropTCP():

    fileSaveNamePckt = fileName + '_pkts_in_fly_nd.csv'
    fileSaveNameByte = fileName + '_bytes_in_fly_nd.csv'
    fileSaveNameLatency = fileName + '_latency_nd.csv'

    csvArray = []
    with open(filePath, 'r') as csvDataFile:
        csvReader = csv.reader(csvDataFile, delimiter = '\t')
        for row in csvReader:
            csvArray.append(row)
            
    resultWritePackage = open(fileSaveNamePckt, 'w')
    resultWriteByte = open(fileSaveNameByte, 'w')
    resultWriteLatency = open(fileSaveNameLatency, 'w')
    
    # Save the sequence Number if a package was send one time 
    sequenceSend = []
    sequenceDrop = []
    
    startTimeStamp = float(csvArray[0][1])  
    
    packageInFlyCount = -1;
    byteInFlyCount = 0;
      
    packageInFly = []

    for i in range(len(csvArray)):

        
        # Exception for the float cast
        try:
            seqNumber = float(csvArray[i][9])
            
            # If the Package is sended for the first time
            if(seqNumber not in sequenceSend and float(csvArray[i][2]) == interfaceSource and seqNumber not in sequenceDrop):

                sourcePckt = csvArray[i]
                
                sequenceSend.append(seqNumber)
                
                noDrop = True
                
                # Check for a drop
                for j in range(i+1, len(csvArray)):
                    # Exception for the float cast
                    try:
                        seqNumber2 = float(csvArray[j][9])
                        
                        if(seqNumber == seqNumber2 and float(csvArray[j][2]) == interfaceSource):
                            noDrop = False
                            sequenceDrop.append(seqNumber)
                            break
                    except:
                        pass
                
                if noDrop:
                
                    packageInFlyCount += 1
                    byteInFlyCount += int(csvArray[i][8])
                        
                    timeStampSrc = float(sourcePckt[1]) - startTimeStamp
                 
                    packageInFly.append([seqNumber, timeStampSrc, packageInFlyCount, byteInFlyCount])

            # If the Package is arrived
            elif(seqNumber in sequenceSend and float(csvArray[i][2]) == interfaceDestination and seqNumber not in sequenceDrop):


                packageInFlyCount -= 1
                byteInFlyCount -= int(csvArray[i][8])

                for pck in packageInFly:
                    if (float(pck[0]) == seqNumber):

                        packageString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[2]) + "\n"
                        byteString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[3]) + "\n"

                        latency = (float(csvArray[i][1]) - startTimeStamp) -  pck[1]
                        latencyString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(latency) + "\n"

                        # It open and close so the results will be save if we end the script
                        resultWritePackage = open(fileSaveNamePckt, 'a')
                        resultWritePackage.write(packageString)
                        resultWritePackage.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteByte = open(fileSaveNameByte, 'a')
                        resultWriteByte.write(byteString)
                        resultWriteByte.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteLatency = open(fileSaveNameLatency, 'a')
                        resultWriteLatency.write(latencyString)
                        resultWriteLatency.close()

                        packageInFly.remove(pck)
                        break
               

        except ValueError as e:
            #print "error",e,"on line",i
            pass
    print("Finished pcktInFlyNoDropTCP")


def pcktInFlyFirstSendUDP():
    fileSaveNamePckt = fileName + '_pkts_in_fly.csv'
    fileSaveNameByte = fileName + '_bytes_in_fly.csv'
    fileSaveNameLatency = fileName + '_latency.csv'
    fileSaveNameDroped = fileName + '_droped.csv'

    csvArray = []
    with open(filePath, 'r') as csvDataFile:
        csvReader = csv.reader(csvDataFile, delimiter='\t')
        for row in csvReader:
            csvArray.append(row)

    resultWritePackage = open(fileSaveNamePckt, 'w')
    resultWriteByte = open(fileSaveNameByte, 'w')
    resultWriteLatency = open(fileSaveNameLatency, 'w')
    resultWriteDroped = open(fileSaveNameDroped, 'w')

    startTimeStamp = float(csvArray[0][1])

    packageInFlyCount = 0
    byteInFlyCount = 0

    packageInFly = []


    # Mark the droped Packages
    # Actual the mark is on the 5. Postion from the csv File this is the srcPort
    # in the real function  is an INT cast on this Postion so its failed if the Package is droped
    for i in range(len(csvArray)):
        if(int(csvArray[i][2]) == interfaceSource):
            droped = True
            for j in range(i+1, len(csvArray)):
                if (int(csvArray[i][2]) == interfaceSource and int(csvArray[j][2]) == interfaceDestination and str(csvArray[i][9]) == str(csvArray[j][9])):
                    droped = False
                    break
            #print(droped)
            if droped:
                csvArray[i][7] = "droped"
                pass

    # real Function
    for i in range(len(csvArray)):

        # Exception for the float cast
        try:
            # The Postion from ip.ID is 9, look pls "auto_tshark-udp.sh"
            ipId = csvArray[i][9]
            
            # Frame Number from Fragments, 
            # this exists only in the last frame from a fragmented Package
            #frameId = csvArray[i][10]
            

            # Droped test with an INT cast, if the Port is not an INT
            # thow an exception -> do nothing and go to the next value
            int(csvArray[i][7])

            # If the Package is sended for the first time
            #if (ipId not in ipIdSend and float(csvArray[i][2]) == interfaceSource):
            if (float(csvArray[i][2]) == interfaceSource):

                sourcePckt = csvArray[i]

                timeStampSrc = float(sourcePckt[1]) - startTimeStamp

                packageInFlyCount += 1
                byteInFlyCount += int(csvArray[i][8])

                packageInFly.append([ipId, timeStampSrc, packageInFlyCount, byteInFlyCount])
                

            # If the Package is arrived
            #elif (ipId in ipIdSend and float(csvArray[i][2]) == interfaceDestination):
            elif (float(csvArray[i][2]) == interfaceDestination):

                packageInFlyCount -= 1
                byteInFlyCount -= int(csvArray[i][8])

                for pck in packageInFly:
                    if (pck[0] == ipId):
                        packageString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[2]) + "\n"
                        byteString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(pck[3]) + "\n"

                        latency = (float(csvArray[i][1]) - startTimeStamp) - pck[1]
                        latencyString = str(pck[0]) + "\t" + str(pck[1]) + "\t" + str(latency) + "\n"

                        # It open and close so the results will be save if we end the script
                        resultWritePackage = open(fileSaveNamePckt, 'a')
                        resultWritePackage.write(packageString)
                        resultWritePackage.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteByte = open(fileSaveNameByte, 'a')
                        resultWriteByte.write(byteString)
                        resultWriteByte.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteLatency = open(fileSaveNameLatency, 'a')
                        resultWriteLatency.write(latencyString)
                        resultWriteLatency.close()

                        packageInFly.remove(pck)
                        break

        except ValueError as e:
            # print "error",e,"on line",i
            if(str(csvArray[i][7]) == 'droped'):

                timeStampSrc = float(csvArray[i][1]) - startTimeStamp

                dropedString = str(csvArray[i][9]) + "\t" + str(timeStampSrc) + "\t" + str(packageInFlyCount) + "\n"

                # It open and close so the results will be save if we end the script
                resultWriteDroped = open(fileSaveNameDroped, 'a')
                resultWriteDroped.write(dropedString)
                resultWriteDroped.close()
            pass

    print("Finished pcktInFlyFirstSendUDP in " + str(time.clock()) + " seconds")


def pcktInFlyFirstSendReverseUDP():
    fileSaveNamePckt = fileName + '_pkts_in_fly.csv'
    fileSaveNameByte = fileName + '_bytes_in_fly.csv'
    fileSaveNameLatency = fileName + '_latency.csv'
    fileSaveNameDroped = fileName + '_droped.csv'

    csvArray = []
    with open(filePath, 'r') as csvDataFile:
        csvReader = csv.reader(csvDataFile, delimiter='\t')
        for row in csvReader:
            csvArray.append(row)

    resultWritePackage = open(fileSaveNamePckt, 'w')
    resultWriteByte = open(fileSaveNameByte, 'w')
    resultWriteLatency = open(fileSaveNameLatency, 'w')
    resultWriteDroped = open(fileSaveNameDroped, 'w')

    startTimeStamp = float(csvArray[0][1])

    packageInFlyCount = 0
    byteInFlyCount = 0

    packageInFly = []

    # real Function
    for i in range(len(csvArray)):

        # Exception for the float cast
        try:
            # The Postion from ip.ID is 9, look pls "auto_tshark-udp.sh"
            ipId = csvArray[i][9]

            # Frame Number from Fragments,
            # this exists only in the last frame from a fragmented Package
            # frameId = csvArray[i][10]

            # Droped test with an INT cast, if the Port is not an INT
            # thow an exception -> do nothing and go to the next value
            int(csvArray[i][7])

            # If the Package is sended for the first time
            # if (ipId not in ipIdSend and float(csvArray[i][2]) == interfaceSource):
            if (float(csvArray[i][2]) == interfaceDestination):

                destinationPckt = csvArray[i]

                packageInFlyCount += 1
                byteInFlyCount += float(csvArray[i][8])


                for j in range(i-1, -1, -1):

                    if (float(csvArray[j][2]) == interfaceDestination):

                        packageInFlyCount += 1
                        byteInFlyCount += float(csvArray[j][8])

                    if (float(csvArray[j][2]) == interfaceSource and destinationPckt[9] == csvArray[j][9]):

                        timeStamp = float(csvArray[j][1]) - startTimeStamp

                        packageString = str(csvArray[j][9]) + "\t" + str(timeStamp) + "\t" + str(packageInFlyCount) + "\n"
                        byteString = str(csvArray[j][9]) + "\t" + str(timeStamp) + "\t" + str(byteInFlyCount) + "\n"

                        latency = float(destinationPckt[1]) - float(csvArray[j][1])
                        latencyString = str(csvArray[j][9]) + "\t" + str(timeStamp) + "\t" + str(latency) + "\n"

                        # It open and close so the results will be save if we end the script
                        resultWritePackage = open(fileSaveNamePckt, 'a')
                        resultWritePackage.write(packageString)
                        resultWritePackage.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteByte = open(fileSaveNameByte, 'a')
                        resultWriteByte.write(byteString)
                        resultWriteByte.close()

                        # It open and close so the results will be save if we end the script
                        resultWriteLatency = open(fileSaveNameLatency, 'a')
                        resultWriteLatency.write(latencyString)
                        resultWriteLatency.close()

                        packageInFlyCount = 0
                        byteInFlyCount = 0
                        break
        except ValueError as e:
            pass

    print("Finished pcktInFlyFirstSendReverseUDP in " + str(time.clock()) + " seconds")


def bandwidthUDP():
    fileSaveNameBandwidth = fileName + '_bandwidth.csv'


    csvArray = []
    with open(filePath, 'r') as csvDataFile:
        csvReader = csv.reader(csvDataFile, delimiter='\t')
        for row in csvReader:
            csvArray.append(row)

    resultWriteBandwidth = open(fileSaveNameBandwidth, 'w')

    startTimeStamp = float(csvArray[0][1])

    firstInIntervall = float(0)

    timeCounter = float(0)

    byteTransfared = float(0)


    # real Function
    # TODO Idee: Man zaehlt die Bytes der Packete und kontorlliert die Differenz der TimeStamps bis diese groesser als das vorgeschrieben Intervall sind
    # TODO danach teil man einfach durch die Zeit und beginnt von neuem
    for i in range(len(csvArray)):

        # Exception for the float cast
        try:
            # The Postion from ip.ID is 9, look pls "auto_tshark-udp.sh"
            ipId = csvArray[i][9]

            # Droped test with an INT cast, if the Port is not an INT
            # thow an exception -> do nothing and go to the next value
            int(csvArray[i][7])

            # TODO zwei arten zu speichern
            # TODO 1. wir benutzen den Intervall Counter um die Bandbreite abzuspeichern <- derzeit benutzt
            # TODO 2. Oder wir nutzen die timeStamps der Pakages und sagen zu diesem Pakage welche Bandbreite zu dem Zeitpunkt gemessen wurde
            # If the Package is arrived
            if(float(csvArray[i][2]) == interfaceDestination):
                destinationPckt = csvArray[i]
                timeStampDest = float(destinationPckt[1]) - startTimeStamp

                if ((timeStampDest - firstInIntervall) < bandWidthInterval):
                    # die 24 Byte kommen von preamble and inter-packe, die tShark subtrahiert
                    byteTransfared += float(destinationPckt[8]) + 20

                else:
                    actualBandwidth = byteTransfared / bandWidthInterval

                    byteString = str(ipId) + "\t" + str(timeCounter) + "\t" + str(actualBandwidth) + "\n"

                    resultWriteBandwidth = open(fileSaveNameBandwidth, 'a')
                    resultWriteBandwidth.write(byteString)
                    resultWriteBandwidth.close()

                    byteTransfared = 0
                    timeCounter += bandWidthInterval
                    firstInIntervall = float(destinationPckt[1]) - startTimeStamp



        except ValueError as e:

            pass

    print("Finished Bandwidth")


if(bandWidthInterval > 0):

    print("Start badnwidth")
    threading.Thread(target=bandwidthUDP(), args=()).start()

# Check the udp Flag
if udpTrue:

        # Check last send paramater
        if lastSend:
            print("The Parameter lastSend (ls) has no affect on UDP")

        # Check first send paramater
        if udpTrue or firstSend:
            try:
                print("Start Thread: Package in Fly from the first sended Package")
                #threading.Thread(target=pcktInFlyFirstSendUDP, args=()).start()
                threading.Thread(target=pcktInFlyFirstSendReverseUDP, args=()).start()

                
            except:
                print("Error: unable to start firstSend thread")
            
        # Check no Drop parameter
        if noDrop:
            print("The Parameter noDrop (nd) has no affect on UDP")


else:

    # Check execute all functions
    if exeAll:
        try:
            #threading.Thread(target=timeInFlyLastSend, args=()).start()
            #threading.Thread(target=timeInFlyFirstSend, args=()).start()
            #threading.Thread(target=timeInFlyNoDrop, args=()).start()
            threading.Thread(target=pcktInFlyLastSendTCP, args=()).start()
            threading.Thread(target=pcktInFlyFirstSendTCP, args=()).start()
            threading.Thread(target=pcktInFlyNoDropTCP, args=()).start()
            print("Execute all Functions in seperate Threads")
        except:
            print("Error: unable to start all TCP thread")

    else: 
        # Check last send paramater
        if lastSend:
            try:
                print("Start Thread: Package in Fly from the last sended Package")
                #threading.Thread(target=timeInFlyLastSend, args=()).start()
                threading.Thread(target=pcktInFlyLastSendTCP, args=()).start()
                
            except:
                print("Error: unable to start TCP lastSend thread")

        # Check first send paramater
        if firstSend:
            try:
                print("Start Thread: Package in Fly from the first sended Package")
                #threading.Thread(target=timeInFlyFirstSend, args=()).start()
                threading.Thread(target=pcktInFlyFirstSendTCP, args=()).start()
                
            except:
                print("Error: unable to start TCP firstSend thread")
            
        # Check no Drop parameter
        if noDrop:
            try:
                print("Start Thread: Package in Fly Skip droped Packages")
                #threading.Thread(target=timeInFlyNoDrop, args=()).start()
                threading.Thread(target=pcktInFlyNoDropTCP, args=()).start()
                
            except:
                print("Error: unable to start TCP noDrop thread")
            
            
            
            
