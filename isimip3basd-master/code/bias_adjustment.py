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



"""
Bias adjustment
===============

Provides functions for bias adjustment of climate simulation data using climate
observation data with the same spatial and temporal resolution.

"""



import warnings
import numpy as np
import scipy.stats as sps
import utility_functions as uf
import multiprocessing as mp
from netCDF4 import Dataset
from optparse import OptionParser
from functools import partial
from contextlib import ExitStack



def map_quantiles_parametric_trend_preserving(
        x_obs_hist, x_sim_hist, x_sim_fut, 
        distribution=None, trend_preservation='additive',
        adjust_p_values=False,
        lower_bound=None, lower_threshold=None,
        upper_bound=None, upper_threshold=None,
        unconditional_ccs_transfer=False, trendless_bound_frequency=False,
        n_quantiles=50, p_value_eps=1e-10,
        max_change_factor=100., max_adjustment_factor=9.):
    """
    Adjusts biases using the trend-preserving parametric quantile mapping method
    described in Lange (2019) <https://doi.org/10.5194/gmd-12-3055-2019>.

    Parameters
    ----------
    x_obs_hist : array
        Time series of observed climate data representing the historical or
        training time period.
    x_sim_hist : array
        Time series of simulated climate data representing the historical or
        training time period.
    x_sim_fut : array
        Time series of simulated climate data representing the future or
        application time period.
    distribution : str, optional
        Kind of distribution used for parametric quantile mapping:
        [None, 'normal', 'weibull', 'gamma', 'beta', 'rice'].
    trend_preservation : str, optional
        Kind of trend preservation used for non-parametric quantile mapping:
        ['additive', 'multiplicative', 'mixed', 'bounded'].
    adjust_p_values : boolean, optional
        Adjust p-values for a perfect match in the reference period.
    lower_bound : float, optional
        Lower bound of values in x_obs_hist, x_sim_hist, and x_sim_fut.
    lower_threshold : float, optional
        Lower threshold of values in x_obs_hist, x_sim_hist, and x_sim_fut.
        All values below this threshold are replaced by lower_bound in the end.
    upper_bound : float, optional
        Upper bound of values in x_obs_hist, x_sim_hist, and x_sim_fut.
    upper_threshold : float, optional
        Upper threshold of values in x_obs_hist, x_sim_hist, and x_sim_fut.
        All values above this threshold are replaced by upper_bound in the end.
    unconditional_ccs_transfer : boolean, optional
        Transfer climate change signal using all values, not only those within
        thresholds.
    trendless_bound_frequency : boolean, optional
        Do not allow for trends in relative frequencies of values below lower
        threshold and above upper threshold.
    n_quantiles : int, optional
        Number of quantile-quantile pairs used for non-parametric quantile
        mapping.
    p_value_eps : float, optional
        In order to keep p-values with numerically stable limits, they are
        capped at p_value_eps (lower bound) and 1 - p_value_eps (upper bound).
    max_change_factor : float, optional
        Maximum change factor applied in non-parametric quantile mapping with
        multiplicative or mixed trend preservation.
    max_adjustment_factor : float, optional
        Maximum adjustment factor applied in non-parametric quantile mapping
        with mixed trend preservation.

    Returns
    -------
    x_sim_fut_ba : array
        Result of bias adjustment.

    """
    lower = lower_bound is not None and lower_threshold is not None
    upper = upper_bound is not None and upper_threshold is not None

    # use augmented quantile delta mapping to transfer the simulated
    # climate change signal to the historical observation
    i_obs_hist = np.ones(x_obs_hist.shape, dtype=bool)
    i_sim_hist = np.ones(x_sim_hist.shape, dtype=bool)
    i_sim_fut = np.ones(x_sim_fut.shape, dtype=bool)
    if lower:
        i_obs_hist = np.logical_and(i_obs_hist, x_obs_hist > lower_threshold)
        i_sim_hist = np.logical_and(i_sim_hist, x_sim_hist > lower_threshold)
        i_sim_fut = np.logical_and(i_sim_fut, x_sim_fut > lower_threshold)
    if upper:
        i_obs_hist = np.logical_and(i_obs_hist, x_obs_hist < upper_threshold)
        i_sim_hist = np.logical_and(i_sim_hist, x_sim_hist < upper_threshold)
        i_sim_fut = np.logical_and(i_sim_fut, x_sim_fut < upper_threshold)
    if unconditional_ccs_transfer:
        # use all values
        x_target = uf.map_quantiles_non_parametric_trend_preserving(
            x_obs_hist, x_sim_hist, x_sim_fut,
            trend_preservation, n_quantiles,
            max_change_factor, max_adjustment_factor,
            True, lower_bound, upper_bound)
    else:
        # use only values within thresholds
        x_target = x_obs_hist.copy()
        x_target[i_obs_hist] = uf.map_quantiles_non_parametric_trend_preserving(
            x_obs_hist[i_obs_hist], x_sim_hist[i_sim_hist],
            x_sim_fut[i_sim_fut], trend_preservation, n_quantiles,
            max_change_factor, max_adjustment_factor,
            True, lower_threshold, upper_threshold)

    # determine extreme value probabilities of future obs
    if lower:
        p_lower = lambda x : np.mean(x <= lower_threshold)
        p_lower_target = p_lower(x_obs_hist) \
            if trendless_bound_frequency else uf.ccs_transfer_sim2obs(
            p_lower(x_obs_hist), p_lower(x_sim_hist), p_lower(x_sim_fut))
    if upper:
        p_upper = lambda x : np.mean(x >= upper_threshold)
        p_upper_target = p_upper(x_obs_hist) \
            if trendless_bound_frequency else uf.ccs_transfer_sim2obs(
            p_upper(x_obs_hist), p_upper(x_sim_hist), p_upper(x_sim_fut))
    if lower and upper:
        p_lower_or_upper_target = p_lower_target + p_upper_target
        if p_lower_or_upper_target > 1 + 1e-10:
            msg = 'sum of p_lower_target and p_upper_target exceeds one'
            warnings.warn(msg)
            p_lower_target /= p_lower_or_upper_target
            p_upper_target /= p_lower_or_upper_target

    # do a parametric quantile mapping of the values within thresholds
    x_source = x_sim_fut
    y = x_source.copy()

    # determine indices of values to be mapped
    i_source = np.ones(x_source.shape, dtype=bool)
    i_target = np.ones(x_target.shape, dtype=bool)
    if lower:
        # make sure that lower_threshold_source < x_source 
        # because otherwise sps.beta.ppf does not work
        lower_threshold_source = \
            uf.percentile1d(x_source, np.array([p_lower_target]))[0] \
            if p_lower_target > 0 else lower_bound if not upper else \
            lower_bound - 1e-10 * (upper_bound - lower_bound)
        i_lower = x_source <= lower_threshold_source
        i_source = np.logical_and(i_source, np.logical_not(i_lower))
        i_target = np.logical_and(i_target, x_target > lower_threshold)
        y[i_lower] = lower_bound
    if upper:
        # make sure that x_source < upper_threshold_source
        # because otherwise sps.beta.ppf does not work
        upper_threshold_source = \
            uf.percentile1d(x_source, np.array([1.-p_upper_target]))[0] \
            if p_upper_target > 0 else upper_bound if not lower else \
            upper_bound + 1e-10 * (upper_bound - lower_bound)
        i_upper = x_source >= upper_threshold_source
        i_source = np.logical_and(i_source, np.logical_not(i_upper))
        i_target = np.logical_and(i_target, x_target < upper_threshold)
        y[i_upper] = upper_bound

    # map quantiles
    while np.any(i_source):
        # break here if target distributions cannot be determined
        if not np.any(i_target):
            msg = 'unable to do any quantile mapping' \
                + ': leaving %i value(s) unadjusted'%np.sum(i_source)
            warnings.warn(msg)
            break

        # use the within-threshold values of x_sim_fut for the source
        # distribution fitting
        x_source_fit = x_source[i_sim_fut]
        x_target_fit = x_target[i_target]

        # determine distribution parameters
        spsdotwhat = sps.norm if distribution == 'normal' else \
                     sps.weibull_min if distribution == 'weibull' else \
                     sps.gamma if distribution == 'gamma' else \
                     sps.beta if distribution == 'beta' else \
                     sps.rice if distribution == 'rice' else \
                     None
        if spsdotwhat is None:
            # prepare non-parametric quantile mapping
            x_source_map = x_source[i_source]
            shape_loc_scale_source = None
            shape_loc_scale_target = None
        else:
            # prepare parametric quantile mapping
            if lower or upper:
                # map the values in x_source to be quantile-mapped such that
                # their empirical distribution matches the empirical
                # distribution of the within-threshold values of x_sim_fut
                x_source_map = uf.map_quantiles_non_parametric_brute_force(
                    x_source[i_source], x_source_fit)
            else:
                x_source_map = x_source

            # fix location and scale parameters for fitting
            floc = lower_threshold if lower else None
            fscale = upper_threshold - lower_threshold \
                if lower and upper else None
    
            # because sps.rice.fit and sps.weibull_min.fit cannot handle
            # fscale=None
            if distribution in ['rice', 'weibull']:
                fwords = {'floc': floc}
            else:
                fwords = {'floc': floc, 'fscale': fscale}
    
            # fit distributions to x_source and x_target
            shape_loc_scale_source = uf.fit(spsdotwhat, x_source_fit, fwords)
            shape_loc_scale_target = uf.fit(spsdotwhat, x_target_fit, fwords)

        # do non-parametric quantile mapping if fitting failed
        if shape_loc_scale_source is None or shape_loc_scale_target is None:
            msg = 'unable to do parametric quantile mapping' \
                + ': doing non-parametric quantile mapping instead'
            if spsdotwhat is not None: warnings.warn(msg)
            p_zeroone = np.linspace(0., 1., n_quantiles + 1)
            q_source_fit = uf.percentile1d(x_source_map, p_zeroone)
            q_target_fit = uf.percentile1d(x_target_fit, p_zeroone)
            y[i_source] = \
                uf.map_quantiles_non_parametric_with_constant_extrapolation(
                x_source_map, q_source_fit, q_target_fit)
            break

        # compute source p-values
        limit_p_values = lambda p : np.maximum(p_value_eps,
                                    np.minimum(1-p_value_eps, p))
        p_source = limit_p_values(spsdotwhat.cdf(
                   x_source_map, *shape_loc_scale_source))

        # compute target p-values
        if adjust_p_values:
            x_obs_hist_fit = x_obs_hist[i_obs_hist]
            x_sim_hist_fit = x_sim_hist[i_sim_hist]
            shape_loc_scale_obs_hist = uf.fit(spsdotwhat,
                                       x_obs_hist_fit, fwords)
            shape_loc_scale_sim_hist = uf.fit(spsdotwhat,
                                       x_sim_hist_fit, fwords)
            if shape_loc_scale_obs_hist is None \
            or shape_loc_scale_sim_hist is None:
                msg = 'unable to adjust p-values: leaving them unadjusted'
                warnings.warn(msg)
                p_target = p_source
            else:
                p_obs_hist = limit_p_values(spsdotwhat.cdf(
                             x_obs_hist_fit, *shape_loc_scale_obs_hist))
                p_sim_hist = limit_p_values(spsdotwhat.cdf(
                             x_sim_hist_fit, *shape_loc_scale_sim_hist))
                p_target = limit_p_values(uf.transfer_odds_ratio(
                           p_obs_hist, p_sim_hist, p_source))
        else:
            p_target = p_source

        # map quantiles
        y[i_source] = spsdotwhat.ppf(p_target, *shape_loc_scale_target)
        break

    return y



