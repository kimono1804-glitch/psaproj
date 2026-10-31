function tests = test_params
%TEST_PARAMS Derived values match the sanity numbers in CLAUDE.md section 4.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src'));
tc.TestData.p = params();
end

function testVoltages(tc)
p = tc.TestData.p;
verifyEqual(tc, p.V1_ph_rms_V, 230.94e3, 'RelTol', 1e-3);
verifyEqual(tc, p.V1_ph_peak_V, 326.6e3, 'RelTol', 1e-3);
end

function testSeriesImpedance(tc)
p = tc.TestData.p;
verifyEqual(tc, p.line_R_total_ohm, 9, 'RelTol', 1e-9);
verifyEqual(tc, p.line_L_total_H, 0.27, 'RelTol', 1e-9);
verifyEqual(tc, p.line_X_total_ohm, 84.82, 'RelTol', 1e-3);
end

function testShunt(tc)
p = tc.TestData.p;
verifyEqual(tc, p.line_C_total_F, 3.6e-6, 'RelTol', 1e-9);
verifyEqual(tc, p.line_B_total_S, 1.131e-3, 'RelTol', 1e-3);
verifyEqual(tc, p.line_Q_charging_var, 180e6, 'RelTol', 0.02);
end

function testSurge(tc)
p = tc.TestData.p;
verifyEqual(tc, p.line_Zc_lossless_ohm, 274, 'RelTol', 0.01);
verifyEqual(tc, p.line_SIL_W, 580e6, 'RelTol', 0.02);
verifyEqual(tc, p.line_travel_time_s, 1e-3, 'RelTol', 0.02);
verifyEqual(tc, p.line_electrical_length_deg, 18, 'RelTol', 0.03);
end

function testSourceImpedance(tc)
p = tc.TestData.p;
verifyEqual(tc, p.src_Z_ohm, 16, 'RelTol', 1e-9);
verifyEqual(tc, p.src_X_ohm, 16*10/sqrt(101), 'RelTol', 1e-9);
verifyEqual(tc, hypot(p.src_R_ohm, p.src_X_ohm), 16, 'RelTol', 1e-9);
q = params('src_impedance_enabled', false);
verifyEqual(tc, [q.src_R_ohm q.src_L_H], [0 0]);
end

function testPmuTiming(tc)
p = tc.TestData.p;
verifyGreaterThanOrEqual(tc, p.pmu_samples_per_cycle, 32);
verifyEqual(tc, p.pmu_report_ratio*p.pmu_Ts_s, 20e-3, 'AbsTol', 1e-12);
verifyEqual(tc, p.pmu_report_ratio, 64);
verifyError(tc, @() params('pmu_samples_per_cycle', 32), 'params:pmu');
end

function testOverrides(tc)
q = params('V2_angle_deg', -20, 'fault_enabled', true);
verifyEqual(tc, q.V2_angle_deg, -20);
verifyTrue(tc, q.fault_enabled);
verifyError(tc, @() params('no_such_field', 1), 'params:unknownField');
end
