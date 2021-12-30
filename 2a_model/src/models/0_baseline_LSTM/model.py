import tensorflow as tf
from tensorflow.keras import layers


class LSTMModel(tf.keras.Model):
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
        return prediction

