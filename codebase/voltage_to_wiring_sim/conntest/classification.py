from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np

from nptyping import NDArray
from .permutation_test import ConnectionTestSummary


def apply_threshold(
    conntest_summaries: list[ConnectionTestSummary],
    p_value_threshold: float,
) -> Classification:
    is_classified_as_connected = np.array(
        [
            test_summary.p_value <= p_value_threshold
            for test_summary in conntest_summaries
        ]
    )
    return Classification(p_value_threshold, is_classified_as_connected)


NumPrePostPairs = Any
IndexArray = NDArray[(NumPrePostPairs,), bool]


@dataclass
class Classification:
    p_value_threshold: float
    is_classified_as_connected: IndexArray


def evaluate_classification(
    classification: Classification,
    is_connected: IndexArray,
) -> ClassificationEvaluation:
    is_classified_as_connected = classification.is_classified_as_connected
    is_TP = is_classified_as_connected & is_connected
    is_FP = is_classified_as_connected & ~is_connected
    is_TN = ~is_classified_as_connected & ~is_connected
    is_FN = ~is_classified_as_connected & is_connected
    num_TP = np.sum(is_TP)
    num_FP = np.sum(is_FP)
    num_TN = np.sum(is_TN)
    num_FN = np.sum(is_FN)
    TPR = num_TP / (num_TP + num_FN)
    FPR = num_FP / (num_FP + num_TN)
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


def sweep_threshold(
    conntest_summaries: list[ConnectionTestSummary],
    is_connected: IndexArray,
) -> tuple[list[Classification], list[ClassificationEvaluation]]:
    classifications = []
    evaluations = []
    thresholds = [summary.p_value for summary in conntest_summaries]
    for p_value_threshold in thresholds:
        classification = apply_threshold(conntest_summaries, p_value_threshold)
        evaluation = evaluate_classification(classification, is_connected)
        classifications.append(classification)
        evaluations.append(evaluation)
    return classifications, evaluations
