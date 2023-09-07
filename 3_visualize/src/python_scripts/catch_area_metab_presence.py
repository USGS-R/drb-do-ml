import pandas as pd
from plot_utils import urban_sites, headwater_site, train_sites, obs_file, input_variables

all_sites = urban_sites + headwater_site + train_sites

df = pd.read_csv(obs_file)
df = df.set_index('site_id')

print("drainage areas [sq km]")
drainage_areas = df['TOTDASQKM'].groupby("site_id").mean().sort_values()
print(drainage_areas.round())

print("")
print("median drainage areas [sq km]")
print(drainage_areas.median().round())

print("")
print("number of metab observations per site")
print(df['GPP'].groupby('site_id').count())

