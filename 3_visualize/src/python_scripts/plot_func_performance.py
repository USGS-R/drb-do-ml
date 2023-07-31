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

import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import plot_utils

# +
run_id = 215

outdir = f"../../out/func_perf/{run_id}"

if not os.path.exists(outdir):
    os.makedirs(outdir)


# -

def get_diff_df(df, it_metric):
    """
    Parameters
    ---
    it_metric : str
        which IT metric you want the difference for (e.g., 'TE1')
    """
    print(df.head())
    df_piv = df.pivot(columns='model', index=['holdout', 'sink', 'replicate', 'site'], values=[it_metric])

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

df_diff_long = df_diff_long.rename(columns={'site': 'site_id'})

d = plot_utils.make_holdout_id_col(df_diff_long)

df_diff_long['holdout_id'].unique()

######## Barplot by site ######################################################
diff_temporal = df_diff_long[df_diff_long['holdout_id'] == 'temporal']
plt.rcParams.update({'font.size': 14})
g = sns.catplot(x='site_id', y='value', hue='model', col='sink', kind='bar',
                data=diff_temporal, legend=False,
                col_order=['do_min', 'do_max'],
                hue_order=plot_utils.model_order,
                col_wrap=1, aspect=3
                )
g.set_xticklabels(rotation=90)
g.set_ylabels('Deviation from \noptimal functional performance')
g.set_titles('{col_name}')
