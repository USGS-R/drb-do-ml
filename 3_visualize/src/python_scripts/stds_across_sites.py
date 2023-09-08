from plot_utils import df_site_filt

df_site_filt = df_site_filt[df_site_filt['holdout_id'] == 'temporal']

# first get the standard deviations for each site/model/variable
df_site_std = df_site_filt.groupby(["model_id", "variable", "site_id"]).std()['rmse']

# take the mean across the sites and variables
mean_std = df_site_std.groupby(["model_id"]).mean()

print(mean_std)
