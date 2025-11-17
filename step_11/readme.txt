To run Step 11 (LISVAP-based PET calculation), you need to use the external LISVAP tool.
LISVAP is not included in this repository because the original source distribution is large (~2 GB).
Instead, please install LISVAP and PCRaster from their official sources and then use the sample configuration files provided in this folder.

⸻

	1.	Install LISVAP and PCRaster

⸻

Follow the official LISVAP installation guide:

https://ec-jrc.github.io/lisflood-lisvap/3_LISVAP_installation/

and the official PCRaster installation guide:

https://pcraster.geo.uu.nl/pcraster/4.4.1/documentation/pcraster_project/install.html

In our workflow, PCRaster is run from a Conda virtual environment (for example named lisvapenv),
and LISVAP is installed via pip inside the same environment. Any equivalent setup is fine,
as long as LISVAP and PCRaster are both available on your PATH.

⸻

	2.	Files provided in this folder (step_11)

⸻

This folder contains:
	•	config.xml
A sample LISVAP configuration file adapted to the CLIMB workflow.
It already contains the correct structure and parameters for reading the output
of Step 10 and producing daily PET fields.
	•	basemap/
A basemap directory prepared for Poland (e.g. required masks, static maps).
LISVAP will use these files for spatial reference and land/sea masking.

You can use these files as a starting point and only adjust the paths to match
your local installation.

⸻

	3.	How to adapt the configuration file

⸻

	1.	Copy the config.xml from this step_11 folder into your LISVAP working directory
(or point LISVAP directly to this file, depending on how you run it).
	2.	Open config.xml in a text editor and update the path entries so that they match your system:
	•	paths to the input meteorological data (NetCDF files produced by Step 10),
	•	path to the basemap directory (this basemap/ folder for Poland),
	•	path to the output directory where LISVAP should write PET NetCDF files.
	3.	Save the modified config.xml.

The original example configuration files shipped with LISVAP may not work directly
with the CLIMB data structure. For this reason, it is recommended to start from
the config.xml provided here and only change the paths.

⸻

	4.	Running LISVAP

⸻

After adapting config.xml:
	1.	Activate the environment where LISVAP and PCRaster are installed (e.g. lisvapenv).
	2.	Run LISVAP using the adapted configuration file, following the instructions from the
LISVAP documentation (for example by specifying the config file as input).

Please refer to the official LISVAP manual for the exact command-line invocation,
as it may change between versions.

⸻

	5.	Notes

⸻

•	This repository only provides the configuration and example setup for Step 11; it does not redistribute the LISVAP source code or binaries.
•	The LISVAP step is optional and only needed if you want to derive PET products in a way that is fully consistent with the JRC/LISFLOOD workflow.
•	Make sure that the temporal coverage and spatial grid of your Step 10 outputs are consistent with the configuration used in LISVAP.