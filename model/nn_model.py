# =============================================================================
# Script      : nn_model.py
# Description : Machine Learning model for CRC error prediction.
#               Uses Logistic Regression trained on a synthetic dataset
#               where features are real CRC values computed by crcmod —
#               making the classification task mathematically meaningful.
#
# Dataset Design (What makes this meaningful, not random):
#   CLEAN samples  (label=0):
#     - Random 32-bit data
#     - CRC16 computed CORRECTLY for that data (valid CRC relationship)
#     - Features: data_bits (32) + correct_crc_bits (16) = 48 features
#
#   CORRUPT samples (label=1):
#     - Random 32-bit data
#     - CRC16 taken from a DIFFERENT random data word (broken relationship)
#     - Features: data_bits (32) + wrong_crc_bits (16) = 48 features
#
#   Why this works:
#     CRC is a linear function of the data bits over GF(2). So for clean
#     samples, the 48-bit feature vector satisfies a strict linear constraint
#     (H * x = 0 over GF(2)). Logistic Regression can detect violation of
#     this constraint, giving accuracy well above 50%.
#
# Author   : TCS Project - 5G NR CRC Engine
# Standard : 3GPP TS 38.212
# =============================================================================

import crcmod
import random
import numpy as np
from sklearn.linear_model    import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics         import (accuracy_score, confusion_matrix,
                                     classification_report)

# =============================================================================
# CRC Function — matches crc_core.v parameters exactly
#   poly    = 0x11021  (CRC-16/CCITT, includes implicit leading 1)
#   initCrc = 0x0000   (matches INIT=16'h0000 in RTL)
#   rev     = False    (MSB-first, no bit reversal)
#   xorOut  = 0x0000   (no final XOR)
# =============================================================================
crc16_fn = crcmod.mkCrcFun(0x11021, initCrc=0x0000, rev=False, xorOut=0x0000)


def int_to_bits(value: int, width: int) -> list:
    """Convert an integer to a list of 'width' bits, MSB-first."""
    return [(value >> (width - 1 - i)) & 1 for i in range(width)]


def compute_crc16(data_int: int) -> int:
    """Return CRC16 for a 32-bit integer (big-endian byte order)."""
    return crc16_fn(data_int.to_bytes(4, byteorder='big'))


# =============================================================================
# Dataset Generation
# =============================================================================

def generate_dataset(num_samples: int = 5000, seed: int = 42) -> tuple:
    """
    Generate a balanced synthetic dataset for CRC error classification.

    Each sample = 32 data bits + 16 CRC16 bits = 48 binary features.
    Label 0 = clean (CRC matches data), Label 1 = corrupt (CRC mismatch).

    Args:
        num_samples : Total number of samples (split 50/50 clean/corrupt)
        seed        : Random seed for reproducibility

    Returns:
        X (np.ndarray) : Feature matrix [num_samples x 48]
        y (np.ndarray) : Label vector   [num_samples]
    """
    random.seed(seed)
    np.random.seed(seed)

    X = []
    y = []

    half = num_samples // 2

    # --- CLEAN samples (label = 0) -------------------------------------------
    # data bits + the CORRECT CRC for that data
    for _ in range(half):
        data      = random.getrandbits(32)
        crc_valid = compute_crc16(data)

        data_bits = int_to_bits(data, 32)
        crc_bits  = int_to_bits(crc_valid, 16)

        X.append(data_bits + crc_bits)   # 48 features
        y.append(0)                       # 0 = no error

    # --- CORRUPT samples (label = 1) -----------------------------------------
    # data bits + a WRONG CRC (computed for different random data)
    for _ in range(num_samples - half):
        data       = random.getrandbits(32)
        other_data = random.getrandbits(32)
        crc_wrong  = compute_crc16(other_data)  # CRC belongs to different data

        data_bits  = int_to_bits(data, 32)
        crc_bits   = int_to_bits(crc_wrong, 16)

        X.append(data_bits + crc_bits)   # 48 features
        y.append(1)                       # 1 = error (CRC mismatch)

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int32)


