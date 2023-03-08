# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %%
import sys
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# %%
sys.path.insert(0, "../../../2a_model/src/models/2_multitask_dense/")

# %%
from model import LSTMModel2Dense

# %%
m = LSTMModel2Dense(10, 3)

# %%
rep_id = 2

# %%
m.load_weights(f"../../../2a_model/out/models/2_multitask_dense/nstates_10/nep_100/rep_{rep_id}/train_weights/")

# %%
o = m(np.random.randn(4, 5, 30))

# %%
w = m.weights

# %%
w[5]

# %%
w[6]

# %%
ax = sns.heatmap(w[5].numpy(), annot=True)
ax.set_xticklabels(['DO_min', 'DO_mean', 'DO_max'])
ax.set_yticklabels(['GPP', 'ER', 'K600', 'depth', 'temp.water'])

# %%
np.expand_dims(w[6].numpy(), 1)

# %%
ax = sns.heatmap(np.expand_dims(w[6].numpy(), 1), annot=True)

# %%
