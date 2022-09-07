# -*- coding: utf-8 -*-
"""
Created on Wed Sep  7 12:40:34 2022

@author: ggorski
"""

#import sys
#sys.path.append('C:/Users/ggorski/OneDrive - DOI/USGS_ML/DO/scratch/4_func_perf/src')

import it_functions
from do_it_functions import calc_it_metrics_sites, diff_from_obs, site_it_metrics

import math
import matplotlib.pyplot as plt
import numpy as np
import os
import pandas as pd
import pickle
import seaborn as sns
import xarray as xr

#%%
#read in the model input data and convert to df
trn_inputs = "scratch/4_func_perf/in/results_tmmx_tmmn/med_obs_io.zarr"
inputs = xr.open_zarr(trn_inputs,consolidated=False)
inputs_df = inputs.to_dataframe()
#%%
#define sources (x) and sinks (y) and run the site_it_metrics function from do_it_functions.py
#it will write the results to the out_file
source = 'srad'
sink = ['do_min','do_mean','do_max', 'do_range']
sites = inputs_df.index.unique('site_id')
out_file = 'scratch/4_func_perf/out/max_it_metrics_srad_tmmx_tmmn_model_do_te012_all_sites'
site_it_metrics(inputs_df, source, sink, sites, out_file)

#%%
#open the it metrics dictionary created above and convert to dataframe that is easier to deal with
with open('scratch/4_func_perf/out/max_it_metrics_srad_tmmx_tmmn_model_do_te012_all_sites','rb') as f:
    max_it_site = pickle.load(f)

sites = {'site_ids':['01472104','01473500','01481500','01480617','01480870','01481000'],
         'train_val': ['Validation','Validation','Validation','Training','Training','Training']}
sites = list(max_it_site.keys())

do_all_sites_list = []
do_diff_all_sites_list = []


for i,site in enumerate(sites):
    max_it = max_it_site[site]
    do_min_df = pd.DataFrame(max_it['do_min'])
    do_min_df['metric'] = 'do_min'
    do_mean_df = pd.DataFrame(max_it['do_mean'])
    do_mean_df['metric'] = 'do_mean'
    do_max_df = pd.DataFrame(max_it['do_max'])
    do_max_df['metric'] = 'do_max'
    do_range_df = pd.DataFrame(max_it['do_range'])
    do_range_df['metric'] = 'do_range'
    
    do_df = pd.concat([do_min_df,do_mean_df,do_max_df, do_range_df])
    do_df['site'] = site
    
    do_all_sites_list.append(do_df)
    
    do_df_diff = do_df.groupby('metric').apply(diff_from_obs)
    do_df_diff['site'] = site
    
    do_diff_all_sites_list.append(do_df_diff)
    
    
do_all_sites = pd.concat(do_all_sites_list)
do_diff_all_sites = pd.concat(do_diff_all_sites_list)

#%% Get basin characteristics for plotting
basin_char = inputs_df.groupby('site_id')[['CAT_BASIN_AREA', 'CAT_BASIN_SLOPE', 'CAT_CNPY11_BUFF100',
       'CAT_ELEV_MEAN', 'CAT_IMPV11', 'CAT_TWI']].max()
basin_char['site_id'] = basin_char.index
#%% calculate the difference in TE from observed and merge with basin characteristics 
#for plotting
site = sites[0]
do_df_diff_all_sites = pd.DataFrame()
for site in sites:
    do_df = do_all_sites[do_all_sites['site'] == site]
    do_df_diff = do_df.groupby('metric').apply(diff_from_obs)
    do_df_diff['site_no'] = site
    do_df_diff_all_sites = pd.concat([do_df_diff_all_sites, do_df_diff])

basin_char_slim = basin_char[(basin_char.site_id != '014721254') & (basin_char.site_id != '014721259')].copy()
basin_char_slim['site_no'] = basin_char_slim.index

basin_char_do_diff = basin_char_slim.merge(do_df_diff_all_sites, on = ['site_no','site_no'], how = 'outer')

#%% #this should produce the last plot in the github discussion with 
#the difference in functional performance for each site for the two models 
#plotted against CAT_CNPY11_BUFF100
colors = ['#1982c4','#ff595e']
three_metrics = basin_char_do_diff[basin_char_do_diff.metric != 'do_range']
two_models = three_metrics.loc[(three_metrics['model'] == 'baseline') | (three_metrics['model'] == 'metab_dense')]
sns.set_style('white')
g = sns.FacetGrid(two_models, col = 'metric', hue = 'model', 
                  col_wrap = 3, height=4, aspect=1, sharex=True, hue_kws={'color': colors})
g.map(sns.scatterplot, 'CAT_CNPY11_BUFF100','TE1', edgecolor = 'black', s = 100)
g.add_legend(title = "Model")
g.set_axis_labels('100 m buffer canopy', 'Functional performance')
ax1, ax2, ax3 = g.axes

ax1.set_title('DO min')
ax2.set_title('DO mean')
ax3.set_title('DO max')

ax1.axhline(0, ls='--', color = 'lightgray')
ax2.axhline(0, ls='--', color = 'lightgray')
ax3.axhline(0, ls='--', color = 'lightgray')

ax1.text(5,0.005, "Optimal\nfunctional\nperformance", size = 10, color = 'lightgray')
ax2.text(5,0.005, "Optimal\nfunctional\nperformance", size = 10, color = 'lightgray')
ax3.text(5,0.005, "Optimal\nfunctional\nperformance", size = 10, color = 'lightgray')

plt.show()

#%% barplot of rmse

colors = ['#1982c4','#ff595e']

g = sns.FacetGrid(two_models, col = 'metric', height = 6, col_wrap=  3)
g.map(sns.barplot, 'site_no','rmse','model', hue_order = np.unique(two_models['model']), order = np.unique(two_models['site_no']), palette = sns.color_palette(colors))
plt.legend(title = "Model", bbox_to_anchor=(1.02, 0.55), loc='upper left', borderaxespad=0)
ax1, ax2, ax3 = g.axes

ax1.set_title('DO min')
ax2.set_title('DO mean')
ax3.set_title('DO max')

#ax1.set_xticklabels(ax1.get_xticklabels(), rotation=90)

for axes in g.axes.flat:
    _ = axes.set_xticklabels(axes.get_xticklabels(), rotation=90)
    

plt.tight_layout()
plt.show()