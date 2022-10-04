# -*- coding: utf-8 -*-
"""
Created on Fri May 27 10:00:43 2022

@author: ggorski
"""
import pandas as pd
#import sys
#sys.path.insert(0, 'C:\\Users\\ggorski\\OneDrive - DOI\\USGS_ML\\DO\\drb-do-ml\\scratch\\Functional_Performance')
import it_functions as it_functions
import numpy as np
import math
import xarray as xr

def calc_it_metrics_sites(inputs_df, source, sink, site, log_transform, models, replicate, base_file_path):
    '''
    Parameters
    ----------
    inputs_df : pandas dataframe
        observed io data from zarr file
    source : str
        source for calculations (srad, tmmx, tmmn)
    sink : list
        sinks ['do_min', 'do_mean', 'do_max']
    site : str
        site number
    log_transform : boolean
        should the source variable be log10 transformed, should only be log10 transformed for discharge
    models: iterable (list or tuple)
        the models for which you want do the calcs (e.g., ['0_baseline_LSTM','2_multitask_dense'])
    replicate: int
        which replicate you want to do the calcs for
    base_file_path: str
        filepath where the model results are
        
    Returns
    -------
    Information theory metric results (transfer entropy) as a nested dictionary

    '''
    
    inputs_site = inputs_df.loc[site][['CAT_BASIN_AREA', 'CAT_BASIN_SLOPE', 'CAT_CNPY11_BUFF100',
           'CAT_ELEV_MEAN', 'CAT_IMPV11', 'CAT_TWI', 'SLOPE', 'day.length', 'depth',
           'discharge', 'light_ratio',
           'model_confidence', 'pr', 'resolution', 'rmax', 'rmin', 'shortwave',
           'site_min_confidence', 'site_name', 'sph', 'srad', 'temp.water', 'tmmn',
           'tmmx', 'velocity', 'vs']]
    targets_site = inputs_df.loc[site][['do_min','do_mean','do_max']]
    
    if 'do_range' in sink:
        targets_site['do_range'] = targets_site['do_max']-targets_site['do_min']
        
    tar_dict = {}
    for m in models:
        file_path = f'{base_file_path}/{m}/nstates_10/nep_100/rep_{replicate}/preds.feather'
        model_preds = pd.read_feather(file_path)
        model_preds = model_preds[model_preds['site_id'] == site].set_index('date')[['do_min','do_mean','do_max']]
        model_preds['do_range'] = model_preds['do_max']-model_preds['do_min']
        #create targets dictionary
        tar_dict[m] = model_preds
    tar_dict['observed'] = targets_site


    
    #create dictionary to store calculations in
    #max_it = {'do_min': {}, 'do_mean': {}, 'do_max':{}, 'do_range':{}}
    max_it = {s: {} for s in sink}
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
            it_dict[snk] = it_functions.calc_it_metrics(M_xy_bound, Mswap, n_lags, nbins, calc_swap = False, alpha = 0.05, ncores = 7)
        
        
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

def site_it_metrics(inputs_df, source, sink, sites, models, replicate, base_file_path):
    #wrapper function for calculating the it metrics for each site
    max_it_site = {}
    for i,site in enumerate(sites):

        print('----------------\n', site,' ', i+1, ' of ', len(sites),' sites')        

        max_it = calc_it_metrics_sites(inputs_df, source, sink, site, log_transform=False,
                                       models = models, replicate = replicate, base_file_path = base_file_path)
        
        max_it_site[site] = max_it

    return max_it_site        


def get_max_it_df(input_file, models, base_file_path, output_file, replicate, sink,
                  source='srad', sites = "all"):
    '''
    This function returns the functional performance (Transfer Entropy (TE) and 
    Mutual Information (MI)) for all models specified, all sinks specified, for
    the specified source, and for _one_ replicate. 
    Parameters
    ----------
    inputs_file : str
        path to input zarr file
    models : iterable (list or tuple)
        the models for which you want to do the calcs (e.g., ['0_baseline_LSTM', '2_multitask_dense'])
    base_file_path: str
        filepath where the model results are (e.g., "2a_model/out/models/")
    output_file: str
        filepath where the results should be written, should be .csv
    replicate : int
        which replicate you want to do the calcs for
    sink : list
        sinks ['do_min', 'do_mean', 'do_max']
    source : str
        source for calculations (srad, tmmx, tmmn)
    sites : chr or list
        if "all" then it metrics are calculated for all sites, if a list is given then 
        calcs are made only for those sites
        
    Returns
    -------
    a Pandas DataFrame with columns:
        `model,rmse,TE{0-8,max,maxt,maxcrit},MI{0-8,max,maxt,maxcrit},metric,site,rep_id`
    '''
    inputs = xr.open_zarr(input_file,consolidated=False)
    inputs_df = inputs.to_dataframe()
    
    if isinstance(sites, str):
        assert sites=='all','sites can either be "all" for all sites or a list'
        sites = inputs_df.index.unique('site_id')
        sites = sites.drop(['014721254', '014721259'])
    else:
        assert isinstance(sites,list),'sites can either be "all" for all sites or a list'
         
    
    max_it_site = site_it_metrics(inputs_df, source, sink, sites, models,
                              replicate, base_file_path)

    do_all_sites_list = []
    #do_diff_all_sites_list = []
    
    for i,site in enumerate(sites):
    
        max_it = max_it_site[site]
        sink_dfs = []
        for s in sink:
            do_sink_df = pd.DataFrame(max_it[s])
            do_sink_df['metric'] = s
            sink_dfs.append(do_sink_df)
        do_df = pd.concat(sink_dfs)
        do_df['site'] = site
    
        do_all_sites_list.append(do_df)
        
    do_all_sites = pd.concat(do_all_sites_list)
    
    do_all_sites.to_csv(output_file)
    



