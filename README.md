# Integration of datasets and models
This work is part of work package 5 of the COMPASS project, whose overarching objective is to characterise compound extremes in current and future climates. COMPASS (COMPound extremes Attribution of climate change: towardS an operational Service) aims to develop a harmonized, yet flexible, methodological framework for **climate and impact attribution** of various complex **extremes** that include compound, sequential and cascading hazard events. For more information and useful links about the project, have a look at the introduction on the [COMPASS Github repository](https://github.com/HORIZON-COMPASS).

<img src="https://private-user-images.githubusercontent.com/28653313/407655928-4c3b95d4-bfc0-4727-a1e8-ee6653a03b5e.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzgzNDI0NTIsIm5iZiI6MTczODM0MjE1MiwicGF0aCI6Ii8yODY1MzMxMy80MDc2NTU5MjgtNGMzYjk1ZDQtYmZjMC00NzI3LWExZTgtZWU2NjUzYTAzYjVlLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTAxMzElMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwMTMxVDE2NDkxMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWNlNWM5ZmM3YzM0OTA3ZTI5MGQ1ZmU3OTJiNDFmYmFjMTgwYTNlNzI3MDQwYWNkOTgwYjY5YmE2NDdlZGUwNjImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.eu2ePZN6oBV2w4_yl2Zivc0SEkGqEF4WadXcVj7BLYk" alt="logoCOMPASS" style="max-width: 100%;">

## Description
This task involved several important steps, including the development of an interface to facilitate the identification and searching of Copernicus datasets (including climate change services, disaster management services and land monitoring services) together with other EU-supported datasets (e.g. ERA5, EMO-1 meteorological observations, Eurostat), providing a search service for these resources in a machine-readable form. This interface is designed to facilitate efficient data retrieval and enable interoperability with different analytical platforms. It will serve as a streamlined access point for researchers, policy makers and other stakeholders to engage with these important datasets. Integration of existing and newly developed climate, exposure and vulnerability toolkits such as Bias-adjustment and Statistical Downscaling (BASD), Historical Analysis of Nature Hazards in Europe (HANZE) and ATTRIbuting Climate Impacts (ATTRICI - in progress) was also performed.

The workflow involves many steps, including:<br/>
**Obtaining and loading data**<br/>
The main objective of the task was to download ERA-5 data from Copernicus Marine API from 1950-2023 in GRIB format. To access the API, the python package “cdsapi” was installed to obtain the API key to download the data using Python. The data was downloaded and assembled in a respective folder.

**ERA5 and ERA5-Land data processing**<br/>
A Python script was utilized to automate the necessary processing of downloaded ERA5-Land climate data for each year from 1950 to 2023. It converts monthly GRIB files into daily NetCDF files and calculates daily aggregates of various climate variables (temperature, precipitation, solar radiation, wind speed). It also calculates relative humidity (hurs) from the temperature and precipitation.

**EMO-1 data processing**<br/>
The processing of EMO-1 data is different than ERA5 as the data includes daily totals for precipitation, minimum and maximum temperatures, wind speed, solar radiation, and water vapor pressure. Therefore, processing involved following changes using Python script:
1.	Temperature Conversion:
Converts maximum (tx) and minimum (tn) temperatures from Celsius to Kelvin by adding 273.15.
Calculates mean temperature (tas) as the average of tx and tn, then converts to Kelvin.
2. Relative Humidity Calculation:
Computes relative humidity (hurs) using temperature and partial pressure data.
The calculation uses the Magnus formula for saturation vapor pressure.
Limits the relative humidity to a maximum of 100%.
3. Wind Speed Conversion:
Converts wind speed (ws) to surface wind (sfcWind) without changing values.
4. Precipitation Rate Conversion:
Converts precipitation (pr) from mm/day to mm/second by dividing by 86400 (seconds in a day).
5. Solar Radiation Conversion:
Converts global radiation (rg) to downward short-wave radiation flux (`rsds`) by dividing by 86400.
6. Time Adjustment:
Applies a one-day backward time shift to certain variables (hurs, sfcWind, pr, rsds).

**Data merging**<br/>
Subsequently, the pre-processed ERA5-Land and EMO-1 data were merged into two separate files as the merging of these files allows for easier handling of long-term climate data series, which is crucial for ease in running simulations in later stages of the process.

**Processing of merged ERA5-Land for BASD**<br/>
Subsequently, the pre-processed ERA5-Land and EMO-1 data were merged into two separate files as the merging of these files allows for easier handling of long-term climate data series, which is crucial for ease in running simulations in later stages of the process. The script will also introduce two new variables:
The temperature data (tas, tasmin, and tasmax) will be converted into two additional metrics:
1.	Temperature Range (tasrange): Defined as the difference between maximum and minimum temperatures (tx - tn).
2.	Temperature Skewness (tasskew): Calculated as (tas - tn) / (tx - tn), indicating the relative position of daily temperature within the daily range.

**Processing of merged EMO-1 data**<br/>
The merged EMO-1 data was scaled to the same resolution as ERA5-Land to ensure consistency in the BASD procedure. The procedure involved generating a grid file with ERA5-Land and remapping the generated weight file from the EMO-1 file based on the grid file. Finally, an aggregated file was generated which is remapped based on the grid file from ERA5-Land ensuring a similar resolution.

**Processing of merged EMO-1 data for BASD**<br/>
A similar procedure with the identical script as described above was performed on EMO-1 data to ensure the consistency of format between two datasets for use in BASD script.

**BASD with ISIMIPBASDv3.0.2**<br/>
The adapted script from Stefan Lange ISIMIPBASDv3.0.2 was adapted for BASD of ERA5-Land data based on finer resolution EMO-1 data that was processed and combined with the coarser resolution EMO-1 data which was converted to the same resolution as ERA5-Land. By doing so, the ERA5-Land was downscaled to the same resolution as that of EMO-1.

**Convert BASD ERA5-Land to EMO-1 format**<br/>
The script in this task performs several procedures to convert climate data processed using the BASD back into a specific format for the EMO-1 model. It utilizes a set of formulas to convert each specific variable to the variables that are available in EMO-1 such as (sfcWind) to (ws). The script covers the duration from 1950-2023.

**Final post-processing of ERA5-Land data**<br/>
The final processing is necessary to handle time shift adjustments and the handling of correct units for each variable for consistency between the datasets. The Python script starts by computing a land mask for the BASD dataset, then extracts grid information and calculates re-gridding weights for the ERA5 data. For each year, the script processed the variable files by setting up file names for input and output. It handled the re-gridding of ERA5 files to match the BASD grid, adjusting for time shifts where necessary. It converted relative humidity (hurs) into partial pressure (pd) for certain variables and ensured consistency in units and time shifts across files.
The script also corrected the time vector, processed and compressed data using cdo commands for specific meteorological variables, and applied transformations such as packing values into smaller byte formats and adjusting chunking for NetCDF outputs. The time units are adapted depending on the period (1950-1989 or 1990-2022), and temporary files are removed at the end of each iteration. The complete flowchart for the tasks is shown in Figure 1 (a)).

