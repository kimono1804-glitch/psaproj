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
| Library | Simscape Electrical physical-network blocks only (no Specialized Power Systems) |

Toolboxes used: MATLAB, Simulink, Simscape, Simscape Electrical (all 25.2).
Python 3 with numpy is used for the independent analytic check.

## How to run

The `matlab` command on this machine points at R2026a, which does not have Simscape.
Call R2025b by its full path:

```
"C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "cd src; run_all"
```

Tests:

```
"C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "addpath src; r = runtests('tests'); disp(table(r)); assertSuccess(r)"
```

Analytic check:

```
C:\Users\nevin\miniconda3\python.exe reference\analytic_check.py
```

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
