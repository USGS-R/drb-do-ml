
import pandas as pd
import re
import os
import seaborn as sns
import matplotlib.pyplot as plt
import plot_utils
from plot_utils import read_and_filter_df, make_holdout_id_col, filter_out_urban_spatial, replacements, model_labels, df_site_filt
import numpy as np
import seaborn.objects as so


outdir = f"../../out"


def format_plot(g):
    for i, ax in enumerate(g.axes.flatten()):
        ax.grid()
        ax.set_axisbelow(True)

    g.set_titles('{col_name}')

    g.axes.flatten()[0].set_ylabel("RMSE (mg O$_\mathrm{{2}} \mathrm{L^{-1}}$)")

    for ax in g.axes.flatten():
        title = ax.get_title()
        if 'do_min' in title:
            new_title = 'DO$_\mathrm{min}$'
        elif 'do_max' in title:
            new_title = 'DO$_\mathrm{max}$'
        elif 'do_mean' in title:
            new_title = 'DO$_\mathrm{mean}$'
        ax.set_title(new_title)

    sns.move_legend(g, loc='lower left', bbox_to_anchor=(0.80, 0.1))
    g._legend.set_title("Model Version")
    return g


######## stripplot by site (temporal)###########################################
df_comb_site_temporal = df_site_filt[df_site_filt["holdout_id"] == "temporal"]
plt.rcParams.update({'font.size': 18})
g = sns.catplot(
    x="site_id",
    y="rmse",
    col="variable",
    data=df_comb_site_temporal,
    hue="model_id",
    kind="strip",
    dodge=True,
    errorbar="sd",
    col_order=["do_min", "do_mean", "do_max"],
    hue_order=model_labels,
)
g = format_plot(g)

g.set_xlabels("Site")
g.set_xticklabels(rotation=45)

plt.savefig(os.path.join(outdir, "val_results_by_site_strip.png"), bbox_inches='tight', dpi=300)

######## Barplot by holdout ####################################################
g = sns.catplot(
    x="holdout_id",
    y="rmse",
    col="variable",
    data=df_site_filt,
    hue="model_id",
    kind="bar",
    errorbar="sd",
    col_order=["do_min", "do_mean", "do_max"],
    hue_order=model_labels,
    order=["temporal", "spatial similar", "spatial dissimilar"],
)
g = format_plot(g)

# Format x-tick labels so that they are title case and "Spatial" and "Similar"
# are on different lines
for ax in g.axes.flatten():
    labels = ax.get_xticklabels()
    new_labels = []
    for l in labels:
        label_text = l.get_text()
        new_labels.append(label_text.replace(" ", "\n").title())
    ax.set_xticklabels(new_labels)

g.set_xlabels("Holdout Experiment")
plt.savefig(os.path.join(outdir, "val_results_by_holdout.png"), bbox_inches='tight', dpi=300)


######## prep for lineplot by month  ###########################################
month_order = [10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9]

df_comb_month = read_and_filter_df("site_month", "val")

df_comb_month = make_holdout_id_col(df_comb_month)
df_comb_month = df_comb_month.replace(replacements)

df_comb_month = df_comb_month[df_comb_month['holdout_id'] == 'temporal']


######## Lineplot by month #####################################################
g = sns.relplot(
    x="date",
    y="rmse",
    col="variable",
    data=df_comb_month,
    hue="model_id",
    kind="line",
    legend=True,
    hue_order=model_labels,
)

for ax in g.axes.flatten():
    ax.set_xticks(list(range(1,13)))

sns.move_legend(g, loc='lower left', bbox_to_anchor=(0.8, 0.1))
g = format_plot(g)
    
g.set_xlabels("Month")
plt.savefig(os.path.join(outdir, "val_results_by_month_line.png"), bbox_inches='tight', dpi=300)

