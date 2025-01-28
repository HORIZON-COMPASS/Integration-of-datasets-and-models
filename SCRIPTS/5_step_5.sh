output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

# number of netCDF chunks (do not change)
n_lats=10
n_lons=10

#Processes each variable seperately to add a second time period for bias_adjustment
#hurs
#filename="${output_dir}/step_4/merge_era5/ERA5_land_daily/hurs_ERA5_1950_1989_t.nc"  #for merged data
filename="${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_2023.nc"  #for selected year
n_times=$(cdo ntime $filename | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,"$n_times" --cnk_dmn=lat,"$n_lats" --cnk_dmn=lon,"$n_lons" -a lon,lat,time "$filename" "${output_dir}/step_5/ERA5_$(basename "$filename" .nc).nc"

echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename" .nc)"

#tas
##### After generate file remember to rename variable name to tas, same as EMO1
##### use this code in terminal: ncrename -v 2t,tas /mnt/g/compass/compass_framework/step_5/tas_YEAR.nc #replace input file with the tas file that you want to rename

filename2="${output_dir}/step_2/ERA5_land_daily/tas_ERA5_2023.nc"
n_times=$(cdo ntime $filename2 | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename2 "${output_dir}/step_5/ERA5_$(basename "$filename2" .nc).nc"
#
echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename2"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename2" .nc)"


##sfcWind
filename3="${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_2023.nc"
n_times=$(cdo ntime $filename3 | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename3 "${output_dir}/step_5/ERA5_$(basename "$filename3" .nc).nc"
#
echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename3"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename3" .nc)"


#rsds
filename4="${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_2023.nc"
n_times=$(cdo ntime $filename4 | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename4 "${output_dir}/step_5/ERA5_$(basename "$filename4" .nc).nc"
#
echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename4"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename4" .nc)"

#pr
filename5="${output_dir}/step_2/ERA5_land_daily/pr_ERA5_2023.nc"
n_times=$(cdo ntime "$filename5" | awk 'NR==1 {print $1}')
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $filename5 "${output_dir}/step_5/ERA5_$(basename "$filename5" .nc).nc"

echo "n_times: $n_times"
echo "n_lats: $n_lats"
echo "n_lons: $n_lons"
echo "Filename: $filename5"
echo "Output file: ${output_dir}/step_5/ERA5_$(basename "$filename5" .nc)"


#
#Convert tas to tasrange and tasskew
tas="${output_dir}/step_2/ERA5_land_daily/tas_ERA5_2023.nc"
tn="${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_2023.nc"
tx="${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_2023.nc"
tasrange="${output_dir}/step_2/ERA5_land_daily/tasrange_ERA5_2023.nc"
tasskew="${output_dir}/step_2/ERA5_land_daily/tasskew_ERA5_2023.nc"
n_times=$(cdo ntime $filename | awk 'NR==1 {print $1}')
##
cdo expr,tasrange="tx - tn" -merge -chname,2t,tn $tn -chname,2t,tx $tx $tasrange
cdo expr,tasskew=" ( tas - tn ) / ( tx - tn ) " -merge -chname,2t,tn $tn -chname,2t,tx $tx -chname,2t,tas $tas $tasskew
##
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $tasrange "${output_dir}/step_5/ERA5_$(basename "$tasrange" .nc).nc"
ncpdq -4 -O --cnk_plc=g3d --cnk_dmn=time,$n_times --cnk_dmn=lat,$n_lats --cnk_dmn=lon,$n_lons -a lon,lat,time $tasskew "${output_dir}/step_5/ERA5_$(basename "$tasskew" .nc).nc"
#