def adjust_bias_one_month(
        data, years, long_term_mean,
        lower_bound=[None], lower_threshold=[None],
        upper_bound=[None], upper_threshold=[None],
        unconditional_ccs_transfer=[False], trendless_bound_frequency=[False],
        randomization_seed=None, detrend=[False], rotation_matrices=[],
        n_quantiles=50, distribution=[None],
        trend_preservation=['additive'], adjust_p_values=[False],
        invalid_value_warnings=False, **kwargs):
    """
    1. Replaces invalid values in time series.
    2. Detrends time series if desired.
    3. Replaces values beyond thresholds by random numbers.
    4. Adjusts inter-variable copula.
    5. Adjusts marginal distributions for every variable.
    6. Replaces values beyond thresholds by the respective bound.
    7. Restores trends.

    Parameters
    ----------
    data : dict of str : list of arrays
        Keys : 'obs_hist', 'sim_hist', 'sim_fut'.
        Values : time series for all climate variables.
    years : dict of str : array
        Keys : 'obs_hist', 'sim_hist', 'sim_fut'.
        Values : years of time steps of time series, used for detrending.
    long_term_mean : dict of str: list of floats
        Keys : 'obs_hist', 'sim_hist', 'sim_fut'.
        Values : average of valid values in complete time series.
    lower_bound : list of floats, optional
        Lower bounds of values in data.
    lower_threshold : list of floats, optional
        Lower thresholds of values in data.
        All values below this threshold are replaced by random numbers between
        lower_bound and lower_threshold before bias adjustment.
    upper_bound : list of floats, optional
        Upper bounds of values in data.
    upper_threshold : list of floats, optional
        Upper thresholds of values in data.
        All values above this threshold are replaced by random numbers between
        upper_threshold and upper_bound before bias adjustment.
    unconditional_ccs_transfer : boolean, optional
        Transfer climate change signal using all values, not only those within
        thresholds.
    trendless_bound_frequency : boolean, optional
        Do not allow for trends in relative frequencies of values below lower
        threshold and above upper threshold.
    randomization_seed : int, optional
        Used to seed the random number generator before replacing invalid
        values and values beyond the specified thresholds.
    detrend : list of booleans, optional
        Detrend time series before bias adjustment and put trend back in
        afterwards.
    rotation_matrices : list of (n,n) ndarrays, optional
        List of orthogonal matrices defining a sequence of rotations in variable
        space, where n is the number of variables.
    n_quantiles : int, optional
        Number of quantile-quantile pairs used for non-parametric quantile
        mapping.
    distribution : list of strs, optional
        Kind of distribution used for parametric quantile mapping:
        [None, 'normal', 'weibull', 'gamma', 'beta', 'rice'].
    trend_preservation : list of strs, optional
        Kind of trend preservation used for non-parametric quantile mapping:
        ['additive', 'multiplicative', 'mixed', 'bounded'].
    adjust_p_values : list of booleans, optional
        Adjust p-values for a perfect match in the reference period.
    invalid_value_warnings : boolean, optional
        Raise user warnings when invalid values are replaced bafore bias
        adjustment.

    Returns
    -------
    x_sim_fut_ba : list of arrays
        Result of bias adjustment.

    Other Parameters
    ----------------
    **kwargs : Passed on to map_quantiles_parametric_trend_preserving.
    
    """
    # remove invalid values from masked arrays and store resulting numpy arrays
    x = {}
    for key, data_list in data.items():
        x[key] = [uf.sample_invalid_values(d, randomization_seed,
            long_term_mean[key][i], invalid_value_warnings)[0]
            for i, d in enumerate(data_list)]

    n_variables = len(detrend)
    trend_sim_fut = [None] * n_variables
    for key, y in years.items():
        for i in range(n_variables):
            # subtract trend
            if detrend[i]:
                x[key][i], t = uf.subtract_or_add_trend(x[key][i], y)
                if key == 'sim_fut': trend_sim_fut[i] = t
            else:
                x[key][i] = x[key][i].copy()
        
            # randomize censored values
            # use low powers to ensure successful transformations of values
            # beyond thresholds to values within thresholds during quantile
            # mapping
            uf.randomize_censored_values(x[key][i], 
                lower_bound[i], lower_threshold[i],
                upper_bound[i], upper_threshold[i],
                True, False, randomization_seed, 1., 1.)

    # use MBCn to adjust copula
    if n_variables > 1 and len(rotation_matrices):
        x['sim_fut'] = uf.adjust_copula_mbcn(x, rotation_matrices, n_quantiles)

    x_sim_fut_ba = []
    for i in range(n_variables):
        # adjust distribution and de-randomize censored values
        y = map_quantiles_parametric_trend_preserving(
            x['obs_hist'][i], x['sim_hist'][i], x['sim_fut'][i],
            distribution[i], trend_preservation[i],
            adjust_p_values[i],
            lower_bound[i], lower_threshold[i],
            upper_bound[i], upper_threshold[i],
            unconditional_ccs_transfer[i], trendless_bound_frequency[i],
            n_quantiles, **kwargs)
    
        # add trend
        if detrend[i]:
            y = uf.subtract_or_add_trend(y, years['sim_fut'], trend_sim_fut[i])
    
        # make sure there are no invalid values
        uf.assert_no_infs_or_nans(x['sim_fut'][i], y)
        x_sim_fut_ba.append(y)

    return x_sim_fut_ba



