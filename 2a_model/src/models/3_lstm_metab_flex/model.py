import tensorflow as tf
from tensorflow.keras import layers
import sys
sys.path.append("2a_model/src/models/1_lstm_metab")
import metab_utils



class LSTMMetabFlex(tf.keras.Model):
    def __init__(
        self,
        hidden_size,
        elev_mean,
        elev_std,
        light_ratio_mean,
        light_ratio_std,
        elev_idx,
        light_ratio_idx,
        recurrent_dropout=0,
        dropout=0,
    ):
        """
        :param hidden_size: [int] the number of hidden units
        :param elev_mean: [float] mean of elevations
        :param elev_std: [float] standard deviation of elevations
        :param light_ratio_mean: [float] mean of light_ratio
        :param light_ratio_std: [float] standard deviation of light_ratio
        :param recurrent_dropout: [float] value between 0 and 1 for the
        probability of a recurrent element to be zero
        :param dropout: [float] value between 0 and 1 for the probability of an
        input element to be zero
        """
        super().__init__()
        self.rnn_layer = layers.LSTM(
            hidden_size,
            return_sequences=True,
            recurrent_dropout=recurrent_dropout,
            dropout=dropout,
        )
        self.metab_out = layers.Dense(5)
        self.do_range_multiplier = layers.Dense(1)
        self.do_mean_wgt = layers.Dense(1)
        self.do_min_wgt = layers.Dense(1)
        self.do_max_wgt = layers.Dense(1)

        self.elev_mean = elev_mean
        self.elev_std = elev_std
        self.elev_idx = elev_idx
        self.light_ratio_mean = light_ratio_mean
        self.light_ratio_std = light_ratio_std
        self.light_ratio_idx = light_ratio_idx

    def call(self, inputs):
        # get elevations and light ratios and unscale them so they work with
        # the rest of the equations
        elev = (inputs[:, :, self.elev_idx] * self.elev_std) + self.elev_mean
        light_ratio = (inputs[:, :, self.light_ratio_idx] * \
                       self.light_ratio_std) + \
                       self.light_ratio_mean

        # the LSTM produces the metabolism estimates and related values
        h = self.rnn_layer(inputs)
        metab = self.metab_out(h)

        GPP = metab[:, :, 0]
        ER = metab[:, :, 1]
        K600 = metab[:, :, 2]
        z = metab[:, :, 3]
        T = metab[:, :, 4]

        K2 = metab_utils.calc_K2(K600, T)
        k2 = K2 *z

        DO_sat = metab_utils.calc_DO_sat(T, elev)

        er_ratio = 1/48

        # use the metabolism estimates to calculate DO min, max, mean
        DO_min = DO_sat + (ER/k2) + tf.squeeze(self.do_min_wgt(h))
        DO_max = DO_sat + \
                 ((GPP * light_ratio) + ER * er_ratio)/(k2 * er_ratio) + \
                 tf.squeeze(self.do_max_wgt(h))
        DO_mean = DO_min + \
                  self.do_range_multiplier(DO_max - DO_min) + \
                  tf.squeeze(self.do_mean_wgt(h))
        return tf.stack((DO_min, DO_mean, DO_max, GPP, ER, K600, z, T), axis=2)


