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
import os
import seaborn as sns
import matplotlib.pyplot as plt
import plot_utils
from plot_utils import read_and_filter_df
import numpy as np
import seaborn.objects as so


# +
run_id = 215

outdir = f"../../out/pred_perf/{run_id}"

if not os.path.exists(outdir):
    os.makedirs(outdir)
# -


models = [
    "0_baseline_LSTM",
    "1_metab_multitask",
    "1a_multitask_gpp_er",
    "2_multitask_dense",
]

df_comb_reach = read_and_filter_df("reach", "val")
df_comb_reach = df_comb_reach.replace(
    {
        "0_baseline_LSTM": "Baseline",
        "1a_multitask_do_gpp_er": "Metab Multitask - GPP, ER",
        "1_metab_multitask": "Metab Multitask",
        "2_multitask_dense": "Metab Dependent",
    }
)

df_comb_reach.holdout.unique()


test_sites_urban = ["01475530", "01475548"]


def define_group(row):
    if row["holdout"] != "temporal" and row["holdout"] != "1_urban":
        return "spatial non-urban"
    elif row["holdout"] == "temporal":
        if row['site_id'] in test_sites_urban:
            return "temporal urban"
        else:
            return "temporal non-urban"
    elif row["holdout"] == '1_urban':
        return "spatial one-urban"


df_comb_reach["holdout_id"] = df_comb_reach.apply(define_group, axis=1)

df_comb_reach.holdout_id.unique()


def plot_by_site_or_holdout(data, x, kind, outfile):
    g = sns.catplot(
        x=x,
        y="rmse",
        col="variable",
        data=data,
        hue="model_id",
        kind=kind,
        legend=False,
        errorbar="sd",
        col_order=["do_min", "do_max"],
        dodge=True
    )
    g.set_xticklabels(rotation=90)

    for i, ax in enumerate(g.axes.flatten()):
        ax.grid()
        ax.set_axisbelow(True)

    g.axes.flatten()[0].set_ylabel("RMSE (mg O2/l)")
    ax.legend(bbox_to_anchor=(1.05, 0.55))
    plt.tight_layout()
    plt.show()
    plt.savefig(os.path.join(outdir, outfile), dpi=300)
    plt.clf()



######## Barplot by site (temporal)############################################
df_comb_reach_temporal = df_comb_reach[df_comb_reach['holdout_id'] == 'temporal non-urban']
plot_by_site_or_holdout(df_comb_reach_temporal, "site_id", "bar", "val_results_by_site.jpg")



######## stripplot by site (temporal)############################################
df_comb_reach_temporal = df_comb_reach[df_comb_reach['holdout_id'] == 'temporal non-urban']
plot_by_site_or_holdout(df_comb_reach_temporal, "site_id", "strip", "val_results_by_site_strip.jpg")


######## stripplot by site (temporal)############################################
df_comb_reach_spatial = df_comb_reach[df_comb_reach['holdout_id'] == 'spatial non-urban']
plot_by_site_or_holdout(df_comb_reach_spatial, "site_id", "strip", "val_results_by_site_strip.jpg")


######## Barplot by holdout ######################################################
plot_by_site_or_holdout(df_comb_reach, "holdout_id", "bar", "val_results_by_holdout.jpg")


# +
######## Stripplot by holdout ####################################################
plot_by_site_or_holdout(df_comb_reach, "holdout_id", "strip", "val_results_by_holdout_strip.jpg")


######## Barplot overall ######################################################
df_comb = read_and_filter_df("overall", "val")

# +
fig, ax = plt.subplots(figsize=(17, 6))
ax = sns.barplot(
    x="variable", y="rmse", data=df_comb, hue="model_id", ax=ax
)  # , hue_order=['0_baseline_LSTM', '1a_multitask_do_gpp_er', '1_metab_multitask', '2_multitask_dense'])
for c in ax.containers:
    ax.bar_label(c, label_type="center", fmt="%.2f")

ax.set_xlabel("")
plt.legend(loc="lower left", bbox_to_anchor=(1.05, 0), title="Model")
plt.tight_layout()
plt.savefig(os.path.join(outdir, "val_results_overall.png"), dpi=300)


######## Barplot calculating site metrics then averaging #########################################
fig, ax = plt.subplots(figsize=(15, 4))
ax = sns.barplot(
    x="variable",
    y="rmse",
    hue="model_id",
    data=df_comb_reach,
    order=["do_min", "do_max"],
)

for c in ax.containers:
    ax.bar_label(c, label_type="center", fmt="%.2f")

ax.set_ylabel("RMSE (mg O2/l)")

plt.legend(loc="lower left", bbox_to_anchor=(1.05, 0), title="Model")
plt.tight_layout()
plt.savefig(os.path.join(outdir, "val_results_overall_avg_across_sites.jpg"), dpi=300)


# +
######## Barplot calculating site metrics then median-ing #########################################
fig, ax = plt.subplots(figsize=(17, 3))
ax = sns.barplot(
    x="variable",
    y="rmse",
    hue="model_id",
    data=df_comb_reach,
    hue_order=None,
    estimator=np.median,
)

for c in ax.containers:
    ax.bar_label(c, label_type="center", fmt="%.2f")

plt.legend(loc="lower left", bbox_to_anchor=(1.05, 0), title="Model")
plt.savefig(os.path.join(outdir, "val_results_overall_median_across_sites.jpg"), dpi=300)
# -

df_comb_month = read_and_filter_df("month", "val")

month_order = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8]

# +
######## Barplot by month #########################################
g = sns.catplot(
    x="date",
    y="rmse",
    col="variable",
    data=df_comb_month,
    hue="model_id",
    kind="strip",
    legend=False,
    ci="sd",
    dodge=True,
    # hue_order=models,
)

for ax in g.axes.flatten():
    ax.grid()
    ax.set_axisbelow(True)
g.set_xlabels("month")
plt.legend(bbox_to_anchor=(1.05, 0.55))
plt.tight_layout()
plt.savefig(os.path.join(outdir, "val_results_by_month_strip.jpg"), dpi=300)
plt.clf()
# -

df_comb_month.sort_values("rmse").iloc[-1]

df_comb_month[df_comb_month["date"] == 12].sort_values("rmse").iloc[-1]

df_2 = df_comb_month[
    (df_comb_month["rep_id"] == 2) & (df_comb_month["model_id"].str.startswith("2"))
]
df_2_pg = df_comb_month[df_comb_month["model_id"].str.startswith("2")]

sns.barplot(x="date", y="rmse", hue="variable", data=df_2)

g = sns.catplot(
    x="date", y="rmse", hue="rep_id", col="variable", data=df_2_pg, col_wrap=1, aspect=2
)
for ax in g.axes.flatten():
    ax.grid()
    ax.set_axisbelow(True)
g.set_xlabels("month")
plt.tight_layout()
plt.savefig(os.path.join(outdir, "2_monthly_performance.jpg"), dpi=300)
