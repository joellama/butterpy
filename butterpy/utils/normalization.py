"""
Utilities for Solar normalization.

Contains
--------
solar_regions (function):
    Runs the `regions` function with Solar inputs.

fit_spot_counts (function):
    Computes spot counts and fits a squared sine function
    to the monthly spot count.

NOTE
----
According to Hathaway (2015), LRSP 12: 4, Figure 2, the peak monthly
    sunspot number varies from cycle to cycle, with peaks as low as 
    50 spots/month (1818, Cycle 6) and as high as 200 (1960, Cycle 19).
    The Solar normalization should return an amplitude somewhere in this range.
"""

import numpy as np
import matplotlib.pyplot as plt
from butterpy.core import regions
from plots import monthly_spot_number


def solar_regions():
    """
    Runs the `regions` function with Solar inputs:

    activityrate = 1,
    minlat = 7,
    maxlat = 35,
    cyclelength = 11,
    cycleoverlap = 1,
    ndays = 100 years
    """
    return regions(activityrate=1, minlat=7, maxlat=35, 
        cyclelength=11, cycleoverlap=1, ndays=365*100)


def fit_spot_counts(spots, make_plot=True):
    """
    Computes spot counts and fits the function

        A sin^2(pi*t/P + phi),
    
    where A is the amplitude, t is time, P is the cycle period,
    and phi is a temporal shift. The form of this function is chosen
    to resemble the form of the emergence rate, defined in `regions`.

    Parameters
    ----------
    spots (astropy Table):
        The output of `regions` containing the table of star spots.

    make_plot (bool, optional, default=True):
        Whether to make and display the plot.

    Returns
    -------
    A (float):
        The spot count amplitude with units of spots/month
    """
    time, nspots = monthly_spot_number(spots, make_plot=False)

    # Fit Asin^2(pi*t/P + phi), based on emergence rate definition.
    from scipy.optimize import curve_fit

    def f(t, A, P, phi):
        return A*np.sin(np.pi*t/P + phi)**2
    
    T = np.array(time)
    N = np.array(nspots)
    popt, _ = curve_fit(f, T, N, p0=(25, 11, 0))
    A = popt[0]

    if make_plot:
        plt.figure()
        plt.plot(T, N, "k", label="Smoothed Spot Count")
        plt.plot(T[::10], f(T[::10], *popt), "bo", ms=8, label=f"Model with A={A:.2f}")
        plt.xlabel("Time (years)")
        plt.ylabel("Monthly Sunspot Number")
        plt.legend()
        plt.show()
    return A

if __name__ == "__main__":
    np.random.seed(88)
    sun = solar_regions()
    A = fit_spot_counts(sun, make_plot=False)
    print(f"amplitude: {A} spots/month")
