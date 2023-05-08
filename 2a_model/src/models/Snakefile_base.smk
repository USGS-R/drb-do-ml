import os
import xarray as xr
import tensorflow as tf
import numpy as np
import pandas as pd
import sys
from utils import get_train_val, get_holdouts

river_dl_dir = "../river-dl"
sys.path.append(river_dl_dir)

src_dir = "../.."
sys.path.append(src_dir)

from river_dl.preproc_utils import asRunConfig
from river_dl.preproc_utils import prep_all_data
from river_dl.evaluate import combined_metrics
from river_dl.postproc_utils import plot_obs, plot_ts, prepped_array_to_df
from river_dl.predict import predict_from_arbitrary_data
from river_dl.train import train_model
from river_dl import loss_functions as lf
from do_it_functions import calc_it_metrics_site

out_dir = os.path.join(config['out_dir'], config['exp_name'])
loss_function = lf.multitask_rmse(config['lambdas'])

include: "visualize_models.smk"

rule as_run_config:
    output:
        "{outdir}/asRunConfig.yml"
    run:
        asRunConfig(config,output[0])


# Finetune/train the model on observations
rule train:
    input:
        "{outdir}/holdout_{holdout}/prepped.npz"
    output:
        directory("{outdir}/holdout_{holdout}/rep_{rep}/train_weights/"),
        "{outdir}/holdout_{holdout}/rep_{rep}/train_log.csv",
        "{outdir}/holdout_{holdout}/rep_{rep}/train_time.txt",
    run:
        optimizer = tf.optimizers.Adam(learning_rate=config['finetune_learning_rate']) 
        params.model.compile(optimizer=optimizer, loss=loss_function)
        data = np.load(input[0], allow_pickle=True)
        nsegs = len(np.unique(data["ids_trn"]))
        train_model(params.model,
                    x_trn = data['x_trn'],
                    y_trn = data['y_obs_trn'],
                    epochs = config['epochs'],
                    batch_size = nsegs,
                    #x_val = data['x_val'],
                    #y_val = data['y_obs_val'],
                    # I need to add a trailing slash here. Otherwise the wgts
                    # get saved in the "outdir"
                    weight_dir = output[0] + "/",
                    log_file = output[1],
                    time_file = output[2],
                    early_stop_patience=config['early_stopping'])


rule make_predictions:
    input:
        "{outdir}/holdout_{holdout}/prepped.npz",
        "{outdir}/holdout_{holdout}/rep_{rep}/train_weights/",
        "../../../out/well_obs_io.zarr",
    output:
        "{outdir}/holdout_{holdout}/rep_{rep}/preds.feather",
    run:
        trn_end, val_start, val_end, val_sites = get_train_val(wildcards.holdout, config)
        weight_dir = input[1] + "/"
        params.model.load_weights(weight_dir)
        preds = predict_from_arbitrary_data(raw_data_file=input[2],
                                            pred_start_date = config['train_start_date'],
                                            pred_end_date = config['val_end_date_temporal_holdout'],
                                            train_io_data=input[0],
                                            model=params.model, 
                                            spatial_idx_name='site_id',
                                            time_idx_name='date')
        preds.reset_index(drop=True).to_feather(output[0])


def filter_predictions(all_preds_file, partition, holdout, config, out_file):
        trn_end, val_start, val_end, val_sites = get_train_val(holdout, config)

        df_preds = pd.read_feather(all_preds_file)
        all_sites = df_preds.site_id.unique()
        trn_sites = all_sites[~np.isin(all_sites, val_sites)]

        df_preds_trn_sites = df_preds[df_preds.site_id.isin(trn_sites)] 

        df_preds_val_sites = df_preds[df_preds.site_id.isin(val_sites)] 


        if partition == "trn":
            df_preds_filt = df_preds_trn_sites[(df_preds_trn_sites.date >= config['train_start_date']) &
                                               (df_preds_trn_sites.date < trn_end)]
        elif partition == "val":
            # get all of the data in the validation sites and in the validation period
            # this assumes that the test period follows the validation period which follows the train period
            df_preds_filt_val = df_preds_val_sites
            if val_end and val_start:
                df_preds_filt_trn = df_preds_trn_sites[(df_preds_trn_sites.date < val_end) &
                                                       (df_preds_trn_sites.date >= val_start)]
                df_preds_filt = pd.concat([df_preds_filt_val , df_preds_filt_trn], axis=0)
            else:
                df_preds_filt = df_preds_filt_val

        elif partition == "val_times":
            # get the data in just the validation times at train and val sites
            df_preds_filt_val = df_preds_val_sites[(df_preds_val_sites.date < val_end) &
                                                   (df_preds_val_sites.date >= val_start)]
            df_preds_filt_trn = df_preds_trn_sites[(df_preds_trn_sites.date < val_end) &
                                                   (df_preds_trn_sites.date >= val_start)]
            df_preds_filt = pd.concat([df_preds_filt_val , df_preds_filt_trn], axis=0)


        df_preds_filt.reset_index(drop=True).to_feather(out_file)




