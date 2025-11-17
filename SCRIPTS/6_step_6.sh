#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 6  (Remap EMO-1 to ERA5-Land grid)
# Purpose:      Remap the merged EMO-1 daily fields (Step 4) to the ERA5-Land
#               grid using conservative remapping with CDO, so that both
#               datasets share the same spatial grid for the BASD step.
# Inputs:       - Merged ERA5-Land files (to define the target grid) in:
#                   ${output_dir}/step_4/merge_era5/{var}_ERA5_1990_2022_t.nc
#               - Merged EMO-1 files in:
#                   ${output_dir}/step_4/merge_emo1/{var}_1990_2022_t.nc
# Outputs:      - Remapped EMO-1 files on the ERA5-Land grid in:
#                   ${output_dir}/step_6/{var}_1990_2022_t_aggregate.nc
#               - Grid description files and remapping weights in:
#                   ${output_dir}/step_4/merge_era5/{var}_ERA5_1990_2022_t_aggregate.txt
#                   ${output_dir}/step_4/merge_emo1/remap_weight_{var}_1990_2022_t_aggregate.nc
# User options: - output_dir, list of variables, target period
# Dependencies: - bash, CDO
# Usage:        - Set `output_dir` and adjust the `variables` array if needed,
#                 then run:
#                   bash 6_step_6.sh
# -------------------------------------------------------------------------

output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Ensure the output directory for Step 6 exists
mkdir -p "${output_dir}/step_6"

# Convert high-resolution EMO-1 fields to the ERA5-Land grid (same resolution)

# For each variable, derive the target grid description from the merged ERA5-Land file.
# The resulting grid file is reused for EMO-1 remapping for that variable and period.

# List of variables to be remapped (can be adapted by the user)
variables=("tas" "pr" "rsds" "sfcWind" "tasmax" "tasmin" "hurs")

## Loop to process each variable
for var in "${variables[@]}"; do
    # ERA5-Land file used to define the target grid
    era5_name="${output_dir}/step_4/merge_era5/${var}_ERA5_1990_2022_t.nc"  #file from step 4 or if it is only one year from step 2
    grid_file="${output_dir}/step_4/merge_era5/${var}_ERA5_1990_2022_t_aggregate.txt"
    cdo griddes $era5_name > $grid_file

    # Generate conservative remapping weights from EMO-1 native grid to the ERA5-Land grid
    emo1_file="${output_dir}/step_4/merge_emo1/${var}_1990_2022_t.nc"
    weight_file="${output_dir}/step_4/merge_emo1/remap_weight_${var}_1990_2022_t_aggregate.nc"
    efas_grid="${output_dir}/step_4/merge_emo1/efas_grid.txt"
    cdo gencon,$grid_file -setgrid,$efas_grid $emo1_file $weight_file

    # Apply the conservative remapping to EMO-1 and write the remapped file
    cdo remap,$grid_file,$weight_file $emo1_file "${output_dir}/step_6/${var}_1990_2022_t_aggregate.nc"
done
