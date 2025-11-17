# (C) 2022 Potsdam Institute for Climate Impact Research (PIK)
# 
# This file is part of ISIMIP3BASD.
#
# ISIMIP3BASD is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the
# Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ISIMIP3BASD is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with ISIMIP3BASD. If not, see <http://www.gnu.org/licenses/>.



# do bias adjustment for all variables in one program call
python -u bias_adjustment.py \
--n-processes 5 \
--randomization-seed 0 \
--step-size 1 \
-v hurs,pr,prsnratio,ps,rlds,rsds,sfcWind,tas,tasrange,tasskew \
--lower-bound 0,0,0,,,0,0,,0,0 \
--lower-threshold .01,.0000011574,.0001,,,.0001,.01,,.01,.0001 \
--upper-bound 100,,1,,,1,,,,1 \
--upper-threshold 99.99,,.9999,,,.9999,,,,.9999 \
--distribution ,gamma,,normal,normal,,weibull,normal,weibull, \
-t bounded,mixed,bounded,additive,additive,bounded,mixed,additive,mixed,bounded \
--unconditional-ccs-transfer 1,,,,,,,,, \
--trendless-bound-frequency 1,,,,,,,,, \
-d ,,,1,1,,,1,, \
-w 0,0,0,0,0,15,0,0,0,0 \
--if-all-invalid-use ,,0.,,,,,,, \
-o ../data/hurs_obs-hist_coarse_1979-2014.nc,../data/pr_obs-hist_coarse_1979-2014.nc,../data/prsnratio_obs-hist_coarse_1979-2014.nc,../data/ps_obs-hist_coarse_1979-2014.nc,../data/rlds_obs-hist_coarse_1979-2014.nc,../data/rsds_obs-hist_coarse_1979-2014.nc,../data/sfcWind_obs-hist_coarse_1979-2014.nc,../data/tas_obs-hist_coarse_1979-2014.nc,../data/tasrange_obs-hist_coarse_1979-2014.nc,../data/tasskew_obs-hist_coarse_1979-2014.nc \
-s ../data/hurs_sim-hist_coarse_1979-2014.nc,../data/pr_sim-hist_coarse_1979-2014.nc,../data/prsnratio_sim-hist_coarse_1979-2014.nc,../data/ps_sim-hist_coarse_1979-2014.nc,../data/rlds_sim-hist_coarse_1979-2014.nc,../data/rsds_sim-hist_coarse_1979-2014.nc,../data/sfcWind_sim-hist_coarse_1979-2014.nc,../data/tas_sim-hist_coarse_1979-2014.nc,../data/tasrange_sim-hist_coarse_1979-2014.nc,../data/tasskew_sim-hist_coarse_1979-2014.nc \
-f ../data/hurs_sim-fut_coarse_2065-2100.nc,../data/pr_sim-fut_coarse_2065-2100.nc,../data/prsnratio_sim-fut_coarse_2065-2100.nc,../data/ps_sim-fut_coarse_2065-2100.nc,../data/rlds_sim-fut_coarse_2065-2100.nc,../data/rsds_sim-fut_coarse_2065-2100.nc,../data/sfcWind_sim-fut_coarse_2065-2100.nc,../data/tas_sim-fut_coarse_2065-2100.nc,../data/tasrange_sim-fut_coarse_2065-2100.nc,../data/tasskew_sim-fut_coarse_2065-2100.nc \
-b ../data/hurs_sim-fut-basd_coarse_2065-2100.nc,../data/pr_sim-fut-basd_coarse_2065-2100.nc,../data/prsnratio_sim-fut-basd_coarse_2065-2100.nc,../data/ps_sim-fut-basd_coarse_2065-2100.nc,../data/rlds_sim-fut-basd_coarse_2065-2100.nc,../data/rsds_sim-fut-basd_coarse_2065-2100.nc,../data/sfcWind_sim-fut-basd_coarse_2065-2100.nc,../data/tas_sim-fut-basd_coarse_2065-2100.nc,../data/tasrange_sim-fut-basd_coarse_2065-2100.nc,../data/tasskew_sim-fut-basd_coarse_2065-2100.nc



# do statistical downscaling for hurs
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v hurs \
--lower-bound 0 \
--lower-threshold .01 \
--upper-bound 100 \
--upper-threshold 99.99 \
-o ../data/hurs_obs-hist_fine_1979-2014.nc \
-s ../data/hurs_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/hurs_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for pr
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v pr \
--lower-bound 0 \
--lower-threshold .0000011574 \
-o ../data/pr_obs-hist_fine_1979-2014.nc \
-s ../data/pr_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/pr_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for prsnratio
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v prsnratio \
--lower-bound 0 \
--lower-threshold .0001 \
--upper-bound 1 \
--upper-threshold .9999 \
--if-all-invalid-use 0. \
-o ../data/prsnratio_obs-hist_fine_1979-2014.nc \
-s ../data/prsnratio_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/prsnratio_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for ps
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v ps \
-o ../data/ps_obs-hist_fine_1979-2014.nc \
-s ../data/ps_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/ps_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for rlds
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v rlds \
-o ../data/rlds_obs-hist_fine_1979-2014.nc \
-s ../data/rlds_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/rlds_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for rsds
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v rsds \
--lower-bound 0 \
--lower-threshold .01 \
-o ../data/rsds_obs-hist_fine_1979-2014.nc \
-s ../data/rsds_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/rsds_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for sfcWind
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v sfcWind \
--lower-bound 0 \
--lower-threshold .01 \
-o ../data/sfcWind_obs-hist_fine_1979-2014.nc \
-s ../data/sfcWind_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/sfcWind_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for tas
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v tas \
-o ../data/tas_obs-hist_fine_1979-2014.nc \
-s ../data/tas_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/tas_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for tasrange
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v tasrange \
--lower-bound 0 \
--lower-threshold .01 \
-o ../data/tasrange_obs-hist_fine_1979-2014.nc \
-s ../data/tasrange_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/tasrange_sim-fut-basd_fine_2065-2100.nc

# do statistical downscaling for tasskew
python -u statistical_downscaling.py \
--n-processes 5 \
--randomization-seed 0 \
-v tasskew \
--lower-bound 0 \
--lower-threshold .0001 \
--upper-bound 1 \
--upper-threshold .9999 \
-o ../data/tasskew_obs-hist_fine_1979-2014.nc \
-s ../data/tasskew_sim-fut-basd_coarse_2065-2100.nc \
-f ../data/tasskew_sim-fut-basd_fine_2065-2100.nc