def adjust_bias_one_location(
        i_loc, variable, step_size=0, window_centers=None,
        months=[1,2,3,4,5,6,7,8,9,10,11,12],
        halfwin_upper_bound_climatology=[0],
        lower_bound=[None], lower_threshold=[None],
        upper_bound=[None], upper_threshold=[None],
        if_all_invalid_use=[np.nan], **kwargs):
    """
    Adjusts biases in climate data representing one grid cell calendar month by
    calendar month and stores result in one numpy array per variable.

    Parameters
    ----------
    i_loc : tuple
        Location index.
    variable : list of strs
        Names of variable to be bias-adjusted in netcdf files.
    step_size: int, optional
        Step size in number of days used for bias adjustment in running-window
        mode. Setting this to 0 implies that bias adjustment is not done in 
        this mode but calendar month by calendar month.
    window_centers : array, optional
        Window centers for bias adjustment in running-window mode. In
        day-of-year units.
    months : list of ints, optional
        List of ints from {1,...,12} representing calendar months for which 
        results of bias adjustment are to be returned. Not used if bias 
        adjustment is done in running-window mode.
    halfwin_upper_bound_climatology : list of ints, optional
        Determines the lengths of running windows used in the calculations of
        climatologies of upper bounds that are used to scale values of obs_hist,
        sim_hist, and sim_fut to the interval [0,1] before bias adjustment. The
        window length is set to halfwin_upper_bound_climatology * 2 + 1 time
        steps. If halfwin_upper_bound_climatology == 0 then no rescaling is
        done.
    lower_bound : list of floats, optional
        Lower bounds of values in data.
    lower_threshold : list of floats, optional
        Lower thresholds of values in data.
    upper_bound : list of floats, optional
        Upper bounds of values in data.
    upper_threshold : list of floats, optional
        Upper thresholds of values in data.
    if_all_invalid_use : list of floats, optional
        Used to replace invalid values if there are no valid values.

    Returns
    -------
    None.

    Other Parameters
    ----------------
    **kwargs : Passed on to adjust_bias_one_month.

    """
    # get local input data
    data = {}
    for key in doys.keys() if step_size else month_numbers.keys():
        datasets = eval(key)
        data[key] = []
        for i, v in enumerate(variable):
             if datasets:
                 x = datasets[i][v][i_loc]
             else:
                 from_pool_queue.put((key, i, v, i_loc, i_process))
                 x = to_pool_queues[i_process].get()
             data[key].append(x)

    # abort here if there are only missing values in at least one dataset
    if uf.only_missing_values_in_at_least_one_dataset(data):
        print(i_loc, 'skipped due to missing data')
        return None

    # otherwise continue
    print(i_loc)
    n_variables = len(variable)
    None_list = [None] * n_variables
    result = [d.data.copy() if isinstance(d, np.ma.MaskedArray) else d.copy()
        for d in data['sim_fut']]
    
    # scale to values in [0, 1]
    ubc = {}
    ubc_doys = {}
    ubc_result = None_list.copy()
    msg = 'found nans in upper bound climatology for variable'
    for i, halfwin in enumerate(halfwin_upper_bound_climatology):
        if halfwin:
            # scale obs_hist, sim_hist, sim_fut
            for key, data_list in data.items():
                ubc[key], ubc_doys[key] = uf.get_upper_bound_climatology(
                    data_list[i], doys[key], halfwin)
                assert not np.any(np.isnan(ubc[key])), f'{msg} {i} in {key}'
                uf.scale_by_upper_bound_climatology(data_list[i],
                    ubc[key], doys[key], ubc_doys[key], divide=True)
    
            # prepare scaling of result
            ubc_result[i] = uf.ccs_transfer_sim2obs_upper_bound_climatology(
                ubc['obs_hist'], ubc['sim_hist'], ubc['sim_fut'])

    # compute mean value over all time steps for invalid value sampling
    long_term_mean = {}
    for key, data_list in data.items():
        long_term_mean[key] = [uf.average_valid_values(d, if_all_invalid_use[i],
            lower_bound[i], lower_threshold[i],
            upper_bound[i], upper_threshold[i])
            for i, d in enumerate(data_list)]

    # do local bias adjustment
    if step_size:
        # do bias adjustment in running-window mode
        data_this_window = {
        'obs_hist': None_list.copy(),
        'sim_hist': None_list.copy(),
        'sim_fut': None_list.copy()
        }
        years_this_window = {}
        for window_center in window_centers:
            # extract data for 31-day wide window around window_center
            for key, data_list in data.items():
                m = uf.window_indices_for_running_bias_adjustment(
                    doys[key], window_center, 31)
                years_this_window[key] = years[key][m]
                for i in range(n_variables):
                    data_this_window[key][i] = data_list[i][m]
    
            # adjust biases and store result as list of masked arrays
            result_this_window = adjust_bias_one_month(
                data_this_window, years_this_window, long_term_mean,
                lower_bound, lower_threshold,
                upper_bound, upper_threshold, **kwargs)
    
            # put central part of bias-adjusted data into result
            m_ba = uf.window_indices_for_running_bias_adjustment(
                doys['sim_fut'], window_center, 31)
            m_keep = uf.window_indices_for_running_bias_adjustment(
                doys['sim_fut'], window_center, step_size, years['sim_fut'])
            m_ba_keep = np.in1d(m_ba, m_keep)
            for i, halfwin in enumerate(halfwin_upper_bound_climatology):
                # scale from values in [0, 1]
                if halfwin:
                   uf.scale_by_upper_bound_climatology(
                       result_this_window[i], ubc_result[i],
                       doys['sim_fut'][m_ba], ubc_doys['sim_fut'], divide=False)
    
                result[i][m_keep] = result_this_window[i][m_ba_keep]
    else:
        # do bias adjustment calendar month by calendar month
        data_this_month = {
        'obs_hist': None_list.copy(),
        'sim_hist': None_list.copy(),
        'sim_fut': None_list.copy()
        }
        years_this_month = {}
        for month in months:
            # extract data
            for key, data_list in data.items():
                m = month_numbers[key] == month
                assert np.any(m), f'no data found for month {month} in {key}'
                y = years[key]
                years_this_month[key] = None if y is None else y[m]
                for i in range(n_variables):
                    data_this_month[key][i] = data_list[i][m]
    
            # adjust biases and store result as list of masked arrays
            result_this_month = adjust_bias_one_month(
                data_this_month, years_this_month, long_term_mean,
                lower_bound, lower_threshold,
                upper_bound, upper_threshold, **kwargs)
    
            # put bias-adjusted data into result
            m = month_numbers['sim_fut'] == month
            for i, halfwin in enumerate(halfwin_upper_bound_climatology):
                # scale from values in [0, 1]
                if halfwin:
                   uf.scale_by_upper_bound_climatology(
                       result_this_month[i], ubc_result[i],
                       doys['sim_fut'][m], ubc_doys['sim_fut'], divide=False)
    
                result[i][m] = result_this_month[i]
    
    # save local result of bias adjustment variable by variable
    for i, v in enumerate(variable):
        if sim_fut_ba:
            sim_fut_ba[i][v][i_loc] = result[i]
            sim_fut_ba[i].sync()
        else:
            from_pool_queue.put(('sim_fut_ba', i, v,
                i_loc, result[i], i_process))
            # wait for response to ensure that the local result has been saved
            x = to_pool_queues[i_process].get()

    return None



