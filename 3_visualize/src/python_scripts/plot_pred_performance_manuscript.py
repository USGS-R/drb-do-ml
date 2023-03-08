# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %%
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import plot_utils
import numpy as np
import seaborn.objects as so

# %%
df_comb_reach = plot_utils.read_and_filter_df("reach", "val")

# %%
df_comb_reach.model_id.unique()

# %%
models = ['0_baseline_LSTM', '1_metab_multitask', '2_multitask_dense']

# %%
df_comb_month = plot_utils.read_and_filter_df('month', 'val')

# %%
######## Barplot by site ######################################################
df_reach = df_comb_reach[df_comb_reach.model_id != '1a_multitask_do_gpp_er']
reach_groups = df_reach.groupby(['site_id', 'variable', 'model_id'])
reach_means = reach_groups.mean()
reach_stds = reach_groups.std()

######## Overall barplot ######################################################
model_groups = df_reach.groupby(['variable', 'model_id'])

model_means = model_groups.mean()
model_stds = model_groups.std()

######## Barplot by month ######################################################
month_groups = df_comb_month.groupby(['date', 'model_id'])

month_means = month_groups.mean()
month_stds = month_groups.std()


# %%
def plot_bars_overall(means, stds, ax):
    variables = ['do_min', 'do_mean', 'do_max']
    x = np.arange(len(variables))  # the label locations
    width = 0.25  # the width of the bars
    multiplier = 0
    
    var_means = means.reset_index().pivot(index='variable', columns='model_id', values='rmse').loc[variables]
    var_stds = stds.reset_index().pivot(index='variable', columns='model_id', values='rmse').loc[variables]

    for col in var_means.columns:
        data = var_means[col]
        offset = width * multiplier
        rects = ax.bar(x + offset, data, width, label=col, yerr=var_stds[col])
        # ax.bar_label(rects, padding=3, fmt='%.2f', label_type='center')
        multiplier += 1
    
    ax.set_xticks(x + width, variables)
    ax.grid()
    ax.set_axisbelow(True)
    

def plot_bars_reach(means, stds, variable, ax):
    sites = means.reset_index()['site_id'].unique()
    x = np.arange(len(sites))  # the label locations
    width = 0.25  # the width of the bars
    multiplier = 0
    
    var_means = means.query(f"variable == '{variable}'").reset_index().pivot(index='site_id', columns='model_id', values='rmse')
    var_stds = stds.query(f"variable == '{variable}'").reset_index().pivot(index='site_id', columns='model_id', values='rmse')
    
    for col in var_means.columns:
        data = var_means[col]
        offset = width * multiplier
        rects = ax.bar(x + offset, data, width, label=col, yerr=var_stds[col])
        multiplier += 1

    ax.set_xticks(x + width, sites)
    ax.grid()
    ax.set_axisbelow(True)
    
def plot_bars_months(means, stds, variable, ax):
    sites = means.reset_index()['date'].unique()
    x = np.arange(len(sites))  # the label locations
    width = 0.25  # the width of the bars
    multiplier = 0
    
    var_means = means.query(f"variable == '{variable}'").reset_index().pivot(index='date', columns='model_id', values='rmse')
    var_stds = stds.query(f"variable == '{variable}'").reset_index().pivot(index='date', columns='model_id', values='rmse')
    
    for col in var_means.columns:
        data = var_means[col]
        offset = width * multiplier
        rects = ax.bar(x + offset, data, width, label=col, yerr=var_stds[col])
        multiplier += 1

    ax.set_xticks(x + width, sites)
    ax.grid()
    ax.set_axisbelow(True)


# %%
fig = plt.figure(constrained_layout=True, figsize=(12, 8))
subfigs = fig.subfigures(2, 1, wspace=0.07)
subfigsTop = subfigs[0].subfigures(1, 2, wspace=0.07, width_ratios=[1, 2])
axsTopRight = subfigsTop[1].subplots(1, 3, sharey=True)
axsTopLeft = subfigsTop[0].subplots()
subfigsTop[0].suptitle('A')
subfigsTop[1].suptitle('B')

plot_bars_overall(model_means, model_stds, axsTopLeft)
# axsTopLeft.bar([0, 1, 2, 3], [0, 1, 2, 3])

variables = ['do_min', 'do_mean', 'do_max']


for i, ax in enumerate(axsTopRight):
    plot_bars_reach(reach_means, reach_stds, variables[i], ax)
    ax.set_title(variables[i])
    
axsBottom = subfigs[1].subplots(1, 3)
for i, ax in enumerate(axsBottom):
    plot_bars_months(month_means, month_stds, variables[i], ax)
    ax.set_title(variables[i])
    


# %%
