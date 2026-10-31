# Two-Area Transmission Line with Two PMUs (MATLAB/Simulink)

This file tells Claude Code how to build, run and verify a Simulink model of two three-phase sources joined by a 300 km, 400 kV, 50 Hz transmission line, with one Phasor Measurement Unit (PMU) at each end. The model is used to study voltage and current phasors, the phase-angle difference between the buses, power flow, and what the PMUs see during a three-phase fault at the line midpoint.

Read the whole file before writing code. The first sections explain what we are building and why. The later sections are the working rules, the build plan, and the checks that decide when the work is finished.

## 1. Goal

Build the whole model from MATLAB scripts, so it can be regenerated, reviewed in git and tested without anyone clicking in the Simulink editor. Then run five operating cases, log the PMU outputs, and produce plots plus a short results table that can be compared against an independent hand calculation.

Success means all of the following are true:

1. `run_all` builds the model, runs all five cases and saves plots and a results table without manual steps.
2. Steady-state results agree with the independent analytic check in section 7 within the stated tolerances.
3. During the fault, the PMU voltage magnitude at the fault side drops, the current magnitude rises, and both recover after clearing.
4. Every number in the final summary comes from a logged run, not from expectation.

## 2. Decisions already made

The original brief left three choices open. Unless the user says otherwise, use these defaults and write them at the top of `README.md` so they are visible.

| Question | Default |
|---|---|
| Source type | Two equivalent grid sources (ideal voltage source behind a series R-L impedance) |
| Analysis | Both steady-state power flow and fault analysis |
| MATLAB version | Detect it with `ver` and `version` at the start of the session. Do not ask the user if it can be detected |

If MATLAB is not installed in the environment Claude Code is running in, say so plainly at the start. Still write all the code, but mark it as untested in the README and in the final message, and do not claim that any simulation ran.

## 3. Library choice (important, read this)

MathWorks is retiring the Simscape Electrical Specialized Power Systems library (powergui, `powerlib`). Its documentation notes that the library will be removed in R2026a, and tells users to move to the regular Simscape Electrical blocks. So:

- **R2026a or newer:** use Simscape Electrical physical-network blocks only. Specialized Power Systems blocks will not be available.
- **R2025b or older:** still use Simscape Electrical physical-network blocks. This keeps one code path for every version. Do not build a second Specialized Power Systems variant unless the user asks.

The PMU to use is **Phasor Measurement Unit (PMU, Three-Phase)** from Simscape / Electrical / Control / Measurements (introduced in R2020a). It takes a three-phase signal vector and returns frequency, phase and magnitude of the positive-sequence component, using the system clock as a shared reference, which stands in for GPS time. The older "PMU (PLL-Based, Positive-Sequence)" block reports phase relative to its own PLL, so two of them are not directly comparable. Do not use it for the angle difference.

