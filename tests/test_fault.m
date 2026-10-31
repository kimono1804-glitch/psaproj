function tests = test_fault
%TEST_FAULT Fault case: direction of change and recovery.
%   During the midpoint three-phase fault the PMU voltage magnitude must
%   drop and the current magnitude must rise at both buses. After clearing,
%   voltage, current and Delta-theta must return to their pre-fault values.
%   The fault-on PMU magnitudes are also compared with the analytic
%   fault-on steady state (a loose check: the PMU window averages a
%   transient with decaying DC offset, so it is reported with its error).
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
warning('off', 'all');
p = params();
mdl = build_model(p, 'save', false);
r = run_case(mdl, 4, p);
close_system(mdl, 0);
tc.TestData.r = r;
tc.TestData.a = analyze_case(r);
tc.TestData.root = root;
end

function testRanToEnd(tc)
verifyEqual(tc, tc.TestData.r.stop_event, 'ReachedStopTime');
end

function testVoltageDropsDuringFault(tc)
a = tc.TestData.a; pre = a.prefault; on = a.rows(1);
verifyLessThan(tc, on.V1_kV_LL_rms, 0.9*pre.V1_kV_LL_rms);
verifyLessThan(tc, on.V2_kV_LL_rms, 0.9*pre.V2_kV_LL_rms);
end

function testCurrentRisesDuringFault(tc)
a = tc.TestData.a; pre = a.prefault; on = a.rows(1);
verifyGreaterThan(tc, on.I1_A_rms, 2*pre.I1_A_rms);
verifyGreaterThan(tc, on.I2_A_rms, 2*pre.I2_A_rms);
end

function testRecoveryAfterClearing(tc)
a = tc.TestData.a; pre = a.prefault; post = a.rows(2);
verifyEqual(tc, post.V1_kV_LL_rms, pre.V1_kV_LL_rms, 'RelTol', 0.01);
verifyEqual(tc, post.V2_kV_LL_rms, pre.V2_kV_LL_rms, 'RelTol', 0.01);
verifyEqual(tc, post.I1_A_rms, pre.I1_A_rms, 'RelTol', 0.02);
verifyEqual(tc, post.I2_A_rms, pre.I2_A_rms, 'RelTol', 0.02);
verifyEqual(tc, post.dtheta_deg, pre.dtheta_deg, 'AbsTol', 0.5);
verifyEqual(tc, post.P1_MW, pre.P1_MW, 'RelTol', 0.02);
end

function testFrequencyStaysNominalOutsideFault(tc)
% Grid sources are ideal 50 Hz, so away from the fault the PMU sees 50 Hz
a = tc.TestData.a; p = tc.TestData.r.p;
for w = {p.prefault_window_s, p.postfault_window_s}
    in = a.t >= w{1}(1) & a.t <= w{1}(2);
    verifyEqual(tc, a.f1_Hz(in), p.f_Hz*ones(nnz(in), 1), 'AbsTol', 0.01);
end
end

function testReportAgainstAnalyticFault(tc)
% Loose check of the fault-on level against the analytic fault steady state
json = fullfile(tempdir, 'psaproj_analytic_reference.json');
if ~isfile(json)
    json = fullfile(tc.TestData.root, 'results', 'analytic_reference.json');
end
assumeTrue(tc, isfile(json), 'Run reference/analytic_check.py first.');
ref = jsondecode(fileread(json));
c = ref.cases; if ~iscell(c), c = num2cell(c); end
f = c{find(cellfun(@(x) x.case_id == 4, c), 1)};
on = tc.TestData.a.rows(1);
fprintf('\nfault-on window: |V1| %.1f kV (analytic %.1f), |I1| %.0f A (analytic %.0f), dtheta %.2f deg (analytic %.2f)\n', ...
    on.V1_kV_LL_rms, f.V1_ph_rms_V*sqrt(3)/1e3, on.I1_A_rms, f.I1_rms_A, on.dtheta_deg, f.dtheta_deg);
verifyEqual(tc, on.V1_kV_LL_rms, f.V1_ph_rms_V*sqrt(3)/1e3, 'RelTol', 0.10);
verifyEqual(tc, on.I1_A_rms, f.I1_rms_A, 'RelTol', 0.10);
end
