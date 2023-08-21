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
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import xarray as xr
import seaborn as sns

# %%
obs_file = "../../../2a_model/out/well_obs_io.zarr"

# %%
urban_sites = ['01475530', '01475548']
headwater_site = ['014721259']
train_sites = ['01472104', '014721254', '01473500', '01480617', '01480870', '01481000', '01481500']

# %%
input_variables = ["SLOPE","TOTDASQKM","CAT_BASIN_SLOPE",
                   "TOT_BASIN_SLOPE","CAT_ELEV_MEAN","CAT_RDX","CAT_BFI","CAT_EWT",
                   "CAT_TWI","CAT_PPT7100_ANN","TOT_PPT7100_ANN","CAT_RUN7100",
                   "CAT_CNPY11_BUFF100","CAT_IMPV11","TOT_IMPV11","CAT_NLCD11_wetland",
                   "TOT_NLCD11_wetland","CAT_SANDAVE","CAT_PERMAVE","TOT_PERMAVE",
                   "CAT_RFACT","CAT_WTDEP","TOT_WTDEP","CAT_NPDES_MAJ","CAT_NDAMS2010",
                   "CAT_NORM_STORAGE2010"]

# %%
ds = xr.open_zarr(obs_file)

# %%
df = ds[input_variables].mean(dim='date').to_dataframe()


# %%
colors = []

for s in df.index:
    if s in urban_sites:
        colors.append(sns.color_palette()[1])
    elif s in headwater_site:
        colors.append(sns.color_palette()[2])
    # elif s in other1:
        # colors.append(sns.color_palette()[3])
    else:
        colors.append(sns.color_palette()[0])

# %%
df_long = df.melt(ignore_index=False).reset_index()

# %%

# %%
sns.set(font_scale=1.7)
g = sns.catplot(x='site_id', y='value', kind='bar', palette=colors, col="variable", col_wrap=7, data=df_long, sharey=False)
g.set_xticklabels([])


legend_elements = [Patch(facecolor=sns.color_palette()[0], label='train site'),
                   Patch(facecolor=sns.color_palette()[1], label='test site'),
                  ]
g.axes[0].legend(handles=legend_elements)
g.savefig('../../out/catch_attr_distr_test_sites.png', dpi=300)


# %%
variables_in_table = ['SLOPE', 'TOT_IMPV11', 'CAT_RDX']

# %%
df_long_train = df_long[df_long['site_id'].isin(train_sites)]

print("Training Sites:")
print(df_long_train.groupby('variable').mean().loc[variables_in_table])

# %%
df_long_urban = df_long[df_long['site_id'].isin(urban_sites)]

print("Urban Sites:")
print(df_long_urban.groupby('variable').mean().loc[variables_in_table])

# %%
df_long_hw = df_long[df_long['site_id'].isin(headwater_site)]

print("Headwater Site:")
print(df_long_hw.groupby('variable').mean().loc[variables_in_table])

# %%
