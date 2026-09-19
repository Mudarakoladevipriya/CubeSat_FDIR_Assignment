# FPGA-Based CubeSat Fault Detection, Isolation, and Protection (FDIR) System

An autonomous, hardware-deterministic Fault Detection, Isolation, and Recovery/Protection (FDIR) controller designed for a 3U CubeSat architecture using Verilog RTL. The system independently monitors spacecraft health metrics, applies persistence filtering, evaluates fault severity, latches critical states, and manages subsystem power states without relying on main On-Board Computer (OBC) software.

---

## 🛰️ System Architecture Overview

The system operates as an independent supervisor sitting between simulated spacecraft subsystem sensors, the power control lines, and the main OBC.


### Module Hierarchy

1. **`top_level.v`**: Top-level wrapper interconnecting all internal sub-modules.
2. **`sensor_interface.v`**: Passes digital sensor readings into internal logic.
3. **`fault_detector.v`**: Compares sensor telemetry against preset bounds and enforces counter-based persistence filtering.
4. **`watchdog.v`**: Tracks `obc_heartbeat` rising edges and asserts a timeout fault if missed for >100 cycles.
5. **`fault_manager.v`**: Prioritizes multi-fault events and classifies system fault severity into Warning, Recoverable, or Critical levels.
6. **`fault_register.v`**: 8-bit register mapping latched fault history accessible via telemetry.
7. **`protection_fsm.v`**: Finite-state machine managing spacecraft protection states (`INIT`, `MONITOR`, `FAULT_ANALYSIS`, `PROTECT`, `SAFE_MODE`, `RECOVERY`, `LATCH`).
8. **`uart_interface.v`**: 8-N-1 UART interface operating at 9600 baud allowing OBC telemetry readout and authorization of `FAULT_CLEAR` commands (`0xCC`).

---

## 📋 Fault Register Map (8-Bit)

| Bit | Fault Flag Name | Trigger Condition | Assigned Severity |
| :---: | :--- | :--- | :--- |
| **0** | Battery Under-Voltage | `battery_voltage < 7.0 V` | Level 3 (Critical) |
| **1** | Battery Over-Voltage | `battery_voltage > 8.4 V` | Level 3 (Critical) |
| **2** | Payload Over-Current | `payload_current > 2.0 A` | Level 2 (Recoverable) |
| **3** | FPGA Over-Temperature | `fpga_temperature > 85 °C` | Level 2 (Recoverable) |
| **4** | OBC Watchdog Timeout | No heartbeat rising edge for 100 cycles | Level 3 (Critical) |
| **5** | Comm Timeout | `comm_status = 0` for persistence count | Level 2 (Recoverable) |
| **6** | Payload Failure | `payload_status = 0` for persistence count | Level 2 (Recoverable) |
| **7** | Reserved | — | — |

*Note: An explicit UART byte command `0xCC` sent to `uart_rx` clears latched flags once conditions return to nominal.*

---

## 🔄 Protection FSM State Transitions

| State | Condition | Next State | `payload_enable` | `safe_mode` |
| :--- | :--- | :--- | :---: | :---: |
| **`INIT`** | Reset released | `MONITOR` | `1` | `0` |
| **`MONITOR`** | `fault_detected = 1` | `FAULT_ANALYSIS` | `1` | `0` |
| **`FAULT_ANALYSIS`** | Critical Severity | `SAFE_MODE` | `1` | `0` |
| **`FAULT_ANALYSIS`** | Recoverable Severity | `PROTECT` | `1` | `0` |
| **`FAULT_ANALYSIS`** | Warning / Nominal | `MONITOR` | `1` | `0` |
| **`PROTECT`** | `fault_detected = 0` | `RECOVERY` | `0` | `0` |
| **`SAFE_MODE`** | Unconditional | `LATCH` | `0` | `1` |
| **`RECOVERY`** | Unconditional | `MONITOR` | `1` | `0` |
| **`LATCH`** | `fault_clear = 1` (via UART `0xCC`) | `RECOVERY` | `0` | `1` |

---

## 🧪 Simulation & Verification

The included testbench (`tb/tb_top_level.v`) tests 7 key operational scenarios:

1. **Test 1: Normal Operation** – Validates nominal pass-through without fault assertions.
2. **Test 2: Persistent Over-Current** – Verifies payload power disconnect when current exceeds 2.0A past persistence time.
3. **Test 3: Transient Current Spike** – Confirms short current spikes below persistence duration are ignored.
4. **Test 4: OBC Heartbeat Failure** – Simulates OBC failure and verifies watchdog timeout assertion.
5. **Test 5: FPGA Over-Temperature** – Tests thermal detection threshold at 90°C.
6. **Test 6: Multiple Faults** – Demonstrates severity override (Critical Level 3 over Level 2).
7. **Test 7: Fault Clear** – Sends `0xCC` over UART to verify state recovery and fault latch clearing.

### Running in Xilinx Vivado

1. Open Xilinx Vivado and create a new RTL project.
2. Add all source files from the `rtl/` folder to **Design Sources**.
3. Add `tb/tb_top_level.v` to **Simulation Sources**.
4. Set `tb_top_level` as the top module in simulation settings.
5. Run **Behavioral Simulation** (`Run Simulation -> Run Behavioral Simulation`).

---

## 📁 Repository Structure

```text
.
├── README.md               # Project documentation
├── Report.pdf              # Complete engineering design report
├── rtl/                    # Synthesizable Verilog RTL source files
│   ├── top_level.v
│   ├── sensor_interface.v
│   ├── fault_detector.v
│   ├── watchdog.v
│   ├── fault_manager.v
│   ├── fault_register.v
│   ├── protection_fsm.v
│   └── uart_interface.v
└── tb/                     # Simulation testbench files
    └── tb_top_level.v