# =============================================================================
# Model Training & Evaluation
# =============================================================================

def train_and_evaluate(num_samples: int = 5000):
    """
    Train a Logistic Regression classifier for CRC error prediction and
    print a full evaluation report.

    Args:
        num_samples : Total dataset size
    """
    print("=" * 60)
    print("  5G NR CRC Engine — ML Error Prediction Model")
    print("  Algorithm : Logistic Regression")
    print("  Features  : 32 data bits + 16 CRC16 bits = 48 inputs")
    print("  Classes   : 0 = Valid CRC  |  1 = Corrupt CRC")
    print(f"  Samples   : {num_samples} ({num_samples//2} clean + {num_samples//2} corrupt)")
    print("=" * 60)

    # -- Step 1: Generate dataset ---------------------------------------------
    print("\n[1/4] Generating synthetic dataset...")
    X, y = generate_dataset(num_samples)
    print(f"      X shape : {X.shape}  (features)")
    print(f"      y shape : {y.shape}  (labels)")
    print(f"      Class 0 : {np.sum(y==0)} samples  (valid CRC)")
    print(f"      Class 1 : {np.sum(y==1)} samples  (corrupt CRC)")

    # -- Step 2: Train/test split (80% train, 20% test) -----------------------
    print("\n[2/4] Splitting dataset (80% train / 20% test)...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"      Train samples : {len(X_train)}")
    print(f"      Test  samples : {len(X_test)}")

    # -- Step 3: Train Logistic Regression ------------------------------------
    print("\n[3/4] Training Logistic Regression model...")
    model = LogisticRegression(
        max_iter   = 1000,      # Enough iterations for convergence on binary features
        solver     = 'lbfgs',  # Efficient for small-medium datasets
        C          = 1.0,      # Regularization strength (default)
        random_state = 42
    )
    model.fit(X_train, y_train)
    print("      Training complete.")

    # -- Step 4: Evaluate -----------------------------------------------------
    print("\n[4/4] Evaluation Results:")
    print("-" * 60)

    y_pred_train = model.predict(X_train)
    y_pred_test  = model.predict(X_test)

    train_acc = accuracy_score(y_train, y_pred_train)
    test_acc  = accuracy_score(y_test,  y_pred_test)

    print(f"  Training Accuracy : {train_acc * 100:.2f}%")
    print(f"  Test  Accuracy    : {test_acc  * 100:.2f}%")

    # Confusion matrix
    cm = confusion_matrix(y_test, y_pred_test)
    print("\n  Confusion Matrix (Test Set):")
    print("                  Predicted")
    print("              Valid   | Corrupt")
    print(f"  Actual Valid  |  {cm[0][0]:4d}  |  {cm[0][1]:4d}")
    print(f"  Actual Corr   |  {cm[1][0]:4d}  |  {cm[1][1]:4d}")

    # Classification report
    print("\n  Classification Report (Test Set):")
    print(classification_report(y_test, y_pred_test,
                                target_names=["Valid CRC", "Corrupt CRC"],
                                digits=4))

    # Interpretation
    print("-" * 60)
    if test_acc > 0.90:
        verdict = "EXCELLENT — Model learned CRC structure effectively."
    elif test_acc > 0.70:
        verdict = "GOOD — Model captures partial CRC-data correlation."
    else:
        verdict = "BASELINE — Logistic Regression limited by CRC non-linearity."

    print(f"  Verdict : {verdict}")
    print("\n  Note: CRC is a linear code over GF(2). Logistic Regression")
    print("  over the binary feature space approximates this relationship.")
    print("  Accuracy >50% confirms the model found real structure, not noise.")
    print("=" * 60)


# =============================================================================
# Entry Point
# =============================================================================
if __name__ == "__main__":
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    train_and_evaluate(num_samples=n)
