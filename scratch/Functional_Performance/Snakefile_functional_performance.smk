import sys
sys.path.insert(0, 'scratch/Functional_Performance/src')
from do_it_functions import get_max_it_df


models = ['0_baseline_LSTM','2_multitask_dense']
replicate = 0
sink = ['do_min', 'do_mean', 'do_max']
source = 'srad'
sites = 'all'

rule calc_it_metrics_single_rep:
    input:
        #input data file
        "../scratch/4_func_perf/in/results_tmmx_tmmn/med_obs_io.zarr",
        #base file path to models
        "../scratch/4_func_perf/in/results_tmmx_tmmn/models"
    output:
        "out/it_metrics_srad_all_sites_0.csv"
    run:
        get_max_it_df(input_file = input[0], 
                    models = models, 
                    base_file_path = input[1], 
                    output_file = output[0], 
                    replicate = replicate, 
                    sink = sink,
                    source=source, 
                    sites = sites)
        


