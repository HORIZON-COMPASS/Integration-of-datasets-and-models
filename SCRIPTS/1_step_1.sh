#!/usr/bin/env python3
# -------------------------------------------------------------------------
# CLIMB workflow step: 1  (Download ERA5-Land and ERA5 data from CDS)
# Purpose:      Download hourly ERA5-Land and ERA5 single-level fields
#               for a specified set of years and months over the target
#               domain and save them as monthly GRIB files.
# Inputs:       - years: iterable of years to download
#               - months: iterable of months to download
# Outputs:      - {output_dir}/step_1/ERA5Land_YYYY_M.grib
#               - {output_dir}/step_1/ERA5_YYYY_M.grib
# User options: - output_dir, years, months, variable list, area
# Dependencies: - Python 3, cdsapi, valid CDS API key (~/.cdsapirc)
# Usage:        - Adjust `output_dir`, `years`, and `months` below and run:
#                   python 1_step_1.sh
# -------------------------------------------------------------------------

import cdsapi
import os

c = cdsapi.Client()

output_dir = 'YOUR-LOCATION/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Define the period to be downloaded (inclusive ranges)
years = range(1990, 2022)
months = range(1, 12)

# Loop over all requested years and months
for y in years:
    for m in months:
        # Download ERA5-Land (land-only, 0.1° grid) if not already present
        era5land_file = os.path.join(output_dir, 'step_1', 'ERA5Land_' + str(y) + '_' + str(m) + '.grib')
        if os.path.isfile(era5land_file):
            print('Already downloaded:', era5land_file)
        else:
            c.retrieve(
                'reanalysis-era5-land',
                {
                    'variable': [
                        '10m_u_component_of_wind', '10m_v_component_of_wind', '2m_dewpoint_temperature',
                        '2m_temperature', 'surface_solar_radiation_downwards', 'total_precipitation'
                    ],
                    'year': str(y),
                    'month': str(m),
                    'day': [
                        '01', '02', '03', '04', '05', '06', '07', '08', '09',
                        '10', '11', '12', '13', '14', '15', '16', '17', '18',
                        '19', '20', '21', '22', '23', '24', '25', '26', '27',
                        '28', '29', '30', '31',
                    ],
                    'time': [
                        '00:00', '01:00', '02:00', '03:00', '04:00', '05:00',
                        '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
                        '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
                        '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
                    ],
                    'area': [
                        55, 13, 48, 26,  # Poland and catchments of Polish rivers
                    ],
                    'format': 'grib',
                },
                era5land_file)

        # Download ERA5 single-level fields (used later for coastal gap-filling)
        era5_file = os.path.join(output_dir, 'step_1', 'ERA5_' + str(y) + '_' + str(m) + '.grib')
        if os.path.isfile(era5_file):
            print('Already downloaded:', era5_file)
        else:
            c.retrieve(
                'reanalysis-era5-single-levels',
                {
                    'product_type': 'reanalysis',
                    'variable': [
                        '10m_u_component_of_wind', '10m_v_component_of_wind', '2m_dewpoint_temperature',
                        '2m_temperature', 'surface_solar_radiation_downwards', 'total_precipitation'
                    ],
                    'year': str(y),
                    'month': str(m),
                    'day': [    
                        '01', '02', '03', '04', '05', '06', '07', '08', '09',
                        '10', '11', '12', '13', '14', '15', '16', '17', '18',
                        '19', '20', '21', '22', '23', '24', '25', '26', '27',
                        '28', '29', '30', '31',
                    ],  
                    'time': [   
                        '00:00', '01:00', '02:00', '03:00', '04:00', '05:00',
                        '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
                        '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
                        '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
                    ],  
                    'area': [   
                        55, 13, 48, 26,
                    ],  
                    'format': 'grib',
                },
                era5_file)