# -*- coding: utf-8 -*-
"""
Created on Fri May 27 10:00:43 2022

@author: ggorski
"""
import pandas as pd
import it_functions
import numpy as np
import math
import pickle

def calc_it_metrics_sites(inputs_df, source, sink, site, log_transform):
    '''
    Parameters
    ----------
    source : str
        source for calculations (srad, tmmx, tmmn)
    sink : list
        sinks ['do_min', 'do_mean', 'do_max']
    site : str
        site number
    log_transform : boolean
        should the source variable be log10 transformed, should only be log10 transformed for discharge
        
    Returns
    -------
    None.

    '''
    
    inputs_site = inputs_df.loc[site][['CAT_BASIN_AREA', 'CAT_BASIN_SLOPE', 'CAT_CNPY11_BUFF100',
           'CAT_ELEV_MEAN', 'CAT_IMPV11', 'CAT_TWI', 'SLOPE', 'day.length', 'depth',
           'discharge', 'light_ratio',
           'model_confidence', 'pr', 'resolution', 'rmax', 'rmin', 'shortwave',
           'site_min_confidence', 'site_name', 'sph', 'srad', 'temp.water', 'tmmn',
           'tmmx', 'velocity', 'vs']]
    targets_site = inputs_df.loc[site][['do_min','do_mean','do_max']]
    targets_site['do_range'] = targets_site['do_max']-targets_site['do_min']
    
    #0 baseline LSTM
    v0_bl = pd.read_feather('scratch/4_func_perf/in/results_tmmx_tmmn/models/0_baseline_LSTM/nstates_10/nep_100/rep_0/preds.feather')
    bl = v0_bl[v0_bl['site_id'] == site].set_index('date')[['do_min','do_mean','do_max']]
    bl['do_range'] = bl['do_max']-bl['do_min']

    #1 metab 
    v1_multi = pd.read_feather('scratch/4_func_perf/in/results_tmmx_tmmn/models/1_metab_multitask/nstates_10/nep_100/rep_0/preds.feather')
    multi = v1_multi[v1_multi['site_id'] == site].set_index('date')[['do_min','do_mean','do_max']]
    multi['do_range'] = multi['do_max']-multi['do_min']

    #2 multi-task
    v1a_metab = pd.read_feather('scratch/4_func_perf/in/results_tmmx_tmmn/models/1a_multitask_do_gpp_er/nstates_10/nep_100/rep_0/preds.feather')
    metab = v1a_metab[v1a_metab['site_id'] == site].set_index('date')[['do_min','do_mean','do_max']]
    metab['do_range'] = metab['do_max']-metab['do_min']
    
    #3 multi-task dense
    v2_metab_dense = pd.read_feather('scratch/4_func_perf/in/results_tmmx_tmmn/models/2_multitask_dense/nstates_10/nep_100/rep_0/preds.feather')
    metab_dense = v2_metab_dense[v2_metab_dense['site_id'] == site].set_index('date')[['do_min','do_mean','do_max']]
    metab_dense['do_range'] = metab_dense['do_max']-metab_dense['do_min']

    #create targets dictionary
    tar_dict = {'observed':targets_site, 'baseline':bl,
                'multitask':multi, 'metab':metab, 'metab_dense':metab_dense}


    
    #create dictionary to store calculations in
    max_it = {'do_min': {}, 'do_mean': {}, 'do_max':{}, 'do_range':{}}
    #create a nested dictionary for each DO variable to store it calcs
    #TE0 = Transfer Entropy at a time lag of 0, MI = mututal information,
    #TEmax is the maximum TE, TEmaxT is the time lag of the maximum TE,
    #TEmaxcrit is the a True/False if TEmax is significant, everything follows the same 
    #convention for MI
    for key in max_it.keys():
        max_it[key] = {'model': [],'rmse':[], 
                       'TE0':[], 'TE1':[], 'TE2':[], 
                       'TE3':[], 'TE4':[], 'TE5':[],
                       'TE6':[], 'TE7':[], 'TE8':[],
                       'TEmax':[],'TEmaxt':[], 'TEmaxcrit':[], 
                       'MI0':[], 'MI1':[], 'MI2':[],
                       'MI3':[], 'MI4':[], 'MI5':[],
                       'MI6':[], 'MI7':[], 'MI8':[],
                      'MImax':[],'MImaxt':[],'MImaxcrit':[]}
    
    
    
    for model in tar_dict.keys():
        #join input and target to make sure they are aligned
        site_inptar = inputs_site.join(tar_dict[model], rsuffix = '_pred')
        
        #assign x = source, y = sink
        x = site_inptar[source]
        y = site_inptar[sink]
        
        #for calculating rmse
        obs_pred = tar_dict['observed'][sink].join(tar_dict[model][sink], rsuffix = '_pred')
        
        
        #load the preprocessing fucntions from it_functions.py
        ppf = it_functions.pre_proc_func()
        
        if log_transform:
            xl10 = ppf.log10(x)
        else:
            xl10 = x.copy()
        x_rss = ppf.remove_seasonal_signal(xl10)
        x_ss = ppf.standardize(x_rss)
        
        y_prepped = {}
        for snk in sink:
            y_rss = ppf.remove_seasonal_signal(y[snk])
            y_prepped[snk] = ppf.standardize(y_rss)
            y_prepped[snk] = y_prepped[snk]
        
        
        print('Calculating it metrics '+model+' '+site)
        n_lags = 9
        nbins = 11
        it_dict = {}
        for snk in sink:
           
            #create an array of the prepped x and y variables
            M = np.stack((x_ss,y_prepped[snk]), axis = 1)
            #Mswap is for caclulating the TE from Y -> X, we don't really need to do that
            #because DO doesn't affect solar radiation, but it is needed for function
            Mswap = np.stack((y_prepped[snk], x_ss), axis = 1)
            #x_bounds and y_bounds are for removing outliers
            x_bounds = it_functions.find_bounds(M[:,0], 0.1, 99.9)
            y_bounds = it_functions.find_bounds(M[:,1], 0.1, 99.9)
            M_x_bound = np.delete(M, np.where((M[:,0] < x_bounds[0]*1.1) | (M[:,0] > x_bounds[1]*1.1)), axis = 0)
            M_xy_bound = np.delete(M_x_bound, np.where((M_x_bound[:,1] < y_bounds[0]*1.1) | (M_x_bound[:,1] > y_bounds[1]*1.1)), axis = 0)

            #calc it metrics and store in the dictionary it_dict
            it_dict[snk] = it_functions.calc_it_metrics(M_xy_bound, Mswap, n_lags, nbins, calc_swap = False, alpha = 0.05, ncores = 8)
        
        
        print('Storing it metrics '+model+' '+site)
        #find the max TE and MI and the time lag at which the max occurs
        #and store that in a dictionary as well
        for snk in sink:
            
            TEmax = max(it_dict[snk]['TE'])
            TEmaxt = int(np.where(it_dict[snk]['TE'] == TEmax)[0])
        
            if TEmax > it_dict[snk]['TEcrit'][TEmaxt]:
                TEmaxcrit = True
            else:
                TEmaxcrit = False
            
            MImax = max(it_dict[snk]['MI'])
            MImaxt = int(np.where(it_dict[snk]['MI'] == MImax)[0])
            
            if MImax > it_dict[snk]['MIcrit'][MImaxt]:
                MImaxcrit = True
            else:
                MImaxcrit = False
            print(snk, MImax)
            #do min
            max_it[snk]['model'].append(model)
            mse = np.square(np.subtract(obs_pred[snk+'_pred'],obs_pred[snk])).mean()
            math.sqrt(mse)
            max_it[snk]['rmse'].append(math.sqrt(mse))
            
            max_it[snk]['TEmax'].append(TEmax)
            max_it[snk]['TE0'].append(it_dict[snk]['TE'][0])
            max_it[snk]['TE1'].append(it_dict[snk]['TE'][1])
            max_it[snk]['TE2'].append(it_dict[snk]['TE'][2])
            max_it[snk]['TE3'].append(it_dict[snk]['TE'][3])
            max_it[snk]['TE4'].append(it_dict[snk]['TE'][4])
            max_it[snk]['TE5'].append(it_dict[snk]['TE'][5])
            max_it[snk]['TE6'].append(it_dict[snk]['TE'][6])
            max_it[snk]['TE7'].append(it_dict[snk]['TE'][7])
            max_it[snk]['TE8'].append(it_dict[snk]['TE'][8])
        
            max_it[snk]['TEmaxt'].append(TEmaxt)
            max_it[snk]['TEmaxcrit'].append(TEmaxcrit)
            
            max_it[snk]['MImax'].append(MImax)
            max_it[snk]['MI0'].append(it_dict[snk]['MI'][0])
            max_it[snk]['MI1'].append(it_dict[snk]['MI'][1])
            max_it[snk]['MI2'].append(it_dict[snk]['MI'][2])
            max_it[snk]['MI3'].append(it_dict[snk]['MI'][3])
            max_it[snk]['MI4'].append(it_dict[snk]['MI'][4])
            max_it[snk]['MI5'].append(it_dict[snk]['MI'][5])
            max_it[snk]['MI6'].append(it_dict[snk]['MI'][6])
            max_it[snk]['MI7'].append(it_dict[snk]['MI'][7])
            max_it[snk]['MI8'].append(it_dict[snk]['MI'][8])
            max_it[snk]['MImaxt'].append(MImaxt)
            max_it[snk]['MImaxcrit'].append(MImaxcrit)
             
    return max_it


def diff_from_obs(df):
    #function for calculating the difference in TE from modeled to observation
    diff_df = df.iloc[:,1:11].sub(df.iloc[0,1:11], axis = 1)
    diff_df['metric'] = df['metric']
    diff_df['model'] = df['model']
    return diff_df.iloc[1:5,:]

def site_it_metrics(inputs_df, source, sink, sites, out_file):
    #function for calculating the it metrics for each site
    max_it_site = {}
    for site in sites:
        if site == '014721254' or site == '014721259':
            continue
        max_it = calc_it_metrics_sites(inputs_df, source, sink, site, log_transform=False)
        
        max_it_site[site] = max_it
        
    it_metrics_file = open(out_file, "wb")
    pickle.dump(max_it_site, it_metrics_file)
    it_metrics_file.close()