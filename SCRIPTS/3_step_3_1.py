#!/usr/bin/env python3
# -------------------------------------------------------------------------
# CLIMB workflow step: 3.1  (Download EMO-1 forcing data)
# Purpose:      Download EMO-1 meteorological forcing NetCDF files from the
#               JRC open data repository for a selected list of variables
#               (e.g. pr, rg, tn, tx, ws) and save them in a structured
#               local directory for further preprocessing in later steps.
# Inputs:       - Base URL of the EMO-1 archive
#               - List of variable subfolders to be downloaded (folders)
# Outputs:      - NetCDF files stored under:
#                   {output_dir}/step_3/emo_data/{variable}/
# User options: - output_dir, list of folders (variables) to download
# Dependencies: - Python 3, requests, beautifulsoup4
# Usage:        - Set `output_dir` and adjust `folders` if needed, then run:
#                   python 3_step_3_1.py
# -------------------------------------------------------------------------

import os
import requests
from bs4 import BeautifulSoup

output_dir = '/LOCATION-TO-YOUR-FOLDER/CLIMB'  # <-- CHANGE THIS to your desired output directory

# Retrieve the list of NetCDF files available in a given EMO-1 subdirectory
def get_file_list(url):
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Find all links leading to .nc files
    file_links = [link.get('href') for link in soup.find_all('a') if link.get('href').endswith('.nc')]
    return file_links

# Download a single NetCDF file from EMO-1 and save it locally
def download_file(file_url, save_directory):
    response = requests.get(file_url)
    filename = os.path.join(save_directory, file_url.split('/')[-1])
    
    with open(filename, 'wb') as file:
        file.write(response.content)
    print(f"Downloaded: {file_url}")

# Iterate over the requested EMO-1 variable folders and download all files
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
save_directory = os.path.join(output_dir, "step_3", "emo_data")
# EMO-1 variable folders to download (can be adapted by the user)
folders = ['pr', 'rg', 'tn', 'tx', 'ws']  # List of folders to iterate through

# Create the main EMO-1 download directory if it does not exist
if not os.path.exists(save_directory):
    os.makedirs(save_directory)

download_files_from_specific_folders(base_url, save_directory, folders)
