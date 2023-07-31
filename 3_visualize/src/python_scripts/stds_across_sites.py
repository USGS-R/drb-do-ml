from plot_utils import read_and_filter_df, make_holdout_id_col, replacements, filter_out_urban_spatial

df_comb_reach = read_and_filter_df("reach", "val")
df_comb_reach = df_comb_reach.replace(replacements)
df_comb_reach = make_holdout_id_col(df_comb_reach)
df_reach_filt = filter_out_urban_spatial(df_comb_reach)

df_reach_filt = df_reach_filt[df_reach_filt['holdout_id'] == 'temporal']

# first get the standard deviations for each site/model/variable
df_reach_std = df_reach_filt.groupby(["model_id", "variable", "site_id"]).std()['rmse']

# take the mean across the sites and variables
mean_std = df_reach_std.groupby(["model_id"]).mean()

print(mean_std)
