import matplotlib.pyplot as plt
validation_sites = ["01472104", "01473500", "01481500"]
test_sites = ["01475530", "01475548"]

model_order = ["0_baseline_LSTM", "1a_multitask_do_gpp_er",
               "1_metab_multitask", "2_multitask_dense"]

def mark_val_sites(ax):
    labels = [item.get_text() for item in ax.get_xticklabels()]
    new_labels = []
    for l in labels:
        if l in validation_sites:
            new_labels.append("*" + l)
        else:
            new_labels.append(l)

    ax.set_xticklabels(new_labels)

    fig = plt.gcf()    
    fig.text(0.5, 0, "* validation site")

    return ax
