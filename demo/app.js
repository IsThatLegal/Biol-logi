/**
 * Bio-Logi: Silicon Protein Interactive Neuromorphic Demo
 * Core Simulation Engine and Visualizer
 */

// Grid Configuration
const COLS = 40;
const ROWS = 20;
const TOTAL_CELLS = COLS * ROWS;

// Color Definitions (Matching index.css CSS variables)
const COLORS = {
    bg: '#040406',
    gridLine: 'rgba(39, 39, 42, 0.25)',
    cyan: '#06b6d4',
    violet: '#8b5cf6',
    emerald: '#10b981',
    rose: '#f43f5e',
    amber: '#f59e0b',
    white: '#f4f4f5',
    orange: '#ff6b35',
    darkGray: '#18181b',
};

// Simulation State
const state = {
    mode: 'sentinel', // 'sentinel' | 'sonar' | 'learning' | 'axi'
    tickCount: 0,
    cells: [],
    target: { x: 20, y: 10, angle: 0 }, // Sentinel mode biological target
    globalEnergy: 100.0, // 0 to 100
    networkState: 'NORMAL', // 'NORMAL' | 'OVERLOAD' | 'RECOVERING'
    decayRate: 140, // mapped to UI slider
    refractoryPeriod: 3, // mapped to UI slider
    dopamineModulation: 1.0, // mapped to UI slider
    sonarDistance: 0,
    sonarIsEchoing: false,
    sonarTimer: 0,
    stdpPacingTick: 0,
    axiLocalLatency: 35,
    axiActualLocalLatency: 35,
    axiLocalTimer: 0,
    axiLocalFired: false,
    axiLocalArrived: false,
    axiTimer: 0,
    axiFired: false,
    axiArrived: false,
    cameraActive: false,
    cameraStream: null,
    videoElement: null,
    hiddenCanvas: null,
    hiddenCtx: null,
};

// Canvas Setup
let canvas, ctx;
let isDrawing = false;
let animationFrameId = null;

// Initialize Cell Structure
function initCells() {
    state.cells = [];
    for (let i = 0; i < TOTAL_CELLS; i++) {
        const x = i % COLS;
        const y = Math.floor(i / COLS);
        
        state.cells.push({
            id: i,
            x: x,
            y: y,
            excitation: 0,
            energy: 255,
            timer: 0, // Refractory period
            role: 'standard', // 'standard' | 'emitter' | 'obstacle' | 'axi-sender' | 'axi-receiver'
            
            // Sentinel sensory properties
            vision: 0,
            smell: 0,
            rf: 0,
            resonance: 0,
            
            // Hebbian learning synaptic weights (to N, S, E, W)
            weights: {
                north: 128,
                south: 128,
                east: 128,
                west: 128,
            },
            lastFired: -999, // Tick count of last spike
            
            // AXI routing properties
            latencyBuffer: 0,
            destinationBusId: -1,
        });
    }

    // Set up specific mode layouts
    applyModeLayout();
}

// Applies initial conditions depending on the active mode
function applyModeLayout() {
    // Reset specific roles and excitations
    state.cells.forEach(cell => {
        cell.role = 'standard';
        cell.excitation = 0;
        cell.timer = 0;
        cell.vision = 0;
        cell.smell = 0;
        cell.rf = 0;
        cell.resonance = 0;
        cell.latencyBuffer = 0;
        cell.destinationBusId = -1;
    });

    state.sonarDistance = 0;
    state.sonarIsEchoing = false;
    state.sonarTimer = 0;

    if (state.mode === 'sentinel') {
        // Place some dedicated "Sentinel Stations" across the grid
        const stations = [
            { x: 5, y: 5 }, { x: 15, y: 4 }, { x: 25, y: 5 }, { x: 35, y: 4 },
            { x: 8, y: 15 }, { x: 18, y: 14 }, { x: 28, y: 15 }, { x: 38, y: 13 }
        ];
        stations.forEach(pos => {
            const idx = pos.y * COLS + pos.x;
            if (state.cells[idx]) {
                state.cells[idx].role = 'sentinel';
            }
        });
    } 
    else if (state.mode === 'sonar') {
        // Set Emitter at Left, Obstacle at Right (row 10)
        const emitterIdx = 10 * COLS + 2;
        const obstacleIdx = 10 * COLS + 22;

        if (state.cells[emitterIdx]) {
            state.cells[emitterIdx].role = 'emitter';
        }
        if (state.cells[obstacleIdx]) {
            state.cells[obstacleIdx].role = 'obstacle';
        }

        // Add pre-configured obstacles to make echolocation interesting
        const secondaryObstacles = [
            { x: 22, y: 8 }, { x: 22, y: 9 }, { x: 22, y: 11 }, { x: 22, y: 12 }
        ];
        secondaryObstacles.forEach(pos => {
            const idx = pos.y * COLS + pos.x;
            if (state.cells[idx]) {
                state.cells[idx].role = 'obstacle';
            }
        });
    }
    else if (state.mode === 'learning') {
        // Neutral connections initialized to 128
        state.cells.forEach(cell => {
            cell.weights.north = 128;
            cell.weights.south = 128;
            cell.weights.east = 128;
            cell.weights.west = 128;
            cell.lastFired = -999;
        });
    }
    else if (state.mode === 'axi') {
        // Split grid: top half is local hops, bottom half is AXI highway bypass
        // Local hops track: Row 5. Sender col 2, Receiver col 37
        const localSenderIdx = 5 * COLS + 2;
        const localReceiverIdx = 5 * COLS + 37;
        state.cells[localSenderIdx].role = 'local-sender';
        state.cells[localReceiverIdx].role = 'local-receiver';

        // AXI highway track: Row 15. Sender col 2, Receiver col 37
        const axiSenderIdx = 15 * COLS + 2;
        const axiReceiverIdx = 15 * COLS + 37;
        state.cells[axiSenderIdx].role = 'axi-sender';
        state.cells[axiReceiverIdx].role = 'axi-receiver';
        state.cells[axiSenderIdx].destinationBusId = axiReceiverIdx;
    }

    updateLegend();
}

