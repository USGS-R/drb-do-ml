from model_plots import plot_obs_preds

rule make_obs_preds_plots:
    input:
        pred_file="{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/preds.feather",
        obs_file="../../../out/well_obs_targets.zarr",
    output:
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/plots/ts_{site_id}_{year}.png"
    run:
        start_date = f"{wildcards.year}-01-01"
        end_date = f"{wildcards.year}-12-31"
        plot_obs_preds(input.pred_file,
                       input.obs_file,
                       site_id=wildcards.site_id,
                       start_date=start_date,
                       end_date=end_date,
                       outfile=output[0]
                       )
        
     
    
