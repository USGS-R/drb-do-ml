
write_to_csv <- function(data, outfile){
  write_csv(data, file = outfile)
  return(outfile)
}
