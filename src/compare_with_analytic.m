function T = compare_with_analytic(S, ref, p)
%COMPARE_WITH_ANALYTIC Simulink results against the analytic check.
%   T = compare_with_analytic(S, ref, p) with S the summary table
%   (results/summary.csv), ref the decoded results/analytic_reference.json
%   and p = params(). Returns one row per checked quantity:
%     Case, Quantity, Unit, Simulink, Analytic, Difference, Tolerance, Status
%   Status is "pass", "fail" or "info" (reported, no tolerance).
%   Tolerances come from params.m (CLAUDE.md section 7). Fault-on values
%   are a loose check because the PMU averages a transient.

rows = {};
P2ref = ref_case(ref, 2).P1_W/1e6;
for id = 1:5
    s = S(S.case_id == id, :);
    r = ref_case(ref, id);
    if isempty(s) || isempty(r), continue; end
    if id == 4
        add(id, 'V1', 'kV', s.V1_kV_LL_rms, r.V1_ph_rms_V*sqrt(3)/1e3, 'rel', p.tol_fault_rel);
        add(id, 'V2', 'kV', s.V2_kV_LL_rms, r.V2_ph_rms_V*sqrt(3)/1e3, 'rel', p.tol_fault_rel);
        add(id, 'I1', 'A',  s.I1_A_rms,     r.I1_rms_A,                'rel', p.tol_fault_rel);
        add(id, 'I2', 'A',  s.I2_A_rms,     r.I2_rms_A,                'rel', p.tol_fault_rel);
        add(id, 'Delta-theta', 'deg', s.dtheta_deg, r.dtheta_deg, 'info', NaN);
        continue
    end
    add(id, 'V1', 'kV', s.V1_kV_LL_rms, r.V1_ph_rms_V*sqrt(3)/1e3, 'rel', p.tol_V_rel);
    add(id, 'V2', 'kV', s.V2_kV_LL_rms, r.V2_ph_rms_V*sqrt(3)/1e3, 'rel', p.tol_V_rel);
    add(id, 'Delta-theta', 'deg', s.dtheta_deg, r.dtheta_deg, 'abs', p.tol_dtheta_deg);
    if id == 1
        add(id, 'P1', 'MW', s.P1_MW, r.P1_W/1e6, 'abs', p.tol_P_rel*abs(P2ref));
        add(id, 'P2', 'MW', s.P2_MW, r.P2_W/1e6, 'abs', p.tol_P_rel*abs(P2ref));
    else
        add(id, 'P1', 'MW', s.P1_MW, r.P1_W/1e6, 'rel', p.tol_P_rel);
        add(id, 'P2', 'MW', s.P2_MW, r.P2_W/1e6, 'rel', p.tol_P_rel);
    end
    add(id, 'Q1', 'Mvar', s.Q1_Mvar, r.Q1_var/1e6, 'info', NaN);
    add(id, 'I1', 'A', s.I1_A_rms, r.I1_rms_A, 'info', NaN);
    add(id, 'Loss', 'MW', s.loss_MW, r.loss_W/1e6, 'info', NaN);
end
T = cell2table(rows, 'VariableNames', ...
    {'Case', 'Quantity', 'Unit', 'Simulink', 'Analytic', 'Difference', 'Tolerance', 'Status'});

    function add(id, q, unit, sim_, exact, kind, tol)
        d = sim_ - exact;
        switch kind
            case 'rel'
                ok = abs(d) <= tol*abs(exact);
                tt = sprintf('%g %%', 100*tol);
            case 'abs'
                ok = abs(d) <= tol;
                tt = sprintf('%.3g %s', tol, unit);
            otherwise
                ok = []; tt = '';
        end
        if isempty(ok), st = 'info'; elseif ok, st = 'pass'; else, st = 'fail'; end
        rows(end+1, :) = {id, q, unit, sim_, exact, d, tt, st};
    end
end

function r = ref_case(ref, id)
c = ref.cases;
if ~iscell(c), c = num2cell(c); end
k = find(cellfun(@(x) x.case_id == id, c), 1);
if isempty(k), r = []; else, r = c{k}; end
end
