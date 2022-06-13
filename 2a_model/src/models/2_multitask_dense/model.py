import tensorflow as tf
from tensorflow.keras import layers


class LSTMModel2Dense(tf.keras.Model):
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
        self.metab_dense = layers.Dense(5)
        self.do_dense = layers.Dense(3)

    @tf.function
    def call(self, inputs):
        h = self.rnn_layer(inputs)
        metab_prediction = self.metab_dense(h)
        do_prediction = self.do_dense(metab_prediction)
        return tf.concat((do_prediction, metab_prediction), axis=2)


class LSTMModelStates(tf.keras.Model):
    """
    LSTM model but returning states (h) instead of the predictions (y)
    """
    def __init__(
        self, hidden_size, num_tasks, recurrent_dropout=0, dropout=0,
    ):
        """
        :param hidden_size: [int] the number of hidden units
        :param num_tasks: [int] number of outputs to predict 
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
        self.dense = layers.Dense(num_tasks)

    @tf.function
    def call(self, inputs):
        h = self.rnn_layer(inputs)
        prediction = self.dense(h)
        return h

