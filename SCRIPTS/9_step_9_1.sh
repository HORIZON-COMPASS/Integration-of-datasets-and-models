#!/bin/bash
output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder
opath="${output_dir}/step_9/"

## step 9.1
## Convert BASD back to EMO-1 format; adapt the script to cover also the 1950-1989 period

# Wind
filename="${output_dir}/step_8/ERA5_sfcWind_ERA5_1950_1989_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1

for y in {1950..1989}
do
  oname2="${opath}ws_${y}.nc"
  cdo -L -f nc4c -z zip expr,ws="sfcWind" -shifttime,1days -selyear,$y $oname1 $oname2
done
rm $oname1 || { echo "Failed to remove $oname1"; exit 1; }

# Temperature
tas="${output_dir}/step_8/ERA5_tas_ERA5_1950_1989_t_basd.nc"
tasrange="${output_dir}/step_8/ERA5_tasrange_ERA5_1950_1989_t_basd.nc"
tas_a="${opath}t_$(basename "$tas" .nc).nc"
tasrange_a="${opath}t_$(basename "$tasrange" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $tas $tas_a
ncpdq -O --cnk_plc=uck -a time,lat,lon $tasrange $tasrange_a
for y in {1950..1989}
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

# Radiation
filename="${output_dir}/step_8/ERA5_rsds_ERA5_1950_1989_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1
for y in {1950..1989}
do
  oname2="${opath}rg_${y}.nc"
  cdo -L -f nc4c -z zip expr,rg="rsds * 86400" -shifttime,1days -selyear,$y $oname1 $oname2
done
rm $oname1

# Vapour pressure / humidity
filename="${output_dir}/step_8/ERA5_hurs_ERA5_1950_1989_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1

for y in {1950..1989}
do
  oname2="${opath}ta_$(basename "$filename" .nc)_${y}.nc"
  cdo -L -f nc4c -z zip -selyear,$y $oname1 $oname2
  oname3="${opath}pd_${y}.nc"
  cdo -L -f nc4c -z zip expr,pd="hurs / 100 * (6.11 * 10 ^ (7.5 * (tas - 273.15) / (237.3 + (tas - 273.15))))" -merge -shifttime,1days -selyear,$y $oname2 -shifttime,630minutes $tas_b $oname3
done
rm $oname1

# Precipitation
filename="${output_dir}/step_8/ERA5_pr_ERA5_1950_1989_t_basd.nc"
oname1="${opath}t_$(basename "$filename" .nc).nc"
ncpdq -O --cnk_plc=uck -a time,lat,lon $filename $oname1
for y in {1950..1989}
do
  oname2="${opath}pr_${y}.nc"
  cdo -L -f nc4c -z zip mulc,86400 -shifttime,24hours -selyear,$y $oname1 $oname2
done
rm $oname1

