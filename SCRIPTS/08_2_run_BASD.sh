#!/bin/bash

#SBATCH --qos=short
#SBATCH --partition=standard
#SBATCH --account=dmcci
##SBATCH --mail-user=slange@pik-potsdam.de
##SBATCH --mail-type=ALL,TIME_LIMIT
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --job-name=basd
#SBATCH --output=slogs/basd.%j
#SBATCH --error=slogs/basd.%j

## this is an adapted script from Stefan Lange for running BASD on ERA5Land and EMO1 files

# all vars and time periods
vars="hurs pr rsds sfcWind tas tasrange tasskew"
pers="1950_1989 1990_2022"

# set paths
cdir=/mnt/g/compass/api/isimip3basd-master/code
idir=/mnt/g/compass/api/files_for_basd
odir=/mnt/g/compass/api/basd_output_data

# Activate conda environment once before loop
source /mnt/g/compass/api/nco/bin/activate

# Iterate over all variables and periods
for var in $vars; do
  for per in $pers; do
    echo "Processing var: $var, period: $per"
    
    # Define file paths
    obs_hist_fine=$idir/EFAS_${var}_1990_2022_t.nc
    obs_hist_coarse=$idir/EFAS_${var}_1990_2022_t_aggregate.nc
    sim_hist_coarse=$idir/ERA5_${var}_ERA5_1990_2022_t.nc
    sim_fut_coarse=$idir/ERA5_${var}_ERA5_${per}_t.nc
    sim_fut_basd_coarse=$odir/ERA5_${var}_ERA5_${per}_t_ba.nc
    sim_fut_basd_fine=$odir/ERA5_${var}_ERA5_${per}_t_basd.nc
    
    # Set parameters based on variable
    case $var in
      hurs*)
        options_ba="-v hurs --lower-bound 0 --lower-threshold .01 --upper-bound 100 --upper-threshold 99.99 -t bounded --unconditional-ccs-transfer 1 --trendless-bound-frequency 1"
        options_sd="-v hurs --lower-bound 0 --lower-threshold .01 --upper-bound 100 --upper-threshold 99.99";;
      pr*)
        options_ba="-v pr --lower-bound 0 --lower-threshold .0000011574 --distribution gamma -t mixed"
        options_sd="-v pr --lower-bound 0 --lower-threshold .0000011574";;
      rsds*)
        options_ba="-v rsds --lower-bound 0 --lower-threshold .0001 --upper-bound 1 --upper-threshold .9999 -t bounded -w 15"
        options_sd="-v rsds --lower-bound 0 --lower-threshold .01";;
      sfcWind*)
        options_ba="-v sfcWind --lower-bound 0 --lower-threshold .01 --distribution weibull -t mixed"
        options_sd="-v sfcWind --lower-bound 0 --lower-threshold .01";;
      tas)
        options_ba="-v tas --distribution normal -t additive -d 1"
        options_sd="-v tas";;
      tasrange)
        options_ba="-v tasrange --lower-bound 0 --lower-threshold .01 --distribution weibull -t mixed"
        options_sd="-v tasrange --lower-bound 0 --lower-threshold .01";;
      tasskew)
        options_ba="-v tasskew --lower-bound 0 --lower-threshold .0001 --upper-bound 1 --upper-threshold .9999 -t bounded"
        options_sd="-v tasskew --lower-bound 0 --lower-threshold .0001 --upper-bound 1 --upper-threshold .9999";;
      *)
        echo "Variable $var not supported ... aborting ..."
        exit 1;;
    esac

    # Perform bias adjustment
    time python -u $cdir/bias_adjustment.py $options_ba \
    --n-processes 16 \
    --randomization-seed 0 \
    --step-size 1 \
    -o $obs_hist_coarse \
    -s $sim_hist_coarse \
    -f $sim_fut_coarse \
    -b $sim_fut_basd_coarse
    chmod 664 $sim_fut_basd_coarse
    echo

    # Perform statistical downscaling
    time python -u $cdir/statistical_downscaling.py $options_sd \
    --n-processes 16 \
    --randomization-seed 0 \
    -o $obs_hist_fine \
    -s $sim_fut_basd_coarse \
    -f $sim_fut_basd_fine
    chmod 664 $sim_fut_basd_fine
    echo
  done
done

# Deactivate conda environment
deactivate
