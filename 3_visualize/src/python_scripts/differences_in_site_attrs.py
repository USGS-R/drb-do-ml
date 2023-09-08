import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import xarray as xr
import seaborn as sns
from plot_utils import urban_sites, headwater_site, train_sites, input_variables, obs_file


df = pd.read_csv(obs_file, dtype={"site_id": str}, index_col=['site_id'])
print(df)

df = df[input_variables].groupby('site_id').mean()
print(df)

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

df_long = df.melt(ignore_index=False).reset_index()


sns.set(font_scale=1.7)
g = sns.catplot(x='site_id', y='value', kind='bar', palette=colors, col="variable", col_wrap=7, data=df_long, sharey=False)
g.set_xticklabels([])


legend_elements = [Patch(facecolor=sns.color_palette()[0], label='train site'),
                   Patch(facecolor=sns.color_palette()[1], label='test site'),
                  ]
g.axes[0].legend(handles=legend_elements)
g.savefig('../../out/catch_attr_distr_test_sites.png', dpi=300)


variables_in_table = ['SLOPE', 'TOT_IMPV11', 'CAT_RDX']

df_long_train = df_long[df_long['site_id'].isin(train_sites)]

print("Training Sites:")
print(df_long_train.groupby('variable').mean().loc[variables_in_table])

df_long_urban = df_long[df_long['site_id'].isin(urban_sites)]

print("Urban Sites:")
print(df_long_urban.groupby('variable').mean().loc[variables_in_table])

df_long_hw = df_long[df_long['site_id'].isin(headwater_site)]

print("Headwater Site:")
print(df_long_hw.groupby('variable').mean().loc[variables_in_table])

