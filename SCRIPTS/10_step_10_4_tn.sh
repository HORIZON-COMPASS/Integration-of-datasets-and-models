#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 10  (Gap-filling daily minimum temperature with ERA5 near coast)
# Purpose:      Use ERA5-based daily minimum temperature (tn, from tasmin/tx)
#               to fill coastal/masked grid cells in the BASD+SD output
#               (Step 9) for the period 1990–2022. The BASD landmask is used
#               to select land values from BASD output and ERA5 is used to
#               fill the remaining cells.
#
# Inputs:       - BASD+SD tn for 1990–2022 (from Step 9, in °C):
#                   ${output_dir}/step_9/tn_YYYY.nc
#               - ERA5-based tasmin (affected by earlier swap issue) from Step 2:
#                   ${output_dir}/step_2/ERA5_for_gapfill/tasmin_ERA5_YYYY.nc
#
# Outputs:      - Gap-filled EMO-1-style tn files:
#                   ${output_dir}/step_10/tn_YYYY.nc
#
# User options: - output_dir, year range (here fixed to 1990–2022)
# Dependencies: - bash, CDO, NCO (ncatted, ncap2, ncpdq)
# Usage:        - Set `output_dir` below and run:
#                   bash 10_step_10_tn.sh
# -------------------------------------------------------------------------

# Base output directory for the CLIMB workflow
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

ipath="${output_dir}/step_9/"
epath="${output_dir}/step_2/ERA5_for_gapfill/"
opath="${output_dir}/step_10/"

# Ensure the output directory for Step 10 exists
mkdir -p "$opath"

## Compute BASD landmask, grid and weights for regridding ERA5 (only needed once, the same files are used for other variables)
## Here we use the first year of the overlap period (1990)
basd_file="${ipath}tn_1990.nc"  # from step 9
basd_mask="${opath}basd_landmask_pl.nc"
grid_file="${opath}basd_grid.txt"
cdo griddes "$basd_file" > "$grid_file"

weight_file="${opath}ERA5_weights.nc"
era5_file="${epath}tasmin_ERA5_1990.nc"  # from step 2
cdo gennn,"$grid_file" "$era5_file" "$weight_file"

# Dimension (adapt n_lats and n_lons to file dimensions if needed)
n_times=1
n_lats=142
n_lons=262

## Loop over target years for gapfilling (1990–2022)
for y in {1990..2022}
do
    filename="${ipath}tn_${y}.nc"  # BASD+SD tn from step 9 (°C)
    tile="$(echo "$(basename "$filename" .nc)" | cut -d'_' -f2)"

    era5_file="${epath}tasmin_ERA5_${tile}.nc"         # ERA5 tasmin file from step 2
    era5_file_regrid="${epath}regrid_tasmin_ERA5_${tile}.nc"

    oname1="${opath}tb_$(basename "$filename" .nc).nc"
    oname2="${opath}tc_$(basename "$filename" .nc).nc"
    oname3="${opath}td_$(basename "$filename" .nc).nc"
    oname4="${opath}te_$(basename "$filename" .nc).nc"
    oname5="${opath}$(basename "$filename" .nc).nc"

    # Note:
    # Added -expr,tn="tx-273.15" to fix an earlier issue in Step 2 where tx and tn
    # were swapped. Here we reconstruct tn in °C from the tx variable (in K).
    cdo -f nc4c -z zip remap,"$grid_file","$weight_file" -expr,tn="tx-273.15" "$era5_file" "$era5_file_regrid"

    # Use BASD mask to select BASD tn values over land and ERA5 tn over remaining cells
    cdo -f nc4c -z zip ifthenelse "$basd_mask" "$filename" "$era5_file_regrid" "$oname1"
    cdo -f nc4c -z zip shifttime,30minutes "$oname1" "$oname2"

    # Set missing value attributes
    ncatted -O -a _FillValue,tn,o,s,-9999 "$oname2"
    ncatted -O -a missing_value,tn,o,s,-9999 "$oname2"

    # Pack and re-chunk to time,lat,lon with simple time dimension
    ncap2 -v -O -s 'tn=pack(tn,0.1,0);' "$oname2" "$oname3"
    ncpdq -O --cnk_plc=g3d \
          --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons \
          -a time,lat,lon "$oname3" "$oname4"

    # Adjust time coordinate to EMO-1-like convention with 1990-01-01 as origin
    ncap2 -O -s 'time=(time-30)/24;' "$oname4" "$oname5"
    ncatted -a units,time,o,c,"days since 1990-01-01 00:00:00" "$oname5"

    # Remove temporary files for this year
    rm t*_tn_*.nc
done

### VERIFY THAT ALL TIMESTEPS ARE THE SAME AS IN ORIGINAL EMO-1-DERIVED FILES (1990–2022)