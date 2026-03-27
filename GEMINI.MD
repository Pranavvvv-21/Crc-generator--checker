# gemini.md

## Objective

Build a complete RTL-based CRC Generation and Checker system compliant with 3GPP TS 38.212, including:

* CRC16, CRC24A, CRC24B, CRC24C
* Sequential (bitwise) and Parallel (byte-wise) implementations
* Self-checking testbench with 2000+ testcases
* Python golden model validation
* Neural network-based error prediction
* Waveform generation and analysis

---

## Step 1: RTL Design

### 1.1 Core CRC Engine (LFSR आधारित)

* Implement parameterized module `crc_core`
* Inputs: clk, rst, valid, data_in (1-bit)
* Logic: feedback = MSB XOR data_in
* Shift + XOR with polynomial

### 1.2 Supported Polynomials

* CRC16  -> 0x1021
* CRC24A -> 0x864CFB
* CRC24B -> 0x800063
* CRC24C -> 0x4C11DB

### 1.3 Top Module

* Input: 32-bit data
* Shift register based serialization
* 32 clock cycles processing
* Instantiate all 4 CRC modules

---

## Step 2: Parallel CRC (High Performance)

* Implement byte-wise CRC (8 bits per cycle)
* Use loop-based shifting inside always block
* Improves throughput significantly

---

## Step 3: CRC Checker

* Check if final CRC == 0
* If not zero → error = 1
* Must support all CRC variants

---

## Step 4: Testbench

### Requirements

* 2000 random testcases
* Clock generation (10ns period)
* Reset handling
* Start signal for each data
* Wait for computation completion

### Output

* Print all CRC values
* Log mismatches
* Detect unknown states

---

## Step 5: Golden Model (Python)

* Use crcmod library
* Generate CRC values
* Compare against RTL output

---

## Step 6: Neural Network Model

* Logistic Regression
* Input: data + CRC bits
* Output: error prediction
* Train on synthetic dataset

---

## Step 7: Waveform Generation

### Tools

* ModelSim / GTKWave

### Signals to Observe

* clk, rst
* start
* data
* shift_reg
* bit_cnt
* crc outputs

### Expected Behavior

* Data shifts every clock
* CRC updates sequentially
* Final value stable after 32 cycles

---

## Step 8: Project Structure

CRC_Project/
├── rtl/
├── tb/
├── model/
├── results/
└── README.md

---

## Step 9: Verification Goals

* 2000 testcases pass
* No mismatches
* Matches Python model
* Clean waveform

---

## Step 10: Demo Flow

1. Explain CRC concept
2. Show RTL (LFSR)
3. Show waveform
4. Show testbench results
5. Show Python validation
6. Show ML model

---

## Final Requirement

* Fully synthesizable design
* Clean modular code
* Industry-level explanation
* Zero logical shortcuts (NO XOR FAKE CRC)

# skills.md

## Technical Skills Demonstrated

### Digital Design

* RTL Design (Verilog)
* LFSR implementation
* Sequential and Parallel architectures
* FSM and control logic

### Communication Systems

* CRC (Cyclic Redundancy Check)
* 5G NR standards (3GPP TS 38.212)
* Error detection techniques

### Verification

* Self-checking testbench
* Random test generation
* Waveform debugging
* Functional validation

### Tools

* ModelSim / QuestaSim
* GTKWave
* Python (crcmod, sklearn)

### Embedded & Hardware

* FPGA-ready design
* Timing-aware architecture
* Pipelining concepts

### AI/ML Integration

* Logistic Regression
* Data preprocessing
* Hybrid hardware-AI validation

### Software & Systems

* Python scripting
* Data validation pipelines
* Automation of testing

---

## Project Strength

* Combines VLSI + AI
* Industry-relevant (5G systems)
* Demonstrates both design + verification
* High-performance optimization (parallel CRC)

---

## Resume Impact Line

"Designed and verified a 5G NR compliant CRC engine (CRC16/24A/24B/24C) using Verilog with parallel optimization, validated using Python golden model and enhanced with ML-based error prediction."
