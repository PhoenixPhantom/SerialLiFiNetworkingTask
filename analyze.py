import numpy as np
import scipy
import matplotlib.pyplot as plt

def analyze_file(path):
    with open(path, "r") as data:
        i = 0
        lines = data.readlines()
        while i < len(lines):
            if lines[i] == "\n": 
                i += 1
                continue
            i = i + analyze_scenario(lines[i:])


def analyze_scenario(lines):
    i = 0
    assert(len(lines) >= (6 + 1) * 4 - 1)
    ax = plt.gca()
    while i < len(lines):
        if lines[i] == "\n": 
            i += 1
            break
        i = i + analyze_test(lines[i:], ax)

    print("")

    ax.set_ylabel("Measurement [b/ms], [s] or [#]")
    ax.set_xlabel("Time [s]")
    plt.legend()
    plt.show()
    return i

Microsecond = 1000
Millisecond = Microsecond * 1000
Second = Millisecond * 1000
Minute = Second * 60



def analyze_test(lines, ax):
    title = lines[0]
    assert(len(lines) >= 6)
    part = title.partition(" (")
    ax.set_title("")
    e = part[2].index(")")
    title = part[2][:e]
    i = title.index(": ")
    load = int(title[i+2:])
    ax.set_title("Network performance in Scenario: " + part[0])

    i = 1
    timescale = np.zeros(1)
    scale = Second / Millisecond
    thrp = np.zeros(int(Minute / Second * scale))
    while i < len(lines):
        if lines[i] == "\n": 
            i += 1
            break
        entries = lines[i].split(",")

        if i == 1:
            data = np.asarray(list(map(int, entries[1:])))
            timescale = data / Second
        else:
            if i == 5:
                data = np.asarray(list(map(int, entries[1:])))
                print("# serial comm. errors ", title, ": ", data)
            elif i == 4:
                #data = np.asarray(list(map(float, entries[1:])))
                data = thrp
                ax.plot(np.linspace(0, 60, len(data)), data, label=" Thrp [b/ms] " + title)
                print(entries[0] + " " + title, " 95% of the data is within ", confidence_interval(0.95, data * (Second/Millisecond)), "b/s")
            else:
                data = np.asarray(list(map(float, entries[1:])), dtype=float) / Second
                part = entries[0].partition(" [")
                if len(part) > 2 and part[2].find("ns") >= 0:
                    assert("Packet delay" == part[0])
                    name = "Delay [s] " + title
                    endt = timescale + data
                    startp = np.asarray(np.floor(timescale * scale), dtype=int)
                    endp = np.asarray(np.floor(endt * scale), dtype=int)
                    weights = np.where(endp > startp, 1/np.asarray(endp - startp, dtype=float), 1)
                    for d in range(len(weights)): thrp[startp[d]:endp[d] + 1] += weights[d] 
                    thrp *= load / (Second / Millisecond) * scale
                else:
                    name = "# Retransm. " + title
                print(name, " 95% of the data is within ", confidence_interval(0.95, data))
                ax.plot(timescale, data, label=name)
        i += 1

    print("")
    return i


def confidence_interval(conf, array):
    data = np.sort(array[~np.isnan(array)])
    if len(data) == 0: return np.nan, np.nan
    lower, upper = (data[0], data[-1])

    seen = 0.0
    for i in range(len(data)):
        if seen < (1.0-conf):
            lower = data[i]
            
        seen += 1 / len(data)
        if seen >= conf:
            upper = data[i]
            break

    return float(lower), float(upper)