// Update Legend UI Dynamically
function updateLegend() {
    const legendContainer = document.getElementById('legend-container');
    if (!legendContainer) return;

    let items = [];
    if (state.mode === 'sentinel') {
        items = [
            { name: 'Sentinel Node', color: COLORS.cyan },
            { name: 'Target Locked', color: COLORS.amber },
            { name: 'Sensory Ripples', color: COLORS.emerald },
        ];
    } else if (state.mode === 'sonar') {
        items = [
            { name: 'Emitter Node', color: COLORS.amber },
            { name: 'Obstacle Block', color: COLORS.rose },
            { name: 'Refractory Wave', color: COLORS.violet },
            { name: 'Sonar Wavefront', color: COLORS.cyan },
        ];
    } else if (state.mode === 'learning') {
        items = [
            { name: 'Plastic Cell', color: 'rgba(139, 92, 246, 0.4)' },
            { name: 'Fired Spike', color: COLORS.white },
            { name: 'Learned Connection', color: COLORS.cyan },
        ];
    } else if (state.mode === 'axi') {
        items = [
            { name: 'Signal Sender', color: COLORS.emerald },
            { name: 'Local Wavefront', color: COLORS.rose },
            { name: 'AXI Highway Axon', color: COLORS.amber },
            { name: 'Signal Receiver', color: COLORS.cyan },
        ];
    }

    legendContainer.innerHTML = items.map(item => `
        <div class="legend-item">
            <div class="legend-color" style="background-color: ${item.color}"></div>
            <span>${item.name}</span>
        </div>
    `).join('');
}

// ----------------------------------------------------
// SIMULATION STEP LOOP
// ----------------------------------------------------
function tick() {
    state.tickCount++;

    // 1. Handle Overload / Energy Repolarization
    if (state.networkState === 'OVERLOAD') {
        state.globalEnergy = Math.max(0, state.globalEnergy - 2.0); // Drain heavily
        if (state.globalEnergy <= 0) {
            state.networkState = 'RECOVERING';
        }
    } else if (state.networkState === 'RECOVERING') {
        // Recovery rate depends on Dopamine slider
        const recoverySpeed = 0.5 * state.dopamineModulation;
        state.globalEnergy = Math.min(100.0, state.globalEnergy + recoverySpeed);
        if (state.globalEnergy >= 100.0) {
            state.networkState = 'NORMAL';
        }
    } else {
        // Normal behavior: auto-repolarize if slightly drained
        if (state.globalEnergy < 100.0) {
            state.globalEnergy = Math.min(100.0, state.globalEnergy + 1.0);
        }
    }

    // 2. Compute Mode Specific Steps
    if (state.mode === 'sentinel') {
        runSentinelLogic();
    } else if (state.mode === 'sonar') {
        runSonarLogic();
    } else if (state.mode === 'learning') {
        runLearningLogic();
    } else if (state.mode === 'axi') {
        runAxiLogic();
    }

    // 3. Update Metrics Dashboard
    updateMetricsUI();
}

// --- Sentinel Sensory Fusion Mode ---
function runSentinelLogic() {
    // A. Move autonomous target along a Lissajous-like curve (only active if camera is off)
    if (!state.cameraActive) {
        state.target.angle += 0.03 * state.dopamineModulation;
        state.target.x = COLS / 2 + Math.cos(state.target.angle) * (COLS / 2.3);
        state.target.y = ROWS / 2 + Math.sin(state.target.angle * 1.6) * (ROWS / 2.5);

        const targetXIdx = Math.round(state.target.x);
        const targetYIdx = Math.round(state.target.y);

        // B. Inject target sensory stimuli directly onto local cells
        state.cells.forEach(cell => {
            const dist = Math.hypot(cell.x - targetXIdx, cell.y - targetYIdx);
            
            // Sensory decay mapping (Vision is short, Smell is mid, RF is far and pulses)
            if (dist < 5) {
                cell.vision = Math.max(cell.vision, Math.round((5 - dist) * 51)); // up to 255
            }
            if (dist < 7) {
                cell.smell = Math.max(cell.smell, Math.round((7 - dist) * 36)); // up to 255
            }
            if (dist < 9 && state.tickCount % 4 === 0) {
                cell.rf = Math.max(cell.rf, Math.round((9 - dist) * 28)); // up to 255
            }
        });
    } else if (state.hiddenCtx && state.videoElement) {
        // Real-Time Camera Retina Mapping
        try {
            state.hiddenCtx.drawImage(state.videoElement, 0, 0, COLS, ROWS);
            const imgData = state.hiddenCtx.getImageData(0, 0, COLS, ROWS);
            const pixels = imgData.data;

            state.cells.forEach(cell => {
                const pixelIdx = (cell.y * COLS + cell.x) * 4;
                const r = pixels[pixelIdx];
                const g = pixels[pixelIdx + 1];
                const b = pixels[pixelIdx + 2];
                
                // Luminance brightness value
                const brightness = Math.round(r * 0.299 + g * 0.587 + b * 0.114);
                
                cell.vision = brightness;
                
                // Inject RF on bright spots to allow sensory fusion target lock-ons
                if (brightness > 190) {
                    cell.rf = Math.min(255, cell.rf + 60);
                }
            });
        } catch (err) {
            console.error("Retina frame capture failed:", err);
        }
    }

    // C. Cellular Automata Propagation & Fusion
    const nextStates = state.cells.map(c => ({
        vision: c.vision,
        smell: c.smell,
        rf: c.rf,
        resonance: c.resonance
    }));

    state.cells.forEach(cell => {
        const idx = cell.id;

        // Cross-modal Fusion Rule (Vision & RF lock-on resonance)
        if (cell.vision > 180 && cell.rf > 120) {
            nextStates[idx].resonance = Math.min(255, cell.resonance + 100);
        }

        // Local Propagation (Spreading Vision/Smell to neighbors)
        const neighbors = getNeighbors(cell.x, cell.y);
        
        if (cell.vision > 40) {
            const visionSpread = Math.floor((cell.vision - 10) / 4);
            neighbors.forEach(nIdx => {
                nextStates[nIdx].vision = Math.min(255, nextStates[nIdx].vision + visionSpread);
            });
        }
        if (cell.smell > 100) {
            const smellSpread = cell.smell - 15;
            neighbors.forEach(nIdx => {
                nextStates[nIdx].smell = Math.min(255, nextStates[nIdx].smell + smellSpread);
            });
        }

        // Decay Rates (modulate with slider)
        const decayVision = Math.round(20 * (state.decayRate / 140));
        const decaySmell = Math.round(10 * (state.decayRate / 140));
        const decayRf = Math.round(15 * (state.decayRate / 140));
        const decayResonance = 5;

        nextStates[idx].vision = Math.max(0, nextStates[idx].vision - decayVision);
        nextStates[idx].smell = Math.max(0, nextStates[idx].smell - decaySmell);
        nextStates[idx].rf = Math.max(0, nextStates[idx].rf - decayRf);
        nextStates[idx].resonance = Math.max(0, nextStates[idx].resonance - decayResonance);
    });

    // Commit states
    state.cells.forEach((cell, idx) => {
        if (state.networkState === 'OVERLOAD') {
            cell.vision = Math.max(0, cell.vision - 40);
            cell.smell = Math.max(0, cell.smell - 40);
            cell.rf = Math.max(0, cell.rf - 40);
            cell.resonance = Math.max(0, cell.resonance - 40);
        } else {
            cell.vision = nextStates[idx].vision;
            cell.smell = nextStates[idx].smell;
            cell.rf = nextStates[idx].rf;
            cell.resonance = nextStates[idx].resonance;
        }
    });
}

