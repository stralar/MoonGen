'''
Dies soll eine allaround Werkzeug zum erzeugen von graphen fuer meine Bachelorarbeit werden
needed packages
numpy
matplotlib
python-tk


Parameter: dateiname und aktionen/BOOLEAN

mit dem dateinamen werden dann die jeweiligen Files gesucht und in das array geladen

'''
import argparse
import glob
import numpy as np
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description='Programm create a PIF list')
parser.add_argument('-n', '--name', help='Please give a Data path to the csv File, example: rnc-psr-tXX-r')

args = parser.parse_args()

fileName = args.name

class BoxplotThroughput():

    data = []
    mbits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    yLabel = "throughput [Mbps]"
    xLabel = "fixed send rate [Mbps]"
    boxLabel = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    fileSaveName = "-throughput"

    def __init__(self):

        # Collect Data from files

        for i in range(len(self.mbits)):
            tmpAllData = []
            filePathDetails = fileName + str(self.mbits[i]) + "-*_bit_per_*"


            for file in glob.glob(filePathDetails):
                #print(file)
                tmpAllData.append(np.loadtxt(file, delimiter="\t"))

            tmpData = []
            for i in range(len(tmpAllData)):
                for j in range(len(tmpAllData[i])):
                    tmpData.append(tmpAllData[i][j][2] / 1000000)

            self.data.append(tmpData)

        #print(self.data)


    def draw_graph(self):
        # Create a figure instance
        fig = plt.figure(len(plt.get_fignums()))


        # Create an axes instance
        ax = fig.add_subplot(111)

        # Create the boxplot
        bp = ax.boxplot(self.data, whis=[0, 99])

        for box in bp['boxes']:
            # change outline color
            box.set(color='blue', linewidth=0.5)
            # change fill color
            # box.set(facecolor='#1b9e77')


        ## change color and linewidth of the medians
        for median in bp['medians']:
            median.set(color='red', linewidth=0.5)

        ## change the style of fliers and their fill
        for flier in bp['fliers']:
            flier.set(marker='+', color='red')

        ax.set_xlabel(self.xLabel)
        ax.set_ylabel(self.yLabel)

        ax.set_xticklabels(self.boxLabel)
        ax.set_ybound(0, 50)

        # Save the figure
        fig.savefig(fileName + self.fileSaveName, bbox_inches='tight')

class BoxplotDelay():

    data = []
    mbits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    yLabel = "delay [sec]"
    xLabel = "fixed send rate [Mbps]"
    boxLabel = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    fileSaveName = "-delay"

    def __init__(self):

        # Collect Data from files

        for i in range(len(self.mbits)):
            tmpAllData = []
            filePathDetails = fileName + str(self.mbits[i]) + "-*_latency.csv"


            for file in glob.glob(filePathDetails):
                #print(file)
                tmpAllData.append(np.loadtxt(file, delimiter="\t"))

            tmpData = []
            for i in range(len(tmpAllData)):
                for j in range(len(tmpAllData[i])):
                    tmpData.append(tmpAllData[i][j][2])

            self.data.append(tmpData)

        #print(self.data)


    def draw_graph(self):
        # Create a figure instance
        fig = plt.figure(len(plt.get_fignums()))
        # Create an axes instance
        ax = fig.add_subplot(111)

        # Create the boxplot
        bp = ax.boxplot(self.data, whis=[0, 99])

        for box in bp['boxes']:
            # change outline color
            box.set(color='blue', linewidth=0.5)
            # change fill color
            # box.set(facecolor='#1b9e77')

        ## change color and linewidth of the caps
        for cap in bp['caps']:
            cap.set(color='#7570b3', linewidth=0.5)

        ## change color and linewidth of the medians
        for median in bp['medians']:
            median.set(color='red', linewidth=0.5)

        ## change the style of fliers and their fill
        for flier in bp['fliers']:
            flier.set(marker='+', color='red')

        ax.set_xlabel(self.xLabel)
        ax.set_ylabel(self.yLabel)

        ax.set_xticklabels(self.boxLabel)

        # Save the figure
        fig.savefig(fileName + self.fileSaveName, bbox_inches='tight')

class AverageDelay():

    yLabel = "delay [sec]"
    xLabel = "packet nr"

    def __init__(self, mbits):

        self.mbits = mbits
        self.fileSaveName = "-" + str(self.mbits) + "Mbits-average-delay"

        self.data = []
        self.mean = []


        # Collect Data from files

        tmpAllData = []
        filePathDetails = fileName + str(self.mbits) + "-*_latency.csv"

        for file in glob.glob(filePathDetails):
            #print(file)
            tmpAllData.append(np.loadtxt(file, delimiter="\t"))

        #print(tmpAllData)

        for i in range(len(tmpAllData)):
            tmpData = []
            for j in range(len(tmpAllData[i])):
                tmpData.append(tmpAllData[i][j][2])

            self.data.append(tmpData)

        #print(len(self.data))

        # calculate the mean
        for i in range(len(self.data[0])):
            singleMean = 0
            for j in range(len(self.data)):
                singleMean += self.data[j][i]
                #print(str(singleMean) + " | " + str(singleMean / len(self.data)))

            self.mean.append(singleMean / len(self.data))

    def draw_graph(self):
        #plt.hold(False)

        # Create a figure instance
        plt.figure(self.mbits)
        # Create an axes instance
        #ax = fig.add_subplot(111)


        # draw the original values
        for i in range(len(self.data)):
            plt.plot(self.data[i], color="gray")

        # draw the mean Line
        plt.plot(self.mean, color="blue")

        #ax.set_ylim(bottom=0, top=0.0005)
        #ax.set_xlim(left=0, right=len(self.data[0]))

        plt.xlabel(self.xLabel)
        plt.ylabel(self.yLabel)


        #ax.set_xticklabels(self.boxLabel)

        # Save the figure
        plt.savefig(fileName + self.fileSaveName, bbox_inches='tight')

if __name__ == '__main__':

    bt = BoxplotThroughput()

    bt.draw_graph()

    bd = BoxplotDelay()

    bd.draw_graph()

    ad = AverageDelay(5)
    ad.draw_graph()

    ad2 = AverageDelay(20)
    ad2.draw_graph()

    ad3 = AverageDelay(40)
    ad3.draw_graph()

    ad4 = AverageDelay(50)
    ad4.draw_graph()

