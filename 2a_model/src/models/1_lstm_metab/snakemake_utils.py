import numpy as np

def get_var_mean_std(data, var_name):
    var_idx = np.where(data["x_vars"] == var_name)
    var_mean = data["x_mean"][var_idx][0]
    var_std = data["x_std"][var_idx][0]
    return var_mean, var_std
    

def get_elev_light_std_means(prepped_file):
    data = np.load(prepped_file)
    el_mean, el_std = get_var_mean_std(data, "hru_elev")
    lt_mean, lt_std = get_var_mean_std(data, "light_ratio")
    return el_mean, el_std, lt_mean, lt_std
    

