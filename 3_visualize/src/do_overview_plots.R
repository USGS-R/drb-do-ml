
plot_do_overview <- function(plot_file, p1_daily_data_csv, p1_inst_data_csv, filesout){
    reticulate::source_python(plot_file)
    return(filesout)
}
