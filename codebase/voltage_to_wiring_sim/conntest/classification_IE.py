from __future__ import annotations

from dataclasses import dataclass
from typing import Any

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
    is_TP = is_classified_as_connected & is_connected
    is_TP_exc = is_TP & is_excitatory
    is_TP_inh = is_TP & is_inhibitory
    is_FP = is_classified_as_connected & ~is_connected
    num_TP = np.sum(is_TP)
    num_TP_exc = np.sum(is_TP_exc)
    num_TP_inh = np.sum(is_TP_inh)
    num_FP = np.sum(is_FP)
    num_positive = np.sum(is_connected)
    num_positive_exc = np.sum(is_excitatory & is_connected)
    num_positive_inh = np.sum(is_inhibitory & is_connected)
    num_negative = np.sum(~is_connected)
    TPR = (num_TP / num_positive) if num_positive > 0 else np.nan
    TPR_exc = (num_TP_exc / num_positive_exc) if num_positive_exc > 0 else np.nan
    TPR_inh = (num_TP_inh / num_positive_inh) if num_positive_inh > 0 else np.nan
    FPR = (num_FP / num_negative) if num_negative > 0 else np.nan

    return fill_dataclass(ClassificationEvaluation, locals())


@dataclass
class ClassificationEvaluation:
    is_TP: IndexArray
    is_TP_exc: IndexArray
    is_TP_inh: IndexArray
    is_FP: IndexArray
    num_TP: int
    num_TP_exc: int
    num_TP_inh: int
    num_FP: int
    TPR: float
    TPR_exc: float
    TPR_inh: float
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


def calc_AUCs(threshold_sweep: list[Classification]) -> (float, float, float):
    TPRs = [tr.evaluation.TPR for tr in threshold_sweep]
    TPR_excs = [tr.evaluation.TPR_exc for tr in threshold_sweep]
    TPR_inhs = [tr.evaluation.TPR_inh for tr in threshold_sweep]
    FPRs = [tr.evaluation.FPR for tr in threshold_sweep]
    AUC = 0
    AUC_exc = 0
    AUC_inh = 0
    # this is not the same as `np.trapz` e.g.
    for i in range(len(FPRs) - 1):
        dx = FPRs[i + 1] - FPRs[i]
        AUC += dx * TPRs[i]
        AUC_exc += dx * TPR_excs[i]
        AUC_inh += dx * TPR_inhs[i]
    return AUC, AUC_exc, AUC_inh
