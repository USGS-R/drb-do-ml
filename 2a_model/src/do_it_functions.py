# -*- coding: utf-8 -*-
"""
Created on Fri May 27 10:00:43 2022

@author: ggorski
"""
import pandas as pd
import sys
#sys.path.insert(0, 'C:\\Users\\ggorski\\OneDrive - DOI\\USGS_ML\\DO\\drb-do-ml\\scratch\\Functional_Performance\\src')
import it_functions as it_functions
import numpy as np
import math
import xarray as xr

def calc_it_metrics_site(inputs_zarr,
                         predictions_file,
                         source,
                         sink,
                         site,
                         log_transform,
                         model,
                         replicate,
                         outfile=None):
    '''
    Calculate the transfer entropy (TE) and Mutual Information (MI) between
    one input (source) and one output (sink) at one site and one replicate

    Parameters
    ----------
    inputs_zarr : str
        path to io zarr file
    predictions_file : str
        path to preds.feather file
    source : str
        source for calculations (e.g., srad, tmmx, tmmn)
    sink : str
        sink for calculations (e.g., 'do_min', 'do_mean', 'do_max')
    site : str
        site number
    log_transform : boolean
        should the source variable be log10 transformed, should only be log10 transformed for discharge
    model: str
        the model for which you are doing the calcs (e.g., '0_baseline_LSTM', 'observed')
    replicate: int
        which replicate you are doing the calcs for
    outfile: str
        filepath to store the output (if desired)
        
    Returns
    -------
    Information theory metric results (transfer entropy) as a nested dictionary

    '''
    inputs = xr.open_zarr(inputs_zarr, consolidated=False)
    inputs_df = inputs.to_dataframe()
    
    # TODO: it'd be nice to read this in dynamically at some point
    inputs_site = inputs_df.loc[site][['CAT_BASIN_AREA', 'CAT_BASIN_SLOPE', 'CAT_CNPY11_BUFF100',
           'CAT_ELEV_MEAN', 'CAT_IMPV11', 'CAT_TWI', 'SLOPE', 'day.length', 'depth',
           'discharge', 'light_ratio',
           'model_confidence', 'pr', 'resolution', 'rmax', 'rmin', 'shortwave',
           'site_min_confidence', 'site_name', 'sph', 'srad', 'temp.water', 'tmmn',
           'tmmx', 'velocity', 'vs']]
    targets_site = inputs_df.loc[site][['do_min','do_mean','do_max']]
    
    if sink == 'do_range':
        targets_site['do_range'] = targets_site['do_max']-targets_site['do_min']
        
    tar_dict = {}

    model_preds = pd.read_feather(predictions_file)
    model_preds = model_preds[model_preds['site_id'] == site].set_index('date')[['do_min','do_mean','do_max']]
    model_preds['do_range'] = model_preds['do_max']-model_preds['do_min']
    #create targets dictionary
    if model != 'observed':
        tar_dict[model] = model_preds
    tar_dict['observed'] = targets_site


    
    #create dictionary to store calculations in
    max_it = {}
    #create a nested dictionary for each DO variable to store it calcs
    #TE0 = Transfer Entropy at a time lag of 0, MI = mututal information,
    #TEmax is the maximum TE, TEmaxT is the time lag of the maximum TE,
    #TEmaxcrit is the a True/False if TEmax is significant, everything follows the same 
    #convention for MI
    
    
    #join input and target to make sure they are aligned
    site_inptar = inputs_site.join(tar_dict[model], rsuffix = '_pred')
    
    #assign x = source, y = sink
    x = site_inptar[source]
    y = site_inptar[sink]
    
    #for calculating rmse
    obs_pred = tar_dict['observed'][[sink]].join(tar_dict[model][[sink]], rsuffix = '_pred')
    
    
    #load the preprocessing fucntions from it_functions.py
    ppf = it_functions.pre_proc_func()
    
    if log_transform:
        xl10 = ppf.log10(x)
    else:
        xl10 = x.copy()
    x_rss = ppf.remove_seasonal_signal(xl10)
    x_ss = ppf.standardize(x_rss)
    
    y_prepped = {}
    y_rss = ppf.remove_seasonal_signal(y)
    y_prepped = ppf.standardize(y_rss)
    
    
    print('Calculating it metrics '+model+' '+site)
    n_lags = 9
    nbins = 11
    it_dict = {}
       
    #create an array of the prepped x and y variables
    M = np.stack((x_ss,y_prepped), axis = 1)
    #Mswap is for caclulating the TE from Y -> X, we don't really need to do that
    #because DO doesn't affect solar radiation, but it is needed for function
    Mswap = np.stack((y_prepped, x_ss), axis = 1)
    #x_bounds and y_bounds are for removing outliers
    x_bounds = it_functions.find_bounds(M[:,0], 0.1, 99.9)
    y_bounds = it_functions.find_bounds(M[:,1], 0.1, 99.9)
    M_x_bound = np.delete(M, np.where((M[:,0] < x_bounds[0]*1.1) | (M[:,0] > x_bounds[1]*1.1)), axis = 0)
    M_xy_bound = np.delete(M_x_bound, np.where((M_x_bound[:,1] < y_bounds[0]*1.1) | (M_x_bound[:,1] > y_bounds[1]*1.1)), axis = 0)

    #calc it metrics and store in the dictionary it_dict
    it_dict = it_functions.calc_it_metrics(M_xy_bound, Mswap, n_lags, nbins, calc_swap = False, alpha = 0.05, ncores = 7)
    
    
    print('Storing it metrics '+model+' '+site)
    #find the max TE and MI and the time lag at which the max occurs
    #and store that in a dictionary as well
        
    TEmax = max(it_dict['TE'])
    TEmaxt = int(np.where(it_dict['TE'] == TEmax)[0])

    if TEmax > it_dict['TEcrit'][TEmaxt]:
        TEmaxcrit = True
    else:
        TEmaxcrit = False
    
    MImax = max(it_dict['MI'])
    MImaxt = int(np.where(it_dict['MI'] == MImax)[0])
    
    if MImax > it_dict['MIcrit'][MImaxt]:
        MImaxcrit = True
    else:
        MImaxcrit = False
    #do min
    max_it['model'] = model
    mse = np.square(np.subtract(obs_pred[sink+'_pred'],obs_pred[sink])).mean()
    math.sqrt(mse)
    max_it['rmse'] = math.sqrt(mse)
    
    max_it['TEmax'] = TEmax
    for i in range(9):
        max_it[f'TE{i}'] = it_dict['TE'][i]
    max_it['TEmaxt'] = TEmaxt
    max_it['TEmaxcrit'] = TEmaxcrit
    
    max_it['MImax'] = MImax
    for i in range(9):
        max_it[f'MI{i}'] = it_dict['MI'][i]
    max_it['MImaxt'] = MImaxt
    max_it['MImaxcrit'] = MImaxcrit
    max_it['replicate'] = replicate
    max_it['sink'] = sink
    max_it['source'] = source
    max_it['site'] = site

    if outfile:
        df = pd.DataFrame(max_it, index=[0])
        df.to_csv(outfile, index=False)
             
    return max_it


