import geopandas as gpd
import xarray as xr
import rioxarray
import numpy as np
from rasterio.features import geometry_mask
import pandas as pd
import os


input_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

# Load the shapefile
shapefile_path = '${input_dir}/step_10/shp/voivodeships.shp'
poland_shapefile = gpd.read_file(shapefile_path)


# List of variables and years you want to process
variables = ['tx', 'tn', 'pd', 'ws', 'rg', 'pr']  # 'tx', 'tn', 'pd', 'ws', 'rg', 'pr'
years = range(1950, 2024)  # range

# Directory where your NetCDF files are located
netcdf_dir = '${input_dir}/step_10/'

# Directory where you want to save the output CSV files
output_dir = '${input_dir}/step_10/mean-y/'

# Make sure the output directory exists
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# List to store results for CSV output
results = []

# Loop through each variable
for variable in variables:

    # Loop through each year and load the NetCDF file
    for year in years:
        netcdf_file = f'{netcdf_dir}{variable}_{year}.nc'
        
        # Check if file exist
        if not os.path.exists(netcdf_file):
            print(f"File {netcdf_file} not found, skipping this year.")
            continue
        
        # Open the dataset
        data = xr.open_dataset(netcdf_file)
        
        # Access the specific variable (e.g., 'tx' for maximum daily temperature)
        var_data = data[variable]
        
        # Make sure the data has proper geospatial coordinates
        var_data = var_data.rio.write_crs("EPSG:4326")

        # Loop through each voivodeship
        for idx, voivodeship in poland_shapefile.iterrows():
            # Get the geometry (boundary) of the voivodeship
            geometry = [voivodeship['geometry']]
            
            # Create a mask for the voivodeship geometry (lat/lon grid is 2D)
            mask = geometry_mask([geom for geom in geometry], 
                                 transform=var_data.rio.transform(), 
                                 invert=True, 
                                 out_shape=var_data.shape[-2:])
            
            # Apply the mask to the entire time series data
            masked_data = var_data.where(mask)

            # Calculate the mean value at each grid cell across all timestamps
            if variable == 'pr':
                # For 'pr' 
                mean_per_grid_cell = masked_data.mean(dim='time') * 365
            else:
                # For all variables except pr
                mean_per_grid_cell = masked_data.mean(dim='time')

            # Calculate the mean of these values for the entire region within the voivodeship
            mean_max_value = mean_per_grid_cell.mean().item()

            # Add the result to the list
            results.append({
                'variable': variable, 
                'voivodeship': voivodeship['nazwa'],  
                'mean': mean_max_value,  
                'year': year  
            })

# Create a DataFrame from the results
df_results = pd.json_normalize(results)
df_results['mean'] = df_results['mean'].round(4)
df_results = df_results.dropna(subset=['year'])
df_results['year'] = df_results['year'].astype(int).astype(str)

print(df_results.head())
print(df_results.columns)

# Save to CSV, one file per variable
for variable in variables:
    df_var = df_results[df_results['variable'] == variable]
    csv_filename = f'{output_dir}{variable}-mean-y.csv'
    df_var.to_csv(csv_filename, index=False)

print("CSV is ready.")