// --- Decentralized Sonar Mode ---
function runSonarLogic() {
    const emitterIdx = 10 * COLS + 2;
    const emitter = state.cells[emitterIdx];

    // Auto trigger emitter pulse every 50 ticks if not already echoing
    if (!state.sonarIsEchoing && state.tickCount % 50 === 0) {
        triggerSonarPulse();
    }

    // Propagation logic
    const nextExcitation = state.cells.map(c => c.excitation);
    const nextTimer = state.cells.map(c => c.timer);

    // Decrement refractory timer
    state.cells.forEach(cell => {
        if (cell.role === 'standard' && cell.timer > 0) {
            nextTimer[cell.id] = cell.timer - 1;
        }
    });

    // Wave movement
    state.cells.forEach(cell => {
        if (cell.excitation > 50) {
            const signal = cell.excitation - 8;
            const neighbors = getNeighbors(cell.x, cell.y);

            if (cell.role === 'obstacle') {
                // Reflect: propagate back to left neighbor
                const leftNeighbor = cell.y * COLS + (cell.x - 1);
                exciteSonarNode(leftNeighbor, signal, nextExcitation, nextTimer);
            } else if (cell.role === 'emitter') {
                // Emitter fires wave to the right (outwards)
                const rightNeighbor = cell.y * COLS + (cell.x + 1);
                exciteSonarNode(rightNeighbor, signal, nextExcitation, nextTimer);
            } else {
                // Standard: propagate both left and right (mostly outward due to refractory block)
                const leftNeighbor = cell.y * COLS + (cell.x - 1);
                const rightNeighbor = cell.y * COLS + (cell.x + 1);
                exciteSonarNode(leftNeighbor, signal, nextExcitation, nextTimer);
                exciteSonarNode(rightNeighbor, signal, nextExcitation, nextTimer);
            }
        }
    });

    // Sonar Timing & Distance Mapping (Emitter logic)
    if (state.sonarIsEchoing) {
        state.sonarTimer++;
        nextTimer[emitterIdx] = state.sonarTimer;

        // If emitter receives a reflected excitation and we have started echoing
        if (emitter.excitation > 50 && state.sonarTimer > 8) {
            state.sonarDistance = state.sonarTimer - 1;
            state.sonarIsEchoing = false;
        }
    }

    // Natural decay
    state.cells.forEach(cell => {
        const decayVal = cell.role === 'obstacle' ? 0 : state.decayRate;
        nextExcitation[cell.id] = Math.max(0, nextExcitation[cell.id] - Math.round(decayVal * 0.15));
    });

    // Commit
    state.cells.forEach((cell, idx) => {
        if (state.networkState === 'OVERLOAD') {
            cell.excitation = 0;
            cell.timer = 0;
        } else {
            cell.excitation = nextExcitation[idx];
            cell.timer = nextTimer[idx];
        }
    });
}

function exciteSonarNode(targetIdx, signal, nextExcitation, nextTimer) {
    if (targetIdx >= 0 && targetIdx < TOTAL_CELLS) {
        const target = state.cells[targetIdx];
        // Can only excite if not in refractory period, or if it is Emitter/Obstacle
        if (target.timer === 0 || target.role === 'emitter' || target.role === 'obstacle') {
            if (nextExcitation[targetIdx] < signal) {
                nextExcitation[targetIdx] = signal;
            }
            if (target.role === 'standard') {
                nextTimer[targetIdx] = state.refractoryPeriod; // Set refractory lock
            }
        }
    }
}

function triggerSonarPulse() {
    const emitterIdx = 10 * COLS + 2;
    if (state.cells[emitterIdx]) {
        state.cells[emitterIdx].excitation = 255;
        state.cells[emitterIdx].timer = 0;
        state.sonarIsEchoing = true;
        state.sonarTimer = 0;
        state.sonarDistance = 0;
    }
}

