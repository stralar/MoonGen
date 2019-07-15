import argparse
import os
import csv
import glob
import sys


parser = argparse.ArgumentParser(description='Programm create a PIF list')
parser.add_argument('-n', '--name', help='Please give a Data path to the csv File')


args = parser.parse_args()

fileName = args.name

mbits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

result = []
for i in range(len(mbits)):
    calData = []

    filePathDetails = fileName + str(mbits[i]) +"-*_bit_per_1.0s.csv"

    for file in glob.glob(filePathDetails):
        try:
            print(os.getcwd() + file)
            with open(file, 'r') as csvDataFile:
                csvReader = csv.reader(csvDataFile, delimiter = '\t')

                for row in csvReader:
                    calData.append(row[2])

        except():
            print("Unexpected error:", sys.exc_info()[0])
            pass
    result.append(calData)


print(result)