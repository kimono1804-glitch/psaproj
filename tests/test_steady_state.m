function tests = test_steady_state
%TEST_STEADY_STATE Simulink steady state against the independent analytic check.
%   Runs reference/analytic_check.py (numpy, exact ABCD line model), checks
%   that its inputs match params.m, then simulates cases 1 to 3 and compares:
%     bus voltage magnitude within 1 percent
%     Delta-theta within 0.5 deg
%     active power within 3 percent (case 1, near zero P: within 3 percent
%       of the case 2 transfer, as an absolute tolerance)
%   The gap to the brief's simplified lossless formula is reported, not tested.
%   Set PSAPROJ_PYTHON to choose the Python interpreter.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
warning('off', 'all');
tc.TestData.root = root;

py = getenv('PSAPROJ_PYTHON');
if isempty(py)
    cand = fullfile(getenv('USERPROFILE'), 'miniconda3', 'python.exe');
    if isfile(cand), py = cand; else, py = 'python'; end
end
json = fullfile(tempdir, 'psaproj_analytic_reference.json');
cmd = sprintf('"%s" "%s" "%s"', py, fullfile(root, 'reference', 'analytic_check.py'), json);
[st, txt] = system(cmd);
assertEqual(tc, st, 0, sprintf('analytic_check.py failed:\n%s', txt));
fprintf('%s\n', txt);
tc.TestData.ref = jsondecode(fileread(json));

p = params();
tc.TestData.p = p;
mdl = build_model(p, 'save', false);
for id = 1:3
    r = run_case(mdl, id, p);
    tc.TestData.a{id} = analyze_case(r);
end
close_system(mdl, 0);
end

function testInputsMatchParams(tc)
p = tc.TestData.p;
in = tc.TestData.ref.inputs;
f = fieldnames(in);
for k = 1:numel(f)
    verifyEqual(tc, in.(f{k}), p.(f{k}), 'RelTol', 1e-12, ...
        sprintf('analytic_check.py input %s differs from params.m', f{k}));
end
end

function testVoltageMagnitude(tc)
for id = 1:3
    [s, ref] = pick(tc, id);
    verifyEqual(tc, s.V1_kV_LL_rms, ref.V1_ph_rms_V*sqrt(3)/1e3, 'RelTol', 0.01, sprintf('case %d |V1|', id));
    verifyEqual(tc, s.V2_kV_LL_rms, ref.V2_ph_rms_V*sqrt(3)/1e3, 'RelTol', 0.01, sprintf('case %d |V2|', id));
end
end

function testAngleDifference(tc)
for id = 1:3
    [s, ref] = pick(tc, id);
    verifyEqual(tc, s.dtheta_deg, ref.dtheta_deg, 'AbsTol', 0.5, sprintf('case %d dtheta', id));
end
end

function testActivePower(tc)
[~, ref2] = pick(tc, 2);
absTol = 0.03*abs(ref2.P1_W)/1e6;
for id = 1:3
    [s, ref] = pick(tc, id);
    for e = {'1', '2'}
        sim_ = s.(['P' e{1} '_MW']);
        exact = ref.(['P' e{1} '_W'])/1e6;
        if id == 1
            verifyEqual(tc, sim_, exact, 'AbsTol', absTol, sprintf('case 1 P%s', e{1}));
        else
            verifyEqual(tc, sim_, exact, 'RelTol', 0.03, sprintf('case %d P%s', id, e{1}));
        end
    end
end
end

function testPowerDirectionAndSign(tc)
% Source 1 leads in cases 2 and 3: power flows bus 1 -> bus 2, dtheta > 0
for id = 2:3
    s = pick(tc, id);
    verifyGreaterThan(tc, s.P1_MW, 0);
    verifyLessThan(tc, s.P2_MW, 0);
    verifyGreaterThan(tc, s.dtheta_deg, 0);
    verifyGreaterThan(tc, s.loss_MW, 0);
end
end

function testPmuPowerMatchesInstantaneous(tc)
for id = 2:3
    s = pick(tc, id);
    verifyEqual(tc, s.P1_from_PMU_MW, s.P1_MW, 'RelTol', 0.01);
end
end

function testReportComparison(tc)
% Not a pass/fail check: prints Simulink vs exact vs the lossless formula.
fprintf('\n case  quantity       Simulink      exact ABCD   diff\n');
for id = 1:3
    [s, ref] = pick(tc, id);
    rows = {
        'V1 kV LL',  s.V1_kV_LL_rms, ref.V1_ph_rms_V*sqrt(3)/1e3
        'V2 kV LL',  s.V2_kV_LL_rms, ref.V2_ph_rms_V*sqrt(3)/1e3
        'I1 A',      s.I1_A_rms,     ref.I1_rms_A
        'dtheta deg',s.dtheta_deg,   ref.dtheta_deg
        'P1 MW',     s.P1_MW,        ref.P1_W/1e6
        'P2 MW',     s.P2_MW,        ref.P2_W/1e6
        'Q1 Mvar',   s.Q1_Mvar,      ref.Q1_var/1e6
        'Q2 Mvar',   s.Q2_Mvar,      ref.Q2_var/1e6
        'loss MW',   s.loss_MW,      ref.loss_W/1e6 };
    for k = 1:size(rows, 1)
        fprintf('  %d    %-11s %12.3f %12.3f %+9.3f\n', id, rows{k,1}, rows{k,2}, rows{k,3}, rows{k,2} - rows{k,3});
    end
    if isfield(ref, 'P_lossless_formula_W')
        pl = ref.P_lossless_formula_W/1e6;
        if abs(pl) < 1
            pct = '';   % percentage is meaningless near zero transfer
        else
            pct = sprintf(' (%+.1f %%)', 100*(s.P1_MW - pl)/abs(pl));
        end
        fprintf('  %d    lossless formula P = %.2f MW (X loop %.2f ohm), gap to Simulink P1 %+.2f MW%s\n', ...
            id, pl, ref.X_loop_ohm, s.P1_MW - pl, pct);
    end
end
verifyTrue(tc, true);
end

function [s, ref] = pick(tc, id)
s = tc.TestData.a{id}.rows;
ref = ref_case(tc.TestData.ref, id);
end

function ref = ref_case(R, id)
% Cases have different fields (fault vs no fault), so jsondecode returns a
% cell array; search it rather than concatenating.
c = R.cases;
if ~iscell(c), c = num2cell(c); end
k = find(cellfun(@(x) x.case_id == id, c), 1);
assert(~isempty(k), 'No analytic case %d.', id);
ref = c{k};
end