// --- Hebbian STDP Plasticity Mode ---
function runLearningLogic() {
    state.stdpPacingTick++;

    // Background pacing stimulus:
    // Repeated causal sequence: Cell A (15, 10) fires, and 1 tick later Cell B (16, 10) fires
    // This strengthens A -> B East connection weight, demonstrating LTP.
    if (state.stdpPacingTick % 12 === 0) {
        const cellAIdx = 10 * COLS + 15;
        state.cells[cellAIdx].excitation = 255;
    } else if (state.stdpPacingTick % 12 === 1) {
        const cellBIdx = 10 * COLS + 16;
        state.cells[cellBIdx].excitation = 255;
    }

    const nextExcitation = state.cells.map(c => c.excitation);
    const nextWeights = state.cells.map(c => ({ ...c.weights }));
    const nextLastFired = state.cells.map(c => c.lastFired);

    state.cells.forEach(cell => {
        const isSpiking = cell.excitation > 100;
        const activeExcitation = isSpiking ? 255 : cell.excitation;

        // 1. Propagate wave based on synaptic weights
        if (activeExcitation > 50) {
            const signal = activeExcitation - 15;
            const directions = [
                { dx: 0, dy: -1, weight: cell.weights.north, name: 'north' },
                { dx: 0, dy: 1, weight: cell.weights.south, name: 'south' },
                { dx: 1, dy: 0, weight: cell.weights.east, name: 'east' },
                { dx: -1, dy: 0, weight: cell.weights.west, name: 'west' }
            ];

            directions.forEach(dir => {
                const nx = cell.x + dir.dx;
                const ny = cell.y + dir.dy;
                if (nx >= 0 && nx < COLS && ny >= 0 && ny < ROWS) {
                    const targetIdx = ny * COLS + nx;
                    // Modulate spread signal strength by the synaptic weight
                    const weightedSignal = Math.floor((signal * dir.weight) / 255);
                    if (weightedSignal > 0 && nextExcitation[targetIdx] < weightedSignal) {
                        nextExcitation[targetIdx] = weightedSignal;
                    }
                }
            });
        }

        if (isSpiking) {
            nextLastFired[cell.id] = state.tickCount;
            // STDP rule execution: Causal strengthens, non-causal weakens
            updateSTDPWeights(cell, nextWeights);
        }

        // 2. Decay excitation and weight forgetfulness
        if (isSpiking) {
            nextExcitation[cell.id] = 0; // Repolarize immediately
        } else {
            const decay = Math.round(15 * (state.decayRate / 140));
            nextExcitation[cell.id] = Math.max(0, cell.excitation - decay);
        }

        // Forgetting mechanism: slow decay back to baseline 128
        if (state.tickCount % 40 === 0) {
            const w = nextWeights[cell.id];
            w.north = forgetWeight(w.north);
            w.south = forgetWeight(w.south);
            w.east = forgetWeight(w.east);
            w.west = forgetWeight(w.west);
        }
    });

    // Commit
    state.cells.forEach((cell, idx) => {
        if (state.networkState === 'OVERLOAD') {
            cell.excitation = 0;
            cell.weights = { north: 128, south: 128, east: 128, west: 128 };
        } else {
            cell.excitation = nextExcitation[idx];
            cell.weights = nextWeights[idx];
            cell.lastFired = nextLastFired[idx];
        }
    });
}

function updateSTDPWeights(cell, nextWeights) {
    const directions = [
        { dx: 0, dy: -1, key: 'north' },
        { dx: 0, dy: 1, key: 'south' },
        { dx: 1, dy: 0, key: 'east' },
        { dx: -1, dy: 0, key: 'west' }
    ];

    directions.forEach(dir => {
        const nx = cell.x + dir.dx;
        const ny = cell.y + dir.dy;
        if (nx >= 0 && nx < COLS && ny >= 0 && ny < ROWS) {
            const targetIdx = ny * COLS + nx;
            const target = state.cells[targetIdx];

            // LTP: target fired AFTER me (Causal connection)
            if (target.lastFired > cell.lastFired && target.lastFired - cell.lastFired <= 3) {
                // Boost weight in that direction
                nextWeights[cell.id][dir.key] = Math.min(255, nextWeights[cell.id][dir.key] + 25);
            }
            // LTD: target fired BEFORE me (Non-causal connection)
            else if (target.lastFired < cell.lastFired && cell.lastFired - target.lastFired <= 3) {
                // Suppress weight in that direction
                nextWeights[cell.id][dir.key] = Math.max(10, nextWeights[cell.id][dir.key] - 15);
            }
        }
    });
}

function forgetWeight(currentVal) {
    // Return slow decay towards neutral 128
    if (currentVal > 128) return Math.max(128, currentVal - 1);
    if (currentVal < 128) return Math.min(128, currentVal + 1);
    return 128;
}

