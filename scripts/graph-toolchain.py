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
from operator import itemgetter


parser = argparse.ArgumentParser(description='Programm create a PIF list')
parser.add_argument('-n', '--name', help='Please give a Data path to the csv File, example: rnc-psr-tXX-r')
parser.add_argument('-p', '--ping', help='Please give a Data path to the csv File, example: ping-psr-tXX-i')


args = parser.parse_args()

fileName = args.name
fileNamePing = args.ping

class BoxplotThroughput():

    data = []
    mbits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    yLabel = "throughput [Mbps]"
    xLabel = "fixed send rate [Mbps]"
    boxLabelX = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
    boxLabelY = [10, 20, 30, 40, 50]

    fileSaveName = "-throughput"

    def __init__(self):

        # Collect Data from files
        for l in range(len(self.mbits)):
            tmpAllData = []
            filePathDetails = fileName + str(self.mbits[l]) + "-*_bit_per_*"


            for file in sorted(glob.glob(filePathDetails)):
                #print(file)
                tmpAllData.append(np.loadtxt(file, delimiter="\t"))

            tmpData = []
            for i in range(len(tmpAllData)):
                for j in range(len(tmpAllData[i])):
                    try:
                        tmpData.append(tmpAllData[i][j][2] / 1000000)
                    except:
                        print(i)

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

        ax.grid(axis='y', ls=':', color='gray')

        ax.set_xlabel(self.xLabel)
        ax.set_ylabel(self.yLabel)

        ax.set_xticklabels(self.boxLabelX)
        ax.set_yticks(self.boxLabelY)

        # Save the figure
        fig.savefig(fileName + self.fileSaveName, bbox_inches='tight')

        fig.clear()

class BoxplotDelay():

    data = []
    mbits = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    yLabel = "delay [sec]"
    xLabel = "fixed send rate [Mbps]"
    boxLabelX = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
    boxLabelY = [0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35]

    fileSaveName = "-delay"

    def __init__(self):

        # Collect Data from files
        for l in range(len(self.mbits)):
            tmpAllData = []
            filePathDetails = fileName + str(self.mbits[l]) + "-*_latency.csv"


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

        ax.grid(axis='y', ls=':', color='gray')

        ax.set_xticklabels(self.boxLabelX)
        ax.set_ybound(0, 0.35)

        # Save the figure
        fig.savefig(fileName + self.fileSaveName, bbox_inches='tight')

        fig.clear()

class AverageDelay():

    yLabel = "delay [sec]"
    xLabel = "packet nr"

    boxLabelY = [0.05, 0.1, 0.15, 0.2, 0.25, 0.3]


    def __init__(self, mbits):

        self.mbits = mbits
        self.fileSaveName = "-" + str(self.mbits) + "Mbits-average-delay"

        self.data = []
        self.mean = []


        # Collect Data from files

        tmpAllData = []
        filePathDetails = fileName + str(self.mbits) + "-*_latency.csv"

        for file in sorted(glob.glob(filePathDetails)):

            tmpAllData.append(np.loadtxt(file, delimiter="\t"))



        for i in range(len(tmpAllData)):
            tmpData = []

            for j in range(len(tmpAllData[i])):
                #tmpData.append([tmpAllData[i][j][0] - tmpAllData[i][0][0], tmpAllData[i][j][2]])
                tmpData.append([j, tmpAllData[i][j][2]])
                #print(tmpAllData[i][j][2])

            self.data.append(tmpData)

        #print(len(self.data))

        # calculate the mean
        for i in range(len(self.data[0])):
            singleMean = 0
            for j in range(len(self.data)):
                try:
                    singleMean += self.data[j][i][1]
                except:
                    singleMean += 0
                #print(str(singleMean) + " | " + str(singleMean / len(self.data)))

            self.mean.append([self.data[0][i][0], singleMean / len(self.data)])

    def draw_graph(self):
        #plt.hold(False)

        # Create a figure instance
        plt.figure(self.mbits)
        # Create an axes instance

        # draw the original values
        for i in range(len(self.data)):
            x = []
            y = []
            for j in range(len(self.data[i])):
                x.append(self.data[i][j][0])
                y.append(self.data[i][j][1])
            plt.plot(x, y, color="gray")

        # draw the mean Line
        x = []
        y = []
        for i in range(len(self.mean)):
            x.append(self.mean[i][0])
            y.append(self.mean[i][1])

        plt.plot(x, y, color="blue")

        # draw a line on the highest mean
        plt.axhline(max(y), ls="--", color="black")

        plt.xlim(left=0)

        plt.xlabel(self.xLabel)
        plt.ylabel(self.yLabel)

        plt.yticks(self.boxLabelY)
        #plt.ylim(top=0.1)

        plt.grid(ls=':', color='gray')

        # Save the figure
        plt.savefig(fileName + self.fileSaveName, bbox_inches='tight')

        plt.close()

