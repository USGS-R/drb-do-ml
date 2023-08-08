# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:light
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

import pandas as pd
import re
import os
import seaborn as sns
import matplotlib.pyplot as plt
import plot_utils
from plot_utils import read_and_filter_df, make_holdout_id_col, filter_out_urban_spatial, replacements, model_labels
import numpy as np
import seaborn.objects as so


# +
outdir = f"../../out"

# -

df_comb_reach = read_and_filter_df("reach", "val")
df_comb_reach = df_comb_reach.replace(replacements)

test_sites_urban = ["01475530", "01475548"]

# -

df_comb_reach = make_holdout_id_col(df_comb_reach)

df_reach_filt = filter_out_urban_spatial(df_comb_reach)


def plot_by_site_or_holdout(data, x, kind, outfile,
                            col_order=['do_min', 'do_mean', 'do_max'],
                            order=None):
    plt.rcParams.update({'font.size': 14})
    g = sns.catplot(
        x=x,
        y="rmse",
        col="variable",
        data=data,
        hue="model_id",
        kind=kind,
        errorbar="sd",
        col_order=col_order,
        dodge=True,
        hue_order=model_labels,
        order=order,
    )
    g.set_xticklabels(rotation=45)
    g.set_titles('{col_name}')
    # g.set_ylabels(

    for i, ax in enumerate(g.axes.flatten()):
        ax.grid()
        ax.set_axisbelow(True)

    g.axes.flatten()[0].set_ylabel("RMSE (mg O2/l)")
    sns.move_legend(g, loc='lower left', bbox_to_anchor=(0.9, 0.1))
    # plt.tight_layout()
    plt.savefig(os.path.join(outdir, outfile), bbox_inches='tight', dpi=300)
    return g



######## stripplot by site (temporal)###########################################
df_comb_reach_temporal = df_comb_reach[df_comb_reach["holdout_id"] == "temporal"]
plot_by_site_or_holdout(
    df_comb_reach_temporal, "site_id", "strip", "val_results_by_site_strip.jpg"
)

######## Barplot by holdout ######################################################
g = plot_by_site_or_holdout(
    df_reach_filt,
    "holdout_id",
    "bar",
    "val_results_by_holdout.jpg",
    order=["temporal", 'spatial similar', 'spatial dissimilar'],
)


# -

month_order = [10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9]

df_comb_month = read_and_filter_df("month_reach", "val")

df_comb_month = make_holdout_id_col(df_comb_month)
df_comb_month = df_comb_month.replace(replacements)

df_comb_month = df_comb_month[df_comb_month['holdout_id'] == 'temporal']


# +
######## Lineplot by month #########################################
g = sns.relplot(
    x="date",
    y="rmse",
    col="variable",
    data=df_comb_month,
    hue="model_id",
    kind="line",
    legend=True,
    # ci="sd",
    # dodge=True,
    # order=month_order,
    hue_order=model_labels,
)

for ax in g.axes.flatten():
    ax.grid()
    ax.set_axisbelow(True)
    ax.set_xticks(list(range(1,13)))

sns.move_legend(g, loc='lower left', bbox_to_anchor=(0.83, 0.1))
    
g.set_xlabels("month")
# plt.tight_layout()
plt.savefig(os.path.join(outdir, "val_results_by_month_line.jpg"), dpi=300)
# -

