#!/usr/bin/env bash
# -------------------------------------------------------------------------
# CLIMB workflow step: 8  (Bias adjustment and statistical downscaling)
# Purpose:      Run the ISIMIP3BASD bias_adjustment.py and
#               statistical_downscaling.py scripts for the CLIMB workflow,
#               using EMO-1 as observational reference (1990–2022) and
#               ERA5-Land as the model to be bias-adjusted/downscaled.
#
#               In this step we:
#                 - calibrate ISIMIP3BASD on the full multi-decadal overlap
#                   period 1990–2022 between EMO-1 and ERA5-Land, and
#                 - apply the calibrated adjustment to the same 1990–2022
#                   ERA5-Land series, producing both:
#                     * bias-adjusted ERA5-Land on the coarse grid, and
#                     * bias-adjusted + statistically downscaled series on
#                       the EMO-1/EFAS grid.
#
# Inputs:       - EMO-1-based reference data (Step 7):
#                   ${output_dir}/step_7/EFAS_${var}_1990_2022_t.nc
#                   ${output_dir}/step_7/EFAS_${var}_1990_2022_t_aggregate.nc
#               - ERA5-Land daily series (Step 5):
#                   ${output_dir}/step_5/ERA5_${var}_ERA5_1990_2022_t.nc
#
# Outputs:      - Bias-adjusted ERA5-Land on the coarse grid:
#                   ${output_dir}/step_8/ERA5_${var}_ERA5_1990_2022_t_ba.nc
#               - Bias-adjusted + statistically downscaled series on the
#                 EMO-1/EFAS grid:
#                   ${output_dir}/step_8/ERA5_${var}_ERA5_1990_2022_t_basd.nc
#
# User options: - output_dir, list of variables, BASD options by variable
# Dependencies: - bash, Python 3, ISIMIP3BASD (bias_adjustment.py,
#                 statistical_downscaling.py) and their Python dependencies
# Usage:        - Set `output_dir` below and ensure that Steps 5 and 7 have
#                 been completed, then run:
#                   bash 8_step_8.sh
# -------------------------------------------------------------------------

# Base output directory for the CLIMB workflow
output_dir='/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Variables and calibration period
vars="hurs pr rsds sfcWind tas tasrange tasskew"
per="1990_2022"

# Location of the ISIMIP3BASD code and input/output directories
cdir="${output_dir}/isimip3basd-master/code"
idir_era5="${output_dir}/step_5"
idir_emo="${output_dir}/step_7"
odir="${output_dir}/step_8"

# Create output directory if it does not exist
mkdir -p "$odir"

# Optional: activate a virtual/conda environment providing ISIMIP3BASD
# source /path/to/your/env/bin/activate

# Iterate over all variables
for var in $vars; do
  echo "==================================================================="
  echo "Processing variable: $var (period: ${per})"
  echo "==================================================================="

  # Define file paths
  # EMO-1 / EFAS:
  #   - obs_hist_fine   : high-resolution reference (non-aggregated)
  #   - obs_hist_coarse : aggregated reference on the coarse grid
  obs_hist_fine="${idir_emo}/EFAS_${var}_${per}_t.nc"
  obs_hist_coarse="${idir_emo}/EFAS_${var}_${per}_t_aggregate.nc"

  # ERA5-Land:
  #   - sim_hist_coarse : historical model series (overlap with EMO-1)
  #   - sim_fut_coarse  : here the same as sim_hist_coarse, since we
  #                       currently apply BASD to the 1990–2022 period only
  sim_hist_coarse="${idir_era5}/ERA5_${var}_ERA5_${per}_t.nc"
  sim_fut_coarse="${idir_era5}/ERA5_${var}_ERA5_${per}_t.nc"

  # Output files:
  sim_fut_basd_coarse="${odir}/ERA5_${var}_ERA5_${per}_t_ba.nc"
  sim_fut_basd_fine="${odir}/ERA5_${var}_ERA5_${per}_t_basd.nc"

  echo "  obs_hist_fine:   $obs_hist_fine"
  echo "  obs_hist_coarse: $obs_hist_coarse"
  echo "  sim_hist_coarse: $sim_hist_coarse"
  echo "  sim_fut_coarse:  $sim_fut_coarse"
  echo "  sim_fut_ba:      $sim_fut_basd_coarse"
  echo "  sim_fut_basd:    $sim_fut_basd_fine"
  echo

  # Set BASD options based on variable
  case $var in
    hurs*)
      options_ba="-v hurs --lower-bound 0 --lower-threshold .01 --upper-bound 100 --upper-threshold 99.99 -t bounded --unconditional-ccs-transfer 1 --trendless-bound-frequency 1"
      options_sd="-v hurs --lower-bound 0 --lower-threshold .01 --upper-bound 100 --upper-threshold 99.99"
      ;;
    pr*)
      options_ba="-v pr --lower-bound 0 --lower-threshold .0000011574 --distribution gamma -t mixed"
      options_sd="-v pr --lower-bound 0 --lower-threshold .0000011574"
      ;;
    rsds*)
      options_ba="-v rsds --lower-bound 0 --lower-threshold .0001 --upper-bound 1 --upper-threshold .9999 -t bounded -w 15"
      options_sd="-v rsds --lower-bound 0 --lower-threshold .01"
      ;;
    sfcWind*)
      options_ba="-v sfcWind --lower-bound 0 --lower-threshold .01 --distribution weibull -t mixed"
      options_sd="-v sfcWind --lower-bound 0 --lower-threshold .01"
      ;;
    tas)
      options_ba="-v tas --distribution normal -t additive -d 1"
      options_sd="-v tas"
      ;;
    tasrange)
      options_ba="-v tasrange --lower-bound 0 --lower-threshold .01 --distribution weibull -t mixed"
      options_sd="-v tasrange --lower-bound 0 --lower-threshold .01"
      ;;
    tasskew)
      options_ba="-v tasskew --lower-bound 0 --lower-threshold .0001 --upper-bound 1 --upper-threshold .9999 -t bounded"
      options_sd="-v tasskew --lower-bound 0 --lower-threshold .0001 --upper-bound 1 --upper-threshold .9999"
      ;;
    *)
      echo "Variable $var not supported ... aborting ..."
      exit 1
      ;;
  esac

  # -------------------------------------------------------------------
  # 1) Bias adjustment on the coarse grid (ERA5-Land resolution)
  # -------------------------------------------------------------------
  echo "Running bias_adjustment.py for $var ..."
  time python -u "${cdir}/bias_adjustment.py" $options_ba \
    --n-processes 16 \
    --randomization-seed 0 \
    --step-size 1 \
    -o "$obs_hist_coarse" \
    -s "$sim_hist_coarse" \
    -f "$sim_fut_coarse" \
    -b "$sim_fut_basd_coarse"

  chmod 664 "$sim_fut_basd_coarse"
  echo

  # -------------------------------------------------------------------
  # 2) Statistical downscaling to the EMO-1/EFAS grid
  # -------------------------------------------------------------------
  echo "Running statistical_downscaling.py for $var ..."
  time python -u "${cdir}/statistical_downscaling.py" $options_sd \
    --n-processes 16 \
    --randomization-seed 0 \
    -o "$obs_hist_fine" \
    -s "$sim_fut_basd_coarse" \
    -f "$sim_fut_basd_fine"

  chmod 664 "$sim_fut_basd_fine"
  echo
done

# Optional: deactivate environment
# deactivate
