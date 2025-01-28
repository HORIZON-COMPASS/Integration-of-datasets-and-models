#!/bin/bash
#SBATCH --qos=short
#SBATCH --partition=standard
#SBATCH --job-name=nco_conv_efas
#SBATCH --account=isimip
#SBATCH --output=anco_conv-%j.out
#SBATCH --error=anco_conv-%j.err
##SBATCH --workdir=/p/tmp/dominikp/test host
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16

output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

vars="hurs rsds sfcWind tas tasrange tasskew" # rsds hurs pr sfcWind tas tasrange tasskew


# number of netCDF chunks (do not change)
n_lats=10
n_lons=10

for var in $vars; do
    echo "Processing var: $var"

## convert EMO-1 to BASD format; convert the script to cover the following: tas, sfcWind, hurs, rsds, pr
## and also do it for the aggregated files from script 6
    filename="${output_dir}/step_6/${var}_2023_aggregate.nc"  #Take any one sample year from EMO-1 to use it for a single year (for example: 1994 is taken here)
#   filename="${output_dir}/step_3/emo_data/EFAS_converted/${var}_2023.nc"  #Use this step for none aggregate data

#filename="tas_1990_2022_t.nc"
#filename="sfcWind_1990_2022_t.nc"
#filename="rsds_1990_2022_t.nc"
#filename="pr_1990_2022_t.nc"
#filename="pr_1990_2022_t_aggregate.nc"
#filename="rsds_1990_2022_t_aggregate.nc"
#filename="sfcWind_1990_2022_t_aggregate.nc"
#filename="tas_1990_2022_t_aggregate.nc"
#filename="hurs_1990_2022_t_aggregate.nc"


# Check if file exist
    if [ ! -f "$filename" ]; then
      echo "File $filename doesn't exist."
      exit 1
    fi

# Download time steps from file
    n_times=$(cdo ntime "$filename" | awk 'NR==1 {print $1}')

# Check if all variables have values
    echo "n_times: $n_times"
    echo "n_lats: $n_lats"
    echo "n_lons: $n_lons"
    echo "filename: $filename"
    echo "Output filename: ${output_dir}/step_7/EFAS_$(basename "$filename" .nc).nc"
    #
    ## Create EFAS file 
    ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename "${output_dir}/step_7/EFAS_$(basename "$filename" .nc).nc"


# ## convert tasmin and tasmax into tasskew and tassrange; add also the aggregated file from 6

# Set files
    tas="${output_dir}/step_6/tas_2023_aggregate.nc" #Take any one sample year from EMO-1 to use it for a single year (for example: 1994 is taken here)
    tn="${output_dir}/step_6/tasmin_2023_aggregate.nc"
    tx="${output_dir}/step_6/tasmax_2023_aggregate.nc"
    tasrange="${output_dir}/step_6/tasrange_2023_aggregate.nc"
    tasskew="${output_dir}/step_6/tasskew_2023_aggregate.nc"



# Calculate tasrange
    cdo -expr,tasrange="(( tasmax - tasmin ) > 0 ) ? ( tasmax - tasmin ) : ( tasmin - tasmax )" -merge $tn $tx $tasrange

# Calculate tasskew
    cdo -expr,tasskew="( tas - tasmin ) / ( tasmax - tasmin )" -merge $tn $tx $tas $tasskew

# Download time steps from file
    n_times=$(cdo ntime "$tasrange" | awk 'NR==1 {print $1}')

# Create EFAS file for tasrange
    ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $tasrange "${output_dir}/step_7/EFAS_$(basename "$tasrange" .nc).nc"

# Create EFAS file for tasskew
    ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $tasskew "${output_dir}/step_7/EFAS_$(basename "$tasskew" .nc).nc"
done
