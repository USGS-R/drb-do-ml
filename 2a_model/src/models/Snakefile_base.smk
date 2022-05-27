import os
import tensorflow as tf
import numpy as np
import pandas as pd
import sys

code_dir = "../river-dl"
sys.path.append(code_dir)

from river_dl.preproc_utils import asRunConfig
from river_dl.preproc_utils import prep_all_data
from river_dl.evaluate import combined_metrics
from river_dl.postproc_utils import plot_obs, plot_ts, prepped_array_to_df
from river_dl.predict import predict_from_arbitrary_data
from river_dl.train import train_model
from river_dl import loss_functions as lf

out_dir = os.path.join(config['out_dir'], config['exp_name'])
loss_function = lf.multitask_rmse(config['lambdas'])

include: "visualize_models.smk"

rule as_run_config:
    output:
        "{outdir}/asRunConfig.yml"
    run:
        asRunConfig(config,output[0])


rule prep_io_data:
    input:
        "../../../out/well_obs_inputs.zarr",
        "../../../out/well_obs_targets.zarr",
    output:
        "{outdir}/prepped.npz"
    run:
        prep_all_data(x_data_file=input[0],
                      y_data_file=input[1],
                      x_vars=config['x_vars'],
                      y_vars_finetune=config['y_vars'],
                      spatial_idx_name='site_id',
                      time_idx_name='date',
                      train_start_date=config['train_start_date'],
                      train_end_date=config['train_end_date'],
                      val_start_date=config['val_start_date'],
                      val_end_date=config['val_end_date'],
                      test_start_date=config['test_start_date'],
                      test_end_date=config['test_end_date'],
                      val_sites=config['validation_sites'],
                      out_file=output[0],
                      normalize_y=False,
                      trn_offset = config['trn_offset'],
                      tst_val_offset = config['tst_val_offset'])

        # check to make sure there is no validation or testing data
        # in the training data set
        data = np.load(output[0], allow_pickle=True)
        df_trn = prepped_array_to_df(data['y_obs_trn'],
                                     data['times_trn'],
                                     data['ids_trn'],
                                     col_names=data['y_obs_vars'])
        df_trn_val_sites = df_trn[df_trn.seg_id_nat.isin(config['validation_sites'])]
        df_trn_tst_sites = df_trn[df_trn.seg_id_nat.isin(config['test_sites'])]

        assert df_trn_val_sites['do_mean'].notna().sum() == 0
        assert df_trn_tst_sites['do_mean'].notna().sum() == 0



# Finetune/train the model on observations
rule train:
    input:
        "{outdir}/prepped.npz"
    output:
        directory("{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/train_weights/"),
        #directory("{outdir}/best_val_weights/"),
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/train_log.csv",
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/train_time.txt",
    run:
        optimizer = tf.optimizers.Adam(learning_rate=config['finetune_learning_rate']) 
        params.model.compile(optimizer=optimizer, loss=loss_function)
        data = np.load(input[0], allow_pickle=True)
        nsegs = len(np.unique(data["ids_trn"]))
        train_model(params.model,
                    x_trn = data['x_trn'],
                    y_trn = data['y_obs_trn'],
                    epochs = int(wildcards.epochs),
                    batch_size = nsegs,
                    x_val = data['x_val'],
                    y_val = data['y_obs_val'],
                    # I need to add a trailing slash here. Otherwise the wgts
                    # get saved in the "outdir"
                    weight_dir = output[0] + "/",
                    #best_val_weight_dir = output[1] + "/",
                    log_file = output[1],
                    time_file = output[2],
                    early_stop_patience=config['early_stopping'])


rule make_predictions:
    input:
        "{outdir}/prepped.npz",
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/train_weights/",
        "../../../out/well_obs_inputs.zarr",
    output:
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/preds.feather",
    run:
        weight_dir = input[1] + "/"
        params.model.load_weights(weight_dir)
        preds = predict_from_arbitrary_data(raw_data_file=input[2],
                                            pred_start_date="1980-01-01",
                                            pred_end_date="2019-01-01",
                                            train_io_data=input[0],
                                            model=params.model, 
                                            spatial_idx_name='site_id',
                                            time_idx_name='date')
        preds.reset_index(drop=True).to_feather(output[0])


