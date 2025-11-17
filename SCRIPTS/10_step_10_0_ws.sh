#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 10  (Gap-filling 10 m wind speed with ERA5 near coast)
# Purpose:      Use ERA5-based 10 m wind speed (sfcWind) to fill coastal/masked
#               grid cells in the BASD+SD output (Step 9) for the period
#               1990–2022. The BASD landmask is derived from BASD ws and then
#               used to select land values from BASD output, while ERA5 is
#               used to fill the remaining cells (e.g. along the coastline).
#
# Inputs:       - BASD+SD ws for 1990–2022 (from Step 9, in m s-1):
#                   ${output_dir}/step_9/ws_YYYY.nc
#               - ERA5-based sfcWind (from Step 2):
#                   ${output_dir}/step_2/ERA5_for_gapfill/sfcWind_ERA5_YYYY.nc
#
# Outputs:      - Gap-filled EMO-1-style ws files:
#                   ${output_dir}/step_10/ws_YYYY.nc
#
# User options: - output_dir, year range (here fixed to 1990–2022)
# Dependencies: - bash, CDO, NCO (ncatted, ncap2, ncpdq)
# Usage:        - Set `output_dir` below and run:
#                   bash 10_step_10_ws.sh
# -------------------------------------------------------------------------

# Base output directory for the CLIMB workflow
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

ipath="${output_dir}/step_9/"
epath="${output_dir}/step_2/ERA5_for_gapfill/"
opath="${output_dir}/step_10/"

# Ensure the output directory for Step 10 exists
mkdir -p "$opath"

## Compute BASD landmask, grid and weights for regridding ERA5 (only needed once,
## the same files are used for other variables in Step 10).
## Here we use the first year of the overlap period (1990).
basd_file="${ipath}ws_1990.nc"  # from step 9
basd_mask="${opath}basd_landmask_pl.nc"
cdo -f nc4c -z zip setmisstoc,0 -expr,sfcWind="(ws >= 0) ? 1 : 0" -seltimestep,1 "$basd_file" "$basd_mask"

grid_file="${opath}basd_grid.txt"
cdo griddes "$basd_file" > "$grid_file"

weight_file="${opath}ERA5_weights.nc"
era5_file="${epath}sfcWind_ERA5_1990.nc"  # from step 2
cdo gennn,"$grid_file" "$era5_file" "$weight_file"

# Dimension (adapt n_lats and n_lons to file dimensions if needed)
n_times=1
n_lats=142
n_lons=262

## Loop over target years for gapfilling (1990–2022)
for y in {1990..2022}
do
    filename="${ipath}ws_${y}.nc"  # BASD+SD ws from step 9
    tile="$(echo "$(basename "$filename" .nc)" | cut -d'_' -f2)"

    era5_file="${epath}sfcWind_ERA5_${tile}.nc"        # ERA5 10 m wind speed from step 2
    era5_file_regrid="${epath}regrid_sfcWind_ERA5_${tile}.nc"

    oname1="${opath}tb_$(basename "$filename" .nc).nc"
    oname2="${opath}tc_$(basename "$filename" .nc).nc"
    oname3="${opath}td_$(basename "$filename" .nc).nc"
    oname4="${opath}te_$(basename "$filename" .nc).nc"
    oname5="${opath}$(basename "$filename" .nc).nc"

    # Remap ERA5 sfcWind to the BASD grid and shift time by +1 day
    cdo -f nc4c -z zip remap,"$grid_file","$weight_file" -shifttime,1days "$era5_file" "$era5_file_regrid"

    # Use BASD mask to select BASD ws over land and ERA5 ws over remaining cells
    cdo -f nc4c -z zip ifthenelse "$basd_mask" "$filename" "$era5_file_regrid" "$oname1"
    cdo -f nc4c -z zip shifttime,-330minutes "$oname1" "$oname2"

    # Set missing value attributes
    ncatted -O -a _FillValue,ws,o,s,-9999 "$oname2"
    ncatted -O -a missing_value,ws,o,s,-9999 "$oname2"

    # Pack and re-chunk to time,lat,lon with simple time dimension
    ncap2 -v -O -s 'ws=pack(ws,0.1,0);' "$oname2" "$oname3"
    ncpdq -O --cnk_plc=g3d \
          --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons \
          -a time,lat,lon "$oname3" "$oname4"

    # Adjust time coordinate to EMO-1-like convention with 1990-01-01 as origin
    ncap2 -O -s 'time=(time-24)/24;' "$oname4" "$oname5"
    ncatted -a units,time,o,c,"days since 1990-01-01 00:00:00" "$oname5"

    # Remove temporary files for this year
    rm t*_ws_*.nc
done

### VERIFY THAT ALL TIMESTEPS ARE THE SAME AS IN ORIGINAL EMO-1-DERIVED FILES (1990–2022)