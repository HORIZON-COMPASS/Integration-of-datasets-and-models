#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 3.3  (Convert EMO-1 variables to EFAS/CLIMB format)
# Purpose:      Convert EMO-1 daily variables cropped to Poland into the
#               EFAS/CLIMB-compatible variables required by the workflow:
#               tas, tasmin, tasmax, hurs, sfcWind, pr and rsds, including
#               basic unit conversions and time shifts.
# Inputs:       - EMO-1 cropped files (tx, tn, pd, ws, pr, rg) in:
#                   ${output_dir}/step_3/emo_data/cutted_emo/{var}/
# Outputs:      - Converted NetCDF files in:
#                   ${output_dir}/step_3/emo_data/EFAS_converted/
# User options: - output_dir, year range, CDO expr definitions if needed
# Dependencies: - bash, CDO (tested with >= 2.0.4)
# Usage:        - Set `output_dir` and year range below, then run:
#                   bash 3_step_3_3.sh
# -------------------------------------------------------------------------

output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Loop over all years in the EMO-1–EFAS overlap period
for y in {1990..2022}
do
	year="$y"

    # File paths for daily maximum/minimum temperature (tx/tn) and outputs
	tx="${output_dir}/step_3/emo_data/cutted_emo/tx/EMO-1arcmin-tx_${year}.nc"
	tn="${output_dir}/step_3/emo_data/cutted_emo/tn/EMO-1arcmin-tn_${year}.nc"
	tasmax="${output_dir}/step_3/emo_data/EFAS_converted/tasmax_${year}.nc"
	tasmin="${output_dir}/step_3/emo_data/EFAS_converted/tasmin_${year}.nc"
    tas="${output_dir}/step_3/emo_data/EFAS_converted/tas_${year}.nc"

    # Convert EMO-1 tx/tn (°C) to tasmax/tasmin/tas (K)
	cdo -f nc4c -z zip expr,tasmax="tx + 273.15" $tx $tasmax
	cdo -f nc4c -z zip expr,tasmin="tn + 273.15" $tn $tasmin
	cdo -f nc4c -z zip expr,tas="(tx + tn) / 2 + 273.15" -merge $tx $tn $tas

    # Relative humidity: derive hurs from vapour pressure (pd) and mean temperature
	hurs0="${output_dir}/step_3/emo_data/EFAS_converted/hurs_raw_${year}.nc"
	hurs="${output_dir}/step_3/emo_data/EFAS_converted/hurs_${year}.nc"
	pd="${output_dir}/step_3/emo_data/cutted_emo/pd/pd_${year}.nc"

    # Compute RH (hurs) from vapour pressure (pd) and mean temperature, then cap at 100%
	cdo -f nc4c -z zip -expr,hurs="pd / (6.11 * 10 ^ (7.5 * ((tn+tx)/2) / (237.3+((tn+tx)/2) ) )) * 100" -merge $tn $tx -shifttime,-1days $pd $hurs0
	cdo -f nc4c -z zip -expr,hurs="(hurs > 100 ) ? 100 : hurs" $hurs0 $hurs

    # Near-surface wind speed: copy ws to sfcWind and align time to EMO-1 convention
	ws="${output_dir}/step_3/emo_data/cutted_emo/ws/ws_${year}.nc"
	sfcWind="${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_${year}.nc"

	cdo -f nc4c -z zip expr,sfcWind="ws" -shifttime,-1days $ws $sfcWind

    # Precipitation: convert from daily totals to daily mean rate (kg m-2 s-1) and shift time
	pr="${output_dir}/step_3/emo_data/cutted_emo/pr/pr_${year}.nc"
	pr_c="${output_dir}/step_3/emo_data/EFAS_converted/pr_${year}.nc"

	cdo -f nc4c -z zip expr,pr="pr/86400" -shifttime,-1days $pr $pr_c

    # Shortwave radiation: convert from J m-2 to W m-2 and shift time
	rg="${output_dir}/step_3/emo_data/cutted_emo/rg/rg_${year}.nc"
	rsds="${output_dir}/step_3/emo_data/EFAS_converted/rsds_${year}.nc"

	cdo -f nc4c -z zip expr,rsds="rg/86400" -shifttime,-1days $rg $rsds

done