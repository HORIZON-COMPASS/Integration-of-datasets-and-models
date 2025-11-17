#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 7  (Prepare EMO-1 reference files for BASD and LISFLOOD)
# Purpose:      Re-chunk EMO-1 daily fields and derive tasrange/tasskew for
#               the multi-decadal period 1990–2022, producing both:
#               - non-aggregated daily files  (..._1990_2022_t.nc)
#               - aggregated daily files      (..._1990_2022_t_aggregate.nc)
#               in the EFAS/CLIMB format expected by ISIMIP3BASD and the
#               hydrological tools.
# Inputs:       - Non-aggregated EMO-1 files from Step 4:
#                   ${output_dir}/step_4/merge_emo1/{var}_1990_2022_t.nc
#               - Aggregated EMO-1 files from Step 6:
#                   ${output_dir}/step_6/{var}_1990_2022_t_aggregate.nc
# Outputs:      - EFAS-style NetCDF files in:
#                   ${output_dir}/step_7/EFAS_{var}_1990_2022_t.nc
#                   ${output_dir}/step_7/EFAS_{var}_1990_2022_t_aggregate.nc
# User options: - output_dir, variable list, chunk sizes (n_lats, n_lons)
# Dependencies: - bash, CDO, NCO (ncpdq)
# Usage:        - Set `output_dir` below and submit via:
#                   sbatch 7_step_7.sh
# -------------------------------------------------------------------------

# Base output directory for the CLIMB workflow
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Ensure the output directory for Step 7 exists
mkdir -p "${output_dir}/step_7"

# Number of chunks along latitude and longitude for ncpdq
n_lats=10
n_lons=10

# Variables to process
variables=("tas" "sfcWind" "hurs" "rsds" "pr")

# Two data types:
#  - ""          : non-aggregated daily files (..._1990_2022_t.nc, from Step 4)
#  - "aggregate" : aggregated daily files     (..._1990_2022_t_aggregate.nc, from Step 6)
types=("aggregate" "")

# ----------------------------------------------------------------------
# 1) Re-chunk core EMO-1 variables for both non-aggregated and aggregated data
# ----------------------------------------------------------------------
for type in "${types[@]}"; do
    for var in "${variables[@]}"; do
        if [ -n "$type" ]; then
            # Aggregated EMO-1 file from Step 6 (remapped to ERA5-Land grid)
            filename="${output_dir}/step_6/${var}_1990_2022_t_${type}.nc"
        else
            # Non-aggregated EMO-1 file from Step 4 (merged original EMO-1 grid)
            filename="${output_dir}/step_4/merge_emo1/${var}_1990_2022_t.nc"
        fi

        if [ -f "$filename" ]; then
            echo "Processing variable: $var, type: ${type:-non-aggregate}"
            # Determine the number of time steps for chunking
            n_times=$(cdo ntime "$filename" | awk 'NR==1 {print $1}')
            echo "  n_times: $n_times, n_lats: $n_lats, n_lons: $n_lons"
            echo "  Input file:  $filename"
            echo "  Output file: ${output_dir}/step_7/EFAS_$(basename "$filename" .nc).nc"

            # Re-chunk and reorder dimensions to lon,lat,time
            ncpdq -4 -O --cnk_plc=g3d \
                  --cnk_dmn=time,"$n_times" --cnk_dmn=lat,"$n_lats" --cnk_dmn=lon,"$n_lons" \
                  -a lon,lat,time "$filename" \
                  "${output_dir}/step_7/EFAS_$(basename "$filename" .nc).nc"
        else
            echo "File $filename does not exist, skipping..."
        fi
    done
done

# ----------------------------------------------------------------------
# 2) Derive tasrange and tasskew and re-chunk them for both data types
# ----------------------------------------------------------------------
for type in "${types[@]}"; do
    if [ -n "$type" ]; then
        # Aggregated EMO-1 files from Step 6
        tas="${output_dir}/step_6/tas_1990_2022_t_${type}.nc"
        tn="${output_dir}/step_6/tasmin_1990_2022_t_${type}.nc"
        tx="${output_dir}/step_6/tasmax_1990_2022_t_${type}.nc"
        tasrange="${output_dir}/step_6/tasrange_1990_2022_t_${type}.nc"
        tasskew="${output_dir}/step_6/tasskew_1990_2022_t_${type}.nc"
    else
        # Non-aggregated EMO-1 files from Step 4
        tas="${output_dir}/step_4/merge_emo1/tas_1990_2022_t.nc"
        tn="${output_dir}/step_4/merge_emo1/tasmin_1990_2022_t.nc"
        tx="${output_dir}/step_4/merge_emo1/tasmax_1990_2022_t.nc"
        tasrange="${output_dir}/step_4/merge_emo1/tasrange_1990_2022_t.nc"
        tasskew="${output_dir}/step_4/merge_emo1/tasskew_1990_2022_t.nc"
    fi

    if [ -f "$tn" ] && [ -f "$tx" ] && [ -f "$tas" ]; then
        echo "Deriving tasrange and tasskew for type: ${type:-non-aggregate}"

        # Calculate tasrange: absolute difference between tasmax and tasmin
        cdo -expr,tasrange="(( tasmax - tasmin ) > 0 ) ? ( tasmax - tasmin ) : ( tasmin - tasmax )" \
            -merge "$tn" "$tx" "$tasrange"

        # Calculate tasskew: relative position of tas between tasmin and tasmax
        cdo -expr,tasskew=" ( tas - tasmin ) / ( tasmax - tasmin ) " \
            -merge "$tn" "$tx" "$tas" "$tasskew"

        # Re-chunk tasrange and tasskew using their own time dimension
        for file in "$tasrange" "$tasskew"; do
            if [ -f "$file" ]; then
                # Determine the number of time steps for this derived file
                n_times=$(cdo ntime "$file" | awk 'NR==1 {print $1}')
                echo "  Re-chunking derived file: $file (n_times=$n_times)"

                ncpdq -4 -O --cnk_plc=g3d \
                      --cnk_dmn=time,"$n_times" --cnk_dmn=lat,"$n_lats" --cnk_dmn=lon,"$n_lons" \
                      -a lon,lat,time "$file" \
                      "${output_dir}/step_7/EFAS_$(basename "$file" .nc).nc"
            else
                echo "  Derived file $file does not exist, skipping..."
            fi
        done
    else
        echo "Files $tn, $tx or $tas do not exist for type ${type:-non-aggregate}, skipping..."
    fi
done
