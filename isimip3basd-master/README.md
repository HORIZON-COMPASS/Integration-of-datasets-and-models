## ISIMIP3BASD

This is the code base used for bias adjustment and statistical downscaling in phase 3 of the [Inter-Sectoral Impact Model Intercomparison Project](https://www.isimip.org/) (ISIMIP3).



## DOCUMENTATION

Version 1.0 of the bias adjustment and statistical downscaling methods encoded herein is described in Lange (2019, [doi:10.5194/gmd-12-3055-2019](https://doi.org/10.5194/gmd-12-3055-2019)). This code base is archived on Zenodo ([doi:10.5281/zenodo.2549631](https://doi.org/10.5281/zenodo.2549631)). Please refer to these sources where applicable.



## COPYRIGHT

&copy; 2019&ndash;2022 Potsdam Institute for Climate Impact Research (PIK)



## LICENSE

ISIMIP3BASD is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

ISIMIP3BASD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with ISIMIP3BASD. If not, see [http://www.gnu.org/licenses/](http://www.gnu.org/licenses/).



## REQUIREMENTS

ISIMIP3BASD is written in Python 3. It has been tested to run well with the following Python release and package versions.
* `python 3.6.9`
* `numpy 1.14.2`
* `scipy 1.1.0`
* `pandas 0.23.0`
* `netCDF4 1.4.1`
* `cf_units 2.0.1`



## HOW TO USE

The `bias_adjustment` module provides functions for bias adjustment of climate simulation data using climate observation data with the same spatial and temporal resolution.

The `statistical_downscaling` module provides functions for statistical downscaling of climate simulation data using climate observation data with the same temporal and higher spatial resolution.

The `utility_functions` module provides auxiliary functions used by the modules `bias_adjustment` and `statistical_downscaling`.

It is assumed that prior to applying the `statistical_downscaling` module, climate simulation data are bias-adjusted at their spatial resolution using the `bias_adjustment` module and spatially aggregated climate observation data.

The modules `bias_adjustment` and `statistical_downscaling` are written to work with input and output climate data stored in the NetCDF file format. For speedy I/O, these NetCDF files should be chunked with large chunk sizes in the time dimension and small chunk sizes in the other dimensions. They should also be neither deflated nor shuffled.

Thanks to their many parameters, the bias adjustment and statistical downscaling methods implemented herein are applicable to many climate variables. Parameter values can be specified via command line options to the main functions of the modules `bias_adjustment` and `statistical_downscaling`.

An example of how to apply those modules for a bias adjustment and statistical downscaling of the files in the `data` directory is given in the Linux Bash script `application_example.sh`. The parameter values used in that example are identical to the setting used in ISIMIP3.



## AUTHOR

Stefan Lange (slange@pik-potsdam.de)  
Potsdam Institute for Climate Impact Research (PIK)  
Member of the Leibniz Association  
P.O. Box 60 12 03  
14412 Potsdam  
Germany
