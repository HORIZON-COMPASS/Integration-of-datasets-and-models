#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 9  (Convert BASD output back to EMO-1-like format)
# Purpose:      Convert bias-adjusted and statistically downscaled ERA5-Land
#               output from Step 8 back into an EMO-1-compatible format for
#               the period 1990–2022. This includes:
#                 - ws       (10 m wind speed)
#                 - tx, tn   (daily max/min 2 m temperature)
#                 - rg       (surface solar radiation, J m-2)
#                 - pd       (vapour pressure)
#                 - pr       (precipitation, mm day-1)
# Inputs:       - BASD+SD outputs from Step 8:
#                   ${output_dir}/step_8/ERA5_{var}_ERA5_1990_2022_t_basd.nc
#                   for var = sfcWind, tas, tasrange, rsds, hurs, pr
# Outputs:      - Yearly EMO-1-style NetCDF files in:
#                   ${output_dir}/step_9/{var}_YYYY.nc
# User options: - output_dir, year range (here fixed to 1990–2022)
# Dependencies: - bash, CDO, NCO (ncpdq)
# Usage:        - Set `output_dir` below and run:
#                   bash 9_step_9_2.sh
# -------------------------------------------------------------------------
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  #  <-- CHANGE THIS to your desired output directory
opath="${output_dir}/step_9/"

# Ensure the output directory for Step 9 exists
mkdir -p "$opath"

## Step 9.2
## Convert BASD output back to EMO-1-like format for 1990–2022

 # ----------------------------------------------------------------------
# Wind: sfcWind (m s-1) -> ws (m s-1), daily files per year with 1-day shift
# ----------------------------------------------------------------------
filename="${output_dir}/step_8/ERA5_sfcWind_ERA5_1990_2022_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1

for y in {1990..2022}
do
  oname2="${opath}ws_${y}.nc"
  cdo -L -f nc4c -z zip expr,ws="sfcWind" -shifttime,1days -selyear,$y $oname1 $oname2
done
rm $oname1 || { echo "Failed to remove $oname1"; exit 1; }

 # ----------------------------------------------------------------------
# Temperature: reconstruct daily tx and tn (°C) from tas (K) and tasrange (K)
# ----------------------------------------------------------------------
tas="${output_dir}/step_8/ERA5_tas_ERA5_1990_2022_t_basd.nc"
tasrange="${output_dir}/step_8/ERA5_tasrange_ERA5_1990_2022_t_basd.nc"
tas_a="${opath}t_$(basename "$tas" .nc).nc"
tasrange_a="${opath}t_$(basename "$tasrange" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $tas $tas_a
ncpdq -O --cnk_plc=uck -a time,lat,lon $tasrange $tasrange_a
for y in {1990..2022}
do
  tas_b="${opath}ta_$(basename "$tas" .nc)_${y}.nc"
  tasrange_b="${opath}ta_$(basename "$tasrange" .nc)_${y}.nc"
  cdo -L -f nc4c -z zip -selyear,$y $tas_a $tas_b
  cdo -L -f nc4c -z zip -selyear,$y $tasrange_a $tasrange_b
  tx="${opath}tx_${y}.nc"
  tn="${opath}tn_${y}.nc"
  cdo -L -f nc4c -z zip expr,tx="tas + 0.5 * tasrange - 273.15" -merge $tas_b $tasrange_b $tx
  cdo -L -f nc4c -z zip expr,tn="tas - 0.5 * tasrange - 273.15" -merge $tas_b $tasrange_b $tn
  rm $tasrange_b # don't remove tas_b, needed later
done
rm $tas_a
rm $tasrange_a

 # ----------------------------------------------------------------------
# Radiation: rsds (W m-2) -> rg (J m-2 day-1) with 1-day shift
# ----------------------------------------------------------------------
filename="${output_dir}/step_8/ERA5_rsds_ERA5_1990_2022_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1
for y in {1990..2022}
do
  oname2="${opath}rg_${y}.nc"
  cdo -L -f nc4c -z zip expr,rg="rsds * 86400" -shifttime,1days -selyear,$y $oname1 $oname2
done
rm $oname1

 # ----------------------------------------------------------------------
# Vapour pressure: hurs (%) + tas (K) -> pd (hPa), with time shifts to
# align humidity and temperature with EMO-1 convention
# ----------------------------------------------------------------------
filename="${output_dir}/step_8/ERA5_hurs_ERA5_1990_2022_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1

for y in {1990..2022}
do
  oname2="${opath}ta_$(basename "$filename" .nc)_${y}.nc"
  cdo -L -f nc4c -z zip -selyear,$y $oname1 $oname2

  # Use the year-specific tas file created in the temperature block
  tas_y="${opath}ta_$(basename "$tas" .nc)_${y}.nc"
  oname3="${opath}pd_${y}.nc"

  cdo -L -f nc4c -z zip \
    expr,pd="hurs / 100 * (6.11 * 10 ^ (7.5 * (tas - 273.15) / (237.3+ (tas - 273.15) ) ))" \
    -merge \
      -shifttime,1days -selyear,$y $oname2 \
      -shifttime,630minutes "$tas_y" \
    $oname3

  # Optional: remove intermediate yearly hurs file
  # rm "$oname2"
done
rm $oname1

 # ----------------------------------------------------------------------
# Precipitation: pr (kg m-2 s-1) -> daily totals (mm day-1) with 24 h shift
# ----------------------------------------------------------------------
filename="${output_dir}/step_8/ERA5_pr_ERA5_1990_2022_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1
for y in {1990..2022}
do
  oname2="${opath}pr_${y}.nc"
  cdo -L -f nc4c -z zip mulc,86400 -shifttime,24hours -selyear,$y $oname1 $oname2
done
rm $oname1
