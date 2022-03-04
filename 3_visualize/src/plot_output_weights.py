# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %%
import sys
import numpy as np
import matplotlib.pyplot as plt

# %%
sys.path.insert(0, "../../2a_model/src/models/0_baseline_LSTM/")

# %%
from model import LSTMModel

# %%
m = LSTMModel(10, 3)

# %%
m.load_weights("../../2a_model/out/models/0_baseline_LSTM/train_weights/")

# %%
data = np.load("../../2a_model/out/models/0_baseline_LSTM/prepped.npz", allow_pickle=True)

# %%
y = m(data['x_val'])

# %%
w = m.weights

# %%
ax = plt.imshow(w[3].numpy())
fig = plt.gcf()
cbar = fig.colorbar(ax)
cbar.set_label('weight value')
ax = plt.gca()
ax.set_yticks(list(range(10)))
ax.set_yticklabels(f"h{i}" for i in range(10))
ax.set_ylabel('hidden state')
ax.set_xticks(list(range(3)))
ax.set_xticklabels(["DO_max", "DO_mean", "DO_min"], rotation=90)
ax.set_xlabel('output variable')
plt.tight_layout()
plt.savefig('../out/hidden_states/out_weights.jpg', bbox_inches='tight')

# %%
