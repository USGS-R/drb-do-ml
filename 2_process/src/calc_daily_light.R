calc_daily_light <- function(start_date, end_date, longitude, latitude){
  #'
  #' @description Function to calculate daily (normalized) max light (i.e. light ratio)
  #' over a range of dates using a site's lat/lon location.
  #' 
  #' @param start_date character string indicating the earliest date to calculate 
  #' daily light. Must be in the format "%Y-%m-%d".
  #' @param end_date character string indicating the latest date to calculate 
  #' daily light. Must be in the format "%Y-%m-%d".
  #' @param longitude numeric value indicating the site longitude in decimal degrees 
  #' @param latitude numeric value indicating the site latitude in decimal degrees
  #' 
  #' @value returns a data frame with the fields "date_localtime", which is the
  #' date represented by local time; "max_light," which represents the maximum light 
  #' estimated within a 30-min window during the day; "sum_light", which represents
  #' the cumulative light estimated over the day; "day_length", which is the total
  #' hours in a day where light > 0; "frac_light" is the ratio between "max_light" and
  #' "sum_light"; "frac_daylength" is equal to 30 minutes divided by "day_length" and 
  #' represents the fraction of total day length represented by the 30-minute 
  #' window that coincides with the daily DO-maximum.
  #' 
  #' @note the streamMetabolizer package is required to calculate daily max light.
  #' streamMetabolizer can be installed using:
  #' remotes::install_github('appling/unitted')
  #' remotes::install_github("USGS-R/streamMetabolizer")
  #'  

  # Generate a synthetic time series (with arbitrary time interval of 30 min)
  # to use for estimating daily max and cumulative light
  dateTime <- seq(strptime(start_date, format = "%Y-%m-%d", tz = "UTC"),
                  strptime(end_date, format = "%Y-%m-%d", tz = "UTC"),
                  by = "30 min")
  
  light_dat <- data.frame(dateTime_utc = dateTime) %>%
    as_tibble() %>%
    mutate(dateTime_local = lubridate::with_tz(dateTime, tzone = "America/New_York"),
           date_localtime = lubridate::date(dateTime_local))
  
  # Calculate mean solar time where the solar zenith corresponds to almost exactly noon
  # I'm getting a warning that google time zone lookup now requires
  # an API, but solar time values are still returned. Is this a problem?
  light_dat$solar_time <- streamMetabolizer::calc_solar_time(light_dat$dateTime_utc, longitude = longitude)
  
  # Calculate PAR for given date-times and site coordinates
  light_dat$light <- streamMetabolizer::calc_light(light_dat$solar_time, latitude, longitude)
  
  # Approximate normalized light during 30-min window that coincides with DO-max
  light_dat_daily <- light_dat %>%
    group_by(date_localtime) %>%
    summarize(max_light = max(light, na.rm = TRUE),
              sum_light = sum(light, na.rm = TRUE),
              day_length = if(any(light > 0)) as.numeric(diff(range(solar_time[light>0])), units='hours') else NA) %>%
    ungroup() %>%
    mutate(frac_light = max_light/sum_light,
           frac_daylength = 0.5/day_length)
  
  return(light_dat_daily)
  
}


calc_seg_light_ratio <- function(segment, start_date, end_date){
  #'
  #' @description Function to calculate daily (normalized) max light (i.e. light ratio)
  #' over a range of dates for a given river segment.
  #' 
  #' @param segment sf LINESTRING representing a single river reach
  #' @param start_date character string indicating the earliest date to calculate 
  #' daily light. Must be in the format "%Y-%m-%d".
  #' @param end_date character string indicating the latest date to calculate 
  #' daily light. Must be in the format "%Y-%m-%d".
  #' 
  #' @value returns a data frame with the fields "date_localtime", which is the
  #' date represented by local time; "max_light," which represents the maximum light 
  #' estimated within a 30-min window during the day; "sum_light", which represents
  #' the cumulative light estimated over the day; "day_length", which is the total
  #' hours in a day where light > 0; "frac_light" is the ratio between "max_light" and
  #' "sum_light"; "frac_daylength" is equal to 30 minutes divided by "day_length" and 
  #' represents the fraction of total day length represented by the 30-minute 
  #' window that coincides with the daily DO-maximum.
  #' 
  #' @note the streamMetabolizer package is required to calculate daily max light.
  #' streamMetabolizer can be installed using:
  #' remotes::install_github('appling/unitted')
  #' remotes::install_github("USGS-R/streamMetabolizer")
  #'  
  

  # 1. Get lat/lon coordinates for each segment
  # cast segment LINESTRING to POINT 
  segment_as_pts <- segment$geometry %>%
    sf::st_cast("POINT") %>%
    sf::st_as_sf() %>%
    mutate(lat = sf::st_coordinates(.)[,2],
           lon = sf::st_coordinates(.)[,1])
  
  # find segment centroid
  segment_centroid <- segment %>%
    sf::st_centroid(geometry) %>%
    mutate(nearest_pt = sf::st_nearest_feature(.,segment_as_pts)) %>%
    # suppress warnings from sf that attributes are assumed constant
    # over geometries of x
    suppressWarnings()
  
  # snap segment centroid to nearest POINT node along LINESTRING
  segment_centroid_snap <- segment_as_pts[unique(segment_centroid$nearest_pt),] %>%
    sf::st_drop_geometry() 
  
  # 2. Estimate daily normalized max light (i.e., the light ratio) for each segment
  daily_light <- calc_daily_light(start_date, 
                                  end_date, 
                                  segment_centroid_snap$lon, 
                                  segment_centroid_snap$lat)
  
  # Format columns
  daily_light_out <- daily_light %>%
    mutate(subsegid = unique(segment$subsegid),
           seg_id_nat = unique(segment$segidnat))
  
  return(daily_light_out)
  
}

