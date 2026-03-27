# 5G NR CRC Engine Project

A comprehensive, industry-standard implementation of a Cyclic Redundancy Check (CRC) subsystem compliant with **3GPP TS 38.212** for 5G New Radio (NR) systems.

## Overview

This project provides a robust hardware-acceleration solution for generating and checking CRC values for 5G NR data streams. It supports multiple polynomial variants including CRC16, CRC24A, CRC24B, and CRC24C, with both sequential (LFSR-based) and parallel (high-performance) architectures.

### Key Features

*   **Standard Compliance**: Fully compliant with **3GPP TS 38.212** specifications.
*   **Multiple CRC Variants**: Support for CRC16, CRC24A, CRC24B, and CRC24C.
*   **Dual Architecture**: 
    *   **Sequential Core**: Efficient 1-bit-per-cycle LFSR implementation.
    *   **Parallel Core**: High-throughput 8-bit-per-cycle implementation.
*   **Integrated Checker**: Real-time error detection logic.
*   **Extensive Verification**: Self-checking testbench with 2,000+ random test cases.
*   **Modern Validation**: Python-based golden reference models and ML-driven error prediction analysis.

## Project Structure

```text
tcsproject/
├── rtl/              # Verilog Source Files
│   ├── crc_core.v     # Basic LFSR-based CRC engine
│   ├── crc_top.v      # Top-level module with multi-CRC support
│   ├── crc_checker.v  # Error detection logic
│   └── crc_parallel.v # High-speed byte-wise implementation
├── tb/               # Testbench and Verification
│   └── tb_crc.v       # 2000+ testcase verification environment
├── model/            # Python Validation Models
│   ├── golden_model.py # Ground-truth reference calculations
│   └── nn_model.py     # ML-based error prediction model
├── results/          # Simulation results and trained models
└── README.md         # Project documentation and usage guide
```

## Getting Started

### Prerequisites

*   **RTL Simulation**: ModelSim, Vivado, or any standard Verilog simulator.
*   **Python Environment**: 
    *   Python 3.8+
    *   `crcmod` (for golden model validation)
    *   `numpy` & `scikit-learn` (for ML models)

### Basic Usage

1.  **Simulate the RTL**:
    *   Load all files in the `rtl/` directory and the testbench in `tb/` into your simulator.
    *   Run the simulation to see the verification results in the console.

2.  **Run the Python Golden Model**:
    ```bash
    cd model/
    python golden_model.py
    ```

3.  **Train the Error Prediction Model**:
    ```bash
    cd model/
    python nn_model.py
    ```

## Specifications

*   **CRC16**: Polynomial `0x1021`, Initial `0xFFFF`
*   **CRC24A**: Polynomial `0x864CFB`, Initial `0x000000`
*   **CRC24B**: Polynomial `0x800063`, Initial `0x000000`
*   **CRC24C**: Polynomial `0x4C11DB`, Initial `0x000000`

---
*Created as part of the 5G NR Hardware R&D development stream.*