def load_or_save_one_location(
        obs_hist_path, sim_hist_path, sim_fut_path, sim_fut_ba_path):
    """
    Gets items from from_pool_queue, then either loads the requested data from
    one of the input netcdf files and puts that data to the to_pool_queue used
    by the requesting process or saves the data transmitted via from_pool_queue
    to the output netcdf file.

    Parameters
    ----------
    obs_hist_path : list of strs
        Paths to input netcdf files with historical observations.
    sim_hist_path : list of strs
        Paths to input netcdf files with historical simulations.
    sim_fut_path : list of strs
        Paths to input netcdf files with future simulations.
    sim_fut_ba_path : list of strs
        Paths to output netcdf files with bias-adjusted future simulations.

    """
    obs_hist, sim_hist, sim_fut, sim_fut_ba = [], [], [], []
    with ExitStack() as stack:
        for a, b, c, d in zip(
            obs_hist_path, sim_hist_path, sim_fut_path, sim_fut_ba_path):
            obs_hist.append(stack.enter_context(Dataset(a, 'r')))
            sim_hist.append(stack.enter_context(Dataset(b, 'r')))
            sim_fut.append(stack.enter_context(Dataset(c, 'r')))
            sim_fut_ba.append(stack.enter_context(Dataset(d, 'r+')))
        while True:
            item = from_pool_queue.get()
            if item is None:
                break
            elif item[0] == 'sim_fut_ba':
                dataset = sim_fut_ba[item[1]]
                dataset[item[2]][item[3]] = item[4]
                dataset.sync()
                to_pool_queues[item[5]].put('synced')
            else:
                dataset = eval(item[0])[item[1]]
                x = dataset[item[2]][item[3]]
                to_pool_queues[item[4]].put(x)



