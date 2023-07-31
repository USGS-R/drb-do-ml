import matplotlib.pyplot as plt
import re
import pandas as pd


model_labels = [
    "v0 - Baseline",
    "v1 - Metab Multitask",
    # "1a_multitask_gpp_er",
    "v2 - Metab Dependent",
]

replacements = {
        "0_baseline_LSTM": model_labels[0],
        # "1a_multitask_do_gpp_er": "Metab Multitask - GPP, ER",
        "1_metab_multitask": model_labels[1],
        "2_multitask_dense": model_labels[2],
    }

validation_sites = ["01472104", "01473500", "01481500"]
test_sites = ["01475530", "01475548"]
test_sites_urban = ["01475530", "01475548"]

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

def read_and_filter_df(metric_type, partition, var="do"):
    f_name = f"../../../2a_model/out/models/combined_{metric_type}_metrics.csv"
    df_comb = pd.read_csv(f_name, dtype={"site_id": str})
    df_comb = df_comb[df_comb["partition"] == partition]
    if var == "do":
        df_comb = df_comb[df_comb["variable"].str.startswith("do")]
    else:
        df_comb = df_comb[df_comb["variable"] == var]
    df_comb = df_comb[df_comb["rmse"].notna()]
    return df_comb


def define_group(row):
    pattern = "^\d{7,8}$"
    holdout = str(row['holdout'])
    if re.match(pattern, holdout) and holdout != "14721259":
        return "spatial similar"
    elif holdout == "temporal":
        if row["site_id"] in test_sites_urban:
            return "temporal urban"
        else:
            return "temporal"
    elif holdout == "1_urban":
        return "spatial one-urban"
    elif holdout == "2_urban" or holdout == "14721259":
        return "spatial dissimilar"


# +
def filter_out_urban_spatial(df):
    """
    Filter out the urban sites from the spatial non-urban holdouts. We don't
    want to see the performance at the urban sites when they've been held out.
    For example, for site holdout_01481500, we only want get the performance at
    that one site, not at the urban sites.
    """
    # get all of the holdout sites
    all_holdouts = pd.Series(df.holdout.unique())

    # get just the ones that are in the spatial non-urban
    pattern = "^\d{7,8}$"
    non_urban_sites = all_holdouts[all_holdouts.str.contains(pattern)]
    # add a '0' to the beginning of the site ids since they were put in as integers
    zero_padded_non_urban_sites = "0" + non_urban_sites

    # get just the non-urban spatial holdout rows
    df_non_urban = df[df["holdout"].isin(non_urban_sites)]

    # remove any urban sites from this
    df_non_urban = df_non_urban[
        df_non_urban["site_id"].isin(zero_padded_non_urban_sites)
    ]

    # get the other rows
    df_other = df[~df["holdout"].str.contains(pattern)]

    # add filtered dataset to the other
    df_filtered = pd.concat([df_other, df_non_urban])

    return df_filtered

def make_holdout_id_col(df):
    df['holdout_id'] = df.apply(define_group, axis=1)
    return df