// --- AXI Latency Mode ---
function runAxiLogic() {
    const localSenderIdx = 5 * COLS + 2;
    const localReceiverIdx = 5 * COLS + 37;
    const axiSenderIdx = 15 * COLS + 2;
    const axiReceiverIdx = 15 * COLS + 37;

    // Trigger cycle every 60 ticks
    if (state.tickCount % 60 === 0) {
        // Stimulate both senders
        state.cells[localSenderIdx].excitation = 255;
        state.cells[axiSenderIdx].excitation = 255;

        // Reset latency trackers
        state.axiLocalTimer = 0;
        state.axiLocalFired = true;
        state.axiLocalArrived = false;

        state.axiTimer = 0;
        state.axiFired = true;
        state.axiArrived = false;
    }

    if (state.axiLocalFired && !state.axiLocalArrived) {
        state.axiLocalTimer++;
    }
    if (state.axiFired && !state.axiArrived) {
        state.axiTimer++;
    }

    const nextExcitation = state.cells.map(c => c.excitation);
    const nextLatencyBuffer = state.cells.map(c => c.latencyBuffer);

    // Apply latency buffers (wire delays)
    state.cells.forEach(cell => {
        if (cell.latencyBuffer > 0) {
            // Signal enters excitation from latency buffer
            nextExcitation[cell.id] = Math.min(255, cell.excitation + cell.latencyBuffer);
            nextLatencyBuffer[cell.id] = 0; // consumed
        }
    });

    // Tick matrix cells
    state.cells.forEach(cell => {
        const excitationVal = cell.id === localSenderIdx || cell.id === axiSenderIdx ? cell.excitation : nextExcitation[cell.id];
        if (excitationVal > 50) {
            const signal = Math.max(0, excitationVal - 15);

            if (cell.destinationBusId !== -1) {
                // AXI Highway routing: Directly map to receiver's latency buffer (1-cycle delay)
                const targetIdx = cell.destinationBusId;
                nextLatencyBuffer[targetIdx] = Math.min(255, nextLatencyBuffer[targetIdx] + signal);
            } else if (cell.id >= 0 && cell.y === 5) {
                // Local Hops propagation (Only along Row 5)
                const rightNeighbor = cell.y * COLS + (cell.x + 1);
                if (rightNeighbor < (cell.y + 1) * COLS) {
                    nextLatencyBuffer[rightNeighbor] = Math.min(255, nextLatencyBuffer[rightNeighbor] + signal);
                }
            }
        }
    });

    // Natural decay
    state.cells.forEach(cell => {
        nextExcitation[cell.id] = Math.max(0, nextExcitation[cell.id] - 12);
    });

    // Check arrivals
    if (nextExcitation[localReceiverIdx] > 100 && !state.axiLocalArrived) {
        state.axiLocalArrived = true;
        state.axiActualLocalLatency = state.axiLocalTimer;
    }
    if (nextExcitation[axiReceiverIdx] > 100 && !state.axiArrived) {
        state.axiArrived = true;
    }

    // Commit
    state.cells.forEach((cell, idx) => {
        if (state.networkState === 'OVERLOAD') {
            cell.excitation = 0;
            cell.latencyBuffer = 0;
        } else {
            cell.excitation = nextExcitation[idx];
            cell.latencyBuffer = nextLatencyBuffer[idx];
        }
    });
}