**Modification in tasks to adapt to daily data**<br/>
After completion of the procedure, the tasks were modified to adapt to the daily data which requires changes to some of the tasks and removal of unnecessary tasks. The major changes were the removal of step 3 and step 4 as the daily data doesn’t need merging (Figure 1 (b)).

**Daily, monthly and yearly mean values**<br/>
Dedicated Python scripts were prepared to calculate mean values for each of the variables on a daily, monthly and yearly basis. The scripts will be able to visualize the data and provide information regarding the trends observed.

**LISVAP model**<br/>
The LISFLOOD model is a hydrological rainfall-runoff and channel routing model developed by the Floods Group within the Natural Hazards Project at the Joint Research Centre (JRC) of the European Commission. This model will be utilized for simulating hydrological processes. Its primary applications include flood forecasting, evaluating river regulation measures, assessing the impacts of land-use changes, and analyzing the effects of climate change. The LISVAP model in this WP will be used for the calculation of Potential reference evapotranspiration (ET0).
<br/><br/>
<img src="https://naturalhazards.eu/workflow.jpg" alt="wp5 workflow" style="max-width:60%;">


The code is under development and this file will be updated to reflect the current updates on the project.

## Installation instructions
Detailed information can be found in the [step-by-step-guide.ipynb](https://github.com/HORIZON-COMPASS/Integration-of-datasets-and-models/blob/main/step-by-step-guide.ipynb) file, which includes a description of each step and error handling procedures.   

## How to contribute
We welcome contributions to improve this project! Here are some ways you can help: <br/>
<b>Report Bugs</b>: If you find a bug, please open an issue with detailed information about the problem and how to reproduce it. <br/>
<b>Submit Pull Requests</b>: If you want to fix a bug or implement a feature, follow these steps:
<ol>
<li>Fork the repository.</li>
<li>Create a new branch (git checkout -b feature/YourFeatureName).</li>
<li>Make your changes.</li>
<li>Commit your changes (git commit -m 'Add some feature').</li>
<li>Push to the branch (git push origin feature/YourFeatureName).</li>
<li>Open a pull request. Suggest Features: Have an idea for a new feature? Open an issue to discuss it.</li>
</ol>

## Acknowledgements
<img src="https://private-user-images.githubusercontent.com/28653313/399447260-e2fad699-697e-43fd-84be-032447d6dd21.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzgzNDI0NTIsIm5iZiI6MTczODM0MjE1MiwicGF0aCI6Ii8yODY1MzMxMy8zOTk0NDcyNjAtZTJmYWQ2OTktNjk3ZS00M2ZkLTg0YmUtMDMyNDQ3ZDZkZDIxLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTAxMzElMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwMTMxVDE2NDkxMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWE5MGUwZmFhYzQxZWRhOTVjMjlmMzJlYTcxYTcwYmFiZTE4MDQ1NzhhZmZmZTY5ODVmYzVjNjY2ZWE4MzYyYTUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.Lurzd3JgZ24QO8Xm37zC1Nv20w0nWfMNZ4ESZklNGUQ" alt="EU_logo" style="max-width: 100%;">
The COMPASS project has received funding from the European Union’s HORIZON Research and Innovation Actions Programme under Grant Agreement No. 101135481

Funded by the European Union. Views and opinions expressed are however those of the author(s) only and do not necessarily reflect those of the European Union or of the European Health and Digital Executive Agency (HADEA). Neither the European Union nor the granting authority HADEA can be held responsible for them.
