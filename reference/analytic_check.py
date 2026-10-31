"""Independent steady-state check of the two-area system (numpy only).

Solves the positive-sequence phasor circuit
    E1 -- Zs -- bus1 ==== 150 km ==== mid ==== 150 km ==== bus2 -- Zs -- E2
with the exact long-line (ABCD) model of each section, for the three
steady-state cases and the fault-on state of the fault case. Nothing here
uses Simulink. The inputs are typed in below on purpose; the MATLAB test
compares them with src/params.m so that the two cannot drift apart.

Conventions (same as the model):
  * Phasors are RMS, phase-to-neutral. Three-phase S = 3 V conj(I).
  * Current is positive flowing out of a bus into the line, at both ends.
    So P2 < 0 when power arrives at bus 2, and the line loss is P1 + P2.
  * Delta-theta = angle(V1) - angle(V2).

Usage:  python reference/analytic_check.py [output.json]
Default output: results/analytic_reference.json
"""

import json
import math
import sys
from pathlib import Path

import numpy as np

# ---- Inputs (must match src/params.m; checked by tests/test_steady_state.m)
INPUTS = {
    "f_Hz": 50.0,
    "V1_LL_rms_V": 400e3,
    "V1_angle_deg": 0.0,
    "V2_LL_rms_V": 400e3,
    "line_length_km": 300.0,
    "line_n_sections": 2,
    "line_R1_ohm_per_km": 0.03,
    "line_L1_H_per_km": 0.9e-3,
    "line_C1_F_per_km": 0.0125e-6,
    "line_G1_S_per_km": 0.0,
    "src_Ssc_VA": 10e9,
    "src_XR": 10.0,
    "fault_R_ohm": 0.01,
}
CASES = [
    {"id": 1, "V2_angle_deg": 0.0, "fault": False},
    {"id": 2, "V2_angle_deg": -10.0, "fault": False},
    {"id": 3, "V2_angle_deg": -20.0, "fault": False},
    {"id": 4, "V2_angle_deg": -10.0, "fault": True},   # fault-on steady state
    {"id": 5, "V2_angle_deg": -10.0, "fault": False},  # post-fault = pre-fault
]


def source_impedance(inp):
    """Series R + jX from short-circuit level and X/R (same formula as params.m)."""
    z = inp["V1_LL_rms_V"] ** 2 / inp["src_Ssc_VA"]
    r = z / math.sqrt(1.0 + inp["src_XR"] ** 2)
    return complex(r, r * inp["src_XR"])


def abcd(inp, length_km):
    """Exact long-line ABCD matrix for one section."""
    w = 2 * math.pi * inp["f_Hz"]
    z = inp["line_R1_ohm_per_km"] + 1j * w * inp["line_L1_H_per_km"]
    y = inp["line_G1_S_per_km"] + 1j * w * inp["line_C1_F_per_km"]
    gamma = np.sqrt(z * y)
    zc = np.sqrt(z / y)
    gl = gamma * length_km
    a = np.cosh(gl)
    b = zc * np.sinh(gl)
    c = np.sinh(gl) / zc
    return np.array([[a, b], [c, a]]), gamma, zc


def equivalent_pi(m):
    """Exact equivalent pi of a symmetric two-port: series Z, shunt Y/2 each end."""
    a, b = m[0, 0], m[0, 1]
    return b, (a - 1) / b


def solve(inp, v2_angle_deg, fault):
    """Nodal solution with nodes bus1, mid, bus2. Returns a dict of results."""
    zs = source_impedance(inp)
    vph1 = inp["V1_LL_rms_V"] / math.sqrt(3)
    vph2 = inp["V2_LL_rms_V"] / math.sqrt(3)
    e1 = vph1 * np.exp(1j * math.radians(inp["V1_angle_deg"]))
    e2 = vph2 * np.exp(1j * math.radians(v2_angle_deg))

    sec_len = inp["line_length_km"] / inp["line_n_sections"]
    m_sec, _, _ = abcd(inp, sec_len)
    zser, yhalf = equivalent_pi(m_sec)
    ys = 1 / zs
    yser = 1 / zser

    # Admittance matrix, node order: bus1, mid, bus2
    Y = np.zeros((3, 3), dtype=complex)
    Y[0, 0] = ys + yser + yhalf
    Y[1, 1] = 2 * (yser + yhalf)
    Y[2, 2] = ys + yser + yhalf
    Y[0, 1] = Y[1, 0] = -yser
    Y[1, 2] = Y[2, 1] = -yser
    if fault:
        Y[1, 1] += 1 / inp["fault_R_ohm"]
    inj = np.array([e1 * ys, 0, e2 * ys])
    v = np.linalg.solve(Y, inj)

    v1, vm, v2 = v
    i1 = (e1 - v1) * ys          # out of bus 1 into the line
    i2 = (e2 - v2) * ys          # out of bus 2 into the line
    s1 = 3 * v1 * np.conj(i1)
    s2 = 3 * v2 * np.conj(i2)
    out = {
        "V1_ph_rms_V": abs(v1), "V2_ph_rms_V": abs(v2), "Vmid_ph_rms_V": abs(vm),
        "V1_angle_deg": math.degrees(np.angle(v1)), "V2_angle_deg": math.degrees(np.angle(v2)),
        "I1_rms_A": abs(i1), "I2_rms_A": abs(i2),
        "I1_angle_deg": math.degrees(np.angle(i1)), "I2_angle_deg": math.degrees(np.angle(i2)),
        "dtheta_deg": math.degrees(np.angle(v1 / v2)),
        "P1_W": s1.real, "Q1_var": s1.imag, "P2_W": s2.real, "Q2_var": s2.imag,
        "loss_W": s1.real + s2.real,
    }
    if fault:
        out["If_rms_A"] = abs(vm) / inp["fault_R_ohm"]
    return out


