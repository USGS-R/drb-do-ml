
def get_holdouts(config):
    return config['validation_sites_nonurban'] + ['1_urban', '2_urban', 'temporal']


def get_train_val(holdout, config):
    if holdout == "temporal":
        trn_end = config['train_end_date_temporal_holdout']
        val_start = config['val_start_date_temporal_holdout'] 
        val_end = config['val_end_date_temporal_holdout'] 

        val_sites = config['validation_sites_urban']
    # spatial holdouts
    else:
        # train on all of the temporal domain
        trn_end = config['train_end_date_spatial_holdout']
        val_start = config['val_start_date_spatial_holdout'] 
        val_end = config['val_end_date_spatial_holdout'] 

        if holdout == "1_urban":
            val_sites = [config['validation_sites_urban'][0]]
        elif holdout == "2_urban":
            val_sites = config['validation_sites_urban']
        else:
            val_sites = [holdout] + config['validation_sites_urban']

    return trn_end, val_start, val_end, val_sites



