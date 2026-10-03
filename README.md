# fir4: 4-Tap FIR Filter, RTL-to-GDS

COMPE572 (VLSI Circuit Design), SDSU. A pipelined 4-tap symmetric FIR low-pass filter taken from a MATLAB golden model through RTL, synthesis, place-and-route, gate-level simulation, and formal equivalence checking.

| | |
|---|---|
| Filter | `y[n] = (x[n] + 3x[n-1] + 3x[n-2] + x[n-3]) >>> 3` |
| Coefficients | `[1 3 3 1] / 8` (binomial low-pass) |
| I/O | 8-bit signed in, 11-bit signed out |
| Clock target | 300 MHz (3.333 ns), 3-stage pipeline |
| Technology | gpdk045 (45 nm), gsclib045 standard cells |
| Tools | MATLAB, Xcelium, Genus, Innovus, Conformal LEC |

## Repository layout

```
SYNTH_PR_FLOW/
├── matlab/            golden model, test vectors, figures
├── rtl/               fir4.sv (pipelined RTL)
├── tb/                tb_fir4.sv + generated hex vectors
├── constraints/       fir4.sdc (300 MHz)
├── scripts/           Genus synthesis scripts
├── innovus/           Innovus P&R scripts (01_init ... 06_signoff)
├── fv/fir4/           Conformal LEC dofiles + reports
└── run_flow.sh        runs every stage
```

PDK and course files (`lib/`, `lef/`, `captable/`, `QRC_Tech/`, PDFs) are excluded from this repo. They live on volta only.

## Running the flow

Run on volta. `run_flow.sh` loads the `cadence_ece` module itself.

```bash
bash run_flow.sh --only matlab     # golden model + vectors + figures
bash run_flow.sh --only rtl        # RTL simulation
bash run_flow.sh --only synth      # Genus synthesis
bash run_flow.sh --only lec_synth  # RTL vs synth netlist
bash run_flow.sh --only pnr        # Innovus place-and-route
bash run_flow.sh --only gls_func   # functional gate-level sim
bash run_flow.sh --only gls_time   # timing gate-level sim (SDF)
bash run_flow.sh --only lec        # RTL vs post-P&R netlist
bash run_flow.sh                   # full flow
```

If the pre-flight Genus check fails, run `bash scripts/diag_env.sh`.

## MATLAB stage

| File | Purpose |
|---|---|
| `fir4_run_all.m` | Entry point: self-checks, then vectors, then figures |
| `fir4_golden.m` | Exact model (`filter()`) and bit-accurate RTL model |
| `fir4_gen_vectors.m` | Builds 8 test patterns, writes hex files for the TB |
| `fir4_visualize.m` | Saves 6 figures to `matlab/figures/` |

Run standalone with `matlab -batch "fir4_run_all"` from `matlab/`.

### RTL datapath modeled in `fir4_golden.m`

| Signal | Expression | Width |
|---|---|---|
| `sum_a` | `x[n] + x[n-3]` | 9-bit signed |
| `sum_b` | `x[n-1] + x[n-2]` | 9-bit signed |
| `prod_b` | `3 * sum_b` | 11-bit signed |
| `y` | `floor((sum_a + prod_b) / 8)` | 8-bit, sign-extended to 11 |

`floor` matches the hardware's arithmetic right shift, including negative values. The model asserts every signal fits its width, so sizing mistakes fail in MATLAB before they show up as LEC mismatches.

### Test vectors (716 total)

| Pattern | Length | What it checks |
|---|---|---|
| impulse | 16 | Output equals the taps |
| step | 32 | DC gain of 1 |
| ramp | 256 | Every input code from -128 to 127 |
| low-freq sine | 64 | Passband, passes nearly unchanged |
| high-freq sine | 64 | Near Nyquist, heavily attenuated |
| chirp | 128 | Full frequency sweep, DC to Nyquist |
| random | 128 | Arbitrary bit patterns (fixed seed) |
| saturation corners | 28 | Accumulator extremes (+1016, -1024) |

Output files, one value per line in two's complement hex for `$readmemh`:

- `tb/stim_vectors.hex`: 8-bit, 2 hex digits
- `tb/expected_vectors.hex`: 11-bit, 3 hex digits

### Figures

1. Frequency response (magnitude + phase)
2. Pole-zero plot
3. Impulse response, exact vs RTL
4. Chirp response
5. Spectrogram, input vs output
6. Quantization error (exact minus RTL)

## Status

- [ ] Part 1: MATLAB + RTL + RTL sim (716/716)
- [ ] Part 2: Synthesis + post-synth LEC
- [ ] Part 3: Place-and-route + signoff
- [ ] Part 4: Functional/timing GLS + post-P&R LEC