def filter_predictions(all_preds_file, partition, out_file):
        df_preds = pd.read_feather(all_preds_file)
        all_sites = df_preds.site_id.unique()
        trn_sites = all_sites[(~np.isin(all_sites, config["validation_sites"])) &
                              (~np.isin(all_sites, config["test_sites"]))]

        df_preds_trn_sites = df_preds[df_preds.site_id.isin(trn_sites)] 

        df_preds_val_sites = df_preds[df_preds.site_id.isin(config['validation_sites'])] 


        if partition == "trn":
            df_preds_filt = df_preds_trn_sites[(df_preds_trn_sites.date >= config['train_start_date'][0]) &
                                               (df_preds_trn_sites.date < config['train_end_date'][0])]
        elif partition == "val":
            # get all of the data in the validation sites and in the validation period
            # this assumes that the test period follows the validation period which follows the train period
            df_preds_filt_val = df_preds_val_sites[df_preds_val_sites.date < config['test_start_date'][0]]
            df_preds_filt_trn = df_preds_trn_sites[(df_preds_trn_sites.date < config['val_end_date'][0]) &
                                                   (df_preds_trn_sites.date >= config['val_start_date'][0])]
            df_preds_filt = pd.concat([df_preds_filt_val , df_preds_filt_trn], axis=0)

        elif partition == "val_times":
            # get the data in just the validation times at train and val sites
            df_preds_filt_val = df_preds_val_sites[(df_preds_val_sites.date < config['val_end_date'][0]) &
                                                   (df_preds_val_sites.date >= config['val_start_date'][0])]
            df_preds_filt_trn = df_preds_trn_sites[(df_preds_trn_sites.date < config['val_end_date'][0]) &
                                                   (df_preds_trn_sites.date >= config['val_start_date'][0])]
            df_preds_filt = pd.concat([df_preds_filt_val , df_preds_filt_trn], axis=0)


        df_preds_filt.reset_index(drop=True).to_feather(out_file)




rule make_filtered_predictions:
    input:
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/preds.feather"
    output:
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/{partition}_preds.feather"
    run:
        filter_predictions(input[0], wildcards.partition, output[0])

 
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
          "../../../out/well_obs_targets.zarr",
          "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/trn_preds.feather",
          "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/val_preds.feather",
          "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/val_times_preds.feather"
     output:
          "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/{metric_type}_metrics.csv"
     params:
         grp_arg = get_grp_arg
     run:
         combined_metrics(obs_file=input[0],
                          pred_data = {"train": input[1],
                                       "val": input[2],
                                       "val_times": input[3]},
                          spatial_idx_name='site_id',
                          time_idx_name='date',
                          group=params.grp_arg,
                          id_dict={"nstates": wildcards.nstates,
                                   "rep_id": wildcards.rep,
                                   "nepochs": wildcards.epochs},
                          outfile=output[0])
 
 
rule exp_metrics:
     input:
        expand("{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/{{metric_type}}_metrics.csv",
                outdir=out_dir,
                rep=list(range(config['num_replicates'])),
                nstates=config['hidden_size'],
                epochs=config['epochs'],
        )
     output:
          "{outdir}/exp_{metric_type}_metrics.csv"
     run:
        all_df = pd.concat([pd.read_csv(met_file, dtype={"site_id": str}) for met_file in input])
        all_df.to_csv(output[0], index=False)
        
 
 
rule plot_prepped_data:
     input:
         "{outdir}/prepped.npz",
     output:
         "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/{variable}_part_{partition}.png",
     run:
         plot_obs(input[0],
                  wildcards.variable,
                  output[0],
                  spatial_idx_name="site_id",
                  time_idx_name="date",
                  partition=wildcards.partition)