def solve_two_port(inp, v2_angle_deg):
    """Same no-fault case from the full-line ABCD matrix, as an internal cross-check."""
    zs = source_impedance(inp)
    e1 = inp["V1_LL_rms_V"] / math.sqrt(3) * np.exp(1j * math.radians(inp["V1_angle_deg"]))
    e2 = inp["V2_LL_rms_V"] / math.sqrt(3) * np.exp(1j * math.radians(v2_angle_deg))
    m, _, _ = abcd(inp, inp["line_length_km"])
    a, b, c, d = m[0, 0], m[0, 1], m[1, 0], m[1, 1]
    # Unknowns x = [V1, I1, V2, I2]
    M = np.array([
        [1, 0, -a, b],    # V1 = A V2 + B (-I2)
        [0, 1, -c, d],    # I1 = C V2 + D (-I2)
        [1, zs, 0, 0],    # V1 = E1 - Zs I1
        [0, 0, 1, zs],    # V2 = E2 - Zs I2
    ], dtype=complex)
    x = np.linalg.solve(M, np.array([0, 0, e1, e2]))
    s1 = 3 * x[0] * np.conj(x[1])
    return s1.real, math.degrees(np.angle(x[0] / x[2]))


def lossless_formula(inp, v2_angle_deg):
    """Brief's simplified formula, three-phase: V_LL^2 / X_loop * sin(delta).

    X_loop includes both source reactances; delta is between the internal
    source voltages, not between the bus PMUs.
    """
    w = 2 * math.pi * inp["f_Hz"]
    x_line = w * inp["line_L1_H_per_km"] * inp["line_length_km"]
    x_loop = x_line + 2 * source_impedance(inp).imag
    delta = math.radians(inp["V1_angle_deg"] - v2_angle_deg)
    return inp["V1_LL_rms_V"] * inp["V2_LL_rms_V"] / x_loop * math.sin(delta), x_loop


def main():
    root = Path(__file__).resolve().parents[1]
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "results" / "analytic_reference.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    inp = INPUTS
    m_full, gamma, zc = abcd(inp, inp["line_length_km"])
    zs = source_impedance(inp)
    print("Line: gamma = %.4e + j%.4e 1/km, Zc = %.2f %+.2fj ohm" % (gamma.real, gamma.imag, zc.real, zc.imag))
    print("Source: Zs = %.3f + j%.3f ohm" % (zs.real, zs.imag))

    results = []
    print("\ncase  dtheta   |V1|kV  |V2|kV   I1 A    I2 A    P1 MW    P2 MW   Q1 Mvar  Q2 Mvar  loss MW  P_lossless MW")
    for c in CASES:
        r = solve(inp, c["V2_angle_deg"], c["fault"])
        r["case_id"] = c["id"]
        r["fault"] = c["fault"]
        r["V2_source_angle_deg"] = c["V2_angle_deg"]
        if not c["fault"]:
            p_ll, x_loop = lossless_formula(inp, c["V2_angle_deg"])
            p_abcd, dth_abcd = solve_two_port(inp, c["V2_angle_deg"])
            r["P_lossless_formula_W"] = p_ll
            r["X_loop_ohm"] = x_loop
            r["P1_full_ABCD_W"] = p_abcd
            # The split-line nodal solution and the full-line ABCD solution must agree
            assert abs(p_abcd - r["P1_W"]) < 1e-3 * max(1.0, abs(p_abcd)), (p_abcd, r["P1_W"])
            assert abs(dth_abcd - r["dtheta_deg"]) < 1e-9
        results.append(r)
        print("%4d %7.3f %8.2f %8.2f %7.1f %7.1f %8.2f %8.2f %8.2f %8.2f %8.3f %s" % (
            c["id"], r["dtheta_deg"], r["V1_ph_rms_V"] * math.sqrt(3) / 1e3, r["V2_ph_rms_V"] * math.sqrt(3) / 1e3,
            r["I1_rms_A"], r["I2_rms_A"], r["P1_W"] / 1e6, r["P2_W"] / 1e6, r["Q1_var"] / 1e6, r["Q2_var"] / 1e6,
            r["loss_W"] / 1e6, ("%10.2f" % (r["P_lossless_formula_W"] / 1e6)) if "P_lossless_formula_W" in r else "   (fault)"))

    with open(out_path, "w") as fh:
        json.dump({"inputs": inp, "cases": results}, fh, indent=2)
    print("\nwrote %s" % out_path)


if __name__ == "__main__":
    main()
