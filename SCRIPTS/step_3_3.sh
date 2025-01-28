#bash
output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder


for y in {1990..2022}
do
	year="$y"

	tx="${output_dir}/step_3/emo_data/cutted_emo/tx/EMO-1arcmin-tx_${year}.nc"
	tn="${output_dir}/step_3/emo_data/cutted_emo/tn/EMO-1arcmin-tn_${year}.nc"
	tasmax="${output_dir}/step_3/emo_data/EFAS_converted/tasmax_${year}.nc"
	tasmin="${output_dir}/step_3/emo_data/EFAS_converted/tasmin_${year}.nc"
    tas="${output_dir}/step_3/emo_data/EFAS_converted/tas_${year}.nc"

	cdo -f nc4c -z zip expr,tasmax="tx + 273.15" $tx $tasmax
	cdo -f nc4c -z zip expr,tasmin="tn + 273.15" $tn $tasmin
	cdo -f nc4c -z zip expr,tas="(tx + tn) / 2 + 273.15" -merge $tx $tn $tas

	hurs0="${output_dir}/step_3/emo_data/EFAS_converted/hurs_raw_${year}.nc"
	hurs="${output_dir}/step_3/emo_data/EFAS_converted/hurs_${year}.nc"
	pd="${output_dir}/step_3/emo_data/cutted_emo/pd/pd_${year}.nc"

	cdo -f nc4c -z zip -expr,hurs="pd / (6.11 * 10 ^ (7.5 * ((tn+tx)/2) / (237.3+((tn+tx)/2) ) )) * 100" -merge $tn $tx -shifttime,-1days $pd $hurs0
	cdo -f nc4c -z zip -expr,hurs="(hurs > 100 ) ? 100 : hurs" $hurs0 $hurs

	ws="${output_dir}/step_3/emo_data/cutted_emo/ws/ws_${year}.nc"
	sfcWind="${output_dir}/step_3/emo_data/EFAS_converted/sfcWind_${year}.nc"

	cdo -f nc4c -z zip expr,sfcWind="ws" -shifttime,-1days $ws $sfcWind

	pr="${output_dir}/step_3/emo_data/cutted_emo/pr/pr_${year}.nc"
	pr_c="${output_dir}/step_3/emo_data/EFAS_converted/pr_${year}.nc"

	cdo -f nc4c -z zip expr,pr="pr/86400" -shifttime,-1days $pr $pr_c

	rg="${output_dir}/step_3/emo_data/cutted_emo/rg/rg_${year}.nc"
	rsds="${output_dir}/step_3/emo_data/EFAS_converted/rsds_${year}.nc"

	cdo -f nc4c -z zip expr,rsds="rg/86400" -shifttime,-1days $rg $rsds

done