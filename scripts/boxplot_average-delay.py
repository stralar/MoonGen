import argparse
import os
import csv
import glob
import sys


parser = argparse.ArgumentParser(description='Programm create a PIF list')
parser.add_argument('-n', '--name', help='Please give a Data path to the csv File: rnc-psr-tXX-rX-')

args = parser.parse_args()

fileName = args.name

fileSaveName = fileName[:-1] + "-boxplot_average-delay.csv"

#rnc-psr-t01-r1-l0-q280-t0_latency

# Collect Data from files
values = []
result = []


filePathDetails = fileName + "*_latency.csv"

for file in glob.glob(filePathDetails):
    calcData = []
    try:
        print(os.getcwd() + "/" + file)
        with open(file, 'r') as csvDataFile:
            csvReader = csv.reader(csvDataFile, delimiter = '\t')

            for row in csvReader:
                calcData.append(row[2])

    except():
        print("Unexpected error:", sys.exc_info()[0])

    values.append(calcData)


for i in range(len(values[0])):
    average = 0.0
    for j in range(len(values)):
        try:
            average += float(values[j][i])
        except():
            print("Unexpected error:", sys.exc_info()[0])
    average = average / len(values)
    result.append(average)


# write Summary in file
resultWritePackage = open(fileSaveName, 'w')
for i in range(len(result)):
    lineString = ""
    try:
        lineString += str(result[i]) + "\t"

    except:
        lineString += "\t"
    lineString += "\n"
    resultWritePackage.write(lineString)

resultWritePackage.close()
