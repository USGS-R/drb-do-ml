import tensorflow as tf
from tensorflow.keras import layers


class LSTMMetab(tf.keras.Model):
    def __init__(
        self, hidden_size, recurrent_dropout=0, dropout=0,
    ):
        """
        :param hidden_size: [int] the number of hidden units
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
        self.metab_out = layers.Dense(3)
        self.do_range_multiplier = layers.Dense(1)
        self.do_mean_wgt = layers.Dense(1)

    def call(self, inputs, DO_sat):
        h = self.rnn_layer(inputs)
        metab = self.metab_out(h)
        GPP = metab[:, :, 0]
        ER = metab[:, :, 1]
        K = metab[:, :, 2]
        DO_min = DO_sat - ER + K
        DO_max = DO_min + GPP - K
        DO_mean = DO_min + self.do_range_multiplier(DO_max - DO_min) + tf.squeeze(self.do_mean_wgt(h))
        return tf.stack((DO_min, DO_mean, DO_max, GPP, ER, K), axis=2)


