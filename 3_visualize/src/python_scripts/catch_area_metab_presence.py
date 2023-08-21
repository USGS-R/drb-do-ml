
# %%
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import xarray as xr
import seaborn as sns

# %%
obs_file = "../../../2a_model/out/well_obs_io.zarr"

# %%
urban_sites = ['01475530', '01475548']
headwater_site = ['014721259']
train_sites = ['01472104', '014721254', '01473500', '01480617', '01480870', '01481000', '01481500']
all_sites = urban_sites + headwater_site + train_sites

# %%
input_variables = ["SLOPE","TOTDASQKM","CAT_BASIN_SLOPE",
                   "TOT_BASIN_SLOPE","CAT_ELEV_MEAN","CAT_RDX","CAT_BFI","CAT_EWT",
                   "CAT_TWI","CAT_PPT7100_ANN","TOT_PPT7100_ANN","CAT_RUN7100",
                   "CAT_CNPY11_BUFF100","CAT_IMPV11","TOT_IMPV11","CAT_NLCD11_wetland",
                   "TOT_NLCD11_wetland","CAT_SANDAVE","CAT_PERMAVE","TOT_PERMAVE",
                   "CAT_RFACT","CAT_WTDEP","TOT_WTDEP","CAT_NPDES_MAJ","CAT_NDAMS2010",
                   "CAT_NORM_STORAGE2010"]

# %%
ds = xr.open_zarr(obs_file)

# %%
ds = ds.sel(site_id=all_sites)

# %%
print("drainage areas [sq km]")
drainage_areas = ds['TOTDASQKM'].mean(dim='date').to_dataframe().sort_values('TOTDASQKM')
print(drainage_areas.round())

print("")
print("median drainage areas [sq km]")
print(drainage_areas.median().round())

print("")
print("number of metab observations per site")
print(ds['GPP'].to_dataframe().groupby('site_id').count())

