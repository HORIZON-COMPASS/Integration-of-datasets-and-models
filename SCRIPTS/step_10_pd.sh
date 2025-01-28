#!/bin/bash

ipath="${output_dir}/step_9/"
epath="${output_dir}/step_2/ERA5_for_gapfill/"
opath="${output_dir}/step_10/"

## compute BASD landmask, grid and weights for regridding ERA% (only needed once, the same files are used for other variables)
basd_file="${ipath}pd_1951.nc" # from step 9
basd_mask="${opath}basd_landmask_pl2.nc"
grid_file="${opath}basd_grid.txt"
cdo griddes $basd_file > $grid_file
weight_file="${opath}ERA5_weights.nc"
era5_file="${epath}hurs_ERA5_1951.nc" # from step 2
cdo gennn,$grid_file $era5_file $weight_file

# dimension (adapt n_lats and n_longs to file dimensions divided by 3)
n_times=1
n_lats=142
n_lons=262

## loop to repeat per variable
for y in {1950..1989}
do
	filename="${ipath}pd_${y}.nc" # from step 9
	tile="$(echo $(basename "$filename" .nc) | cut -d'_' -f2)"
	era5_file="${epath}hurs_ERA5_${tile}.nc" # from step 2
	era5_file_regrid="${epath}regrid_hurs_ERA5_${tile}.nc"
	oname1="${opath}tb_$(basename "$filename" .nc).nc"
	oname2="${opath}tc_$(basename "$filename" .nc).nc"
	oname3="${opath}td_$(basename "$filename" .nc).nc"
	oname4="${opath}te_$(basename "$filename" .nc).nc"
	oname5="${opath}$(basename "$filename" .nc).nc"

  	era5_file_tas="${epath}tas_ERA5_${tile}.nc"
	era5_file_pd="${epath}pd_ERA5_${tile}.nc"

	"""
	Added expr,pd="hurs / 100 * (6.11 * 10 ^ (7.5 * (dpt - 273.15) / (237.3 + (dpt - 273.15) ) ))" 
	to calculate the actual vapor pressure which is used in EMO-1 data.

	"""
	cdo -f nc4c -z zip expr,pd="hurs / 100 * (6.11 * 10 ^ (7.5 * (dpt - 273.15) / (237.3 + (dpt - 273.15) ) ))" -merge $era5_file $era5_file_tas $era5_file_pd

	cdo -f nc4c -z zip remap,$grid_file,$weight_file -shifttime,1days $era5_file_pd $era5_file_regrid

	cdo -f nc4c -z zip ifthenelse $basd_mask $filename $era5_file_regrid $oname1
	cdo -f nc4c -z zip shifttime,-690minutes $oname1 $oname2

	ncatted -O -a _FillValue,pd,o,s,-9999 $oname2
	ncatted -O -a missing_value,pd,o,s,-9999 $oname2

	ncap2 -v -O -s 'pd=pack(pd,0.1,0);' $oname2 $oname3
	ncpdq -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a time,lat,lon $oname3 $oname4
	ncap2 -O -s 'time=(time-24)/24;' $oname4 $oname5
	ncatted -a units,time,o,c,"days since 1950-01-02 00:00:00" $oname5
	#ncatted -a units,time,o,c,"days since 1990-01-01 00:00:00" $oname5
	
  # remove temporary files
rm t*_pd*.nc
done


### VERIFY THAT ALL TIMESTEPS ARE THE SAME AS IN ORIGINAL EMO-1 FILES (1990 AND NEXT),
### AND THAT 1950 TO 1989 FILES ARE CONSISTENT WITH NEWER ONES WITH TIMESTEPS