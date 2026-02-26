import skrf as rf
import math
import sys
from matplotlib import pyplot as plt


print('Read S1P, S2P files and plot inductor parameters')

# evaluate commandline
networks = []
global_fmin = 0
global_fmax = math.inf

# read all files specified in command line
for arg in sys.argv[1:]:
    network = rf.Network(arg)
    f = network.frequency.f
    networks.append(network)
    global_fmin = max(global_fmin, min(f))
    global_fmax = min(global_fmax, max(f))

    # shorted name if file name is too long
    if len(arg)>17:
        network.name = network.name[:10] + '..' + network.name[-7:]

# set minimum frequency no lower than 100 MHz, to avoid 'divide by zero'
global_fmin = 100e6

# create string with frequency spec for shared frequency range (covered by all data sets)
fspec = str(int(global_fmin/1e6)) + '-' + str(int(global_fmax/1e6)) + 'mhz'


# ---------------------------------------------------------


# function to get differential Zin from one- or twoport data
def get_diff_model (sub):
    if sub.number_of_ports == 1:
        Zdiff=sub.z[0::,0,0]
    elif sub.number_of_ports == 2:
        z11=sub.z[0::,0,0]
        z21=sub.z[0::,1,0]
        z12=sub.z[0::,0,1]
        z22=sub.z[0::,1,1]
        Zdiff = z11-z12-z21+z22
    else:
        print('S-parameter files with ', sub.number_of_ports, ' ports not supported')
        exit(1)    
    
    freq = sub.frequency.f
    omega = freq*2*math.pi
    Ldiff = Zdiff.imag/omega
    Rdiff = Zdiff.real
    Qdiff = Zdiff.imag/Zdiff.real
    
    return freq, Rdiff, Ldiff, Qdiff



# find value of SRF where L=0 for first file
Lmin = math.inf
Rmin = math.inf
Qmax = 0
for network in networks:
    freq0, Rdiff0, Ldiff0, Qdiff0 = get_diff_model(network[fspec])
    Lmin = min(Lmin, Ldiff0[1]*1e9)
    Rmin = min(Rmin, Rdiff0[1])
    Qmax = max (Qmax, max(Qdiff0))


srf_index = rf.find_nearest_index(Ldiff0,min(Ldiff0))
if srf_index>20:
	# limit plots slightly above SRF
	print('SRF found at index ', srf_index, ' f=', freq0[srf_index]/1e9, ' GHz')
	plot_fmax_ghz = 1.2*freq0[srf_index]/1e9
else:
	plot_fmax_ghz = global_fmax/1e9


# ---------------------------------------------------------

# Do the plotting for differential parameters
fig1, axes = plt.subplots(2, 2, figsize=(12, 8))  # NxN grid
fig1.suptitle("Differential Inductor Parameters")

colors = ['b', 'r', 'm', 'c', 'g', 'y', 'k', 'w']
linestyles = ['solid', 'dashed', 'dashdot', 'dotted','solid', 'dashed', 'dashdot', 'dotted']

# Inductance
ax = axes[0,0]
ax.set_ylim (0, 3*Lmin)
ax.set_xlim (0, plot_fmax_ghz)

