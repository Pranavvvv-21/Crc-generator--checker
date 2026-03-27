# =============================================================================
# Script      : golden_model.py
# Description : Python golden reference model for 5G NR CRC Engine.
#               Computes CRC16 and CRC24A on random 32-bit data vectors
#               using the crcmod library. Output format matches the RTL
#               testbench $display lines for direct side-by-side comparison.
#
# Polynomial Configuration (matches crc_core.v / crc_top.v):
#   CRC16  : poly=0x1021, init=0x0000, MSB-first, no reflection, no final XOR
#   CRC24A : poly=0x864CFB, init=0x000000, MSB-first, no reflection, no final XOR
#
# RTL Testbench Output Format (tb_crc.v):
#   Test# | Data       | CRC16  | CRC24A   | ...
#   0     | 0012345678 | ab12   | 8f3c22   | ...
#
# Usage:
#   python golden_model.py              # Run 100 tests (default)
#   python golden_model.py 2000         # Run 2000 tests (match testbench)
#
# Install dependency:
#   pip install crcmod
#
# Author   : TCS Project - 5G NR CRC Engine
# Standard : 3GPP TS 38.212
# =============================================================================

import crcmod
import random
import sys

# =============================================================================
# CRC Function Definitions
# =============================================================================
# crcmod poly notation: include the leading implicit '1' bit.
#   CRC16  (16-bit) : 0x1021 → crcmod poly = 0x1_1021
#   CRC24A (24-bit) : 0x864CFB → crcmod poly = 0x1_864CFB
#
# Parameters match crc_core.v:
#   initCrc = 0x0000 / 0x000000  (INIT parameter in RTL)
#   rev     = False              (MSB-first, no bit reversal)
#   xorOut  = 0x0                (no final XOR applied)
# =============================================================================

crc16_fn  = crcmod.mkCrcFun(0x11021,   initCrc=0x0000,   rev=False, xorOut=0x0000)
crc24a_fn = crcmod.mkCrcFun(0x1864CFB, initCrc=0x000000, rev=False, xorOut=0x000000)


def compute_crcs(data_int: int) -> tuple:
    """
    Compute CRC16 and CRC24A for a 32-bit integer input.

    Args:
        data_int : 32-bit unsigned integer (matches RTL 'data' input)

    Returns:
        (crc16, crc24a) as integers
    """
    data_bytes = data_int.to_bytes(4, byteorder='big')  # MSB-first (matches RTL shift order)
    return crc16_fn(data_bytes), crc24a_fn(data_bytes)


def run_golden_model(num_tests: int = 100, seed: int = 42):
    """
    Run the CRC golden model on 'num_tests' random 32-bit vectors.
    Output format mirrors tb_crc.v $display lines for direct comparison.

    Args:
        num_tests : Number of random test vectors to generate
        seed      : Random seed for reproducibility (set 0 for true random)
    """
    if seed:
        random.seed(seed)

    # -- Header (mirrors testbench banner) ------------------------------------
    print("=" * 65)
    print("  5G NR CRC Engine — Python Golden Reference Model")
    print("  Standard  : 3GPP TS 38.212")
    print(f"  Testcases : {num_tests}")
    print(f"  Seed      : {seed if seed else 'random'}")
    print("=" * 65)
    print(f"{'Test#':<6} | {'Data':>10} | {'CRC16':>6} | {'CRC24A':>8} | Status")
    print("-" * 65)

    for i in range(num_tests):
        # Generate random 32-bit data word
        data = random.getrandbits(32)

        # Compute CRCs using golden functions
        crc16, crc24a = compute_crcs(data)

        # -- Output line matches RTL testbench format exactly -----------------
        # RTL: "%-6d | %010h | %04h | %06h | ..."
        print(f"{i:<6} | {data:010x} | {crc16:04x}   | {crc24a:06x}   | GOLDEN")

    print("=" * 65)
    print(f"  DONE: {num_tests} golden CRC values generated.")
    print("  Compare CRC16 and CRC24A columns with RTL tb_crc.v output.")
    print("  Mismatch in any row = RTL implementation error.")
    print("=" * 65)


# =============================================================================
# Entry Point
# =============================================================================
if __name__ == "__main__":
    # Accept optional CLI argument for number of tests
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    run_golden_model(num_tests=n)
