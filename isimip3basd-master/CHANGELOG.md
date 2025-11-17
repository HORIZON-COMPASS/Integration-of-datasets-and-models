## v3.0.2 (2022-10-06)

* Fixed a bug in the bias adjustment code that occurred when default values were used for the options `--step-size` and `--detrend`. In this case the code did not work due to an empty dictionary `years`. This dictionary is now populated regardless of the setting of those options.



## v3.0.1 (2022-06-27)

* Added the license header to the application example bash script and changed the following details of how the output NetCDF files are generated.
* All dimensions of the output NetCDF files are now limited to prevent `IndexError: tuple index out of range`.
* The fill value of the data variable of the output NetCDF files can no longer be set using the option `--fill-value` as this option has been removed. Instead, it is now copied from the input NetCDF files if available, otherwise a default fill value from the `netCDF4` package is used.
* The fill value is now set when the data variable of the output NetCDF files is created instead of afterwards using `setncattr` as the old approach resulted in an `AttributeError` with some versions of the `netCDF4` package.



## v3.0.0 (2022-04-28)

* Added application example that shows how the code is to be used and which parameter values were used for bias adjustment and statistical downscaling in ISIMIP3.
* Changed the I/O framework of the code. NetCDF files are now read and written using `netCDF4` instead of `iris`. This has several implications, as listed below.
* Output is now directly written to NetCDF files, i.e. intermediate `npy` files are not produced anymore. The option `--keep-npy-stack` has been removed accordingly.
* The option `--resume-job` has been removed, i.e. it is no longer possible to resume previously interrupted applications.
* It is no longer possible to select time ranges from input NetCDF files, i.e. options `--o-time-range`, `--s-time-range`, and `--f-time-range` have been removed.
* In multiprocessing applications with n processes, one of those processes is now exclusively dedicated to I/O operations. The data processing is done by the other n-1 processes.
* The option `--limit-time-dimension` is no longer available. Dimensions in output NetCDF files are limited or unlimited depending on whether they are in the input files, i.e. this property is carried over.
* The option `--anonymous-dimension-name` is not needed anymore and has been removed accordingly.
* Grids of data variables of input NetCDF files are now thoroughly checked with respect to fulfilling the design assumptions of the statistical downscaling method.
* The bilinear interpolation done in the first step of statistical downscaling is no longer done globally but at the local level. This significantly reduces the memory needed in an application, to an extent that input files with grids of arbitrary size can now be handled provided that the data variables are suitably chunked (see README).
* Bias adjustment outputs generated with v3.0.0 and v2.5.2 of the code are identical. Statistical downscaling results are not identical even though the method is the same. Differences are only stochastic in nature and caused by the different bilinear interpolation implementations.
* Time now has to be the last dimension of all data variables in all input NetCDF files and it is in the output files too.
* Variable names specified using the option `-v` now have to be the names of the data variables of the input NetCDF files rather than their standard names as before.



## v2.5.2 (2022-02-18)

* Changed implementation of spatial interpolation to fine grid in statistical downscaling code such that less memory is needed. This has no effect on the results.



## v2.5.1 (2021-12-13)

* Changed storage of local bias adjustment and statistical downscaling results. As before, those temporary results are stored in one `npy` file per time series. However, those `npy` files are now collected in one `zip` archive per process. This new approach strongly reduces the number of temporary output files produced during bias adjustment and statistical downscaling and hence reduces the risk of running into file system quotas.



## v2.5.0 (2021-04-14)

* Added option to not use (i.e. overwrite) existing local bias adjustment or statistical downscaling results. This is the new default.
* Added option to do bias adjustment in running-window mode with adjustable step size. Compared to a month-by-month bias adjustment the new mode reduces discontinuities in statistics such as multi-year daily mean values at each turn of the month.
* Added options to ignore trends in frequencies of values beyond threshold and not limit the climate change signal transfer to values within threshold, both for a better bias adjustment of hurs in the case of too many supersaturated hurs values in the simulated input data.
* Simplified transfer of climate change signal in frequencies of values beyond threshold for a better bias adjustment under climate change of variables such as prsnratio.



## v2.4.1 (2020-06-15)

* Fixed bug that occurred when there are no values within threshold in the data to be quantile-mapped but there should be such values after bias adjustment. In this case, nonparametric quantile mapping is now applied.



## v2.4.0 (2020-06-10)

* Changed how the pseudo future observations are generated by limiting the climate change signal transfer to values within threshold for a better bias adjustment of variables such as hurs and pr.
* Introduced brute force quantile mapping of the values to be quantile mapped to the distribution of all simulated future values within threshold prior to the actual quantile mapping for a better bias adjustment of variables such as hurs and pr in the case of biased frequencies of values beyond threshold.



## v2.3.1 (2020-05-27)

* Added rough goodness-of-fit test to fit function to notice bad distribution fits. The test is based on the Kolmogorov-Smirnov test statistic. In the case of a noticed bad fit, quantile mapping is done nonparametrically.



## v2.3 (2020-02-06)

* Added non-parametric quantile mapping option for a more robust bias adjustment of bounded variables. Non-parametric quantile mapping is applied if no distribution type is specified for parametric quantile mapping.
* Changed climate change signal transfer to empirical percentiles of bounded variables and frequencies of values beyond threshold (equations (8) and (9) in Lange (2019, [doi:10.5194/gmd-12-3055-2019](https://doi.org/10.5194/gmd-12-3055-2019))) for a better bias adjustment under climate change.
* Changed sampling of invalid values for months without valid values. In these cases the average of the valid values from all months is used. Only if there are no valid values at all `if_all_invalid_use` is used.



## v2.2 (2020-01-29)

* Changed randomization of values beyond threshold for a better bias adjustment of variables such as hurs: randomization is now applied to all values beyond threshold, ranks of values beyond threshold are preserved, random numbers are no longer raised to higher power.
* Fixed numerical instability of climate change signal transfer to upper bound climatology to improve bias adjustment of variables such as rsds.



## v2.1 (2020-01-18)

* Changed sampling of invalid values to mimic trend in valid values to better preserve within-period trends for variables such as prsnratio.
* Removed the automatic calculation of the number of iterations of the (modified) MBCn algorithm. Made univariate bias adjustment and statistical downscaling with 20 iterations the new defaults.
* Made detrending conditional on trend being significantly (at the 5 % level) different from 0.
* Fixed numerical instability of upper bound scaling to improve bias adjustment of variables such as rsds.
* Fixed minor bugs related to missing output directories, inconsistent spatial shapes, and running the code with different numpy versions.
* Facilitated resumption of canceled jobs by using already existing local results.



## v2.0 (2019-08-18)

* Added multivariate bias adjustment option.
* Added support of input NetCDF files with missing values.
* Added support of different downscaling factors in different spatial dimensions.
* Increased execution speed by eliminating various I/O bottlenecks.
* Reduced memory usage by sharing resources between processes and saving local results in stack of `npy` files.
* Fixed minor bugs related to bilinear regridding, detrending, and applications to fewer than 12 calendar months.



## v1.0 (2019-03-07)

* Reference version for Lange (2019, [doi:10.5194/gmd-12-3055-2019](https://doi.org/10.5194/gmd-12-3055-2019)).
