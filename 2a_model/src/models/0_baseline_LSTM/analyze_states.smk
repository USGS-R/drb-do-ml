code_dir = '../river-dl'
import sys
sys.path.insert(0, code_dir)
# if using river_dl installed with pip this is not needed

from model import LSTMModelStates
from river_dl.postproc_utils import prepped_array_to_df
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd


out_dir = "../../../out/models/0_baseline_LSTM/analyze_states"
in_dir = "../../../out/models/0_baseline_LSTM"


def get_site_ids():
    df = pd.read_csv(f"{in_dir}/rep_0/reach_metrics.csv", dtype={"site_id": str})
    return df.site_id.unique()


rule all:
    input:
        expand("{outdir}/rep_{rep}/states_{trained_or_random}_{site_id}.png",
               outdir=out_dir,
               rep=list(range(6)),
               trained_or_random = ["trained", "random"],
               site_id = get_site_ids()),
        expand("{outdir}/rep_{rep}/output_weights.jpg",
               outdir=out_dir,
               rep=list(range(6))),


model = LSTMModelStates(
    config['hidden_size'],
    recurrent_dropout=config['recurrent_dropout'],
    dropout=config['dropout'],
    num_tasks=len(config['y_vars'])
)


rule write_states:
    input:
        f"{in_dir}/rep_{{rep}}/prepped.npz",
        f"{in_dir}/rep_{{rep}}/train_weights/",
    output:
        "{outdir}/rep_{rep}/states_{trained_or_random}.csv"
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
        axs = df_site.plot(subplots=True, figsize=(8,10))
        for ax in axs.flatten():
            ax.legend(loc = "upper left")
        plt.suptitle(wildcards.site_id)
        plt.tight_layout()
        plt.savefig(output[0])
    

rule plot_output_weights:
    input:
        f"{in_dir}/rep_{{rep}}/prepped.npz",
        f"{in_dir}/rep_{{rep}}/train_weights/",
    output:
        "{outdir}/rep_{rep}/output_weights.jpg"
    run:
        data = np.load(input[0], allow_pickle=True)
        m = LSTMModelStates(
            config['hidden_size'],
            recurrent_dropout=config['recurrent_dropout'],
            dropout=config['dropout'],
            num_tasks=len(config['y_vars'])
        )
        m.load_weights(input[1] + "/")
        m(data['x_val'])
        w = m.weights
        ax = plt.imshow(w[3].numpy())
        fig = plt.gcf()
        cbar = fig.colorbar(ax)
        cbar.set_label('weight value')
        ax = plt.gca()
        ax.set_yticks(list(range(10)))
        ax.set_yticklabels(f"h{i}" for i in range(10))
        ax.set_ylabel('hidden state')
        ax.set_xticks(list(range(3)))
        ax.set_xticklabels(["DO_max", "DO_mean", "DO_min"], rotation=90)
        ax.set_xlabel('output variable')
        plt.tight_layout()
        plt.savefig(output[0], bbox_inches='tight')
