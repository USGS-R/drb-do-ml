# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.11.2
#   kernelspec:
#     display_name: Python 3
#     language: python
#     name: python3
# ---

import pandas as pd
import matplotlib.pyplot as plt

df_inst = pd.read_csv('1_fetch/out/inst_do_data.csv', parse_dates=['dateTime'], infer_datetime_format=True, dtype={'site_no':str})

df_inst = df_inst.drop_duplicates(subset=['site_no', 'dateTime'])

df_inst = df_inst.pivot(index='dateTime', values='Value_Inst', columns='site_no')

inst_daily_means = df_inst.resample('D').mean()

df_daily = pd.read_csv('1_fetch/out/daily_do_data.csv', parse_dates=['Date'], infer_datetime_format=True, dtype={'site_no':str})

df_daily_means = df_daily.pivot(index='Date', columns='site_no', values='DO')

axs = df_daily_means.plot(subplots=True, figsize=(12, 24), sharey=True, grid=True, layout=(9, 2), color='steelblue')
for ax in axs.flatten():
    ax.legend(loc='upper left')
    ax.axvline('1980-01-01', color='maroon')
fig = plt.gcf()
fig.suptitle('daily mean DO (mg/l) at daily sites', y=0.99)
plt.tight_layout()
plt.savefig( "3_visualize/out/daily_daily_means.jpg", dpi=300)

axs = inst_daily_means.plot(subplots=True, figsize=(12, 24), sharey=True, grid=True, layout=(10, 2), color='steelblue')
for ax in axs.flatten():
    ax.legend(loc='upper left')
fig = plt.gcf()
fig.suptitle('daily mean DO (mg/l) at instantaneous sites', y=0.99)
plt.tight_layout()
plt.savefig("3_visualize/out/inst_daily_means.jpg", dpi=300)

inst_doy_means = inst_daily_means.groupby([inst_daily_means.index.month, inst_daily_means.index.day]).mean().reset_index(drop=True)
daily_doy_means = df_daily_means.groupby([df_daily_means.index.month, df_daily_means.index.day]).mean().reset_index(drop=True)
doy_means = inst_doy_means.join(daily_doy_means)
ax = doy_means.plot(alpha=0.5, color='steelblue', legend=False)
ax.set_xlabel('day of year')
ax.set_ylabel('mean DO concentration (mg/l)')
plt.savefig("3_visualize/out/doy_means.jpg", dpi=300)


