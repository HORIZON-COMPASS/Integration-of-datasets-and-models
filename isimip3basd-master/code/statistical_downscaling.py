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
Statistical downscaling
=======================

Provides functions for statistical downscaling of climate simulation data using
climate observation data with the same temporal and higher spatial resolution.

"""



import warnings
import numpy as np
import utility_functions as uf
import multiprocessing as mp
from netCDF4 import Dataset
from optparse import OptionParser
from functools import partial
from itertools import product



def weighted_sum_preserving_mbcn(
        x_obs, x_sim_coarse, x_sim,
        sum_weights, rotation_matrices=[], n_quantiles=50):
    """
    Applies the core of the modified MBCn algorithm for statistical downscaling
    as described in Lange (2019) <https://doi.org/10.5194/gmd-12-3055-2019>.

    Parameters
    ----------
    x_obs : (M,N) ndarray
        Array of N observed time series of M time steps each at fine spatial
        resolution.
    x_sim_coarse : (M,) array
        Array of simulated time series of M time steps at coarse spatial
        resolution.
    x_sim : (M,N) ndarray
        Array of N simulated time series of M time steps each at fine spatial
        resolution, derived from x_sim_coarse by bilinear interpolation.
    sum_weights : (N,) array
        Array of N grid cell-area weights.
    rotation_matrices : list of (N,N) ndarrays, optional
        List of orthogonal matrices defining a sequence of rotations in the  
        second dimension of x_obs and x_sim.
    n_quantiles : int, optional
        Number of quantile-quantile pairs used for non-parametric quantile
        mapping.

    Returns
    -------
    x_sim : (M,N) ndarray
        Result of application of the modified MBCn algorithm.

    """
    # initialize total rotation matrix
    n_variables = sum_weights.size
    o_total = np.diag(np.ones(n_variables))

    # p-values in percent for non-parametric quantile mapping
    p = np.linspace(0., 1., n_quantiles+1)

    # normalise the sum weights vector to length 1
    sum_weights = sum_weights / np.sqrt(np.sum(np.square(sum_weights)))

    # rescale x_sim_coarse for initial step of algorithm
    x_sim_coarse = x_sim_coarse * np.sum(sum_weights)

    # iterate
    n_loops = len(rotation_matrices) + 2
    for i in range(n_loops):
        if not i:  # rotate to the sum axis
            o = uf.generate_rotation_matrix_fixed_first_axis(sum_weights)
        elif i == n_loops - 1:  # rotate back to original axes for last qm
            o = o_total.T
        else:  # do random rotation
            o = rotation_matrices[i-1]

        # compute total rotation
        o_total = np.dot(o_total, o)

        # rotate data
        x_sim = np.dot(x_sim, o)
        x_obs = np.dot(x_obs, o)
        sum_weights = np.dot(sum_weights, o)

        if not i:
            # restore simulated values at coarse grid scale
            x_sim[:,0] = x_sim_coarse

            # quantile map observations to values at coarse grid scale
            q_sim = uf.percentile1d(x_sim_coarse, p)
            q_obs = uf.percentile1d(x_obs[:,0], p)
            x_obs[:,0] = \
                uf.map_quantiles_non_parametric_with_constant_extrapolation(
                x_obs[:,0], q_obs, q_sim)
        else:
            # do univariate non-parametric quantile mapping for every variable
            x_sim_previous = x_sim.copy()
            for j in range(n_variables):
                q_sim = uf.percentile1d(x_sim[:,j], p)
                q_obs = uf.percentile1d(x_obs[:,j], p)
                x_sim[:,j] = \
                    uf.map_quantiles_non_parametric_with_constant_extrapolation(
                    x_sim[:,j], q_sim, q_obs)

            # preserve weighted sum of original variables
            if i < n_loops - 1:
                x_sim -= np.outer(np.dot(
                   x_sim - x_sim_previous, sum_weights), sum_weights)

    return x_sim



def downscale_one_month(
        data, long_term_mean,
        lower_bound=None, lower_threshold=None,
        upper_bound=None, upper_threshold=None,
        randomization_seed=None, **kwargs):
    """
    1. Replaces invalid values in time series.
    2. Replaces values beyond thresholds by random numbers.
    3. Applies the modified MBCn algorithm for statistical downscaling.
    4. Replaces values beyond thresholds by the respective bound.

    Parameters
    ----------
    data : dict of str : masked ndarray
        Keys : 'obs_fine', 'sim_coarse', 'sim_coarse_remapbil'.
        Values : arrays of shape (M,N), (M,), (M,N).
    long_term_mean : dict of str : scalar or array
        Keys : 'obs_fine', 'sim_coarse', 'sim_coarse_remapbil'.
        Values : scalar (for key 'sim_coarse') or array respresenting the
        average of all valid values in the complete time series for one climate
        variable and one location.
    lower_bound : float, optional
        Lower bound of values in data.
    lower_threshold : float, optional
        Lower threshold of values in data. All values below this threshold are
        replaced by random numbers between lower_bound and lower_threshold
        before application of the modified MBCn algorithm.
    upper_bound : float, optional
        Upper bound of values in data.
    upper_threshold : float, optional
        Upper threshold of values in data. All values above this threshold are
        replaced by random numbers between upper_threshold and upper_bound
        before application of the modified MBCn algorithm.
    randomization_seed : int, optional
        Used to seed the random number generator before replacing values beyond
        the specified thresholds.

    Returns
    -------
    x_sim_fine : (M,N) ndarray
        Result of application of the modified MBCn algorithm.

    Other Parameters
    ----------------
    **kwargs : Passed on to weighted_sum_preserving_mbcn.
    
    """
    x = {}
    for key, d in data.items():
        # remove invalid values from masked array and store resulting data array
        x[key] = uf.sample_invalid_values(
            d, randomization_seed, long_term_mean[key])[0]

        # randomize censored values, use high powers to create many values close
        # to the bounds as this keeps weighted sums similar to original values
        x[key] = uf.randomize_censored_values(x[key], 
            lower_bound, lower_threshold, upper_bound, upper_threshold,
            False, False, randomization_seed, 10., 10.)

    # downscale
    x_sim_coarse_remapbil = x['sim_coarse_remapbil'].copy()
    x_sim_fine = weighted_sum_preserving_mbcn(
        x['obs_fine'], x['sim_coarse'], x['sim_coarse_remapbil'], **kwargs)

    # de-randomize censored values
    uf.randomize_censored_values(x_sim_fine, 
        lower_bound, lower_threshold, upper_bound, upper_threshold, True, True)

    # make sure there are no invalid values
    uf.assert_no_infs_or_nans(x_sim_coarse_remapbil, x_sim_fine)

    return x_sim_fine



def downscale_one_location(
        i_loc_coarse, variable,
        downscaling_factors, ascending, circular, sum_weights,
        months=[1,2,3,4,5,6,7,8,9,10,11,12],
        lower_bound=None, lower_threshold=None,
        upper_bound=None, upper_threshold=None,
        if_all_invalid_use=np.nan, **kwargs):
    """
    Applies the modified MBCn algorithm for statistical downscaling calendar
    month by calendar month to climate data within one coarse grid cell.

    Parameters
    ----------
    i_loc_coarse : tuple
        Coarse location index.
    variable : str
        Name of variable to be downscaled in netcdf files.
    downscaling_factors : array of ints
        Downscaling factors for all grid dimensions.
    ascending : tuple of booleans
        Whether coordinates are monotonically increasing.
    circular : tuple of booleans
        Whether coordinates are circular.
    sum_weights : ndarray
        Array of fine grid cell area weights.
    months : list, optional
        List of ints from {1,...,12} representing calendar months for which 
        results of statistical downscaling are to be returned.
    lower_bound : float, optional
        Lower bound of values in data.
    lower_threshold : float, optional
        Lower threshold of values in data.
    upper_bound : float, optional
        Upper bound of values in data.
    upper_threshold : float, optional
        Upper threshold of values in data.
    if_all_invalid_use : float, optional
        Used to replace invalid values if there are no valid values.

    Returns
    -------
    None.

    Other Parameters
    ----------------
    **kwargs : Passed on to downscale_one_month.

    """
    # get local input data
    i_loc_fine = tuple(slice(df * i_loc_coarse[i], df * (i_loc_coarse[i] + 1))
        for i, df in enumerate(downscaling_factors))
    j_loc_fine = tuple(np.arange(s.start, s.stop) for s in i_loc_fine)
    oshape = lambda key: (np.prod(downscaling_factors), month_numbers[key].size)
    data = {}
    key = 'obs_fine'
    if obs_fine:
        x = obs_fine[variable][i_loc_fine]
    else:
        from_pool_queue.put((key, variable, i_loc_fine, i_process))
        x = to_pool_queues[i_process].get()
    data[key] = x.reshape(oshape(key)).T
    key = 'sim_coarse'
    if sim_coarse:
        x = uf.extended_load(sim_coarse[variable],
            i_loc_coarse, space_shapes[key], circular)
    else:
        from_pool_queue.put((key, variable,
            i_loc_coarse, space_shapes[key], circular, i_process))
        x = to_pool_queues[i_process].get()
    ivalues_central, ivalues = x
    igrid = tuple(uf.xipm1(x, i) for x, i in zip(grids[key], i_loc_coarse))
    data[key] = ivalues_central
    key = 'sim_coarse_remapbil'
    ogrid = tuple(x[i] for x, i in zip(grids[key], i_loc_fine))
    ovalues = uf.remapbil(ivalues, igrid, ogrid, ascending)
    data[key] = np.ma.masked_invalid(ovalues.reshape(oshape(key)).T)

    # abort here if there are only missing values in at least one time series
    # do not abort though if the if_all_invalid_use option has been specified
    if np.isnan(if_all_invalid_use):
        if uf.only_missing_values_in_at_least_one_time_series(data):
            print(i_loc_coarse, 'skipped due to missing data')
            return None

    # otherwise continue
    print(i_loc_coarse)

    # compute mean value over all time steps for invalid value sampling
    long_term_mean = {}
    for key, d in data.items():
        long_term_mean[key] = uf.average_valid_values(d, if_all_invalid_use,
            lower_bound, lower_threshold, upper_bound, upper_threshold)

    # do statistical downscaling calendar month by calendar month
    result = data['sim_coarse_remapbil'].copy()
    sum_weights_loc = sum_weights[i_loc_fine].flatten()
    data_this_month = {}
    for month in months:
        # extract data
        for key, d in data.items():
            m = month_numbers[key] == month
            assert np.any(m), f'no data found for month {month} in {key}'
            data_this_month[key] = d[m]

        # do statistical downscaling
        result_this_month = downscale_one_month(data_this_month, long_term_mean,
            lower_bound, lower_threshold, upper_bound, upper_threshold,
            sum_weights=sum_weights_loc, **kwargs)
    
        # put downscaled data into result
        m = month_numbers['sim_coarse_remapbil'] == month
        result[m] = result_this_month

    # save local result of statistical downscaling
    for i, i_loc in enumerate(product(*j_loc_fine)):
        if sim_fine:
            sim_fine[variable][i_loc] = result[:,i]
            sim_fine.sync()
        else:
            from_pool_queue.put(('sim_fine', variable,
                i_loc, result[:,i], i_process))
            # wait for response to ensure that the local result has been saved
            x = to_pool_queues[i_process].get()

    return None



def load_or_save_one_location(obs_fine_path, sim_coarse_path, sim_fine_path):
    """
    Gets items from from_pool_queue, then either loads the requested data from
    one of the input netcdf files and puts that data to the to_pool_queue used
    by the requesting process or saves the data transmitted via from_pool_queue
    to the output netcdf file.

    Parameters
    ----------
    obs_fine_path : str
        Path to input netcdf file with observation at fine resolution.
    sim_coarse_path : str
        Path to input netcdf file with simulation at coarse resolution.
    sim_fine_path : str
        Path to output netcdf file with simulation statistically downscaled to
        fine resolution.

    """
    with Dataset(obs_fine_path, 'r') as obs_fine, \
        Dataset(sim_coarse_path, 'r') as sim_coarse, \
        Dataset(sim_fine_path, 'r+') as sim_fine:
        while True:
            item = from_pool_queue.get()
            if item is None:
                break
            elif item[0] == 'obs_fine':
                x = obs_fine[item[1]][item[2]]
                to_pool_queues[item[3]].put(x)
            elif item[0] == 'sim_coarse':
                x = uf.extended_load(
                    sim_coarse[item[1]], item[2], item[3], item[4])
                to_pool_queues[item[5]].put(x)
            elif item[0] == 'sim_fine':
                sim_fine[item[1]][item[2]] = item[3]
                sim_fine.sync()
                to_pool_queues[item[4]].put('synced')



def downscale(
        obs_fine_path, sim_coarse_path, sim_fine_path,
        n_processes=1, **kwargs):
    """
    Applies the modified MBCn algorithm for statistical downscaling calendar
    month by calendar month and coarse grid cell by coarse grid cell.

    Parameters
    ----------
    obs_fine_path : str
        Path to input netcdf file with observation at fine resolution.
    sim_coarse_path : str
        Path to input netcdf file with simulation at coarse resolution.
    sim_fine_path : str
        Path to output netcdf file with simulation statistically downscaled to
        fine resolution.
    n_processes : int, optional
        Number of processes used for parallel processing.

    Other Parameters
    ----------------
    **kwargs : Passed on to downscale_one_location.

    """
    # downscale every location individually
    global from_pool_queue, to_pool_queues, obs_fine, sim_coarse, sim_fine
    i_locations_coarse = np.ndindex(space_shapes['sim_coarse'])
    sdol = partial(downscale_one_location, **kwargs)
    if n_processes > 1:
        from_pool_queue = mp.Queue()
        to_pool_queues = [mp.Queue() for i in range(n_processes-1)]
        obs_fine, sim_coarse, sim_fine = None, None, None
        reader_writer = mp.Process(target=load_or_save_one_location,
            args=(obs_fine_path, sim_coarse_path, sim_fine_path))
        reader_writer.start()
        with mp.Manager() as manager:
            ipq = manager.Queue()
            for i in range(n_processes-1):
                ipq.put(i)
            def initializer(q):
                global i_process
                i_process = q.get()
            with mp.Pool(n_processes-1, initializer, (ipq,)) as pool:
                foo = list(pool.imap(sdol, i_locations_coarse))
                from_pool_queue.put(None)
                reader_writer.join()
    else:
        from_pool_queue, to_pool_queues = None, None
        with Dataset(obs_fine_path, 'r') as obs_fine, \
            Dataset(sim_coarse_path, 'r') as sim_coarse, \
            Dataset(sim_fine_path, 'r+') as sim_fine:
            foo = list(map(sdol, i_locations_coarse))



def main():
    """
    Prepares and executes the application of the modified MBCn algorithm for
    statistical downscaling.

    """
    # parse command line options and arguments
    parser = OptionParser()
    parser.add_option('-o', '--obs-fine', action='store',
        type='string', dest='obs_fine', default=None,
        help='path to input netcdf file with observation at fine resolution')
    parser.add_option('-s', '--sim-coarse', action='store',
        type='string', dest='sim_coarse', default=None,
        help='path to input netcdf file with simulation at coarse resolution')
    parser.add_option('-f', '--sim-fine', action='store',
        type='string', dest='sim_fine', default=None,
        help=('path to output netcdf file with simulation statistically '
              'downscaled to fine resolution'))
    parser.add_option('-v', '--variable', action='store',
        type='string', dest='variable', default=None,
        help=('name of variable to be downscaled in netcdf files '
              '(has to be the same in all files)'))
    parser.add_option('-m', '--months', action='store',
        type='string', dest='months', default='1,2,3,4,5,6,7,8,9,10,11,12',
        help=('comma-separated list of integers from {1,...,12} representing '
              'calendar months that shall be statistically downscaled'))
    parser.add_option('--n-processes', action='store',
        type='int', dest='n_processes', default=1,
        help='number of processes used for multiprocessing (default: 1)')
    parser.add_option('--n-iterations', action='store',
        type='int', dest='n_iterations', default=20,
        help=('number of iterations used for statistical downscaling (default: '
              '20)'))
    parser.add_option('--lower-bound', action='store',
        type='float', dest='lower_bound', default=None,
        help=('lower bound of variable that has to be respected during '
              'statistical downscaling (default: not specified)'))
    parser.add_option('--lower-threshold', action='store',
        type='float', dest='lower_threshold', default=None,
        help=('lower threshold of variable that has to be respected during '
              'statistical downscaling (default: not specified)'))
    parser.add_option('--upper-bound', action='store',
        type='float', dest='upper_bound', default=None,
        help=('upper bound of variable that has to be respected during '
              'statistical downscaling (default: not specified)'))
    parser.add_option('--upper-threshold', action='store',
        type='float', dest='upper_threshold', default=None,
        help=('upper threshold of variable that has to be respected during '
              'statistical downscaling (default: not specified)'))
    parser.add_option('--randomization-seed', action='store',
        type='int', dest='randomization_seed', default=None,
        help=('seed used during randomization to generate reproducible results '
              '(default: not specified)'))
    parser.add_option('-q', '--n-quantiles', action='store',
        type='int', dest='n_quantiles', default=50,
        help=('number of quantiles used for non-parametric quantile mapping '
              '(default: 50)'))
    parser.add_option('--if-all-invalid-use', action='store',
        type='float', dest='if_all_invalid_use', default=np.nan,
        help=('replace missing values, infs and nans by this value before '
              'statistical downscaling if there are no other values available '
              'in a time series (default: not specified)'))
    parser.add_option('--repeat-warnings', action='store_true',
        dest='repeat_warnings', default=False,
        help='repeat warnings for the same source location (default: do not)')
    (options, args) = parser.parse_args()
    if options.repeat_warnings: warnings.simplefilter('always', UserWarning)

    # do some preliminary checks
    print('checking inputs ...')
    assert options.n_iterations > 0, 'invalid number of iterations'
    months = list(np.sort(np.unique(np.array(
        options.months.split(','), dtype=int))))
    uf.assert_validity_of_months(months)
    uf.assert_consistency_of_bounds_and_thresholds(
        options.lower_bound, options.lower_threshold,
        options.upper_bound, options.upper_threshold)

    # check input data and and make some information globally accessible
    global grids, month_numbers, space_shapes
    grids, space_shapes, month_numbers = {}, {}, {}
    data_variable_dimensions = None
    msg = 'data variable dimensions differ between obs_fine and sim_coarse'
    with Dataset(options.obs_fine, 'r') as obs_fine, \
        Dataset(options.sim_coarse, 'r') as sim_coarse:
        for key in ('sim_coarse', 'obs_fine', 'sim_coarse_remapbil'):
            if key == 'sim_coarse_remapbil':
                grids[key] = grids['obs_fine']
                month_numbers[key] = month_numbers['sim_coarse']
                space_shapes[key] = space_shapes['obs_fine']
                continue
            coords = uf.analyze_input_nc(eval(key), options.variable)
            if data_variable_dimensions is None:
                data_variable_dimensions = tuple(coords.keys())
            else:
                assert tuple(coords.keys()) == data_variable_dimensions, msg
            grids[key] = list(coords.values())[:-1]
            month_numbers[key] = uf.convert_datetimes(
                coords['time'], 'month_number')
            space_shapes[key] = tuple(c.size for c in grids[key])

        # make sure the grids meet the requirements of the downscaling algorithm
        downscaling_factors, ascending, circular = uf.analyze_input_grids(
            grids['sim_coarse'], grids['obs_fine'])

        # create empty output netcdf file
        uf.setup_output_nc(options.sim_fine, sim_coarse, options.variable,
            options, 'sd_', None, obs_fine)

    # compute grid cell weights at fine resolution
    sum_weights = uf.grid_cell_weights(coords)

    # get list of rotation matrices to be used for all locations and months
    if options.randomization_seed is not None:
        np.random.seed(options.randomization_seed)
    rotation_matrices = [uf.generateCREmatrix(np.prod(downscaling_factors))
        for i in range(options.n_iterations)]

    # do statistical downscaling
    spatial_dimensions_str = ', '.join(data_variable_dimensions[:-1])
    print(f'downscaling at coarse location ({spatial_dimensions_str}) ...')
    downscale(
        options.obs_fine, options.sim_coarse, options.sim_fine,
        options.n_processes,
        downscaling_factors=downscaling_factors,
        ascending=ascending,
        circular=circular,
        sum_weights=sum_weights,
        randomization_seed=options.randomization_seed,
        rotation_matrices=rotation_matrices,
        months=months,
        lower_bound=options.lower_bound,
        lower_threshold=options.lower_threshold,
        upper_bound=options.upper_bound,
        upper_threshold=options.upper_threshold,
        n_quantiles=options.n_quantiles,
        if_all_invalid_use=options.if_all_invalid_use,
        variable=options.variable)



if __name__ == '__main__':
    main()
