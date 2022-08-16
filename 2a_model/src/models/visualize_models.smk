from model_plots import plot_obs_preds

site_set = config['site_set']

rule make_obs_preds_plots:
    input:
        pred_file="{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/preds.feather",
        obs_file=f"../../../out/{site_set}_io.zarr",
    output:
        "{outdir}/nstates_{nstates}/nep_{epochs}/rep_{rep}/plots/ts_{site_id}_{year}.png"
    run:
        start_date = f"{wildcards.year}-01-01"
        end_date = f"{wildcards.year}-12-31"
        exp_id = out_dir.split("nstates")[0].split("/")[-1].split("_")[0]
        info_dict = {"exp id": exp_id,
                     "n states": wildcards.nstates,
                     "n epochs": wildcards.epochs,
                     "rep id": wildcards.rep,
                     "site id": wildcards.site_id}
        plot_obs_preds(input.pred_file,
                       input.obs_file,
                       site_id=wildcards.site_id,
                       start_date=start_date,
                       end_date=end_date,
                       outfile=output[0],
                       info_dict=info_dict
                       )
        
     
    
