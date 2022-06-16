import xarray as xr
import numpy as np

def subset_nc_to_comids(nc_file, comids):
    comids = [int(c) for c in comids]

    ds = xr.open_dataset(nc_file)

    # filter out comids that are not in climate drivers (should only be 4781767)
    comids = np.array(comids)
    comids_in_climate = comids[np.isin(comids, ds.COMID.values)]
    comids_not_in_climate = comids[~np.isin(comids, ds.COMID.values)]

    # make sure it's just the one that we are expecting
    assert list(comids_not_in_climate) == [4781767]

    ds_comids = ds.sel(COMID=comids_in_climate)
    return ds_comids.to_dataframe()
