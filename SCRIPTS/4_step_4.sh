#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 4  (Merge daily ERA5-Land and EMO-1 files)
# Purpose:      Merge yearly daily NetCDF files from previous steps into
#               continuous multi-year time series for use in the BASD step.
#               This includes:
#                 - ERA5-Land variables for 1950–1989 and 1990–2022, and
#                 - EMO-1-derived variables for 1990–2022.
# Inputs:       - ERA5-Land daily NetCDF files from Step 2:
#                   ${output_dir}/step_2/ERA5_land_daily/{var}_ERA5_YYYY.nc
#               - EMO-1 converted daily NetCDF files from Step 3.3:
#                   ${output_dir}/step_3/emo_data/EFAS_converted/{var}_YYYY.nc
# Outputs:      - Merged ERA5-Land files in:
#                   ${output_dir}/step_4/merge_era5/{var}_ERA5_1950_1989_t.nc
#                   ${output_dir}/step_4/merge_era5/{var}_ERA5_1990_2022_t.nc
#               - Merged EMO-1 files in:
#                   ${output_dir}/step_4/merge_emo1/{var}_1990_2022_t.nc
# User options: - output_dir; adjust year ranges or variable lists if needed
# Dependencies: - bash, CDO
# Usage:        - Set `output_dir` below, then run:
#                   bash 4_step_4.sh
# -------------------------------------------------------------------------

output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Define and create output subdirectories for merged ERA5-Land and EMO-1 files
STEP_4_OUTPUT="${output_dir}/step_4"
MERGE_ERA5="${STEP_4_OUTPUT}/merge_era5"
MERGE_EMO1="${STEP_4_OUTPUT}/merge_emo1"

# Create the output directories if they don't exist
mkdir -p $MERGE_ERA5
mkdir -p $MERGE_EMO1

# Merge ERA5-Land daily files into continuous 1990–2022 time series (overlap with EMO-1)
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_2022.nc $MERGE_ERA5/hurs_ERA5_1990_2022_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_2022.nc $MERGE_ERA5/tas_ERA5_1990_2022_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_2022.nc $MERGE_ERA5/tasmin_ERA5_1990_2022_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_2022.nc $MERGE_ERA5/tasmax_ERA5_1990_2022_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_2022.nc $MERGE_ERA5/sfcWind_ERA5_1990_2022_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_2022.nc $MERGE_ERA5/rsds_ERA5_1990_2022_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_199?.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_200?.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_201?.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_2020.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_2021.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_2022.nc $MERGE_ERA5/pr_ERA5_1990_2022_t.nc

# Merge ERA5-Land daily files for the pre-EMO period 1950–1989
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_198?.nc $MERGE_ERA5/hurs_ERA5_1950_1989_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/tas_ERA5_198?.nc $MERGE_ERA5/tas_ERA5_1950_1989_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_198?.nc $MERGE_ERA5/tasmin_ERA5_1950_1989_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_198?.nc $MERGE_ERA5/tasmax_ERA5_1950_1989_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_198?.nc $MERGE_ERA5/sfcWind_ERA5_1950_1989_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_198?.nc $MERGE_ERA5/rsds_ERA5_1950_1989_t.nc
cdo mergetime ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_195?.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_196?.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_197?.nc ${output_dir}/step_2/ERA5_land_daily/pr_ERA5_198?.nc $MERGE_ERA5/pr_ERA5_1950_1989_t.nc

# Merge EMO-1-derived daily files for 1990–2022 to match the ERA5-Land overlap period
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/hurs_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/hurs_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/hurs_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/hurs_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/hurs_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/hurs_2022.nc $MERGE_EMO1/hurs_1990_2022_t.nc
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/tas_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tas_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tas_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tas_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/tas_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/tas_2022.nc $MERGE_EMO1/tas_1990_2022_t.nc
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/tasmin_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmin_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmin_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmin_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmin_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmin_2022.nc $MERGE_EMO1/tasmin_1990_2022_t.nc
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/tasmax_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmax_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmax_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmax_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmax_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/tasmax_2022.nc $MERGE_EMO1/tasmax_1990_2022_t.nc
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_2022.nc $MERGE_EMO1/sfcWind_1990_2022_t.nc
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/rsds_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/rsds_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/rsds_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/rsds_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/rsds_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/rsds_2022.nc $MERGE_EMO1/rsds_1990_2022_t.nc
cdo -f nc4c -z zip mergetime ${output_dir}/step_3/emo_data/EFAS_converted/pr_199?.nc ${output_dir}/step_3/emo_data/EFAS_converted/pr_200?.nc ${output_dir}/step_3/emo_data/EFAS_converted/pr_201?.nc ${output_dir}/step_3/emo_data/EFAS_converted/pr_2020.nc ${output_dir}/step_3/emo_data/EFAS_converted/pr_2021.nc ${output_dir}/step_3/emo_data/EFAS_converted/pr_2022.nc $MERGE_EMO1/pr_1990_2022_t.nc
