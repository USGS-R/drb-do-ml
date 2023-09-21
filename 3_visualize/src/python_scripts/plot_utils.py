import matplotlib.pyplot as plt
import re
import pandas as pd

# CHANGE THIS IF NECESSARY
metric_data_directory = '../../../../pgdl-do-data-release/out_data'

obs_file = f"{metric_data_directory}/model_inputs_outputs.csv"

input_variables = ["SLOPE","TOTDASQKM","CAT_BASIN_SLOPE",
                   "TOT_BASIN_SLOPE","CAT_ELEV_MEAN","CAT_RDX","CAT_BFI","CAT_EWT",
                   "CAT_TWI","CAT_PPT7100_ANN","TOT_PPT7100_ANN","CAT_RUN7100",
                   "CAT_CNPY11_BUFF100","CAT_IMPV11","TOT_IMPV11","CAT_NLCD11_wetland",
                   "TOT_NLCD11_wetland","CAT_SANDAVE","CAT_PERMAVE","TOT_PERMAVE",
                   "CAT_RFACT","CAT_WTDEP","TOT_WTDEP","CAT_NPDES_MAJ","CAT_NDAMS2010",
                   "CAT_NORM_STORAGE2010"]


sites_xwalk = {
        "01480617" : "BC_53",
        "01480870" : "BC_40",
        "01481000" : "BC_24",
        "01481500" : "BC_8",
        "01472104" : "SR_72", 
        "01473500" : "SR_40",
        "01475530" : "CC_12",
        "01475548" : "CC_4",
        "014721259" : "BAP",
        "014721254" : "FC"
        }


model_labels = [
    "v0 - Baseline",
    "v1 - Process-Informed Multitask",
    "v2 - Process-Dependent Multitask",
]

replacements = {
        "0_baseline_LSTM": model_labels[0],
        "1_metab_multitask": model_labels[1],
        "2_multitask_dense": model_labels[2],
    }

train_sites = ['01472104', '014721254', '01473500', '01480617', '01480870', '01481000', '01481500']
urban_sites = ['01475530', '01475548']
headwater_site = ['014721259']

all_sites = train_sites + urban_sites + headwater_site

model_order = ["0_baseline_LSTM", "1a_multitask_do_gpp_er",
               "1_metab_multitask", "2_multitask_dense", "2a_lower_lambda_metab"]


def read_and_filter_df(metric_type, partition, var="do"):
    f_name = f"{metric_data_directory}/{metric_type}_metrics.csv"
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
    # if it's a site_id but not the headwater site it's considered "spatially
    # similar". Other options are "1_urban", "2_urban", and "temporal"
    if re.match(pattern, holdout) and int(holdout) != int(headwater_site[0]):
        return "spatial similar"
    elif holdout == "temporal":
        if row["site_id"] in urban_sites:
            return "temporal urban"
        else:
            return "temporal"
    elif holdout == "1_urban":
        return "spatial one-urban"
    elif holdout == "2_urban" or int(holdout) == int(headwater_site[0]):
        return "spatial dissimilar"


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


df_comb_site = read_and_filter_df("site", "val")
df_comb_site = df_comb_site.replace(replacements)
df_comb_site = make_holdout_id_col(df_comb_site)
df_site_filt = filter_out_urban_spatial(df_comb_site).query('model_id != "1a_multitask_do_gpp_er"')
df_site_filt = df_site_filt.replace(sites_xwalk)
