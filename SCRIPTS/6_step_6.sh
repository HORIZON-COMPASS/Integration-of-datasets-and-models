%%bash

output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

## convert high-res EMO-1 files into the same resolution as ERA5Land;

# ERA5Land file to generate grid file
# the grid file will be the same across all ERA5 land files (for given time period), just generate once

## List of variables to process
variables=("tas" "pr" "rsds" "sfcWind" "tasmax" "tasmin" "hurs")

## Loop to process each variable
for var in "${variables[@]}"; do
    # ERA5Land file to generate grid file
    era5_name="${output_dir}/step_4/merge_era5/${var}_ERA5_2023.nc"  #file from step 4 or if it is only one year from step 2
    grid_file="${output_dir}/step_4/merge_era5/${var}_ERA5_1990_2022_t_aggregate.txt"
    cdo griddes $era5_name > $grid_file

    # Generate conservative remapping weights
    emo1_file="${output_dir}/step_4/merge_emo1/${var}_1990_2022_t.nc"
    weight_file="${output_dir}/step_4/merge_emo1/remap_weight_${var}_1990_2022_t_aggregate.nc"
    efas_grid="${output_dir}/step_4/merge_emo1/efas_grid.txt"
    cdo gencon,$grid_file -setgrid,$efas_grid $emo1_file $weight_file

    # Remap EMO1 file
    cdo remap,$grid_file,$weight_file $emo1_file "${output_dir}/step_6/${var}_1990_2022_t_aggregate.nc"
done


