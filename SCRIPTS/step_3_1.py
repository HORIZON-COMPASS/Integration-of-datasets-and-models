import os
import requests
from bs4 import BeautifulSoup

output_dir='/LOCATION-TO-YOUR-FOLDER/compass_framework'  # Keep location of Python to compass_framework folder

# Function to get the list of files from the given URL
def get_file_list(url):
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Find all links leading to .nc files
    file_links = [link.get('href') for link in soup.find_all('a') if link.get('href').endswith('.nc')]
    return file_links

# Function to download a file and save it locally
def download_file(file_url, save_directory):
    response = requests.get(file_url)
    filename = os.path.join(save_directory, file_url.split('/')[-1])
    
    with open(filename, 'wb') as file:
        file.write(response.content)
    print(f"Downloaded: {file_url}")

# Function to iterate through specific folders and download files
def download_files_from_specific_folders(base_url, save_directory, folders):
    for folder in folders:
        full_folder_url = f"{base_url}/{folder}"
        print(f"Processing folder: {full_folder_url}")
        
        # Create the subdirectory if it does not exist
        folder_save_directory = os.path.join(save_directory, folder)
        if not os.path.exists(folder_save_directory):
            os.makedirs(folder_save_directory)
        
        file_list = get_file_list(full_folder_url)
        
        for file_link in file_list:
            full_file_url = f"{full_folder_url}/{file_link}"
            download_file(full_file_url, folder_save_directory)

# Usage
base_url = 'https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/CEMS-EFAS/meteorological_forcings/EMO-1arcmin'
save_directory = "${output_dir}/step_3/emo_data"
folders = ['pr', 'rg', 'tn', 'tx', 'ws']  # List of folders to iterate through

# Create the main directory to save downloaded files if it doesn't exist
if not os.path.exists(save_directory):
    os.makedirs(save_directory)

download_files_from_specific_folders(base_url, save_directory, folders)
