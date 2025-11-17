#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 10  (Gap-filling precipitation with ERA5 near coast)
# Purpose:      Use ERA5-based precipitation (pr) to fill coastal/masked
#               grid cells in the BASD+SD output (Step 9) for the period
#               1990–2022. The BASD landmask is used to select land values
#               from BASD output and ERA5 is used to fill the remaining cells.
#
# Inputs:       - BASD+SD precipitation for 1990–2022 (from Step 9):
#                   ${output_dir}/step_9/pr_YYYY.nc
#               - ERA5-based precipitation (from Step 2):
#                   ${output_dir}/step_2/ERA5_for_gapfill/pr_ERA5_YYYY.nc
#
# Outputs:      - Gap-filled EMO-1-style precipitation files:
#                   ${output_dir}/step_10/pr_YYYY.nc
#
# User options: - output_dir, year range (here fixed to 1990–2022)
# Dependencies: - bash, CDO, NCO (ncatted, ncap2, ncpdq)
# Usage:        - Set `output_dir` below and run:
#                   bash 10_step_10_pr.sh
# -------------------------------------------------------------------------

# Base output directory for the CLIMB workflow
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

ipath="${output_dir}/step_9/"
epath="${output_dir}/step_2/ERA5_for_gapfill/"
opath="${output_dir}/step_10/"

# Ensure the output directory for Step 10 exists
mkdir -p "$opath"

## Compute BASD landmask, grid and weights for regridding ERA5 (only needed once)
## Here we use the first year of the overlap period (1990)
basd_file="${ipath}pr_1990.nc"  # from step 9
basd_mask="${opath}basd_landmask_pl.nc"
grid_file="${opath}basd_grid.txt"
cdo griddes "$basd_file" > "$grid_file"

weight_file="${opath}ERA5_weights.nc"
era5_file="${epath}pr_ERA5_1990.nc"  # from step 2
cdo gennn,"$grid_file" "$era5_file" "$weight_file"

# Dimension (adapt n_lats and n_lons to file dimensions divided by 3 if needed)
n_times=1
n_lats=142
n_lons=262

## Loop over target years for gapfilling (1990–2022)
for y in {1990..2022}
do
    filename="${ipath}pr_${y}.nc"  # BASD+SD pr from step 9
    tile="$(echo "$(basename "$filename" .nc)" | cut -d'_' -f2)"

    era5_file="${epath}pr_ERA5_${tile}.nc"        # ERA5 precipitation rate from step 2
    era5_file_regrid="${epath}regrid_pr_ERA5_${tile}.nc"

    oname1="${opath}tb_$(basename "$filename" .nc).nc"
    oname2="${opath}tc_$(basename "$filename" .nc).nc"
    oname3="${opath}td_$(basename "$filename" .nc).nc"
    oname4="${opath}te_$(basename "$filename" .nc).nc"
    oname5="${opath}$(basename "$filename" .nc).nc"

    # Convert ERA5 precipitation rate (kg m-2 s-1) to daily totals (mm day-1)
    # and remap to the BASD grid, shifting time by +1 day to match EMO-1 convention.
    cdo -f nc4c -z zip remap,"$grid_file","$weight_file" -expr,pr="pr*86400" -shifttime,1days "$era5_file" "$era5_file_regrid"

    # Use BASD mask to select BASD values over land and ERA5 over remaining cells
    cdo -f nc4c -z zip ifthenelse "$basd_mask" "$filename" "$era5_file_regrid" "$oname1"
    cdo -f nc4c -z zip shifttime,360minutes "$oname1" "$oname2"

    # Set missing value attributes
    ncatted -O -a _FillValue,pr,o,s,-9999 "$oname2"
    ncatted -O -a missing_value,pr,o,s,-9999 "$oname2"

    # Pack and re-chunk to time,lat,lon with simple time dimension
    ncap2 -v -O -s 'pr=pack(pr,0.1,0);' "$oname2" "$oname3"
    ncpdq -O --cnk_plc=g3d \
          --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons \
          -a time,lat,lon "$oname3" "$oname4"

    # Adjust time coordinate to EMO-1 convention
    ncap2 -O -s 'time=(time-24)/24;' "$oname4" "$oname5"
    #ncatted -a units,time,o,c,"days since 1950-01-02 00:00:00" "$oname5"
    ncatted -a units,time,o,c,"days since 1990-01-01 00:00:00" "$oname5"

    # Remove temporary files for this year
    rm t*_pr_*.nc
done

### VERIFY THAT ALL TIMESTEPS ARE THE SAME AS IN ORIGINAL EMO-1 FILES (1990–2022)