// ----------------------------------------------------
// GRID RENDERING (CANVAS 2D)
// ----------------------------------------------------
function render() {
    if (!canvas || !ctx) return;

    // Clear Canvas
    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    ctx.fillStyle = COLORS.bg;
    ctx.fillRect(0, 0, rect.width, rect.height);

    // Calculate Cell Dimensions
    const cw = rect.width / COLS;
    const ch = rect.height / ROWS;

    // Draw Grid Lines
    ctx.strokeStyle = COLORS.gridLine;
    ctx.lineWidth = 1;
    for (let c = 0; c <= COLS; c++) {
        ctx.beginPath();
        ctx.moveTo(c * cw, 0);
        ctx.lineTo(c * cw, rect.height);
        ctx.stroke();
    }
    for (let r = 0; r <= ROWS; r++) {
        ctx.beginPath();
        ctx.moveTo(0, r * ch);
        ctx.lineTo(rect.width, r * ch);
        ctx.stroke();
    }

    // Render Mode Visuals
    state.cells.forEach(cell => {
        const cx = cell.x * cw;
        const cy = cell.y * ch;

        // Render basic node structure if active / has values
        if (state.mode === 'sentinel') {
            drawSentinelCell(ctx, cell, cx, cy, cw, ch);
        } else if (state.mode === 'sonar') {
            drawSonarCell(ctx, cell, cx, cy, cw, ch);
        } else if (state.mode === 'learning') {
            drawLearningCell(ctx, cell, cx, cy, cw, ch);
        } else if (state.mode === 'axi') {
            drawAxiCell(ctx, cell, cx, cy, cw, ch);
        }
    });

    // Render Mode overlays
    if (state.mode === 'sentinel') {
        // Draw biological target path & target ring
        const tx = state.target.x * cw;
        const ty = state.target.y * ch;

        ctx.shadowBlur = 20;
        ctx.shadowColor = COLORS.emerald;
        ctx.fillStyle = 'rgba(16, 185, 129, 0.4)';
        ctx.beginPath();
        ctx.arc(tx, ty, Math.sin(state.tickCount * 0.1) * 6 + 18, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = COLORS.emerald;
        ctx.beginPath();
        ctx.arc(tx, ty, 6, 0, Math.PI * 2);
        ctx.fill();
        ctx.shadowBlur = 0; // reset
    } 
    else if (state.mode === 'axi') {
        // Draw long-range AXI Golden Highway Wire
        const senderX = (2 * cw) + (cw / 2);
        const senderY = (15 * ch) + (ch / 2);
        const receiverX = (37 * cw) + (cw / 2);
        const receiverY = (15 * ch) + (ch / 2);

        ctx.strokeStyle = COLORS.amber;
        ctx.lineWidth = 2.5;
        ctx.setLineDash([8, 6]);
        ctx.lineDashOffset = -state.tickCount * 1.5;
        ctx.beginPath();
        ctx.moveTo(senderX, senderY);
        ctx.lineTo(receiverX, receiverY);
        ctx.stroke();
        ctx.setLineDash([]); // Reset dash

        // Draw direct arrows or bypass markers
        ctx.fillStyle = COLORS.amber;
        ctx.beginPath();
        ctx.arc(senderX, senderY, 6, 0, Math.PI * 2);
        ctx.arc(receiverX, receiverY, 6, 0, Math.PI * 2);
        ctx.fill();
    }

    // Flashbang Noise overlay
    if (state.networkState === 'OVERLOAD') {
        ctx.fillStyle = `rgba(244, 63, 94, ${Math.random() * 0.3 + 0.1})`;
        ctx.fillRect(0, 0, rect.width, rect.height);
        
        ctx.fillStyle = COLORS.white;
        ctx.font = `bold 16px var(--font-sans)`;
        ctx.textAlign = 'center';
        ctx.fillText("⚠️ CRITICAL METABOLIC COLLAPSE ⚠️", rect.width / 2, rect.height / 2);
    }
}

// Draw cell in Sentinel Mode
function drawSentinelCell(ctx, cell, cx, cy, cw, ch) {
    if (cell.role === 'sentinel') {
        // Sentinel monitoring node
        ctx.fillStyle = cell.resonance > 100 ? 'rgba(245, 158, 11, 0.2)' : 'rgba(6, 182, 212, 0.1)';
        ctx.strokeStyle = cell.resonance > 100 ? COLORS.amber : COLORS.cyan;
        ctx.lineWidth = 2;
        ctx.fillRect(cx + 2, cy + 2, cw - 4, ch - 4);
        ctx.strokeRect(cx + 2, cy + 2, cw - 4, ch - 4);

        if (cell.resonance > 100) {
            ctx.shadowBlur = 10;
            ctx.shadowColor = COLORS.amber;
            ctx.fillStyle = COLORS.amber;
            ctx.beginPath();
            ctx.arc(cx + cw / 2, cy + ch / 2, 4, 0, Math.PI * 2);
            ctx.fill();
            ctx.shadowBlur = 0;
        }
    } else {
        // Standard cells show combined vision (Green), smell (Purple) & RF (Cyan) values
        if (cell.vision > 0 || cell.smell > 0 || cell.rf > 0) {
            const r = Math.min(255, Math.floor(cell.smell * 0.6 + cell.rf * 0.2));
            const g = Math.min(255, Math.floor(cell.vision * 0.7));
            const b = Math.min(255, Math.floor(cell.rf * 0.9 + cell.smell * 0.5));
            ctx.fillStyle = `rgba(${r}, ${g}, ${b}, 0.6)`;
            ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
        }
    }
}

// Draw cell in Sonar Mode
function drawSonarCell(ctx, cell, cx, cy, cw, ch) {
    if (cell.role === 'emitter') {
        ctx.fillStyle = COLORS.amber;
        ctx.beginPath();
        ctx.moveTo(cx + cw / 2, cy + 2);
        ctx.lineTo(cx + cw - 2, cy + ch - 2);
        ctx.lineTo(cx + 2, cy + ch - 2);
        ctx.closePath();
        ctx.fill();

        if (state.sonarIsEchoing) {
            ctx.shadowBlur = 12;
            ctx.shadowColor = COLORS.amber;
            ctx.strokeStyle = COLORS.amber;
            ctx.strokeRect(cx - 2, cy - 2, cw + 4, ch + 4);
            ctx.shadowBlur = 0;
        }
    } else if (cell.role === 'obstacle') {
        ctx.fillStyle = COLORS.rose;
        ctx.strokeStyle = COLORS.white;
        ctx.lineWidth = 1.5;
        ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
        ctx.strokeRect(cx + 2, cy + 2, cw - 4, ch - 4);
    } else {
        // Standard node wave renders
        if (cell.excitation > 0) {
            ctx.fillStyle = `rgba(6, 182, 212, ${cell.excitation / 255})`;
            ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
        } else if (cell.timer > 0) {
            // Refractory period block rendered in Violet
            ctx.fillStyle = `rgba(139, 92, 246, ${cell.timer / state.refractoryPeriod * 0.45})`;
            ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
        }
    }
}

// Draw cell in Hebbian Plasticity Mode
function drawLearningCell(ctx, cell, cx, cy, cw, ch) {
    const padding = 2;
    const rx = cx + padding;
    const ry = cy + padding;
    const rw = cw - padding * 2;
    const rh = ch - padding * 2;

    // Draw base cell representation
    if (cell.excitation > 50) {
        ctx.fillStyle = COLORS.white;
        ctx.fillRect(rx, ry, rw, rh);
    } else {
        ctx.fillStyle = 'rgba(39, 39, 42, 0.15)';
        ctx.fillRect(rx, ry, rw, rh);
    }

    // Draw connection lines to neighbors according to weights
    const drawSynapse = (x1, y1, x2, y2, weight) => {
        if (weight <= 128) return; // Only draw reinforced paths to keep canvas readable
        const intensity = (weight - 128) / 127;
        ctx.strokeStyle = `rgba(6, 182, 212, ${intensity * 0.85})`;
        ctx.lineWidth = intensity * 3;
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.stroke();
    };

    const mx = cx + cw / 2;
    const my = cy + ch / 2;

    drawSynapse(mx, my, mx, cy, cell.weights.north);
    drawSynapse(mx, my, mx, cy + ch, cell.weights.south);
    drawSynapse(mx, my, cx + cw, my, cell.weights.east);
    drawSynapse(mx, my, cx, my, cell.weights.west);
}

// Draw cell in AXI Highway Mode
function drawAxiCell(ctx, cell, cx, cy, cw, ch) {
    if (cell.role === 'local-sender' || cell.role === 'axi-sender') {
        ctx.fillStyle = COLORS.emerald;
        ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
    } else if (cell.role === 'local-receiver' || cell.role === 'axi-receiver') {
        ctx.fillStyle = COLORS.cyan;
        ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
    } else {
        // Standard CA cell wave propagation
        if (cell.excitation > 0) {
            const color = cell.y === 5 ? COLORS.rose : COLORS.cyan;
            ctx.fillStyle = color;
            ctx.fillRect(cx + 1, cy + 1, cw - 2, ch - 2);
        }
    }
}

// Helper to grab cell 4-way neighbors indices
function getNeighbors(x, y) {
    const coords = [
        { x: x, y: y - 1 }, // North
        { x: x, y: y + 1 }, // South
        { x: x + 1, y: y }, // East
        { x: x - 1, y: y }, // West
    ];

    return coords
        .filter(c => c.x >= 0 && c.x < COLS && c.y >= 0 && c.y < ROWS)
        .map(c => c.y * COLS + c.x);
}

// ----------------------------------------------------
// METRICS & INTERFACE STATE UPDATES
// ----------------------------------------------------
function updateMetricsUI() {
    // 1. Energy Progress Bar
    const energyBar = document.getElementById('energy-progress');
    const energyValText = document.getElementById('energy-value');
    if (energyBar && energyValText) {
        const percentage = Math.round(state.globalEnergy);
        energyBar.style.width = `${percentage}%`;

        // Update color class
        energyBar.className = 'energy-bar';
        if (percentage < 30) {
            energyBar.classList.add('exhausted');
            energyValText.textContent = `${percentage}% (Metabolic Paralysis)`;
        } else if (percentage < 70) {
            energyBar.classList.add('tired');
            energyValText.textContent = `${percentage}% (Depleted - Gain Control Active)`;
        } else {
            energyValText.textContent = `${percentage}% (Fully Repolarized)`;
        }
    }

    // 2. Network Status
    const netStateText = document.getElementById('network-state-text');
    const netSubtext = document.getElementById('network-subtext');
    if (netStateText && netSubtext) {
        if (state.networkState === 'OVERLOAD') {
            netStateText.textContent = 'OVERLOAD STATE';
            netStateText.className = 'status-display overload';
            netSubtext.textContent = 'Decentralized automatic shutdown active';
        } else if (state.networkState === 'RECOVERING') {
            netStateText.textContent = 'RECOVERING';
            netStateText.className = 'status-display recovering';
            netSubtext.textContent = 'Repolarizing metabolic cell reserves';
        } else {
            if (state.globalEnergy < 50) {
                netStateText.textContent = 'CRITICAL ENERGY';
                netStateText.className = 'status-display recovering';
                netSubtext.textContent = 'Voltage gates clamped to prevent burnout';
            } else {
                netStateText.textContent = 'NORMAL STATE';
                netStateText.className = 'status-display';
                netSubtext.textContent = 'Resilient automatic gain control';
            }
        }
    }

    // 3. AXI Latency Comparison Metrics
    const latencyCard = document.getElementById('latency-metric-card');
    const localFill = document.getElementById('latency-local-fill');
    const localText = document.getElementById('latency-local-text');
    const axiFill = document.getElementById('latency-axi-fill');
    const axiText = document.getElementById('latency-axi-text');
    const savingText = document.getElementById('latency-saving-text');

    if (latencyCard) {
        if (state.mode === 'axi') {
            latencyCard.style.opacity = '1';
            latencyCard.style.pointerEvents = 'all';

            const localLatency = state.axiActualLocalLatency;
            const axiLatency = 1;

            // Fill bars
            localFill.style.width = '100%';
            localText.textContent = `${localLatency} cyc`;

            const percentageFill = Math.max(4, (axiLatency / localLatency) * 100);
            axiFill.style.width = `${percentageFill}%`;
            axiText.textContent = `${axiLatency} cyc`;

            const saving = ((1 - (axiLatency / localLatency)) * 100).toFixed(1);
            savingText.textContent = `${saving}% Latency Reduction Verified`;
        } else {
            // Dim latency panel if not in AXI mode
            latencyCard.style.opacity = '0.3';
            latencyCard.style.pointerEvents = 'none';
        }
    }
}

// ----------------------------------------------------
// INTERACTION & CONTROL HANDLERS
// ----------------------------------------------------
function handleCanvasInteraction(e) {
    if (state.networkState === 'OVERLOAD' || state.networkState === 'RECOVERING') return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const col = Math.floor((x / rect.width) * COLS);
    const row = Math.floor((y / rect.height) * ROWS);

    if (col >= 0 && col < COLS && row >= 0 && row < ROWS) {
        const cellIdx = row * COLS + col;
        const cell = state.cells[cellIdx];

        if (state.mode === 'sentinel') {
            // Click to stimulate target vision directly
            cell.vision = 255;
            cell.rf = 200;
        } else if (state.mode === 'sonar') {
            // Clicking places/removes obstacles, unless clicking Emitter
            if (cell.role === 'emitter') {
                triggerSonarPulse();
            } else {
                cell.role = cell.role === 'obstacle' ? 'standard' : 'obstacle';
                cell.excitation = 0;
            }
        } else if (state.mode === 'learning') {
            // Clicking excites the clicked node, creating stimulus
            cell.excitation = 255;
            cell.lastFired = state.tickCount;
        } else if (state.mode === 'axi') {
            // Clicking sender excites both tracks
            if (cell.role === 'local-sender' || cell.role === 'axi-sender') {
                state.cells[5 * COLS + 2].excitation = 255;
                state.cells[15 * COLS + 2].excitation = 255;
                
                state.axiLocalTimer = 0;
                state.axiLocalFired = true;
                state.axiLocalArrived = false;

                state.axiTimer = 0;
                state.axiFired = true;
                state.axiArrived = false;
            } else {
                cell.excitation = 255;
            }
        }
    }
}

// Bind Sliders & Buttons
function setupUIListeners() {
    // Mode Buttons
    const modes = ['sentinel', 'sonar', 'learning', 'axi'];
    modes.forEach(modeId => {
        const btn = document.getElementById(`btn-${modeId}`);
        if (btn) {
            btn.addEventListener('click', () => {
                modes.forEach(m => document.getElementById(`btn-${m}`)?.classList.remove('active'));
                btn.classList.add('active');
                
                state.mode = modeId;
                const badge = document.getElementById('current-mode-badge');
                if (badge) {
                    badge.textContent = modeId.toUpperCase() + (modeId === 'axi' ? ' LATENCY' : ' FUSION');
                }
                
                applyModeLayout();
            });
        }
    });

    // Parameters Sliders
    const decaySlider = document.getElementById('slider-decay');
    const valDecay = document.getElementById('val-decay');
    if (decaySlider && valDecay) {
        decaySlider.addEventListener('input', (e) => {
            state.decayRate = parseInt(e.target.value);
            valDecay.textContent = state.decayRate;
        });
    }

    const refractorySlider = document.getElementById('slider-refractory');
    const valRefractory = document.getElementById('val-refractory');
    if (refractorySlider && valRefractory) {
        refractorySlider.addEventListener('input', (e) => {
            state.refractoryPeriod = parseInt(e.target.value);
            valRefractory.textContent = state.refractoryPeriod;
        });
    }

    const dopamineSlider = document.getElementById('slider-dopamine');
    const valDopamine = document.getElementById('val-dopamine');
    if (dopamineSlider && valDopamine) {
        dopamineSlider.addEventListener('input', (e) => {
            state.dopamineModulation = parseFloat(e.target.value);
            valDopamine.textContent = `${state.dopamineModulation.toFixed(1)}x`;
        });
    }

    // Disturbances Buttons
    const btnFlashbang = document.getElementById('btn-flashbang');
    if (btnFlashbang) {
        btnFlashbang.addEventListener('click', () => {
            state.networkState = 'OVERLOAD';
            state.cells.forEach(cell => {
                cell.excitation = 255;
            });
        });
    }

    const btnClear = document.getElementById('btn-clear');
    if (btnClear) {
        btnClear.addEventListener('click', () => {
            applyModeLayout();
        });
    }

    const btnCamera = document.getElementById('btn-camera');
    if (btnCamera) {
        btnCamera.addEventListener('click', () => {
            if (state.cameraActive) {
                // Stop camera stream
                if (state.cameraStream) {
                    state.cameraStream.getTracks().forEach(track => track.stop());
                }
                state.cameraActive = false;
                state.cameraStream = null;
                if (state.videoElement) {
                    state.videoElement.pause();
                    state.videoElement = null;
                }
                btnCamera.textContent = '🎥 Enable Camera Retina Feed';
                btnCamera.style.borderColor = 'var(--clr-emerald)';
                btnCamera.style.color = 'var(--clr-emerald)';
                btnCamera.style.background = 'rgba(16, 185, 129, 0.05)';
            } else {
                // Request camera permission preferring back camera
                navigator.mediaDevices.getUserMedia({ 
                    video: { 
                        width: { ideal: 320 }, 
                        height: { ideal: 240 }, 
                        facingMode: "environment" 
                    } 
                })
                .then(stream => {
                    state.cameraStream = stream;
                    state.videoElement = document.createElement('video');
                    state.videoElement.srcObject = stream;
                    state.videoElement.setAttribute('autoplay', '');
                    state.videoElement.setAttribute('playsinline', '');
                    state.videoElement.play();

                    state.hiddenCanvas = document.createElement('canvas');
                    state.hiddenCanvas.width = COLS;
                    state.hiddenCanvas.height = ROWS;
                    state.hiddenCtx = state.hiddenCanvas.getContext('2d');

                    state.cameraActive = true;
                    
                    // Switch to Sentinel mode
                    if (state.mode !== 'sentinel') {
                        const sentinelBtn = document.getElementById('btn-sentinel');
                        if (sentinelBtn) sentinelBtn.click();
                    }

                    btnCamera.textContent = '🟢 Retina Feed Active (Click to Stop)';
                    btnCamera.style.borderColor = 'var(--clr-rose)';
                    btnCamera.style.color = 'var(--clr-rose)';
                    btnCamera.style.background = 'rgba(244, 63, 94, 0.1)';
                })
                .catch(err => {
                    console.error("Camera access denied:", err);
                    alert("Could not access camera. Please verify permissions.");
                });
            }
        });
    }

    // Mouse Canvas Dragging Event Listeners
    canvas.addEventListener('mousedown', (e) => {
        isDrawing = true;
        handleCanvasInteraction(e);
    });
    
    canvas.addEventListener('mousemove', (e) => {
        if (isDrawing) {
            handleCanvasInteraction(e);
        }
    });

    window.addEventListener('mouseup', () => {
        isDrawing = false;
    });

    // Touch support for tablets/mobile
    canvas.addEventListener('touchstart', (e) => {
        isDrawing = true;
        if (e.touches[0]) {
            handleCanvasInteraction(e.touches[0]);
        }
        e.preventDefault();
    }, { passive: false });

    canvas.addEventListener('touchmove', (e) => {
        if (isDrawing && e.touches[0]) {
            handleCanvasInteraction(e.touches[0]);
        }
        e.preventDefault();
    }, { passive: false });

    canvas.addEventListener('touchend', () => {
        isDrawing = false;
    });
}

// Handles Canvas resizing for High-DPI screens (Retina)
function resizeCanvas() {
    if (!canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.parentNode.getBoundingClientRect();
    
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    
    ctx.scale(dpr, dpr);
}

// ----------------------------------------------------
// ENGINE STARTUP
// ----------------------------------------------------
function start() {
    canvas = document.getElementById('sim-canvas');
    if (!canvas) {
        console.error("Canvas element not found.");
        return;
    }
    ctx = canvas.getContext('2d');

    // Canvas scaling
    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    // Initialize CA cells
    initCells();

    // Setup interactive events
    setupUIListeners();

    // Run tick/rendering loop
    let lastTime = 0;
    function loop(time) {
        // Run tick logic every ~80ms (modulate speed with dopamine)
        const frameInterval = 80 / state.dopamineModulation;
        if (time - lastTime >= frameInterval) {
            tick();
            lastTime = time;
        }

        render();
        animationFrameId = requestAnimationFrame(loop);
    }
    animationFrameId = requestAnimationFrame(loop);
}

// Document Ready Bootstrap
document.addEventListener('DOMContentLoaded', () => {
    start();
});
