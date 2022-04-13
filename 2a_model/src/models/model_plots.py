import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import xarray as xr

def plot_obs_preds(pred_file, obs_file, site_id, start_date, end_date,
                   outfile=None, info_dict=None):
    df_pred = pd.read_feather(pred_file)
    df_pred_site = df_pred.query(f"site_id == '{site_id}'")
    df_obs_site = xr.open_zarr(obs_file).sel(site_id=site_id).to_dataframe()
    df_pred_site = df_pred_site.set_index('date')
    df_obs_site = df_obs_site.reset_index().set_index('date')[df_pred_site.columns]
    df_obs_site['type'] = 'obs'
    df_pred_site['type'] = 'pred'
    df_comb = pd.concat([df_obs_site, df_pred_site])
    del df_comb['site_id']
    df_comb = df_comb.loc[start_date: end_date]
    df_comb = df_comb.reset_index().melt(id_vars=["date", "type"])
    sns.relplot(x = "date",
                y="value",
                row="variable",
                hue="type",
                data=df_comb,
                kind='line',
                height=1,
                aspect=5,
                facet_kws={'sharey': False},
                palette=["black", "steelblue"]
                )
    if info_dict:
        info_text = "\n".join([f"{key}: {val}" for key, val in info_dict.items()])
        plt.figtext(0.9,
                    0.05,
                    info_text,
                    ha='left',
                    va='bottom',
                    bbox={'facecolor': 'white', 'pad': 10})
    if outfile:
        plt.savefig(outfile, dpi=300, bbox_inches='tight')