def adjust_bias(
        obs_hist_path, sim_hist_path, sim_fut_path, sim_fut_ba_path,
        space_shape, n_processes=1, **kwargs):
    """
    Adjusts biases grid cell by grid cell.

    Parameters
    ----------
    obs_hist_path : list of strs
        Paths to input netcdf files with historical observations.
    sim_hist_path : list of strs
        Paths to input netcdf files with historical simulations.
    sim_fut_path : list of strs
        Paths to input netcdf files with future simulations.
    sim_fut_ba_path : list of strs
        Paths to output netcdf files with bias-adjusted future simulations.
    space_shape : tuple
        Describes the spatial dimensions of the climate data.
    n_processes : int, optional
        Number of processes used for parallel processing.

    Other Parameters
    ----------------
    **kwargs : Passed on to adjust_bias_one_location.

    """
    # adjust every location individually
    global from_pool_queue, to_pool_queues
    global obs_hist, sim_hist, sim_fut, sim_fut_ba
    i_locations = np.ndindex(space_shape)
    abol = partial(adjust_bias_one_location, **kwargs)
    if n_processes > 1:
        from_pool_queue = mp.Queue()
        to_pool_queues = [mp.Queue() for i in range(n_processes-1)]
        obs_hist, sim_hist, sim_fut, sim_fut_ba = None, None, None, None
        reader_writer = mp.Process(target=load_or_save_one_location,
            args=(obs_hist_path, sim_hist_path, sim_fut_path, sim_fut_ba_path))
        reader_writer.start()
        with mp.Manager() as manager:
            ipq = manager.Queue()
            for i in range(n_processes-1):
                ipq.put(i)
            def initializer(q):
                global i_process
                i_process = q.get()
            with mp.Pool(n_processes-1, initializer, (ipq,)) as pool:
                foo = list(pool.imap(abol, i_locations))
                from_pool_queue.put(None)
                reader_writer.join()
    else:
        from_pool_queue, to_pool_queues = None, None
        obs_hist, sim_hist, sim_fut, sim_fut_ba = [], [], [], []
        with ExitStack() as stack:
            for a, b, c, d in zip(
                obs_hist_path, sim_hist_path, sim_fut_path, sim_fut_ba_path):
                obs_hist.append(stack.enter_context(Dataset(a, 'r')))
                sim_hist.append(stack.enter_context(Dataset(b, 'r')))
                sim_fut.append(stack.enter_context(Dataset(c, 'r')))
                sim_fut_ba.append(stack.enter_context(Dataset(d, 'r+')))
            foo = list(map(abol, i_locations))



