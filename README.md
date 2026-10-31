# psaproj: two-area transmission line with two PMUs

A Simulink model of two 400 kV, 50 Hz grid sources joined by a 300 km line, with a
Phasor Measurement Unit (PMU) at each end. Everything is built from MATLAB scripts.
See `CLAUDE.md` for the full specification.

## Decisions

| Question | Choice |
|---|---|
| Source type | Two equivalent grid sources (ideal voltage source behind a series R-L impedance) |
| Analysis | Steady-state power flow and a midpoint three-phase fault |
| MATLAB version | R2025b Update 7 (25.2), detected with `ver` |
| Line model | Two 150 km nominal pi sections (distributed model could not run the fault case, see Deviations) |
| Solver | ode23t, variable step, max step 1e-4 s, RelTol 1e-4 |
| Library | Simscape Electrical physical-network blocks only (no Specialized Power Systems) |

Toolboxes used: MATLAB, Simulink, Simscape, Simscape Electrical (all 25.2).
Python 3 with numpy is used for the independent analytic check.

## How to run

The `matlab` command on this machine points at R2026a, which does not have Simscape.
Call R2025b by its full path. Run these from the repository folder, in PowerShell (the
`&` is needed to run a quoted program path):

```powershell
cd "C:\Users\nevin\Desktop\aeryal flow\psaproj\psaproj"
& "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "cd src; run_all"
```

Tests:

```powershell
& "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "addpath src; r = runtests('tests'); disp(table(r)); assertSuccess(r)"
```

Analytic check:

```powershell
& "C:\Users\nevin\miniconda3\python.exe" reference\analytic_check.py
```

In cmd.exe, leave out the `&`.

`run_all` takes about 2.5 minutes and the test suite about 6 minutes on the development
machine. Outputs go to `results/`: one dashboard PNG per simulation, a fault zoom PNG,
`summary.csv`, `report.html`, and the saved `Simulink.SimulationOutput` for each case.

## Viewing the results

`run_all` ends by showing the results:

- **From the terminal** (`matlab -batch`): `results/report.html` opens in your web browser.
  It is one self-contained page: headline numbers, what each case shows, the results
  table, the verification against the analytic solution with pass or fail for each
  check, and every plot. It can be shared as a single file.
- **Inside the MATLAB desktop** (`cd src; run_all` in the Command Window): a results
  window opens with the same report, plus a toolbar to open any case as zoomable MATLAB
  figures (redrawn from the saved simulation, no re-run) or open the report in a browser.

To look at results again later without re-simulating, run `show_results` in the MATLAB
desktop (with `src` on the path), or open `results/report.html` directly.
`run_all('show', false)` writes everything but opens nothing. The report follows the
system light or dark setting.

## Files

| File | Purpose |
|---|---|
| `src/params.m` | Every number, one struct, units in field names. Derived values computed here. |
| `src/block_map.m` | Finds library blocks for this release, checks parameter names, records port roles and enum values. |
| `src/build_model.m` | Builds `models/two_area_pmu.slx` from scratch (stages: skeleton, line, full). |
| `src/set_case.m` | Applies a case: model workspace `P`, source impedance, fault, solver. |
| `src/run_case.m` | Simulates one case and returns the logged PMU, raw and P/Q signals. |
| `src/analyze_case.m` | Delta-theta, ROCOF, window averages, summary rows. Sign conventions at the top. |
| `src/plot_case.m` | Dashboards and the fault zoom plot. |
| `src/run_all.m` | Entry point. |
| `src/make_report.m` | Writes `results/report.html` from the saved results. |
| `src/show_results.m` | MATLAB results window (report plus zoomable figures). |
| `src/compare_with_analytic.m` | Simulink against the analytic solution, pass or fail per check. |
| `src/extract_signals.m` | Pulls PMU, raw and P/Q signals out of a saved simulation. |
| `src/find_python.m` | Finds a Python with numpy for the analytic check. |
| `src/set_block_params.m` | Sets block parameters only if the name exists and is not hidden. |
| `reference/analytic_check.py` | Independent steady state with numpy and the exact ABCD line model. |

## Results (R2025b, from `results/summary.csv`)

