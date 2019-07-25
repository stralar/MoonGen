import argparse
import os
import csv
import glob
import sys


parser = argparse.ArgumentParser(description='Programm create a PIF list')
parser.add_argument('-n', '--name', help='Please give a Data path to the csv File: rnc-psr-tXX-r')

args = parser.parse_args()

fileName = args.name

fileSaveName = fileName[:-1] + "boxplot_delay.csv"

mbits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

# Collect Data from files
result = []
for i in range(len(mbits)):
    calcData = []

    filePathDetails = fileName + str(mbits[i]) +"-*_latency.csv"

    for file in glob.glob(filePathDetails):
        try:
            print(os.getcwd() + file)
            with open(file, 'r') as csvDataFile:
                csvReader = csv.reader(csvDataFile, delimiter = '\t')

                for row in csvReader:
                    calcData.append(row[2])

        except():
            print("Unexpected error:", sys.exc_info()[0])
            pass
    result.append(calcData)

# write Summary in file
resultWritePackage = open(fileSaveName, 'w')
for i in range(len(result[0])):
    lineString = ""
    for j in range(len(result)):
        try:
            lineString += str(result[j][i]) + "\t"

        except:
            lineString += "\t"
    lineString += "\n"
    resultWritePackage.write(lineString)

resultWritePackage.close()
