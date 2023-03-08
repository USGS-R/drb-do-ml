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
import plot_utils



def get_diff_df(df, it_metric):
    """
    Parameters
    ---
    it_metric : str
        which IT metric you want the difference for (e.g., 'TE1')
    """
    df_piv = df.pivot(columns='model', index=['sink', 'replicate', 'site'], values=[it_metric])

    df_piv.columns = df_piv.columns.get_level_values(1)

    df_diff_vals = df_piv.values - df_piv[['observed']].values
    
    df_diff = pd.DataFrame(df_diff_vals, index=df_piv.index, columns=df_piv.columns)
    
    del df_diff['observed']
    
    return df_diff


df = pd.read_csv("../../../2a_model/out/models/combined_FP_metrics.csv",
                 dtype={"site": str})

fp_metric = 'TE1'
df_diff = get_diff_df(df,fp_metric)


df_diff_long = df_diff.reset_index().melt(id_vars=df_diff.index.names)

# df_diff_long = df_diff_long.replace({"0_baseline_LSTM": "baseline", "2_multitask_dense": "multitask dense"})


######## Barplot by site ######################################################
plt.rcParams.update({'font.size': 14})
g = sns.catplot(x='site', y='value', hue='model', col='sink', kind='bar',
                data=df_diff_long, legend=False,
                col_order=['do_min', 'do_mean', 'do_max'],
                hue_order=plot_utils.model_order
                )
g.set_xticklabels(rotation=90)
g.set_ylabels('Deviation from \noptimal functional performance')
g.set_titles('{col_name}')
for site_id, ax in g.axes_dict.items():
    plot_utils.mark_val_sites(ax)

plt.legend(loc="lower left", bbox_to_anchor=(1.05, 0), title='Model')
plt.tight_layout()
plt.savefig("../../out/func_perf/func_performance_site_tmmx.png")
plt.clf()

######## Barplot overall ######################################################
fig, ax = plt.subplots(figsize=(6,4))

ax = sns.barplot(x='sink', y='value', hue='model', data=df_diff_long,
                 order=['do_min', 'do_mean', 'do_max'], ax=ax,
                 hue_order=plot_utils.model_order)

ax.set_ylabel('Deviation from \noptimal functional performance')
ax.set_xlabel('')
plt.legend(loc="lower right", title='Model')
plt.tight_layout()
plt.savefig("../../out/func_perf/func_performance_overall_tmmx.png")


