from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any
from warnings import warn

import numpy as np
import seaborn as sns
from matplotlib.axes import Axes
from matplotlib.colors import to_rgb
from matplotlib.patches import Patch
from nptyping import NDArray

from .permutation_test import ConnectionTestSummary
from ..support.plot_util import new_plot_if_None


NumPrePostPairs = Any
IndexArray = NDArray[(NumPrePostPairs,), bool]


def apply_threshold(
    conntest_summaries: list[ConnectionTestSummary],
    p_value_threshold: float,
) -> IndexArray:
    is_classified_as_connected = np.array(
        [
            test_summary.p_value <= p_value_threshold
            for test_summary in conntest_summaries
        ]
    )
    return is_classified_as_connected


def evaluate_classification(
    is_classified_as_connected: IndexArray,
    is_connected: IndexArray,
) -> ClassificationEvaluation:
    is_TP = is_classified_as_connected & is_connected
    is_FP = is_classified_as_connected & ~is_connected
    is_TN = ~is_classified_as_connected & ~is_connected
    is_FN = ~is_classified_as_connected & is_connected
    num_TP = np.sum(is_TP)
    num_FP = np.sum(is_FP)
    num_TN = np.sum(is_TN)
    num_FN = np.sum(is_FN)
    num_positive = num_TP + num_FN
    num_negative = num_FP + num_TN
    if num_positive > 0:
        TPR = num_TP / num_positive
    else:
        warn("No connected (pre,post)-pairs. TPR is meaningless.")
        TPR = np.nan
    if num_negative > 0:
        FPR = num_FP / num_negative
    else:
        warn("No unconnected (pre,post)-pairs. FPR is meaningless.")
        FPR = np.nan
    return ClassificationEvaluation(
        is_TP, is_FP, is_TN, is_FN, num_TP, num_FP, num_TN, num_FN, TPR, FPR
    )


@dataclass
class ClassificationEvaluation:
    is_TP: IndexArray
    is_FP: IndexArray
    is_TN: IndexArray
    is_FN: IndexArray
    num_TP: int
    num_FP: int
    num_TN: int
    num_FN: int
    TPR: float
    FPR: float


@dataclass
class Classification:
    p_value_threshold: float
    is_classified_as_connected: IndexArray
    evaluation: ClassificationEvaluation


def sweep_threshold(
    conntest_summaries: list[ConnectionTestSummary],
    is_connected: IndexArray,
) -> list[Classification]:
    results = []
    p_values = [summary.p_value for summary in conntest_summaries]
    thresholds = np.unique([0] + p_values)
    for p_value_threshold in thresholds:
        is_classified_as_connected = apply_threshold(
            conntest_summaries, p_value_threshold
        )
        evaluation = evaluate_classification(is_classified_as_connected, is_connected)
        result = Classification(
            p_value_threshold, is_classified_as_connected, evaluation
        )
        results.append(result)
    return results


def plot_classifications(classifications: list[Classification], ax: Axes = None):
    # We'll draw a matrix with four colours.
    # cols = p-value threshold
    # rows = pre-post-pairs
    num_p_value_thresholds = len(classifications)
    num_pre_post_pairs = len(classifications[0].is_classified_as_connected)
    matrix = np.empty((num_pre_post_pairs, num_p_value_thresholds, 3))  # 3 = rgb
    for threshold_nr, classif in enumerate(classifications):  # cols
        for pair_nr in range(num_pre_post_pairs):  # rows
            if classif.evaluation.is_TP[pair_nr]:
                color = EvalColors.TP.value
            elif classif.evaluation.is_FP[pair_nr]:
                color = EvalColors.FP.value
            elif classif.evaluation.is_TN[pair_nr]:
                color = EvalColors.TN.value
            elif classif.evaluation.is_FN[pair_nr]:
                color = EvalColors.FN.value
            else:
                color = to_rgb("black")
            matrix[pair_nr, threshold_nr] = color
    ax = new_plot_if_None(ax)
    ax.imshow(matrix, aspect="auto")

    # Draw a border around each cell (using the 'minor' grid)
    ax.grid(False, "major")
    ax.grid(True, "minor", color="k", lw=0.5)
    ax.set_xticks(np.arange(0, num_p_value_thresholds) + 0.5, minor=True)
    ax.set_yticks(np.arange(0, num_pre_post_pairs) + 0.5, minor=True)

    # Add xticklabels manually
    p_value_thresholds = [c.p_value_threshold for c in classifications]
    num_xlabels = 8
    xlabel_stride = round(num_p_value_thresholds / num_xlabels)
    ax.set_xticks(np.arange(0, num_p_value_thresholds)[::xlabel_stride])
    ax.set_xticklabels(p_value_thresholds[::xlabel_stride])

    legend_patches = []
    for color, label in zip(EvalColors, EvalLabels):
        patch = Patch(
            facecolor=color.value,
            label=label.value,
            edgecolor="black",
            linewidth=0.5,
        )
        legend_patches.append(patch)
    ax.legend(handles=legend_patches)

    ax.set_xlabel("p-value threshold")
    ax.set_ylabel("(pre-post)-pair")

    return ax


class EvalColors(Enum):
    TP = sns.desaturate(to_rgb("C0"), 0.8)  # blue
    FN = sns.set_hls_values(TP, l=0.8)  # light blue
    TN = sns.desaturate(to_rgb("C1"), 0.9)  # orange
    FP = sns.set_hls_values(TN, l=0.8)  # light orange


class EvalLabels(Enum):
    TP = "True positives"
    FN = "False negatives"
    TN = "True negatives"
    FP = "False positives"


def plot_ROC(classifications: list[Classification], ax: Axes = None, **kwargs):
    TPRs = [c.evaluation.TPR for c in classifications]
    FPRs = [c.evaluation.FPR for c in classifications]
    ax = new_plot_if_None(ax)
    step_kwargs = dict(marker=".")
    step_kwargs.update(kwargs)
    ax.step(FPRs, TPRs, where="post", clip_on=False, **step_kwargs)
    ax.fill_between(FPRs, TPRs, step="post", alpha=0.1, color="grey")
    ax.set_aspect("equal")
    ax.set(
        xlabel="#FP / #unconnected",
        ylabel="#TP / #connected",
        xlim=(0, 1),
        ylim=(0, 1),
    )
    return ax