class LossFrequency():
    yLabel = "loss frequency"
    xLabel = "packet nr"

    def __init__(self, mbits):

        self.mbits = mbits
        self.fileSaveName = "-" + str(self.mbits) + "Mbits-loss-frequency-delay"

        self.data = []
        self.mean = []

        # Collect Data from pkts in fly files

        filePathDetails = fileName + str(self.mbits) + "-*_pkts_in_fly.csv"

        for file in sorted(glob.glob(filePathDetails)):
            self.data.append(np.loadtxt(file, delimiter="\t"))


        # Collect Data from dropped pckts files
        filePathDetails = fileName + str(self.mbits) + "-*_droped.csv"
        dataCount = 0


        for file in sorted(glob.glob(filePathDetails)):

            for row in np.loadtxt(file, delimiter="\t"):
                # mark the dropped Packages
                row[2] = -1
                self.data[dataCount] = np.append(self.data[0], row).reshape((-1,3))

            # Sort the data after the timecode
            self.data[dataCount] = sorted(self.data[0], key=itemgetter(1))

            dataCount += 1

        # calculate the mean
        for i in range(len(self.data[0])):
            singleMean = 0
            for j in range(len(self.data)):
                try:
                    if(self.data[j][i][2] == -1):
                        singleMean += 1
                except:
                    singleMean += 0

            self.mean.append(singleMean)


    def draw_graph(self):
        # plt.hold(False)

        # Create a figure instance
        plt.figure(self.mbits)
        # Create an axes instance
        # ax = fig.add_subplot(111)

        # draw the mean Line
        plt.plot(self.mean, color="blue")

        # ax.set_ylim(bottom=0, top=0.0005)
        # ax.set_xlim(left=0, right=len(self.data[0]))

        plt.xlabel(self.xLabel)
        plt.ylabel(self.yLabel)

        plt.grid(ls=':', color='gray')

        # Save the figure
        plt.savefig(fileName + self.fileSaveName, bbox_inches='tight')

        plt.close()

class LossFrequency2():
    yLabel = "loss frequency"
    xLabel = "packet nr"

    def __init__(self, mbits):

        self.mbits = mbits
        self.fileSaveName = "-" + str(self.mbits) + "Mbits-loss-frequency2-delay"

        self.data = []
        self.mean = []
        self.losses = []


        # Collect Data from files

        tmpAllData = []
        filePathDetails = fileName + str(self.mbits) + "-*_latency.csv"

        for file in sorted(glob.glob(filePathDetails)):
            #print(file)
            tmpAllData.append(np.loadtxt(file, delimiter="\t"))

        for i in range(len(tmpAllData)):
            tmpData = []
            for j in range(len(tmpAllData[i])):
                tmpData.append(tmpAllData[i][j][2])

            self.data.append(tmpData)

        # calculate the mean delay for the hole time
        for delay in self.data:
            self.mean.append(np.mean(delay))


        for i in range(len(self.data[0])):
            losses = 0
            for j in range(len(self.data)):
                try:
                    if(self.data[j][i] > self.mean[j]):
                        losses += 1
                except:
                    pass
            self.losses.append(losses)

    def draw_graph(self):
        # plt.hold(False)

        # Create a figure instance
        plt.figure(self.mbits)
        # Create an axes instance
        # ax = fig.add_subplot(111)

        # draw the mean Line
        plt.plot(self.losses, color="blue")

        # ax.set_ylim(bottom=0, top=0.0005)
        # ax.set_xlim(left=0, right=len(self.data[0]))

        plt.xlabel(self.xLabel)
        plt.ylabel(self.yLabel)

        plt.grid(ls=':', color='gray')

        # Save the figure
        plt.savefig(fileName + self.fileSaveName, bbox_inches='tight')

        plt.close()

class CCDF():
    yLabel = "CDF"
    xLabel = "RTT [s]"

    def __init__(self):


        self.fileSaveName = "-ccdf"

        self.data = []
        self.sum = []
        self.cdf = []
        self.ccdf = []
        self.legend = []

        # Collect Data from pings

        filePathDetails = fileNamePing + "*.csv"

        for file in sorted(glob.glob(filePathDetails)):
            print(file)
            self.data.append(np.sort(np.loadtxt(file, delimiter="\t")))
            self.legend.append(file)

        print(len(self.data))
        #np.bincount(self.data)

        # calculate cdf values
        for val in self.data:
            tmpSum = float(val.sum())
            tmpCumSum = val.cumsum()
            tmpCumSum2 = tmpCumSum / tmpCumSum[-1]
            print("\nCumSum: " + str(tmpCumSum) + "\nNorm: "+ str(tmpCumSum2))

            self.sum.append(tmpSum)
            self.cdf.append(val.cumsum(0) / tmpSum)
            #self.cdf.append(np.cumsum()/ tmpSum)


            # calculate ccdf values
            self.ccdf.append(1 - (val.cumsum(0) / tmpSum))



    def draw_graph(self):

        #for i in range(len(self.cdf)):
        #    plt.plot(self.data[i], self.cdf[i], 'bo')

        for val in self.data:
            plt.plot((val.cumsum() / val.cumsum()[-1]))

        plt.xscale('log')

        plt.ylim([0,1])
        plt.ylabel('CDF')
        plt.xlabel('RTT [s]')

        plt.savefig(fileNamePing + "-cdf.png")

        plt.close()


        #for i in range(len(self.ccdf)):
        #    plt.plot(self.data[i], self.ccdf[i], 'bo')
        for val in self.data:
            plt.plot(val, 1 - (val.cumsum() / val.cumsum()[-1]))

        plt.legend(self.legend)


        plt.yscale('log')
        #plt.xscale('log')


        plt.ylabel('CCDF')
        plt.xlabel('RTT [s]')

        plt.savefig(fileNamePing + self.fileSaveName + ".png")

        plt.close()




if __name__ == '__main__':
    if fileName:
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

        lf = LossFrequency(40)
        lf.draw_graph()

        lf = LossFrequency(50)
        lf.draw_graph()

        lf2 = LossFrequency2(40)
        lf2.draw_graph()

        lf2 = LossFrequency2(50)
        lf2.draw_graph()

    if fileNamePing:
        p = CCDF()
        p.draw_graph()
