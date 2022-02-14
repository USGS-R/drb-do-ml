from model import LSTMModelStates
from river_dl.postproc_utils import prepped_array_to_df
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

code_dir = '../river-dl'
# if using river_dl installed with pip this is not needed
import sys
sys.path.insert(0, code_dir)

out_dir = "../../../out/models/0_baseline_LSTM/analyze_states"
in_dir = "../../../out/models/0_baseline_LSTM"


def get_site_ids():
    df = pd.read_csv(f"{in_dir}/reach_metrics.csv", dtype={"site_id": str})
    return df.site_id.unique()


rule all:
    input:
        expand("{outdir}/states_{trained_or_random}_{site_id}.png",
               outdir=out_dir,
               trained_or_random = ["trained", "random"],
               site_id = get_site_ids())


model = LSTMModelStates(
    config['hidden_size'],
    recurrent_dropout=config['recurrent_dropout'],
    dropout=config['dropout'],
    num_tasks=len(config['y_vars'])
)


rule write_states:
    input:
        f"{in_dir}/prepped.npz",
        f"{in_dir}/train_weights/",
    output:
        "{outdir}/states_{trained_or_random}.csv"
    run:
        data = np.load(input[0], allow_pickle=True)
        if wildcards.trained_or_random == "trained":
            model.load_weights(input[1] + "/")
        states = model(data['x_val'])
        states_df = prepped_array_to_df(states, data["times_val"], data["ids_val"],
                                        col_names=[f"h{i}" for i in range(10)], 
                                        spatial_idx_name="site_id")
        states_df["site_id"] = states_df["site_id"].astype(str)
        states_df.to_csv(output[0], index=False)


rule plot_states:
    input:
        "{outdir}/states_{trained_or_random}.csv"
    output:
        "{outdir}/states_{trained_or_random}_{site_id}.png"
    run:
        df = pd.read_csv(input[0], parse_dates=["date"], infer_datetime_format=True, dtype={"site_id": str})
        df_site = df.query(f"site_id == '{wildcards.site_id}'")
        del df_site["site_id"]
        df_site = df_site.set_index("date")
        df_site.plot(subplots=True, figsize=(8,10))
        plt.tight_layout()
        plt.savefig(output[0])
    
