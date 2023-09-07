from plot_utils import df_site_filt

summary = df_site_filt.groupby(["model_id", "variable", "holdout_id"]).describe()

print('#'*40 + '  Values for Section 3.1  ' + 40*'#')
print(summary['rmse'][['mean']].query('holdout_id == "temporal"'))
print('#' * 100)
print('#' * 100)


print("summary stats by site")
summary_by_site = df_site_filt.groupby(["model_id", "variable", "holdout_id", "site_id"]).describe()
print('#'*40 + '  Values for Section 3.1.1  ' + 40*'#')
print(summary_by_site['rmse'][['mean']].query('holdout_id == "temporal"'))
print('#' * 100)
print('#' * 100)


print('#'*40 + '  Values for Section 3.2.1 ' + 40*'#')
print(summary['rmse'][['mean']].query('holdout_id == "spatial similar"'))
print('#' * 100)
print('#' * 100)
