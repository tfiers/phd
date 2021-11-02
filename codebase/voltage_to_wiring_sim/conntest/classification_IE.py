from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from warnings import warn

import numpy as np
from nptyping import NDArray

from .classification import apply_threshold
from .permutation_test import ConnectionTestSummary
from ..support.misc import fill_dataclass


NumPrePostPairs = Any
IndexArray = NDArray[(NumPrePostPairs,), bool]


def evaluate_classification(
    is_classified_as_connected: IndexArray,
    is_connected: IndexArray,
    is_inhibitory: IndexArray,
) -> ClassificationEvaluation:
    is_excitatory = ~is_inhibitory
    is_TP_inh = is_inhibitory & is_classified_as_connected & is_connected
    is_TP_exc = is_excitatory & is_classified_as_connected & is_connected
    is_FP = is_classified_as_connected & ~is_connected
    is_TN = ~is_classified_as_connected & ~is_connected
    is_FN_inh = is_inhibitory & ~is_classified_as_connected & is_connected
    is_FN_exc = is_excitatory & ~is_classified_as_connected & is_connected
    num_TP_inh = np.sum(is_TP_inh)
    num_TP_exc = np.sum(is_TP_exc)
    num_FP = np.sum(is_FP)
    num_TN = np.sum(is_TN)
    num_FN_inh = np.sum(is_FN_inh)
    num_FN_exc = np.sum(is_FN_exc)
    num_positive_inh = num_TP_inh + num_FN_inh
    num_positive_exc = num_TP_exc + num_FN_exc
    num_negative = num_FP + num_TN
    if num_positive_inh > 0:
        TPR_inh = num_TP_inh / num_positive_inh
    else:
        warn("No connected inhibitory (pre,post)-pairs. TPR_inh is meaningless.")
        TPR_inh = np.nan
    if num_positive_exc > 0:
        TPR_exc = num_TP_exc / num_positive_exc
    else:
        warn("No connected excitatory (pre,post)-pairs. TPR_exc is meaningless.")
        TPR_exc = np.nan
    if num_negative > 0:
        FPR = num_FP / num_negative
    else:
        warn("No unconnected (pre,post)-pairs. FPR is meaningless.")
        FPR = np.nan

    return fill_dataclass(ClassificationEvaluation, locals())


@dataclass
class ClassificationEvaluation:
    is_TP_inh: IndexArray
    is_TP_exc: IndexArray
    is_FP: IndexArray
    is_TN: IndexArray
    is_FN_inh: IndexArray
    is_FN_exc: IndexArray
    num_TP_inh: int
    num_TP_exc: int
    num_FP: int
    num_TN: int
    num_FN_inh: int
    num_FN_exc: int
    TPR_inh: float
    TPR_exc: float
    FPR: float


@dataclass
class Classification:
    p_value_threshold: float
    is_classified_as_connected: IndexArray
    evaluation: ClassificationEvaluation


def sweep_threshold(
    conntest_summaries: list[ConnectionTestSummary],
    is_connected: IndexArray,
    is_inhibitory: IndexArray,
) -> list[Classification]:
    results = []
    p_values = [summary.p_value for summary in conntest_summaries]
    thresholds = np.unique([0] + p_values)
    for p_value_threshold in thresholds:
        is_classified_as_connected = apply_threshold(
            conntest_summaries, p_value_threshold
        )
        evaluation = evaluate_classification(
            is_classified_as_connected, is_connected, is_inhibitory
        )
        result = Classification(
            p_value_threshold, is_classified_as_connected, evaluation
        )
        results.append(result)
    return results


def calc_AUCs(threshold_sweep: list[Classification]) -> (float, float):
    TPR_inhs = [tr.evaluation.TPR_inh for tr in threshold_sweep]
    TPR_excs = [tr.evaluation.TPR_exc for tr in threshold_sweep]
    FPRs = [tr.evaluation.FPR for tr in threshold_sweep]
    AUC_inh = 0
    AUC_exc = 0
    # this is not the same as `np.trapz` e.g.
    for i in range(len(FPRs) - 1):
        AUC_inh += (FPRs[i + 1] - FPRs[i]) * TPR_inhs[i]
        AUC_exc += (FPRs[i + 1] - FPRs[i]) * TPR_excs[i]
    return AUC_inh, AUC_exc
