# import numpy as np
import tensorflow as tf


def calc_press_pa(elev):
    """
    Calculate the atmospheric pressure at a given elevation. 
    Notes:
    - using "normal temperature and pressure" (20 deg C)
    References:
    - https://en.wikipedia.org/wiki/Barometric_formula

    :param elev: (float) elevation in meters 
    :returns: (float) atmospheric pressure in units of atm
    """
    g0 = 9.80665 # (m/s^2) gravitational constant
    M = 0.0289644 # (kg/mol) molar mass of Earth's air
    R = 8.3144598 # (J/mol/K) universal gas constant
    Tb = 293.15 # reference temperature; 20 deg C
    Pb = 101325 # reference pressure; Pa at 20 deg C

    P = Pb * tf.math.exp((-g0 * M * elev)/(R * Tb))

    return P


def calc_press_atm(elev):
    return calc_press_pa(elev)/101325


def calc_DO_sat(temp_C, elev, salinity=0):
    """
    calculate saturation DO
    :param temp_C: (float) temperature in degrees C
    :param elev: (float) elevation in meters

    """
    # DO just based on temperature
    A1 = -139.34411
    A2 = 1.575701e5
    A3 = 6.642308e7
    A4 = 1.243800e10
    A5 = 8.621949e11

    temp_K = temp_C + 273.15

    DO = tf.math.exp(A1 + (A2/temp_K) -
                     (A3/(temp_K**2)) +
                     (A4/(temp_K**3)) -
                     (A5/(temp_K**4)))


    # salinity factor
    Fs = tf.math.exp(-salinity*(0.017674 - (10.754/temp_K) + (2140.7/(temp_K**2))))


    # pressure factor 
    P_atm = calc_press_atm(elev)
    theta = 0.000975 -\
         temp_C*1.426e-5 +\
         (temp_C**2)*6.436e-8

    u = tf.math.exp(11.8571 - (3840.70/temp_K) - (216961/(temp_K**2)))


    Fp = ((P_atm - u)*(1-(theta*P_atm))) /\
            ((1-u)*(1-theta))

    return DO * Fp * Fs


def calc_K2(K600, T):
    sA = 1568
    sB = -86.04
    sC = 2.142
    sD = -0.0216
    sE = -0.5
    return K600 * ((sA + sB*T + sC*T**2 + sD*T**3)/600)**sE