for n,network in enumerate(networks):
    nw = network[fspec]
    freq, Rdiff, Ldiff, Qdiff = get_diff_model(nw[fspec])
    ax.plot(freq / 1e9, Ldiff*1e9, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Diff. Inductance (nH)")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# Q factor
ax = axes[0,1]
ax.set_ylim (0, 1.2*Qmax)
ax.set_xlim (0, plot_fmax_ghz)

for n,network in enumerate(networks):
    nw = network[fspec]
    freq, Rdiff, Ldiff, Qdiff = get_diff_model(nw[fspec])
    ax.plot(freq / 1e9, Qdiff, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Diff. Q factor")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# Resistance
ax = axes[1,0]
ax.set_ylim (0, 5*Rmin)
ax.set_xlim (0, plot_fmax_ghz)

for n,network in enumerate(networks):
    nw = network[fspec]
    freq, Rdiff, Ldiff, Qdiff = get_diff_model(nw[fspec])
    ax.plot(freq / 1e9, Rdiff, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Diff. Resistance (Ohm)")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# Resistance detail
ax = axes[1,1]
ax.set_ylim (0.5*Rmin, 3*Rmin)

network = networks[0]
Rs = rf.find_nearest(Rdiff0, 3*Rmin)
Rs_index = rf.find_nearest_index(Rdiff0,Rs)
ax.set_xlim (0, freq0[Rs_index]/1e9)


for n,network in enumerate(networks):
    nw = network[fspec]
    freq, Rdiff, Ldiff, Qdiff = get_diff_model(nw[fspec])
    ax.plot(nw.frequency.f / 1e9, Rdiff, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Diff. Resistance (Ohm)")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# ---------------------------------------------------------

# calculate Pi model parameters

# Zser = series element
# Zshunt1 = left shunt element
# Zshunt2 = right shunt element

def get_pi_model (sub):

    y11=sub.y[0::,0,0]
    y21=sub.y[0::,1,0]
    y12=sub.y[0::,0,1]
    y22=sub.y[0::,1,1]
    ymn = (y12+y21)/2

    Zshunt1 =  1 / (y11 + ymn)
    Zshunt2 =  1 / (y22 + ymn)
    Zseries = -1 / (ymn)

    # values over frequency
    freq  = sub.frequency.f
    omega = freq*2*math.pi

    Rseries = Zseries.real
    Lseries = Zseries.imag/omega
    Cshunt1 = -1 / (omega*Zshunt1.imag)
    Cshunt2 = -1 / (omega*Zshunt2.imag)
    Rshunt1 = (1 / (y11+ymn)).real
    Rshunt2 = (1 / (y22+ymn)).real
    Rshunt = (Rshunt1+Rshunt2)/2

    return freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt


# ---------------------------------------------------------

# Do the plotting for Pi model parameters
fig2, axes = plt.subplots(2, 3, figsize=(16, 8))  # NxN grid
fig2.suptitle("Pi model Parameters")


# Inductance in series path
ax = axes[0,0]
ax.set_ylim (0, 3*Lmin)
ax.set_xlim (0, plot_fmax_ghz)

for n,network in enumerate(networks):
    if network.number_of_ports == 2:
        nw = network[fspec]
        freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt = get_pi_model(nw)
        ax.plot(freq / 1e9, Lseries*1e9, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Series path L (nH)")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# Resistance in series path
ax = axes[0,1]
ax.set_ylim (0, 5*Rmin)
ax.set_xlim (0, plot_fmax_ghz)

for n,network in enumerate(networks):
    if network.number_of_ports == 2:
        nw = network[fspec]
        freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt = get_pi_model(nw)
        ax.plot(freq / 1e9, Rseries, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Series path tesistance (Ohm)")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# Get limits for plotting shunt elements
Cmin = 1e12
Rmin = 1e12
for n,network in enumerate(networks):
    if network.number_of_ports == 2:
        nw = network[fspec]
        freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt = get_pi_model(nw)
        Cmin = min(Cmin, min(Cshunt1) )
        Rmin = min(Rmin, min(Rshunt))


# Shunt path C1
ax = axes[1,0]
ax.set_ylim (0, 5*Cmin*1e15)

for n,network in enumerate(networks):
    if network.number_of_ports == 2:
        nw = network[fspec]
        freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt = get_pi_model(nw)
        ax.plot(freq / 1e9, Cshunt1*1e15, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Shunt path Capacitance 1 (fF)")
ax.set_xmargin(0)
ax.legend()
ax.grid()


# Shunt path C2
ax = axes[1,1]
ax.set_ylim (0, 5*Cmin*1e15)

for n,network in enumerate(networks):
    if network.number_of_ports == 2:
        nw = network[fspec]
        freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt = get_pi_model(nw)
        ax.plot(freq / 1e9, Cshunt2*1e15, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Shunt path Capacitance 2 (fF)")
ax.set_xmargin(0)
ax.legend()
ax.grid()

# Shunt path R
ax = axes[1,2]
ax.set_ylim (0, 20*Rmin)

for n,network in enumerate(networks):
    nw = network[fspec]
    freq, Rseries, Lseries, Cshunt1, Cshunt2, Rshunt = get_pi_model(nw)
    ax.plot(freq / 1e9, Rshunt, color = colors[n], linestyle=linestyles[n], label=nw.name)
ax.set_xlabel("Frequency (GHz)")
ax.set_ylabel("Shunt path resistance (Ohm)")
ax.set_xmargin(0)
ax.legend()
ax.grid()



fig1.tight_layout()
fig1.savefig("/workdir/inductor_plot_diff.png")
fig2.tight_layout()
fig2.savefig("/workdir/inductor_plot_pi.png")

