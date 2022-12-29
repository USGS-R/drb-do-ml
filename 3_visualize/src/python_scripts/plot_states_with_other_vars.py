# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %%
import pandas as pd
import xarray as xr
import matplotlib.pyplot as plt

# %% [markdown]
# ## load states and aux data

# %%
df_states = pd.read_csv("../../2a_model/out/models/0_baseline_LSTM/analyze_states/rep_0/states_trained.csv", 
                        dtype={"site_id": str}, parse_dates=["date"], infer_datetime_format=True)

# %%
df_aux = pd.read_csv("../../1_fetch/out/daily_aux_data.csv",
                    dtype={"site_no": str}, parse_dates=["Date"], infer_datetime_format=True)
df_aux = df_aux.rename(columns={"site_no": "site_id", "Date":"date"})

# %%
site_id = "01480870"

# %%
df_aux_site = df_aux.query(f"site_id == '{site_id}'").set_index('date')
df_states_site = df_states.query(f"site_id == '{site_id}'").set_index('date')

# %% [markdown]
# ## load input data

# %%
ds = xr.open_zarr("../../2a_model/out/well_observed_train_val_inputs.zarr/", consolidated=False)

# %%
df_air_temp = ds.seg_tave_air.sel(site_id=site_id).to_dataframe()

# %%
del df_air_temp['site_id']
del df_aux_site['site_id']
del df_states_site['site_id']

# %%
df_comb = df_states_site.join(df_aux_site).join(df_air_temp)

# %% [markdown]
# ___

# %% [markdown]
# # Comparison with Flow

# %%
axs = df_comb.loc[:, df_comb.columns.str.startswith('h')].plot(subplots=True, figsize=(16,20))
axs = axs.ravel()
for ax in axs:
    ax.legend(loc="upper left")
    ax_twin = ax.twinx()
    df_comb.Flow.plot(ax=ax_twin, color="black", alpha=0.6)
    ax_twin.set_ylabel('flow [cfs]')
    plt.tight_layout()
    plt.savefig("../out/states_with_flow.jpg")

# %%
axs = df_comb.loc[:, df_comb.columns.str.startswith('h0')].plot(subplots=True, figsize=(20,5))
axs = axs.ravel()
for ax in axs:
    ax.legend(loc="upper left")
    ax_twin = ax.twinx()
    df_comb.Flow.plot(ax=ax_twin, color="darkgray")
    ax_twin.set_ylabel('flow [cfs]')


# %%
def plot_one_state_w_flow(df_comb, state, color):
    axs = df_comb.loc["2018", df_comb.columns.str.startswith(state)].plot(subplots=True, figsize=(20,5), 
                                                                     color=color, fontsize=20)
    axs = axs.ravel()
    for ax in axs:
        ax.legend(loc="upper left", fontsize=20)
        ax_twin = ax.twinx()
        df_comb.loc["2018", "Flow"].plot(ax=ax_twin, color="black", alpha=0.6, fontsize=20)
        ax_twin.set_ylabel('flow [cfs]', fontsize=20)
        ax.set_xlabel('date', fontsize=20)
        plt.tight_layout()
        plt.savefig(f"../out/{state}_2018_w_flow.jpg")


# %%
plot_one_state_w_flow(df_comb, "h0", color="#1f77b4")

# %%
df_comb.plot.scatter('h0', 'Flow', alpha=0.5)
plt.tight_layout()
plt.savefig("../out/flow_h0_scatter.jpg")

# %%
plot_one_state_w_flow(df_comb, "h1", "#ff7f0e")

# %% [markdown]
# # Comparison with Temperature

# %%
axs = df_comb.loc[:, df_comb.columns.str.startswith('h')].plot(subplots=True, figsize=(16,20))
axs = axs.ravel()
for ax in axs:
    ax.legend(loc="upper left")
    ax_twin = ax.twinx()
    df_comb.seg_tave_air.plot(ax=ax_twin, color="darkgray")
    ax_twin.set_ylabel('avg air temp [degC]')
    plt.tight_layout()
    plt.savefig("../out/states_w_air_temp.jpg")

# %%
df_comb.tail()

# %%
