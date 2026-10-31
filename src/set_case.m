function p = set_case(mdl, c, base)
%SET_CASE Apply a case to the model.
%   p = set_case(mdl, id) applies simulation case id (1 to 4, see
%   params.m sim_cases) on top of params(), and returns the case params.
%   p = set_case(mdl, id, base) uses the params struct base instead.
%   p = set_case(mdl, p) applies a ready params struct as it is.
%
%   What is applied: the struct P in the model workspace (all block
%   values refer to it), the source impedance option, the fault block
%   type and trigger, and the solver settings.

if isstruct(c)
    p = c;
else
    if nargin < 3, base = params(); end
    sc = base.sim_cases([base.sim_cases.id] == c);
    if isempty(sc), error('set_case:id', 'No simulation case %d.', c); end
    p = params(base, 'V2_angle_deg', sc.V2_angle_deg, 'fault_enabled', sc.fault_enabled);
    p.case_id = sc.id;
    p.case_name = sc.name;
end

m = block_map();
assignin(get_param(mdl, 'ModelWorkspace'), 'P', p);

% Source impedance: series R-L from params, or none
for s = {'Source1', 'Source2'}
    blk = [mdl '/' s{1}];
    if ~exist_block(blk), continue; end
    if p.src_impedance_enabled
        set_block_params(blk, 'impedance_option', m.enum.source3_impedance_seriesRL);
        set_block_params(blk, 'R', 'P.src_R_ohm', 'R_unit', 'Ohm', 'L', 'P.src_L_H', 'L_unit', 'H');
    else
        set_block_params(blk, 'impedance_option', m.enum.source3_impedance_none);
    end
end

% Fault: three-phase to ground with a temporal trigger, or no fault
blk = [mdl '/Fault'];
if exist_block(blk)
    set_block_params(blk, 'fault_type_option', m.enum.fault3_abcg);
    set_block_params(blk, 'R_pn_fault', 'P.fault_R_ohm', 'R_pn_fault_unit', 'Ohm', ...
                          'R_ng_fault', 'P.fault_Rng_ohm', 'R_ng_fault_unit', 'Ohm');
    if p.fault_enabled
        set_block_params(blk, 'enable_temporal_fault', '1');
        set_block_params(blk, 'fault_start_time', 'P.fault_t_on_s', 'fault_start_time_unit', 's', ...
                              'fault_duration', 'P.fault_duration_s', 'fault_duration_unit', 's');
    else
        set_block_params(blk, 'enable_temporal_fault', '0');
        set_block_params(blk, 'fault_type_option', m.enum.fault3_none);
    end
end

% Solver
set_param(mdl, 'StopTime', num2str(p.t_stop_s), ...
    'SolverType', 'Variable-step', 'Solver', p.solver, ...
    'MaxStep', num2str(p.solver_max_step_s), ...
    'RelTol', num2str(p.solver_rel_tol), 'AbsTol', num2str(p.solver_abs_tol));
end

function tf = exist_block(blk)
tf = getSimulinkBlockHandle(blk) ~= -1;
end
