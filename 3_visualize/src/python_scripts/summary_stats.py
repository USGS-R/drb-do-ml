from plot_utils import read_and_filter_df, make_holdout_id_col, replacements, filter_out_urban_spatial

df_comb_reach = read_and_filter_df("reach", "val")
df_comb_reach = df_comb_reach.replace(replacements)
df_comb_reach = make_holdout_id_col(df_comb_reach)
df_reach_filt = filter_out_urban_spatial(df_comb_reach).query('model_id != "1a_multitask_do_gpp_er"')


summary = df_reach_filt.groupby(["model_id", "variable", "holdout_id"]).describe()
print(summary)

print(summary['rmse'][['mean']].query('holdout_id == "temporal"'))
print(summary['rmse'][['mean']].query('holdout_id == "spatial similar"'))

summary_by_site = df_reach_filt.groupby(["model_id", "variable", "holdout_id", "site_id"]).describe()
print(summary_by_site)
print(summary_by_site['rmse'][['mean']].query('holdout_id == "temporal"'))

