# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %%
import pandas as pd
import seaborn as sns
import xarray as xr
import matplotlib.pyplot as plt

# %%
df = pd.read_csv("../../2_process/out/daily_water_temp.csv", dtype={"site_no": str}, parse_dates=["Date"], infer_datetime_format=True)
df = df.rename(columns={"site_no":"site_id", "Date":"date"})

# %%
df_aux = pd.read_csv("../../1_fetch/out/daily_aux_data.csv",
                    dtype={"site_no": str}, parse_dates=["Date"], infer_datetime_format=True)

# %%
df_preds = pd.read_feather("../../2a_model/out/models/0_baseline_LSTM/rep_0/val_times_preds.feather")

# %%
df_aux = df_aux.rename(columns={"site_no": "site_id", "Date": "date"}).set_index(["site_id", "date"])

# %%
df.set_index(['site_id', 'date'], inplace=True)
df_preds.set_index(['site_id', 'date'], inplace=True)
df_comb = df_preds.join(df_aux)

# %%
temp_do_pair_counts = (df_comb['Wtemp'] + df_comb['do_mean']).groupby('site_id').count()

# %%
temp_do_pair_counts

# %%
sites_w_temp_do_pairs = temp_do_pair_counts[temp_do_pair_counts > 0].index

# %%
df_comb = df_comb.reset_index()
df_comb = df_comb[df_comb['site_id'].isin(sites_w_temp_do_pairs)]

# %%
ds_obs_do = xr.open_zarr("../../2a_model/out/well_observed_train_val_do.zarr/", consolidated=False)

# %%
df_obs_do = ds_obs_do.do_mean.to_dataframe()

# %%
df_comb = df_comb.set_index(['site_id', 'date']).join(df_obs_do, lsuffix="_pred", rsuffix="_obs").reset_index()
df_comb = df_comb.rename(columns = {"do_mean_pred": "pred", "do_mean_obs": "obs"})

# %%
df_comb.columns

# %%
df_mlt = df_comb.melt(id_vars=['site_id', 'date', 'Wtemp'], value_vars=['pred', 'obs'], var_name="Pred or obs")

# %%
sns.set(font_scale=1.5, style="whitegrid")
fg = sns.relplot(x="Wtemp", y="value", col="site_id", data=df_mlt, hue="Pred or obs", col_wrap=3, kind='scatter', alpha=0.5)
fg.set_xlabels("Observed daily mean \n water temperature (deg C)")
fg.set_ylabels("Predicted or observed daily \n mean DO concentration (mg/l)")
# plt.tight_layout()
plt.savefig("../out/do_preds_vs_temp.png", dpi=300)

# %%