def main():
    """
    Prepares and executes the bias adjustment algorithm.

    """
    # parse command line options and arguments
    parser = OptionParser()
    parser.add_option('-o', '--obs-hist', action='store',
        type='string', dest='obs_hist', default='',
        help=('comma-separated list of paths to input netcdf files with '
             'historical observations (one file per variable)'))
    parser.add_option('-s', '--sim-hist', action='store',
        type='string', dest='sim_hist', default='',
        help=('comma-separated list of paths to input netcdf files with '
             'historical simulations (one file per variable)'))
    parser.add_option('-f', '--sim-fut', action='store',
        type='string', dest='sim_fut', default='',
        help=('comma-separated list of paths to input netcdf files with '
             'future simulations (one file per variable)'))
    parser.add_option('-b', '--sim-fut-ba', action='store',
        type='string', dest='sim_fut_ba', default='',
        help=('comma-separated list of paths to output netcdf files with '
             'bias-adjusted future simulations (one file per variable)'))
    parser.add_option('-v', '--variable', action='store',
        type='string', dest='variable', default='',
        help=('comma-separated list of names of variables in input '
              'netcdf files'))
    parser.add_option('--step-size', action='store',
        type='int', dest='step_size', default=0,
        help=('step size in number of days used for bias adjustment in ',
              'running-window mode (default: 0, which implies that bias ',
              'adjustment is not done in this mode but calendar month by '
              'calendar month)'))
    parser.add_option('-m', '--months', action='store',
        type='string', dest='months', default='1,2,3,4,5,6,7,8,9,10,11,12',
        help=('comma-separated list of integers from {1,...,12} representing '
              'calendar months to be bias-adjusted (not used if bias '
              'adjustment is done in running-window mode)'))
    parser.add_option('--n-processes', action='store',
        type='int', dest='n_processes', default=1,
        help='number of processes used for multiprocessing (default: 1)')
    parser.add_option('--n-iterations', action='store',
        type='int', dest='n_iterations', default=0,
        help=('number of iterations used for copula adjustment (default: 0, '
              'which means that no copula adjustment is applied)'))
    parser.add_option('-w', '--halfwin-upper-bound-climatology', action='store',
        type='string', dest='halfwin_upper_bound_climatology', default='0',
        help=('comma-separated list of half window lengths used to compute '
              'climatologies of upper bounds used to scale values before and '
              'after bias adjustment (default: 0, which is interpreted as do '
              'not scale)'))
    parser.add_option('--lower-bound', action='store',
        type='string', dest='lower_bound', default='',
        help=('comma-separated list of lower bounds of variables that has to '
              'be respected during bias adjustment (default: not specified)'))
    parser.add_option('--lower-threshold', action='store',
        type='string', dest='lower_threshold', default='',
        help=('comma-separated list of lower thresholds of variables that has '
              'to be respected during bias adjustment (default: not '
              'specified)'))
    parser.add_option('--upper-bound', action='store',
        type='string', dest='upper_bound', default='',
        help=('comma-separated list of upper bounds of variables that has to '
              'be respected during bias adjustment (default: not specified)'))
    parser.add_option('--upper-threshold', action='store',
        type='string', dest='upper_threshold', default='',
        help=('comma-separated list of upper thresholds of variables that has '
              'to be respected during bias adjustment (default: not '
              'specified)'))
    parser.add_option('--randomization-seed', action='store',
        type='int', dest='randomization_seed', default=None,
        help=('seed used during randomization to generate reproducible results '
              '(default: not specified)'))
    parser.add_option('--distribution', action='store',
        type='string', dest='distribution', default='',
        help=('comma-separated list of distribution families used for '
              'parametric quantile mapping (default: not specified, which '
              'invokes non-parametric quantile mapping, alternatives: '
              'normal, gamma, weibull, beta, rice)'))
    parser.add_option('-t', '--trend-preservation', action='store',
        type='string', dest='trend_preservation', default='additive',
        help=('comma-separated list of kinds of trend preservation (default: '
              'additive, alternatives: multiplicative, mixed, bounded)'))
    parser.add_option('-q', '--n-quantiles', action='store',
        type='int', dest='n_quantiles', default=50,
        help=('number of quantiles used for non-parametric quantile mapping '
              '(default: 50)'))
    parser.add_option('-e', '--p-value-eps', action='store',
        type='float', dest='p_value_eps', default=1.e-10,
        help=('lower cap for p-values during parametric quantile mapping '
              '(default: 1.e-10)'))
    parser.add_option('--max-change-factor', action='store',
        type='float', dest='max_change_factor', default=100.,
        help=('cap for change factor for non-parametric quantile mapping '
              '(default: 100.)'))
    parser.add_option('--max-adjustment-factor', action='store',
        type='float', dest='max_adjustment_factor', default=9.,
        help=('cap for adjustment factor for non-parametric quantile mapping '
              '(default: 9.)'))
    parser.add_option('--if-all-invalid-use', action='store',
        type='string', dest='if_all_invalid_use', default='',
        help=('comma-separated list of values used to replace missing values, '
              'infs and nans before biases adjustment if there are no other '
              'values in a time series (default: not specified)'))
    parser.add_option('-p', '--adjust-p-values', action='store',
        type='string', dest='adjust_p_values', default='',
        help=('comma-separated list of flags to adjust p-values during '
              'parametric quantile mapping for a perfect adjustment of the '
              'reference period distribution (default: do not)'))
    parser.add_option('-d', '--detrend', action='store',
        type='string', dest='detrend', default='',
        help=('comma-separated list of flags to subtract trend before bias '
              'adjustment and add it back afterwards (default: do not)'))
    parser.add_option('--unconditional-ccs-transfer', action='store',
        type='string', dest='unconditional_ccs_transfer', default='',
        help=('comma-separated list of flags to transfer climate change '
              'signal using all values (default: use only values within '
              'thresholds for climate change signal transfer)'))
    parser.add_option('--trendless-bound-frequency', action='store',
        type='string', dest='trendless_bound_frequency', default='',
        help=('comma-separated list of flags to not allow for trends in '
              'relative frequencies of values below lower threshold and '
              'above upper threshold (default: do allow for such trends)'))
    parser.add_option('--repeat-warnings', action='store_true',
        dest='repeat_warnings', default=False,
        help='repeat warnings for the same source location (default: do not)')
    parser.add_option('--invalid-value-warnings', action='store_true',
        dest='invalid_value_warnings', default=False,
        help=('raise warning when missing values, infs or nans are replaced by '
              'sampling from all other values before bias adjustment '
              '(default: do not)'))
    (options, args) = parser.parse_args()
    if options.repeat_warnings: warnings.simplefilter('always', UserWarning)

    # convert options for different variables to lists
    print('checking inputs ...')
    variable = uf.split(options.variable)
    n_variables = len(variable)
    obs_hist_path = uf.split(options.obs_hist, n_variables)
    sim_hist_path = uf.split(options.sim_hist, n_variables)
    sim_fut_path = uf.split(options.sim_fut, n_variables)
    sim_fut_ba_path = uf.split(options.sim_fut_ba, n_variables)
    halfwin_upper_bound_climatology = uf.split(
        options.halfwin_upper_bound_climatology, n_variables, int)
    lower_bound = uf.split(options.lower_bound, n_variables, float)
    lower_threshold = uf.split(options.lower_threshold, n_variables, float)
    upper_threshold = uf.split(options.upper_threshold, n_variables, float)
    upper_bound = uf.split(options.upper_bound, n_variables, float)
    distribution = uf.split(options.distribution, n_variables)
    trend_preservation = uf.split(options.trend_preservation, n_variables)
    if_all_invalid_use = uf.split(
        options.if_all_invalid_use, n_variables, float, np.nan)
    adjust_p_values = uf.split(
        options.adjust_p_values, n_variables, bool, False)
    detrend = uf.split(options.detrend, n_variables, bool, False)
    unconditional_ccs_transfer = uf.split(
        options.unconditional_ccs_transfer, n_variables, bool, False)
    trendless_bound_frequency = uf.split(
        options.trendless_bound_frequency, n_variables, bool, False)

    # do some preliminary checks
    if options.step_size:
        months = [1,2,3,4,5,6,7,8,9,10,11,12]
        uf.assert_validity_of_step_size(options.step_size)
    else:
        months = list(np.sort(np.unique(np.array(
            options.months.split(','), dtype=int))))
        uf.assert_validity_of_months(months)
    for i in range(n_variables):
        uf.assert_consistency_of_bounds_and_thresholds(
            lower_bound[i], lower_threshold[i],
            upper_bound[i], upper_threshold[i])
        uf.assert_consistency_of_distribution_and_bounds(distribution[i],
            lower_bound[i], lower_threshold[i],
            upper_bound[i], upper_threshold[i])

    # check input data and and make some information globally accessible
    global month_numbers, years, doys
    month_numbers, years, doys = {}, {}, {}
    space_shape = None
    window_centers = None
    for i, v in enumerate(variable):
        with Dataset(obs_hist_path[i], 'r') as obs_hist, \
            Dataset(sim_hist_path[i], 'r') as sim_hist, \
            Dataset(sim_fut_path[i], 'r') as sim_fut:
            for key in ('obs_hist', 'sim_hist', 'sim_fut'):
                msg_ = f' {key} {v}'
                msg0 = 'found input data spatial shapes mismatch in' + msg_
                msg1 = 'found input data months mismatch in' + msg_
                msg2 = 'found input data years mismatch in' + msg_
                msg3 = 'found input data days of year mismatch in' + msg_
                coords = uf.analyze_input_nc(eval(key), v)
                # make sure that all inputs have identical spatial dimensions
                s = tuple(v.size for k, v in coords.items() if k != 'time')
                if space_shape is None: space_shape = s
                else: assert space_shape == s, msg0
                # prepare bias adjustment calendar month by calendar month
                if not options.step_size:
                    j = uf.convert_datetimes(coords['time'], 'month_number')
                    if i: assert np.all(month_numbers[key] == j), msg1
                    else: month_numbers[key] = j
                # prepare bias adjustment in running-window mode and detrending
                j = uf.convert_datetimes(coords['time'], 'year')
                if i: assert np.all(years[key] == j), msg2
                else: years[key] = j
                # prepare bias adjustment in running-window mode
                # and scaling by upper bound climatology
                if options.step_size or halfwin_upper_bound_climatology[i]:
                    j = uf.convert_datetimes(coords['time'], 'day_of_year')
                    if i: assert np.all(doys[key] == j), msg3
                    else: doys[key] = j
                # make sure that a full period is continuously covered
                if not i and options.step_size:
                    uf.assert_full_period_coverage(years[key], doys[key], key)

            # prepare bias adjustment in running-window mode
            if not i and options.step_size:
                # make sure all input data cover the same number of doys
                uf.assert_uniform_number_of_doys(doys)
                # get application window centers
                window_centers = uf.window_centers_for_running_bias_adjustment(
                    doys['sim_fut'], options.step_size)

            # create empty output netcdf file
            uf.setup_output_nc(sim_fut_ba_path[i], sim_fut, v,
                options, 'ba_', i, None)

    # get list of rotation matrices to be used for all locations and months
    if options.randomization_seed is not None:
        np.random.seed(options.randomization_seed)
    rotation_matrices = [uf.generateCREmatrix(n_variables)
        for i in range(options.n_iterations)]
    
    # do bias adjustment
    spatial_dimensions_str = ', '.join(tuple(coords.keys())[:-1])
    print(f'adjusting at location ({spatial_dimensions_str}) ...')
    adjust_bias(
        obs_hist_path, sim_hist_path, sim_fut_path, sim_fut_ba_path,
        space_shape, options.n_processes,
        step_size=options.step_size,
        window_centers=window_centers,
        months=months,
        halfwin_upper_bound_climatology=halfwin_upper_bound_climatology,
        lower_bound=lower_bound,
        lower_threshold=lower_threshold,
        upper_bound=upper_bound,
        upper_threshold=upper_threshold,
        distribution=distribution,
        trend_preservation=trend_preservation,
        n_quantiles=options.n_quantiles,
        p_value_eps=options.p_value_eps,
        max_change_factor=options.max_change_factor,
        max_adjustment_factor=options.max_adjustment_factor,
        if_all_invalid_use=if_all_invalid_use,
        adjust_p_values=adjust_p_values,
        invalid_value_warnings=options.invalid_value_warnings,
        unconditional_ccs_transfer=unconditional_ccs_transfer,
        trendless_bound_frequency=trendless_bound_frequency,
        randomization_seed=options.randomization_seed,
        detrend=detrend,
        rotation_matrices=rotation_matrices,
        variable=variable)



if __name__ == '__main__':
    main()
