# OVERLAY2022, https://github.com/aclai-lab/OVERLAY2022.jl

###########################################################
#                       How to use                        #
###########################################################

# 1) Define where csvs are placed
# 2) Set the parameters accordingly to your needings, as shown in the example code
# 3) Select one, two, or more csv that has to be merged and plotted.
#    Make an array with those csvs and convert it into a sequence of numpy matrixes
# 4) Let the loop do the plotting. The result can be saved both as .png or .pgf

###########################################################
#                     Dependencies                        #
###########################################################
import pandas as pd
import numpy as np
import matplotlib

matplotlib.use("pgf")
matplotlib.rcParams.update({
    "pgf.texsystem": "pdflatex",
    'font.family': 'serif',
    'text.usetex': True,
    'pgf.rcfonts': False,
})

from matplotlib.lines import Line2D
import matplotlib.pyplot as plt

###########################################################
#                    General parameters                   #
###########################################################

linestyles = [
    ('solid',                 (0, ())           ), 
    ('loosely dotted',        (0, (1, 5))       ),
    ('dashed',                (0, (7, 7))       ),
    ('dashdotted',            (0, (3, 5, 1, 5)) ),
    ('dotted',                (0, (1, 1))       ),
    ('densely dashed',        (0, (5, 3))       ),
]
colors = ['b', 'r', 'c', 'm', 'y', 'k']

###########################################################
#                        Plotting                         #
###########################################################
def export_plot(data, x, n_pr, linestyles, colors, memo_values, prun_values, export_name, legend_ncol):
    plt.figure(figsize=(6.5, 4), dpi=80)
    
    # For each pruning factor (thus, for each specified csv)
    for i in range(n_pr):
        nrows, ncols = data[i].shape

        # For each row in the current csv
        for row in range(nrows):
            # Draw a line representing the cumulated time 
            # to model-checking until some n-th formula
            plt.plot(
                np.linspace(1,ncols,x),
                data[i].cumsum(axis=1)[row],
                linestyle=linestyles[row][1],
                color=colors[i],
                linewidth=1
            )

            plt.xlabel("$i$-{th} formula", fontsize=22, labelpad=10)
            plt.ylabel("Cumulative time", fontsize=22, labelpad=10)
            plt.tick_params(axis='both', which='major', labelsize=18)

    # Create a custom legend, which color is black
    lines = [Line2D([0], [0], color='black', linestyle=linestyles[i][1]) for i in range(nrows)]
    labels = ["${}$".format(memo_values[i]) for i in range(nrows)]
    plt.legend(lines, labels, prop={'size': 18}, ncol=legend_ncol)

    plt.tight_layout()
    plt.savefig(export_name)
    return

###########################################################
#                           Main                          #
###########################################################
if __name__ == '__main__':
    memo_values  = ["h_{memo}^{single}", "h_{memo}^{multi}=0", "h_{memo}^{multi}=1", "h_{memo}^{multi}=2", "h_{memo}^{multi}=4", "h_{memo}^{multi}=8"]
    prun_values  = ["0.2", "0.5"]

    export_name = "Insert filename here, including the extension (e.g .png or .pgf)"
    x = 1000
    first_set  = "50_16_1/50.0_20.0_16.0_1.0_1000.0_0.2_1000.0_1.0.csv" #csv with 0.2 pruning factor
    second_set = "50_16_1/50.0_20.0_16.0_1.0_1000.0_0.5_1000.0_1.0.csv" #csv with 0.5 pruning factor
    data = [pd.read_csv(first_set, header=None), pd.read_csv(second_set, header=None)]
    data = [np.array(data[0]), np.array(data[1])]
    export_plot(data, x, len(prun_values), linestyles, colors, memo_values, prun_values, export_name + format, legend_ncol=1)