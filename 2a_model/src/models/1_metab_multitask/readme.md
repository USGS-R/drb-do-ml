
To run this model, use the Snakefile of 0_baseline_LSTM, but change the config file option in the command line (--configfile) to the one you want.

For example

```
snakemake -s 2a_model/src/models/0_baseline_LSTM/Snakefile --configfile 2a_model/src/models/1_metab_multitask/config.yml -j -k
```