The PMU block does not connect to the electrical network directly. It needs a signal vector, so each bus needs a three-phase voltage sensor and a three-phase current sensor, followed by whatever conversion blocks are needed to get a plain 3-element Simulink signal (for example PS-Simulink converters, then a Mux or the sensor's own vector output). The PMU gives the positive-sequence view of the signal only. It is not a full record of all three phase quantities, so also log the raw three-phase sensor signals for anything that needs them.

### Do not trust remembered block paths

Exact library paths and parameter names change between releases. Create `src/block_map.m`, which holds a list of candidate paths for each role (three-phase source, pi-section line, distributed line, three-phase fault, voltage sensor, current sensor, PMU, solver configuration, electrical reference). At the start of a build it must try each candidate in a scratch model, keep the first one that loads, and fail with a clear message listing what it tried if none work. When a path is unknown, use `find_system` or `libinfo` and the block's own documentation page (`doc <blockname>`) to discover it. Also read the real parameter names with `get_param(blk,'DialogParameters')` before calling `set_param`. Never guess a parameter name.

## 4. System data

These are illustrative starting values, not data from a real line.

| Parameter | Value |
|---|---|
| Source 1 voltage | 400 kV line-to-line RMS, 0 degrees |
| Source 2 voltage | 400 kV line-to-line RMS, -10 degrees for the base case |
| Frequency | 50 Hz |
| Line length | 300 km |
| Positive-sequence resistance | 0.03 ohm/km |
| Positive-sequence inductance | 0.9 mH/km |
| Positive-sequence capacitance | 0.012 uF/km |
| PMU reporting rate | 50 reports per second to start with |
| Simulation time | 2 s |

Derived values the code should compute (not hard-code), with the expected result for a sanity check:

- Phase-to-neutral RMS voltage: 400 kV / sqrt(3) = about 230.9 kV. Peak is about 326.6 kV.
- Total series resistance 9 ohm, inductance 0.27 H, series reactance about 84.8 ohm at 50 Hz.
- Total shunt capacitance 3.6 uF per phase, giving a shunt susceptance of about 1.13 mS and a charging power of roughly 180 MVAr for the whole line.
- Surge impedance about 274 ohm, so the surge impedance loading is roughly 580 MW.
- Wave travel time over 300 km is about 1 ms, and the line is about 18 electrical degrees long at 50 Hz. This is short enough that a pi-section is reasonable for power-frequency work, but the distributed model is the better reference.

### Assumptions that the brief did not give (flag them in the README)

- **Source impedance.** The brief says to set source impedance but gives no value. Assume a short-circuit level of 10 GVA with X/R of 10 at each end. That is a source reactance near 16 ohm. Keep it as named parameters in `params.m` so it is easy to change. Zero source impedance makes the angle across the line equal the source angle difference exactly, which is a useful special case for testing.
- **Fault.** Three-phase fault at the midpoint, fault resistance 0.01 ohm, applied at t = 1.00 s, cleared at t = 1.10 s. Keep these as parameters.
- **Zero-sequence data.** Not given. For balanced three-phase cases it does not matter. If any block demands zero-sequence values, use a documented placeholder (for example R0 = 3 R1, L0 = 3 L1, C0 = 0.6 C1) and say so.

## 5. Repository layout

```
.
  CLAUDE.md                this file
  README.md                how to run, assumptions, known limits
  src/
    params.m               all numbers live here, one struct, with units in names
    block_map.m            resolves library paths for the installed release
    build_model.m          creates and saves the Simulink model from scratch
    set_case.m             applies a case (angle, fault on/off) to the model
    run_case.m             simulates one case, returns a logged result struct
    analyze_case.m         computes Delta-theta, P, Q, and summary numbers
    plot_case.m            makes the plots listed in section 8
    run_all.m              entry point, runs everything, writes results
  reference/
    analytic_check.py      independent steady-state calculation (section 7)
  tests/
    test_params.m          derived values match section 4
    test_model_builds.m    model builds, compiles, has no unconnected ports
    test_steady_state.m    compares Simulink against the analytic check
    test_fault.m           checks the fault direction of change and recovery
  results/                 generated, git-ignored except the summary table
  models/                  generated .slx, git-ignored
```

Keep the generated `.slx` out of git and rebuild it from `build_model.m`. Commit the scripts, the tests and the summary table.

## 6. Build plan

Work in this order. Do not move on until the current step passes its check. After each step, run the check and show the actual output.

1. **Environment.** Report `version`, `ver` entries for Simulink, Simscape and Simscape Electrical, and whether `matlab -batch` works. If a toolbox is missing, stop and tell the user which one.
2. **Parameters.** Write `params.m`. Add `test_params.m` to confirm the derived numbers in section 4.
3. **Block map.** Write `block_map.m` and run it against the installed release. Print the resolved path for every role.
4. **Skeleton model.** In `build_model.m`, create the model, add the Solver Configuration and Electrical Reference blocks, the two sources and a single line section, and connect them. Get it to compile and run for 0.2 s with no PMUs.
5. **Line model.** Use the distributed-parameter three-phase line as the reference model. Also support a pi-section option for comparison, selected by a flag in `params.m`. For the fault case, split the line into two 150 km sections so the fault block sits at the midpoint. Use the same split in the no-fault cases, so the cases differ only by the fault switch.
6. **Measurement.** At bus 1 and bus 2 add a three-phase voltage sensor and a three-phase current sensor. Define the current direction once, positive when flowing out of the bus into the line, and use it everywhere. Add a PMU on the voltage and another on the current at each bus. That is four PMU blocks, or two if the current is analysed separately, but voltage at both ends is the minimum.
7. **Logging.** Log, using named signals, the PMU outputs (frequency, phase, magnitude), the raw three-phase voltages and currents, and the active and reactive power at both ends. Use `Simulink.SimulationOutput` and save it with the case name.
8. **Cases.** Implement `set_case.m` for the five cases in section 8. Run each one.
9. **Analysis and plots.** Compute Delta-theta(t), power, and the summary table. Generate the plots.
10. **Verification.** Run the analytic check and the tests. Report any mismatch honestly, with numbers, and investigate before adjusting tolerances.

### PMU settings

The block has a rated frequency, a number of samples per cycle, and a ratio between reporting rate and sampling rate. Set the rated frequency to 50 Hz. Choose the samples per cycle to be at least 32. The reporting period equals the ratio times the sample time, so pick the ratio that gives 20 ms between reports for the 50 reports per second target, then confirm it by measuring the spacing of the logged output times. Remember that the PMU needs about one cycle (20 ms) to settle after start-up and after a step change, so ignore the first cycle in checks and expect the angle estimate to lag the true waveform during the fault.

### Solver

Start with a variable-step stiff solver such as `ode23t`, maximum step around 1e-4 s, and tighten the tolerances if the fault transients look unreliable. Keep the model's simulation time at 2 s. If the PMU sample times conflict with the variable-step solver, switch to a fixed-step Simscape local solver with a step of 20 to 50 microseconds and record that in the README.

## 7. Independent check

The Simulink result must be checked against something that does not use Simulink. Write `reference/analytic_check.py` (numpy only) that computes the steady-state solution of the same system in phasors.

1. Per-kilometre series impedance z = R' + j w L' and shunt admittance y = j w C'.
2. Propagation constant gamma = sqrt(z y) and characteristic impedance Zc = sqrt(z / y).
3. Two-port ABCD matrix for the full 300 km: A = D = cosh(gamma l), B = Zc sinh(gamma l), C = sinh(gamma l) / Zc.
4. Add the source impedances at each end, solve for the bus voltages and currents, then compute the angle difference between the buses and the three-phase P and Q at each end.

Then compare with the simplified lossless formula from the brief. Be careful with one detail: the brief writes P = |V1||V2| sin(delta) / X using phase-to-neutral voltages, which is the power **per phase**. The three-phase total is three times that, which equals V_LL squared divided by X times sin(delta). Also, X here is the total reactance in the loop, so it should include the two source reactances if they are not zero, and delta is the angle between the two internal source voltages, not between the bus PMUs.

As a rough guide to what to expect for the base case, a lossless line alone (zero source impedance) at 10 degrees gives about 330 MW, and 20 degrees gives about 645 MW. With the assumed source impedances in section 4, the transfer is clearly lower, in the region of 240 MW at 10 degrees. Use these only as a plausibility check. The analytic script, not these numbers, is the reference.

Tolerances to start with: bus voltage magnitude within 1 percent, angle difference within 0.5 degrees, active power within 3 percent against the exact ABCD result. The simplified lossless formula will be off by more than that because it ignores resistance and shunt capacitance. Report the gap instead of forcing agreement.

## 8. Operating cases and outputs

| Case | Condition | What should be observed |
|---|---|---|
| 1 | Source 2 at 0 degrees | Very little active power. A small current remains because of the line charging |
| 2 | Source 2 at -10 degrees | Active power flows from source 1 to source 2 |
| 3 | Source 2 at -20 degrees | Larger transfer, within the line and source limits |
| 4 | Three-phase fault at midpoint, t = 1.00 s, on top of case 2 | Voltage drops, current rises, PMU estimates change |
| 5 | Fault cleared at t = 1.10 s | Voltage, current and angle recover according to the system dynamics |

Cases 4 and 5 are one simulation with a fault window, analysed in two parts: fault-on and post-fault. Cases 1 to 3 are steady-state runs.

Sign convention: the angle difference is Delta-theta(t) = theta_PMU1(t) - theta_PMU2(t). With source 2 at -10 degrees, source 1 leads, so active power flows from bus 1 to bus 2 and Delta-theta is positive. Write this at the top of `analyze_case.m` and keep it consistent in every plot label.

Plots to produce for each case, saved as PNG in `results/`, on separate axes or a dashboard:

1. Voltage magnitude at both buses (PMU output).
2. Current magnitude at both terminals.
3. PMU phase angles and their difference.
4. Frequency and rate of change of frequency (compute ROCOF from the logged frequency).
5. Active and reactive power at both ends.
6. Fault-on and post-fault responses, with the fault window shaded.

Also write `results/summary.csv` with one row per case: steady-state or window-averaged voltage and current magnitudes, Delta-theta, P and Q at each end, and the line loss (P sent minus P received).

## 9. Working rules for Claude Code

- Run things. Do not describe what a script would do when you can run `matlab -batch "run('src/run_all.m')"` and read the output. Quote real output when reporting.
- Never report a result you did not produce. If a run failed or could not be done, say so and show the error.
- Do not edit generated files by hand. Fix the script that generates them.
- Put every number in `params.m`. No magic numbers inside the builders.
- Keep commits small, one per build-plan step, with a message that says what was checked.
- When a block path or parameter name is uncertain, discover it from the installed release instead of guessing.
- If a result looks wrong (for example power flowing the wrong way, or Delta-theta of the wrong sign), check the sensor polarity and current direction first. Those are the usual cause.
- If you must deviate from this file, write the reason in the README under "Deviations".
- Use plain, readable prose in the README and comments. No em dashes.

## 10. Known limits to state in the README

- Parameters are illustrative, not from a real line.
- Positive-sequence data only. Unbalanced faults need zero-sequence data and are out of scope for the first version.
- The PMU block estimates the positive-sequence phasor over a one-cycle window, so its output lags and smears fast transients. It is not a full IEEE C37.118 P-class or M-class implementation.
- The simplified power formula ignores resistance and shunt capacitance.

## 11. Extensions, after the base model passes

Only start these when the user asks.

1. Synchrophasor-based fault detection and location using the two end measurements.
2. Wide-area monitoring of the angle difference with alarm thresholds.
3. Two synchronous generators in place of the grid sources, with governor and exciter models.
4. Unbalanced faults with proper zero-sequence line data.
5. Higher PMU reporting rates (100 reports per second) and a comparison of settling behaviour.
