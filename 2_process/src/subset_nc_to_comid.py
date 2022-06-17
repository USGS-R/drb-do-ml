import xarray as xr
import numpy as np
import pandas as pd


def ds_to_dataframe_faster(ds):
    """
    doing this to try to avoid the multi-index joins
    """
    series_list = []
    for var in ds.data_vars:
        if "lat" not in var and "lon" not in var:
            df_var = ds[var].to_pandas().reset_index()
            df_var_tidy = df_var.melt(id_vars='COMID', value_name=var)
            series_list.append(df_var_tidy[var])
    series_list.append(df_var_tidy['COMID'])
    series_list.append(df_var_tidy['time'])
    return pd.concat(series_list, axis=1)


def subset_nc_to_comids(nc_file, comids):
    comids = [int(c) for c in comids]

    ds = xr.open_dataset(nc_file)

    # filter out comids that are not in climate drivers (should only be 4781767)
    comids = np.array(comids)
    comids_in_climate = comids[np.isin(comids, ds.COMID.values)]
    comids_not_in_climate = comids[~np.isin(comids, ds.COMID.values)]
    print(comids_not_in_climate)

    # make sure it's just the one that we are expecting
    if len(comids_not_in_climate) > 0 :
        assert list(comids_not_in_climate) == [4781767]
    ds_comids = ds.sel(COMID=comids_in_climate)
    return ds_to_dataframe_faster(ds_comids)