rule make_filtered_predictions:
    input:
        "{outdir}/holdout_{holdout}/rep_{rep}/preds.feather",
    output:
        "{outdir}/holdout_{holdout}/rep_{rep}/{partition}_preds.feather"
    run:
        filter_predictions(input[0], wildcards.partition, wildcards.holdout, config, output[0])

 
def get_grp_arg(wildcards):
     if wildcards.metric_type == 'overall':
         return None
     elif wildcards.metric_type == 'month':
         return 'month'
     elif wildcards.metric_type == 'reach':
         return 'seg_id_nat'
     elif wildcards.metric_type == 'month_reach':
         return ['seg_id_nat', 'month']
 
 
rule combine_metrics:
     input:
          "../../../out/well_obs_io.zarr",
          "{outdir}/holdout_{holdout}/rep_{rep}/trn_preds.feather",
          "{outdir}/holdout_{holdout}/rep_{rep}/val_preds.feather",
     output:
          "{outdir}/holdout_{holdout}/rep_{rep}/{metric_type}_metrics.csv"
     params:
         grp_arg = get_grp_arg
     run:
         combined_metrics(obs_file=input[0],
                          pred_data = {"train": input[1],
                                       "val": input[2]},
                          spatial_idx_name='site_id',
                          time_idx_name='date',
                          group=params.grp_arg,
                          id_dict={"holdout": wildcards.holdout,
                                   "rep_id": wildcards.rep},
                          outfile=output[0])
 
 
rule exp_metrics:
     input:
        expand("{outdir}/holdout_{holdout}/rep_{rep}/{{metric_type}}_metrics.csv",
                outdir=out_dir,
                holdout=get_holdouts(config),
                rep=list(range(config['num_replicates'])),
        )
     output:
          "{outdir}/exp_{metric_type}_metrics.csv"
     run:
        all_df = pd.concat([pd.read_csv(met_file, dtype={"site_id": str}) for met_file in input])
        all_df.to_csv(output[0], index=False)
        
 
 
rule calc_functional_performance_one:
    input:
        "../../../out/well_obs_io.zarr",
        "{outdir}/holdout_{holdout}/rep_{rep}/preds.feather"
    output:
        "{outdir}/holdout_{holdout}/rep_{rep}/func_perf/{site}-{src}-{snk}-{model}.csv"
    run:
        calc_it_metrics_site(input[0],
                             input[1],
                             wildcards.src,
                             wildcards.snk,
                             wildcards.site,
                             log_transform=False,
                             model=wildcards.model,
                             replicate=wildcards.rep,
                             outfile=output[0])


def get_func_perf_sites():
    input_file = "../../../out/well_obs_io.zarr"
    inputs = xr.open_zarr(input_file, consolidated=False)
    inputs_df = inputs.to_dataframe()
    
    sites = inputs_df.index.unique('site_id')
    sites = sites.drop(['014721254', '014721259'])
    return sites


rule gather_func_performances:
    input:
        expand("{outdir}/holdout_{holdout}/rep_{rep}/func_perf/{site}-{src}-{snk}-{{model}}.csv",
                outdir=out_dir,
                rep=list(range(config['num_replicates'])),
                site=get_func_perf_sites(),
                holdout=get_holdouts(config),
                src=['tmmx'],
                snk=['do_min', 'do_mean', 'do_max'])
    output:
        "{outdir}/{model}_func_perf.csv"
    run:
        df_list = []
        for in_file in input:
            df = pd.read_csv(in_file, dtype={"site": str})
            df_list.append(df)
        df_comb = pd.concat(df_list)
        df_comb.to_csv(output[0], index=False)
