# 🧬 Bio-Logi: Silicon Protein Matrix

Welcome to the **Bio-Logi** Silicon Protein simulation engine. This project implements a decentralized, bio-inspired neuromorphic architecture in Zig, designed to run directly on FPGA hardware without requiring a central CPU or heavy operating system runtime.

```
      ___           ___                                 
     /\  \         /\  \         _____                  
    /::\  \       /::\  \       /::\  \        ___      
   /:/\:\  \     /:/\:\  \     /:/\:\  \      /\__\     
  /::\~\:\  \   /:/  \:\  \   /:/  \:\__\    /:/__/     
 /:/\:\ \:\__\ /:/__/ \:\__\ /:/__/ \:|__|  /::\  \     
 \/__\:\/:/  / \:\  \ /:/  / \:\  \ /:/  /  \/\:\  \__  
      \::/  /   \:\  /:/  /   \:\  /:/  /    ~~\:\/\__\ 
      /:/  /     \:\/:/  /     \:\/:/  /        \::/  / 
     /:/  /       \::/  /       \::/  /         /:/  /  
     \/__/         \/__/         \/__/          \/__/   
```

---

## 🚀 Quick Start & Onboarding

Get the project built, tested, and running in under a minute.

### 1. Prerequisites
Ensure you have the **Zig Compiler (v0.12 or newer)** installed.
Verify your installation:
```bash
zig version
```

### 2. Build the Project
Compile the core logic binary:
```bash
zig build
```

### 3. Run the Entire Test Suite
Run the unit test runner covering cell size constraints, sensory fusion, echolocation, and plasticity:
```bash
zig build test
```

### 4. Run the Latency Benchmark
Compare local grid-hopping delays against direct **AXI Highway (Long-Range Axon)** routing:
```bash
zig run src/bench.zig
```
*(Expects ~94.1% latency reduction!)*

---

## 🖥️ Live Simulations

This repository contains interactive terminal dashboards representing different subsystems of the neuromorphic spinal processor.

| Command | Subsystem | Description |
| :--- | :--- | :--- |
| `zig run src/sentinel.zig` | **Sentinel Sensory Fusion** | Visualizes 5-sense + RF target locking with real-time live map. |
| `zig run src/sonar.zig` | **Decentralized Sonar** | Fires pulses, reflects waves at an obstacle, and measures echo returning at tick 37 (dist 36). |
| `zig run src/learning.zig` | **Hebbian Plasticty (STDP)** | Simulates causal pre-before-post timing to strengthen synaptic weights dynamically. |
| `zig run src/reward_learning.zig`| **Reward Reinforcement** | Trains a simulated agent to master path wiring to target nodes using neuromodulator waves. |

---

## 🌐 Interactive Web Demo

For a rich, visual, interactive demonstration of the neuromorphic cellular automata architecture, run the built-in demo server:

```bash
# Start the demo server from the project directory
python3 -m http.server --directory demo 8080
```
Open **[http://localhost:8080](http://localhost:8080)** in your browser to interact with:
* **Sentinel Sensory Fusion:** Watch multi-modal sensory ripples and locks onto target anomalies.
* **Decentralized Sonar:** Place custom obstacles and measure return echo distance.
* **Hebbian Plasticity (STDP):** Click cells to stimulate them and watch connections strengthen (LTP) or weaken (LTD) based on spike timing.
* **AXI Latency Highway:** View live comparison of direct 1-cycle routing vs 17-cycle local hop propagation.

---

## 🔋 Core Architecture Concepts

* **Metabolic Constraint (`energy`):** Firing drains local cell energy; cells recover over time. This naturally prevents runaway positive feedback loops.
* **AXI Highways (Long-Range Axons):** High-speed bypass pathways enabling `O(1)` routing across large grids, bypasses `O(N)` propagation lag.
* **FPGA Isomorphism:** All core logic elements are represented as `packed struct`s comptime-validated to be exactly `128-bit` or `256-bit` for Block-RAM (BRAM) alignment.
* **Resilient Overload Safety:** Under 100% sensory overload noise, the cells naturally enter a metabolic "Paralytic State" rather than thrashing or crashing.

---

## 🛠️ Development Workflow

When writing new cells or logic, please conform to our engineering guidelines:

1. **No Standard Library in Tick Loops:** Tick methods must be OS-free and heap-allocation-free to maintain sub-microsecond determinism.
2. **Saturating Arithmetic:** Always use Zig's saturating operators (`+|`, `-|`) for state adjustments to prevent overflow/underflow panics.
3. **Comptime Checks:** Ensure every new FPGA structure asserts its target size at compile-time:
   ```zig
   comptime {
       if (@bitSizeOf(MyStruct) != 256) {
           @compileError("MyStruct must be exactly 256 bits for FPGA Block RAM alignment");
       }
   }
   ```
