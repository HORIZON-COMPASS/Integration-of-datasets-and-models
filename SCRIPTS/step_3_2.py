import os
import numpy as np
from netCDF4 import Dataset

"""
The script cuts the dimensions to specific latitude and longitude
of the original EMO1 file downloaded from https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/
It will loop over the folder and save each file with in a different folder to prevent any permission error
associated with .nc files

"""
output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

input_dir = "${output_dir}/step_3/emo_data"
output_subdir = "${output_dir}/step_3/emo_data/cutted_emo"

lon_min, lon_max = 12.950000, 26.050000  #For Poland
lat_min, lat_max = 47.950000, 55.050000  #For Poland

chunk_size = 100

def process_variable_in_chunks(src_var, dst_var, lon_indices, lat_indices):
    full_shape = src_var.shape
    dim_names = src_var.dimensions
    lat_dim = dim_names.index('lat') if 'lat' in dim_names else None
    lon_dim = dim_names.index('lon') if 'lon' in dim_names else None
    src_slices = [slice(None)] * len(full_shape)
    dst_slices = [slice(None)] * len(full_shape)
    
    if lat_dim is not None:
        src_slices[lat_dim] = lat_indices
        dst_slices[lat_dim] = slice(None)
    if lon_dim is not None:
        src_slices[lon_dim] = lon_indices
        dst_slices[lon_dim] = slice(None)
    if lat_dim is None and lon_dim is None:
        dst_var[:] = src_var[:]
        return

    chunk_dims = [i for i, dim in enumerate(dim_names) if dim not in ['lat', 'lon']]
    chunk_dim = chunk_dims[0] if chunk_dims else 0
    
    for start in range(0, full_shape[chunk_dim], chunk_size):
        end = min(start + chunk_size, full_shape[chunk_dim])
        src_chunk_slices = list(src_slices)
        dst_chunk_slices = list(dst_slices)
        src_chunk_slices[chunk_dim] = slice(start, end)
        dst_chunk_slices[chunk_dim] = slice(start, end)
        
        chunk_data = src_var[tuple(src_chunk_slices)]
        dst_var[tuple(dst_chunk_slices)] = chunk_data

def cut_file_for_poland(input_file_path, output_file_dir):
    try:
        with Dataset(input_file_path, 'r') as src:
            lon = src.variables['lon'][:]
            lat = src.variables['lat'][:]
            lon_indices = np.where((lon >= lon_min) & (lon <= lon_max))[0]
            lat_indices = np.where((lat >= lat_min) & (lat <= lat_max))[0]
            
            output_file_name = os.path.basename(input_file_path).replace('.nc', '_poland.nc')
            output_file_path = os.path.join(output_file_dir, output_file_name)
            
            with Dataset(output_file_path, 'w') as dst:
                dst.setncatts({a: src.getncattr(a) for a in src.ncattrs()})
                for name, dimension in src.dimensions.items():
                    if name == 'lon':
                        dst.createDimension(name, len(lon_indices))
                    elif name == 'lat':
                        dst.createDimension(name, len(lat_indices))
                    else:
                        dst.createDimension(name, (len(dimension) if not dimension.isunlimited() else None))
                
                for name, variable in src.variables.items():
                    if name in ['lon', 'lat']:
                        x = dst.createVariable(name, variable.datatype, (name,))
                    else:
                        x = dst.createVariable(name, variable.datatype, variable.dimensions)
                    
                    dst[name].setncatts({a: variable.getncattr(a) for a in variable.ncattrs()})
                    
                    if name == 'lon':
                        dst[name][:] = lon[lon_indices]
                    elif name == 'lat':
                        dst[name][:] = lat[lat_indices]
                    else:
                        process_variable_in_chunks(src[name], dst[name], lon_indices, lat_indices)

        print(f"Successfully created cut file: {output_file_path}")
    except Exception as e:
        print(f"Failed to process file {input_file_path}. Error: {e}")
        raise

def process_folder(folder_path):
    try:
        output_subfolder = os.path.join(output_subdir, f"Cutted_{os.path.basename(folder_path)}")
        if not os.path.exists(output_subfolder):
            os.makedirs(output_subfolder)
        
        for file_name in os.listdir(folder_path):
            if file_name.endswith(".nc"):
                file_path = os.path.join(folder_path, file_name)
                
                print(f"Processing file: {file_path}")
                cut_file_for_poland(file_path, output_subfolder)
    except Exception as e:
        print(f"Error processing folder {folder_path}. Error: {e}")

def main():
    try:
        if not os.path.exists(output_subdir):
            os.makedirs(output_subdir)
        
        subfolders = ['pd', 'pr', 'ws', 'rg', 'tn', 'tx']
        
        for subfolder in subfolders:
            folder_path = os.path.join(input_dir, subfolder)
            if os.path.isdir(folder_path):
                print(f"Processing folder: {folder_path}")
                process_folder(folder_path)
            else:
                print(f"Folder not found: {folder_path}")

    except Exception as e:
        print(f"Critical error in main processing loop. Error: {e}")

if __name__ == "__main__":
    main()