# MoonGen
Dies ist mein Repository fuer meine Bachelorarbeit.

Ich werde eine schon modifizierte MoonGen Version die ich von meinem Betreuer erhalten habe verwenden.

In den folgenden Monaten versuche ich die Eigenschaften eines LTE-Netzes in MoonGen + DPDK zu emulieren.


# TODO List:
- fuer den anfang 35Mbps uplink
- Uplink Richung
- Downlink Richtung

# IDEE:
- Ich glaube man braucht keine MB/s und rx/tx-queue Parameter mehr da man immer von Theoretischen 50Mbps ausgeht.

- Delay in abhaengigkeit von der Menge/Groeße des Puffers der die incomming Packages enthaelt. Delay durch eine Wahscheinlichkeitsverteilung hinzufuegen

- mit der empirische Standardabweichung rumspielen

# Analyse
- The median is given by the central mark and the borders of the box are the 0.25 and 0.75 percentiles. The lower and upper whiskers denote the range of data points that are not considered outliers, based on the 0.99 coverage of the Gaussian distribution.(A_measurment_study...)
- 50 independent runs of two seconds per run, danach den durschnitt errechnen und dann dieses 50 werte plotten
- 40 Mbps and packets 1400 Bytes this dwell time would amount to a buffer size of around 280 packets
