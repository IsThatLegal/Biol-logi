# Bio-Logi Project Instructions

## Architecture Reference
See `ARCHITECTURE.md` for the core "Silicon Protein" vision and patentable pillars.

## Development Workflows
1. **Simulation Accuracy:** Every change to `src/protein_core.zig` must maintain FPGA-readiness. Use `packed struct` and avoid any standard library features that rely on a heavy OS runtime.
2. **Testing:** Run `zig test src/protein_core.zig` before any commit to ensure "Bio-Logic" stability.
3. **Hardware Mapping:** Maintain the 16-byte (128-bit) alignment for the `Protein` struct to ensure compatibility with standard FPGA memory buses.

## Style Guidelines
- Prefer **Saturating Arithmetic** (`+|`, `-|`) for all protein state changes.
- Use **Explicit Allocators** (primarily `FixedBufferAllocator` or `page_allocator` for init) to maintain zero-jitter performance.
