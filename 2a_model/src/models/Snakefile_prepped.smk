workdir: "2a_model/src/models/0_baseline_LSTM"
configfile: "../config_base.yml"

import sys
import numpy as np
from utils import get_train_val, get_holdouts

river_dl_dir = "../river-dl"
sys.path.append(river_dl_dir)

src_dir = "../.."
sys.path.append(src_dir)

from river_dl.preproc_utils import prep_all_data
from river_dl.postproc_utils import prepped_array_to_df

out_dir = os.path.join(config['out_dir'], config['exp_name'])


rule all:
    input:
          expand("{outdir}/holdout_{holdout}/prepped.npz",
                  outdir=out_dir,
                  holdout=get_holdouts(config))


rule prep_io_data:
    input:
        "../../../out/well_obs_io.zarr",
    output:
        "{outdir}/holdout_{holdout}/prepped.npz"
    run:
        trn_end, val_start, val_end, val_sites = get_train_val(wildcards.holdout, config) 
        prep_all_data(x_data_file=input[0],
                      y_data_file=input[0],
                      x_vars=config['x_vars'],
                      y_vars_finetune=config['y_vars'],
                      spatial_idx_name='site_id',
                      time_idx_name='date',
                      train_start_date=config['train_start_date'],
                      train_end_date=trn_end,
                      val_start_date=None,
                      seq_len=365,
                      val_end_date=None,
                      val_sites=val_sites,
                      out_file=output[0],
                      normalize_y=False,
                      trn_offset = config['trn_offset'],
                      tst_val_offset = config['tst_val_offset'])

        # check to make sure there is no validation data
        # in the training data set
        data = np.load(output[0], allow_pickle=True)
        df_trn = prepped_array_to_df(data['y_obs_trn'],
                                     data['times_trn'],
                                     data['ids_trn'],
                                     col_names=data['y_obs_vars'])
        df_trn_val_sites = df_trn[df_trn.seg_id_nat.isin(val_sites)]

        assert df_trn_val_sites['do_mean'].notna().sum() == 0


