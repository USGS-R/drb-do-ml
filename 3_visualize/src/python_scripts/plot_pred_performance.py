# ---
# jupyter:
#   jupytext:
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
import seaborn as sns
import matplotlib.pyplot as plt

validation_sites = ["01472104", "01473500", "01481500"]
test_sites = ["01475530", "01475548"]

models = ["0_baseline_LSTM", "2_multitask_dense"]


def read_and_combine_dfs(model_ids, metric_type, partition, parent_dir):
    f_name = "{p}{model}/exp_{metric_type}_metrics.csv"
    dfs = []
    for m in model_ids:
        df = pd.read_csv(f_name.format(p=parent_dir, model=m, metric_type=metric_type), dtype={'site_id':str})
        df['model'] = m
        dfs.append(df)

    df_comb = pd.concat(dfs)
    df_comb = df_comb[df_comb['partition'] == partition]
    df_comb = df_comb[df_comb['variable'].str.startswith('do')]
    df_comb = df_comb[df_comb['rmse'].notna()]
    return df_comb


df_comb_reach_new = read_and_combine_dfs(models, 'reach', 'val', "../../")
df_comb_reach_new['type'] = 'new inputs'

df_comb_reach_old = read_and_combine_dfs(models, "reach", 'val', "archive_221215/")
df_comb_reach_old['type'] = 'old inputs'

df_comb_reach = pd.concat([df_comb_reach_new, df_comb_reach_old])

# +
g = sns.catplot(x='site_id', y='rmse', row='model', col='variable', data=df_comb_reach, hue='type', kind='bar', legend=False, ci='sd')
g.set_xticklabels(rotation=90)
for ax in g.axes.flatten():
    ax.grid()
    ax.set_axisbelow(True)

plt.legend(bbox_to_anchor=(1.05, .55))
plt.tight_layout()
plt.savefig("figs/val_results_new_inputs.png")

# +
g = sns.catplot(x='site_id', y='rmse', col='variable', data=df_comb_reach_new, hue='model', kind='bar', legend=False, ci='sd')
g.set_xticklabels(rotation=90)
for ax in g.axes.flatten():
    ax.grid()
    ax.set_axisbelow(True)

plt.legend(bbox_to_anchor=(1.05, .55))
plt.tight_layout()
plt.savefig("figs/val_results_new_inputs.png")
# -

g=sns.catplot(x='site_id', y='rmse', hue='model', col='variable', col_wrap=3, data=df_comb_reach, dodge=True, legend=False)
g.set_xticklabels(rotation=90)
for ax in g.axes.flatten():
    ax.grid()
plt.legend(bbox_to_anchor=(1.05, .55))
plt.tight_layout()
plt.savefig('val_results_strip.png')

# +
g=sns.catplot(x='variable', y='rmse', hue='model', col='site_id', col_wrap=3, data=df_comb_reach, dodge=True, legend=False)
for site_id, ax in g.axes_dict.items():
    ax.grid()
    if site_id in validation_sites:
        ax.text(1, 3.2, "**Validation Site**", ha='center')

    
plt.legend(bbox_to_anchor=(1.5, 1.15))
plt.tight_layout()
plt.savefig('val_results_strip.png')
# -

df_comb = read_and_combine_dfs(models, 'overall', 'val', "archive_221215/")

df_comb_new = read_and_combine_dfs(models, 'overall', 'val', "./")
df_comb_new['type'] = 'new inputs'

df_comb_old = read_and_combine_dfs(models, "overall", 'val', "archive_221215/")
df_comb_old['type'] = 'old inputs'

df_comb = pd.concat([df_comb_new, df_comb_old])

g = sns.catplot(x='variable', y='rmse', data=df_comb, hue='type', col='model', kind="bar")
for ax in g.axes.flatten():
    ax.bar_label(ax.containers[0], label_type="center")
    ax.bar_label(ax.containers[1], label_type="center")
plt.savefig("figs/val_results_overall_new_inputs.png")

# +
ax = sns.barplot(x='variable', y='rmse', data=df_comb_new, hue='model')
ax.bar_label(ax.containers[0], label_type="center")
ax.bar_label(ax.containers[1], label_type="center")

# plt.tight_layout()
plt.savefig("figs/val_results_overall.png")
# -


