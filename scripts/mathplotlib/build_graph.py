import numpy as np
import matplotlib.pyplot as plt

def pic(x,y,z): 

    plt.contourf(x,y,z)
    plt.xlabel('Außenradius (in $\mu$m)')
    plt.ylabel('Innenradius (in $\mu$m)')
    plt.colorbar()
    plt.savefig('result2d.png')
    plt.show()

if __name__ == '__main__':

    a = []
    X = []
    Y = []
    Z = []

    a = np.loadtxt("DataMaximumTHKonst.txt", delimiter=",")
    
    for i in range(0,15):               # Außenradius Anzahl Schritte
        x = []
        y = []
        z = []
        for j in range(0,15):           # Innenradius Anzahl Schritte
            x.append(a[i*15+j][0])
            y.append(a[i*15+j][1])
            z.append(a[i*15+j][2])
        X.append(x)
        Y.append(y)
        Z.append(z)
    pic(X,Y,Z)
