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


def read_and_filter_df(metric_type, partition):
    f_name = f"../../../2a_model/out/models/combined_{metric_type}_metrics.csv"
    df_comb = pd.read_csv(f_name, dtype={"site_id": str})
    df_comb = df_comb[df_comb['partition'] == partition]
    df_comb = df_comb[df_comb['variable'].str.startswith('do')]
    df_comb = df_comb[df_comb['rmse'].notna()]
    return df_comb


df_comb_reach = read_and_filter_df("reach", "val")

# +
g = sns.catplot(x='site_id', y='rmse', col='variable', data=df_comb_reach, hue='model_id', kind='bar', legend=False, ci='sd')
g.set_xticklabels(rotation=90)
for ax in g.axes.flatten():
    ax.grid()
    ax.set_axisbelow(True)

plt.legend(bbox_to_anchor=(1.05, .55))
plt.tight_layout()
plt.savefig("../../out/pred_perf/val_results_by_site.png")
plt.clf()
# -

g=sns.catplot(x='site_id', y='rmse', hue='model_id', col='variable', col_wrap=3, data=df_comb_reach, dodge=True, legend=False)
g.set_xticklabels(rotation=90)
for ax in g.axes.flatten():
    ax.grid()

for site_id, ax in g.axes_dict.items():
    ax.grid()
    if site_id in validation_sites:
        ax.text(1, 3.2, "**Validation Site**", ha='center')
plt.legend(bbox_to_anchor=(1.05, .55))
plt.tight_layout()
plt.savefig('../../out/pred_perf/val_results_by_site_strip.png')
plt.clf()

# -

df_comb = read_and_filter_df('overall', 'val')

# +
fig, ax = plt.subplots(figsize=(6,4))
ax = sns.barplot(x='variable', y='rmse', data=df_comb, hue='model_id', ax=ax)
ax.bar_label(ax.containers[0], label_type="center", fmt='%.2f')
ax.bar_label(ax.containers[1], label_type="center", fmt='%.2f')

plt.savefig("../../out/pred_perf/val_results_overall.png")
# -


