

output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

#fix the range for years
for y in {2023..2023}
do
    year="$y"
    year_n="$((y+1))"
    i1="${output_dir}/step_1/ERA5Land_${year}_1.grib"
    i2="${output_dir}/step_1/ERA5Land_${year}_2.grib"
    i3="${output_dir}/step_1/ERA5Land_${year}_3.grib"
    i4="${output_dir}/step_1/ERA5Land_${year}_4.grib"
    i5="${output_dir}/step_1/ERA5Land_${year}_5.grib"
    i6="${output_dir}/step_1/ERA5Land_${year}_6.grib"
    i7="${output_dir}/step_1/ERA5Land_${year}_7.grib"
    i8="${output_dir}/step_1/ERA5Land_${year}_8.grib"
    i9="${output_dir}/step_1/ERA5Land_${year}_9.grib"
    i10="${output_dir}/step_1/ERA5Land_${year}_10.grib"
    i11="${output_dir}/step_1/ERA5Land_${year}_11.grib"
    i12="${output_dir}/step_1/ERA5Land_${year}_12.grib"
    i13="${output_dir}/step_1/ERA5Land_${year_n}_1.grib"
    o_tas="${output_dir}/step_2/ERA5_land_daily/tas_ERA5_${year}.nc"
    o_tasmin="${output_dir}/step_2/ERA5_land_daily/tasmin_ERA5_${year}.nc"
    o_tasmax="${output_dir}/step_2/ERA5_land_daily/tasmax_ERA5_${year}.nc"
    o_t_dew="${output_dir}/step_2/ERA5_land_daily/dew_ERA5_${year}.nc"
    o_sfcWind="${output_dir}/step_2/ERA5_land_daily/sfcWind_ERA5_${year}.nc"
    o_rsds="${output_dir}/step_2/ERA5_land_daily/rsds_ERA5_${year}.nc"
    o_pr="${output_dir}/step_2/ERA5_land_daily/pr_ERA5_${year}.nc"
    o_rsds_t="${output_dir}/step_2/ERA5_land_daily/rsds_t_ERA5_${year}.nc"
    o_pr_t="${output_dir}/step_2/ERA5_land_daily/pr_t_ERA5_${year}.nc"
    o_hurs="${output_dir}/step_2/ERA5_land_daily/hurs_ERA5_${year}.nc"

    """
    cdo version 2.0.4 requires variable names as their actual names not coded names such as var167 for example.
    Use code cdo vardes {path_to_file.grib} to check description of the variables and their actual name: 
    For example : 
    165  10u           10 metre U wind component [m s**-1]
    166  10v           10 metre V wind component [m s**-1]
    168  2d            2 metre dewpoint temperature [K]
    167  2t            2 metre temperature [K]
    169  ssrd          Surface solar radiation downwards [J m**-2]
    228  tp            Total precipitation [m]

    For later versions of cdo, it may require to write var167 (instead of 2t for example) or other coded names instead of actual variable names.
    
   """

    cdo -f nc -daymean -selname,2t -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $o_tas
    cdo -f nc -daymin -selname,2t -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $o_tasmin
    cdo -f nc -daymax -selname,2t -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $o_tasmax
    cdo -f nc expr,rsds="ssrd/86400" -selhour,0 -selname,ssrd -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $i13 $o_rsds_t
    cdo -f nc expr,pr="tp/86.4" -selhour,0 -selname,tp -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $i13 $o_pr_t
    cdo selyear,$y -shifttime,-1days $o_rsds_t $o_rsds
    cdo selyear,$y -shifttime,-1days $o_pr_t $o_pr
    cdo -f nc -daymean -selname,2d,2t -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $o_t_dew
    cdo expr,hurs="(10 ^ (7.5 * (2d-273.15) / (237.3+(2d-273.15)))) / (10 ^ (7.5 * (2t-273.15) / (237.3+(2t-273.15)))) * 100" $o_t_dew $o_hurs
    cdo -f nc expr,sfcWind="sqrt(10u*10u+10v*10v)" -daymean -selname,10u,10v -mergetime $i1 $i2 $i3 $i4 $i5 $i6 $i7 $i8 $i9 $i10 $i11 $i12 $o_sfcWind
    rm $o_rsds_t
    rm $o_pr_t
    rm $o_t_dew

done
