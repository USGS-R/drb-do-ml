import matplotlib.pyplot as plt
import pandas as pd
validation_sites = ["01472104", "01473500", "01481500"]
test_sites = ["01475530", "01475548"]

model_order = ["0_baseline_LSTM", "1a_multitask_do_gpp_er",
               "1_metab_multitask", "2_multitask_dense", "2a_lower_lambda_metab"]

def mark_val_sites(ax):
    labels = [item.get_text() for item in ax.get_xticklabels()]
    new_labels = []
    for l in labels:
        if l in validation_sites:
            new_labels.append("*" + l)
        else:
            new_labels.append(l)

    ax.set_xticklabels(new_labels)

    fig = plt.gcf()    
    fig.text(0.5, 0, "* validation site")

    return ax

def read_and_filter_df(metric_type, partition):
    f_name = f"../../../2a_model/out/models/combined_{metric_type}_metrics.csv"
    df_comb = pd.read_csv(f_name, dtype={"site_id": str})
    df_comb = df_comb[df_comb['partition'] == partition]
    df_comb = df_comb[df_comb['variable'].str.startswith('do')]
    df_comb = df_comb[df_comb['rmse'].notna()]
    return df_comb