| Case | Window (s) | V1 kV | V2 kV | I1 A | I2 A | Delta-theta deg | P1 MW | Q1 Mvar | P2 MW | Q2 Mvar | Loss MW |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1, source 2 at 0 deg | 1.5 to 2.0 | 403.81 | 403.81 | 138.2 | 138.2 | 0.000 | 0.15 | -96.67 | 0.15 | -96.67 | 0.30 |
| 2, source 2 at -10 deg | 1.5 to 2.0 | 403.10 | 403.05 | 380.3 | 352.9 | 7.237 | 243.41 | -106.11 | -239.91 | -55.96 | 3.50 |
| 3, source 2 at -20 deg | 1.5 to 2.0 | 400.94 | 400.84 | 705.2 | 676.5 | 14.526 | 482.48 | -84.01 | -469.48 | 14.77 | 13.00 |
| 4, fault on | 1.04 to 1.09 | 291.75 | 291.76 | 3947.9 | 3744.9 | 10.369 | 252.13 | 1954.58 | 250.91 | 1947.48 | 503.04 |
| 5, after clearing | 1.6 to 2.0 | 403.10 | 403.05 | 380.3 | 352.9 | 7.237 | 243.41 | -106.11 | -239.91 | -55.96 | 3.50 |

Voltages are line-to-line RMS and currents RMS, both from the PMUs. P and Q are
time-averaged from the instantaneous three-phase P and Q of the raw signals.

What the cases show:

- Case 1: almost no active power. Each end takes about 97 Mvar of line charging.
- Cases 2 and 3: power flows from bus 1 to bus 2 and Delta-theta is positive, as
  expected. The angle across the line (7.2 and 14.5 deg) is smaller than the source
  angle (10 and 20 deg) because part of it sits across the source impedances.
- Case 4: both bus voltages fall to about 292 kV (0.72 pu) and the currents rise about
  tenfold, to about 3.9 kA. Delta-theta rises to about 10 deg.
- Case 5: everything returns to the case 2 values. The PMU voltage settles within about
  0.2 s of clearing.

Reading the fault rows: the window holds only three PMU reports and the currents carry a
decaying DC offset, so the fault-on numbers are approximate. P, Q and loss in row 4 are
averages over a transient. The column `P1_from_PMU_MW` (P from the PMU V and I phasors)
is a steady-state cross-check only. It matches the instantaneous P to 0.001 percent in
cases 1, 2, 3 and 5. During the fault, the current lags the voltage by about 84 deg, so
P depends on the cosine of an angle near 90 deg, and a few degrees of PLL transient
swings it widely (-376 MW in row 4).

## Verification

`tests/test_steady_state.m` compares cases 1 to 3 with `reference/analytic_check.py`
(exact ABCD line, no Simulink):

| Quantity | Worst difference | Tolerance |
|---|---|---|
| Bus voltage magnitude | 0.003 percent | 1 percent |
| Delta-theta | 0.017 deg (case 3) | 0.5 deg |
| Active power P1, P2 | 0.34 percent (case 3, P2) | 3 percent |
| Reactive power (reported only) | 0.2 Mvar | none |
| Line loss (reported only) | +0.13 MW in every case | none |

The simplified lossless formula, three-phase P = V_LL^2 / X_loop sin(delta) with
X_loop = 84.8 + 2 x 15.9 = 116.7 ohm and delta between the source voltages, gives 238.2
and 469.1 MW for cases 2 and 3. That is 2.2 and 2.9 percent below Simulink, because it
ignores resistance and line charging.

`tests/test_fault.m`: during the fault the voltage drops below 0.9 of pre-fault and the
current rises above twice pre-fault at both buses. After clearing, voltage and current
return within 1 and 2 percent and Delta-theta within 0.5 deg. The fault-on PMU values
are within 10 percent of the analytic fault-on steady state (V1 291.7 against 291.5 kV,
I1 3948 against 3914 A).

All 25 tests pass: `test_params` 7, `test_model_builds` 5, `test_steady_state` 7,
`test_fault` 6.

## Assumptions not given in the brief

- Source impedance: short-circuit level 10 GVA, X/R = 10 at each end (about 16 ohm).
- Fault: three-phase, midpoint, 0.01 ohm, applied at 1.00 s, cleared at 1.10 s.
- Zero-sequence data: not given. Placeholders R0 = 3 R1, L0 = 3 L1, C0 = 0.6 C1 are used
  only where a block demands them. They do not affect balanced cases.

All of these are named fields in `src/params.m`.

## Conventions

- Current is positive when flowing out of a bus into the line, at both ends.
  So P at bus 2 is negative when power arrives there, and the line loss is P1 + P2.
- Delta-theta(t) = theta_PMU1(t) - theta_PMU2(t). Positive when bus 1 leads.

## Deviations

