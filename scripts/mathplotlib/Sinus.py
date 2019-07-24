import numpy as np
import matplotlib.pyplot as plt

def pic(x,s1,s2,s3,s4): 

    plt.plot(x,s1,label = 'Sinus $\dfrac{\lambda}{3}$')
    plt.plot(x,s2,label = 'Sinus $\dfrac{\lambda}{3}$')
    plt.plot(x,s3,label = 'Sinus $\dfrac{\lambda}{3}$')
    plt.plot(x,s4,label = 'Sinus integriert')
    plt.xlim(0,np.pi/2)
    plt.ylim(-1.1,1.1)
    plt.xticks([])
    plt.yticks([])
    plt.axhline(y=0, color='k')
    plt.savefig('Sinus.png')
    #plt.show()

if __name__ == '__main__':

    X = []
    s4 = []
    s1 = []
    s2 = []
    s3 = []
    
    for i in range(200):               # Außenradius Anzahl Schritte
        X.append(i*np.pi/200)
        s1.append(np.sin(X[i]))
        s2.append(np.sin(X[i]-np.pi/2))
        s3.append(np.sin(X[i]-np.pi))
        s4.append(np.sin(X[i]-np.pi*3/2))
    pic(X,s1,s2,s3,s4)
