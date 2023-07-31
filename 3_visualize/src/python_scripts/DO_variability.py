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

import xarray as xr
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

ds = xr.open_zarr("../../../2a_model/out/med_obs_io.zarr/")

sites = ['01472104', '014721254', '014721259', '01473500', '01480617', '01480870', '01481000', '01481500']

ds = ds.sel(date = slice('2007-10-01', '2021-10-01'), site_id=sites)

ds

do_df = ds[['do_min', 'do_max']].to_dataframe()
do_df = do_df.dropna().reset_index()
do_df = do_df[do_df['site_id'].isin(sites)].set_index(['site_id', 'date'])

do_df_long = do_df.reset_index().melt(id_vars=['site_id', 'date'])

# So, we see that do_max has the highest standard deviation

site_stds=do_df.groupby('site_id').std()

site_stds.mean()

ax = site_stds.plot.bar()
ax.set_ylabel('standard deviation (mg/l)')

ax = do_df.groupby('site_id').count()['do_min'].plot.bar()
ax.set_ylabel('num observations')

do_df['month'] = do_df.index.get_level_values("date").month

ax = do_df.groupby('month').std().plot.bar()
ax.set_ylabel('standard deviation (mg/l)')

site_month = do_df.groupby(['month', 'site_id']).std()

site_month_long = site_month.melt(ignore_index=False).reset_index()

sns.catplot(x='month', y='value', hue='variable', col='site_id', col_wrap=4, kind='bar', data=site_month_long)