- Line capacitance is 0.0125 uF/km, not 0.012 uF/km. With L = 0.9 mH/km, the brief's
  value gives a wave speed of 1/sqrt(LC) = 304,000 km/s, which is faster than light.
  Both Simscape Electrical line blocks refuse to compile that. 0.0125 uF/km is a typical
  400 kV value (0.994 c). L, R and the series reactance (84.8 ohm) are unchanged. New
  derived values: C total 3.75 uF, B 1.178 mS, charging 188.5 MVAr, Zc 268.3 ohm,
  SIL 596 MW, travel time 1.006 ms, electrical length 18.1 degrees. Agreed with the user.

- The main line model is the three-phase pi block, not the distributed model. Each
  150 km section is one nominal pi (`line_model = 'pi'`). Reasons:
  1. Simscape Electrical R2025b has no three-phase distributed line that takes R, L, C
     per km. The distributed option uses the single-phase "Transmission Line" block in
     "Distributed parameter line" mode, one per phase, with positive-sequence data and
     no mutual coupling (exact for balanced conditions).
  2. That distributed model runs the no-fault cases, but with the fault it fails to
     simulate. The solver cannot find consistent states at fault inception. Tried:
     ode23t and ode15s with looser and tighter tolerances, more nonlinear iterations,
     fixed-step local solvers (Backward Euler and trapezoidal, 20 to 50 us), source
     parasitic conductance, the other source impedance option, larger fault resistance,
     and a smooth variable-resistor fault instead of the Fault block. All failed. It
     only ran with zero source impedance, which would drop the assumed 16 ohm source.
  3. Multi-segment pi (3 or more segments per section) also stalls in the fault case
     (over 120 s for 1.2 s of simulation), while one segment per section runs in seconds.
  For 150 km at 50 Hz (about 9 electrical degrees) a nominal pi differs from the exact
  line by well under 1 percent, and the exact ABCD analytic check stays the independent
  reference.
  4. The planned distributed comparison for cases 1 to 3 could not be produced. In the
     full model the distributed option also fails without a fault, at t = 1.2556 to
     1.2574 s ("transient initialization ... failed to converge"), for every steady
     case. Raising the Simscape delay memory budget from 1 MB to 64 MB made no
     difference. The cause is not known. `run_all('skip_distributed', false)` still
     tries it and prints the failure; it is off by default.
- PMU inputs are scaled to per unit, and the PMU's inner PLL has its input normalisation
  switched on. The PMU (Three-Phase) block is a PLL with fixed gains (Kp = 100, Ki = 1000)
  and its mask fixes the inner "Sinusoidal Measurement (PLL, Three-Phase)" block's input
  normalisation off, so the PLL speed depends on the signal size:
  1. Fed raw volts and amps it diverged (frequency estimates of -2400 to +340 Hz).
  2. Scaled to per unit (voltage base 326.6 kV peak, current base from 500 MVA), voltage
     PMUs were exact, but no single current base worked for every case. A bench run of
     the PMU on recorded currents, against a one-cycle DFT of the same signal, gave:
     500 MVA base: fault current read 675 to 1277 A peak (true 5516 A) and the angle was
     out by up to 173 degrees after clearing (lost lock). 5000 MVA base: fault current
     right, but the small case 1 current angle was out by up to 28 degrees (slow PLL).
  3. With the inner PLL's input normalisation on, every case matched the DFT within
     0.05 degrees and the fault current within about 1 percent (5285 to 5469 A peak after
     the first report), independent of the base.
  So `build_model` deactivates the library link on each PMU copy in the model (the
  library is untouched) and sets `InputNormalization` on in its inner PLL block. Set
  `pmu_input_normalization = false` in `params.m` to use the stock block. Logged raw
  signals stay in SI units, and `run_case` converts PMU magnitudes back to SI. PMU
  magnitudes are peak values; the summary table converts them to RMS.
- PMU samples per cycle is 64, not 32. The PMU (Three-Phase) block in R2025b only offers
  24, 48 or 64. 64 meets the "at least 32" rule. With Ts = 1/(50*64) = 0.3125 ms, a
  reporting rate factor k = 64 gives one report every 20 ms (50 per second).

## Known limits

- Parameters are illustrative, not from a real line.
- Positive-sequence data only. Unbalanced faults are out of scope.
- The PMU block estimates the positive-sequence phasor over a one-cycle window, so its
  output lags and smears fast transients. It is not a full IEEE C37.118 P-class or
  M-class implementation.
- The simplified power formula ignores resistance and shunt capacitance.
