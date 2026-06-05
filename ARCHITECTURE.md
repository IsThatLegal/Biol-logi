# Bio-Logi: Silicon Protein Architecture

## Vision
To create a decentralized, bio-inspired nervous system for robotics that is "Silicon-Ready" (FPGA-optimized), energy-aware, and capable of emergent "Flow State" behavior without a central CPU.

## Core Innovation: The Metabolic Logic Matrix
Unlike standard Neural Networks or Cellular Automata, the **Silicon Protein** architecture introduces **Metabolic Constraint** as a primary driver of logic.

1. **Metabolic Awareness:** Every node (Protein) has an `energy` state. High-frequency firing depletes energy, requiring "recovery" ticks. This prevents runaway feedback loops (Stability).
2. **Nervous System Resilience:** Proven via "Flashbang Stress Tests." The system enters a safe "Paralytic State" under 100% sensory noise, preventing computational explosion, and recovers fully once the stimulus subsides.
3. **Bit-Perfect Silicon Mapping:** Data structures are `packed structs` (128-bit/256-bit) aligned to FPGA Block RAM (BRAM).
4. **Cooperative Resonance:** Signal extraction is achieved through neighbor-to-neighbor confidence spreading, allowing lock-on to life-signs in extreme noise environments.

## Patentable Pillars
- **Energy-Constrained Decentralized Logic:** Using metabolism to govern signal propagation.
- **Hardware-Software Isomorphism:** The exact match between the Zig simulation and the FPGA gate-level implementation.
- **Emergent Balance (Flow State):** The specific algorithm used to prevent oscillations while maintaining high reaction speed.

## Engineering Standards
- **Zero Runtime:** No Garbage Collection, no hidden allocations.
- **Deterministic Ticks:** Every simulation tick must map 1-to-1 to a hardware clock cycle.
- **Comptime Validation:** Use Zig's `comptime` to verify bit-widths and alignment at compile-time.

## Simulation Modules & Prototypes

### 1. Sentinel Protein (`SentinelProtein`)
* **Purpose:** Multi-modal sensory fusion core mapping 5 human senses (vision, hearing, touch, smell, taste) + superhuman RF sensing.
* **Size:** 256-bit packed struct aligned to FPGA BRAM.
* **Mechanism:** Fuses inputs (e.g., co-occurring vision and RF stimuli) into a unified `resonance` signal representing fused target tracking. Integrates a non-clobbering decay pattern to allow parallel sensory propagation without wave overwriting.

### 2. Sonar Echolocation (`SonarProtein`)
* **Purpose:** Decentralized 1D spatial mapping using acoustic/sensory wave reflections.
* **Size:** 128-bit packed struct.
* **Mechanism:** 
  * **Emitter:** Fires an initial wavefront pulse, increments an echoing timer, and captures return echoes.
  * **Standard Nodes:** Propagate signals bi-directionally with a 3-tick temporal refractory period to prevent backward wave leaks.
  * **Obstacles:** Reflect wavefronts back to their origin.
  * **Role-Dependent Decay:** Employs high decay (140) for standard nodes to keep waves transient, and 0 decay for obstacles to allow reflected signals to linger until neighbor refractory windows clear. The echo returns at tick 37 (reporting exact distance 36).

### 3. Hebbian Learning Core (`LearningProtein`)
* **Purpose:** Decentralized spike-timing-dependent plasticity (STDP) for auto-tuning node connections.
* **Size:** 256-bit packed struct.
* **Mechanism:** 
  * **Spike Thresholding:** Spikes to 255 when excitation exceeds 100, then repolarizes to 0 to prevent wave overlap.
  * **Hebbian Plasticity:** Synaptic connection weights (North, South, East, West) are dynamically updated based on firing causality: causal spikes (pre before post) strengthen connections (+25), while non-causal spikes (post before pre) weaken them (-15).
  * **Weight Decay:** Natural forgetting (decay -1 every 50 ticks) prevents saturation and local lockups.

