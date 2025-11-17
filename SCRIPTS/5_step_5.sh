#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 5  (Prepare ERA5-Land chunks and derived variables)
# Purpose:      Re-chunk selected daily ERA5-Land NetCDF files (from Step 2)
#               along time/lat/lon for efficient use in the BASD step, and
#               derive additional variables needed by the workflow:
#               - tasrange  (tx - tn)
#               - tasskew   ( (tas - tn) / (tx - tn) )
# Inputs:       - Daily ERA5-Land files (single year) in:
#                   ${output_dir}/step_2/ERA5_land_daily/
#                 for hurs, tas, sfcWind, rsds, pr, tasmin, tasmax
# Outputs:      - Re-chunked files in:
#                   ${output_dir}/step_5/ERA5_{var}_ERA5_YYYY.nc
#                 plus re-chunked tasrange and tasskew files.
# User options: - output_dir, target year(s), chunk sizes (n_lats, n_lons)
# Dependencies: - bash, CDO, NCO (ncpdq, ncrename)
# Usage:        - Set `output_dir` and the filenames/year below, then run:
#                   bash 5_step_5.sh
# -------------------------------------------------------------------------
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Ensure the output directory for Step 5 exists
mkdir -p "${output_dir}/step_5"

n_lats=10
n_lons=10

# Number of chunks along latitude and longitude for ncpdq (can be tuned)
n_lats=10
n_lons=10

# Process each variable separately to prepare ERA5-Land input for BASD
# ----------------------------------------------------------------------
# hurs: compute number of time steps, then re-chunk and reorder dimensions
# ----------------------------------------------------------------------
#hurs
filename="${output_dir}/step_4/merge_era5/hurs_ERA5_1990_2022_t.nc"  #for merged data
#filename="${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_2023.nc"  #for selected year
n_times=$(cdo ntime $filename | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,"$n_times" --cnk_dmn=lat,"$n_lats" --cnk_dmn=lon,"$n_lons" -a lon,lat,time "$filename" "${output_dir}/step_5/ERA5_$(basename "$filename" .nc).nc"

echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename" .nc)"

#
# ----------------------------------------------------------------------
# tas: re-chunk 2 m temperature (later renamed from 2t to tas with ncrename)
# ----------------------------------------------------------------------
#tas
##### After generate file remember to rename variable name to tas, same as EMO1
##### use this code in terminal: ncrename -v 2t,tas /mnt/g/compass/compass_framework/step_5/tas_YEAR.nc #replace input file with the tas file that you want to rename

filename2="${output_dir}/step_4/merge_era5/ERA5_land_daily/tas_ERA5_1990_2022_t.nc"
n_times=$(cdo ntime $filename2 | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename2 "${output_dir}/step_5/ERA5_$(basename "$filename2" .nc).nc"
#
echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename2"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename2" .nc)"


#
# ----------------------------------------------------------------------
# sfcWind: re-chunk near-surface wind speed
# ----------------------------------------------------------------------
##sfcWind
filename3="${output_dir}/step_4/merge_era5/ERA5_land_daily/sfcWind_ERA5_1990_2022_t.nc"
n_times=$(cdo ntime $filename3 | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename3 "${output_dir}/step_5/ERA5_$(basename "$filename3" .nc).nc"
#
echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename3"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename3" .nc)"


# ----------------------------------------------------------------------
# rsds: re-chunk shortwave radiation
# ----------------------------------------------------------------------
#rsds
filename4="${output_dir}/step_4/merge_era5/ERA5_land_daily/rsds_ERA5_1990_2022_t.nc"
n_times=$(cdo ntime $filename4 | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename4 "${output_dir}/step_5/ERA5_$(basename "$filename4" .nc).nc"
#
echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename4"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename4" .nc)"

# ----------------------------------------------------------------------
# pr: re-chunk precipitation
# ----------------------------------------------------------------------
#pr
filename5="${output_dir}/step_4/merge_era5/ERA5_land_daily/pr_ERA5_1990_2022_t.nc"
n_times=$(cdo ntime "$filename5" | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename5 "${output_dir}/step_5/ERA5_$(basename "$filename5" .nc).nc"

echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename5"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename5" .nc)"


#
# ----------------------------------------------------------------------
# Derived variables: tasrange and tasskew from tas, tasmin (tn) and tasmax (tx)
# ----------------------------------------------------------------------
#Convert tas to tasrange and tasskew
tas="${output_dir}/step_4/merge_era5/ERA5_land_daily/tas_ERA5_1990_2022_t.nc"
tn="${output_dir}/step_4/merge_era5/ERA5_land_daily/tasmin_ERA5_1990_2022_t.nc"
tx="${output_dir}/step_4/merge_era5/ERA5_land_daily/tasmax_ERA5_1990_2022_t.nc"
tasrange="${output_dir}/step_4/merge_era5/ERA5_land_daily/tasrange_ERA5_1990_2022_t.nc"
tasskew="${output_dir}/step_4/merge_era5/ERA5_land_daily/tasskew_ERA5_1990_2022_t.nc"
# Use the tas file to determine the number of time steps for tasrange/tasskew
n_times=$(cdo ntime "$tas" | awk 'NR==1 {print $1}')
##
cdo expr,tasrange="tx - tn" -merge -chname,2t,tn $tn -chname,2t,tx $tx $tasrange
cdo expr,tasskew=" ( tas - tn ) / ( tx - tn ) " -merge -chname,2t,tn $tn -chname,2t,tx $tx -chname,2t,tas $tas $tasskew
##
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $tasrange "${output_dir}/step_5/ERA5_$(basename "$tasrange" .nc).nc"
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $tasskew "${output_dir}/step_5/ERA5_$(basename "$tasskew" .nc).nc"
#