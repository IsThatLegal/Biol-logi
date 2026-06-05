# Bio-Logi: Silicon Protein Architecture

## Vision
To create a decentralized, bio-inspired nervous system for robotics that is "Silicon-Ready" (FPGA-optimized), energy-aware, and capable of emergent "Flow State" behavior without a central CPU.

## Core Innovation: The Metabolic Logic Matrix
Unlike standard Neural Networks or Cellular Automata, the **Silicon Protein** architecture introduces **Metabolic Constraint** as a primary driver of logic.

1. **Metabolic Awareness:** Every node (Protein) has an `energy` state. High-frequency firing depletes energy, requiring "recovery" ticks. This prevents runaway feedback loops (Stability).
2. **Bit-Perfect Silicon Mapping:** Data structures are `packed structs` aligned to 128-bit or 64-bit boundaries, mapping directly to FPGA Block RAM (BRAM).
3. **Saturating Bio-Logic:** All arithmetic is saturating (`+|`, `-|`) to ensure behavioral stability under extreme sensor stimulus.
4. **Decentralized Convergence:** Global "Flow State" is achieved solely through local neighborhood interactions (North, South, East, West).

## Patentable Pillars
- **Energy-Constrained Decentralized Logic:** Using metabolism to govern signal propagation.
- **Hardware-Software Isomorphism:** The exact match between the Zig simulation and the FPGA gate-level implementation.
- **Emergent Balance (Flow State):** The specific algorithm used to prevent oscillations while maintaining high reaction speed.

## Engineering Standards
- **Zero Runtime:** No Garbage Collection, no hidden allocations.
- **Deterministic Ticks:** Every simulation tick must map 1-to-1 to a hardware clock cycle.
- **Comptime Validation:** Use Zig's `comptime` to verify bit-widths and alignment at compile-time.
