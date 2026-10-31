function map = block_map(varargin)
%BLOCK_MAP Resolve library block paths for the installed release.
%   map = block_map() returns a struct with one field per role. Each value
%   is the first candidate library path that loads in a scratch model.
%   Candidate parameter names for each role are also checked against the
%   block's real DialogParameters, so builders never set a guessed name.
%
%   map = block_map('verbose') also prints the resolved path for each role.
%   The result is cached per MATLAB session; block_map('refresh') re-resolves.

persistent cache
verbose = any(strcmpi(varargin, 'verbose'));
if any(strcmpi(varargin, 'refresh')), cache = []; end
if ~isempty(cache)
    map = cache;
    if verbose, print_map(map); end
    return
end

nl = newline;
% role, {candidate paths}, {parameter names the builders will set}
roles = {
  'solver',          {'nesl_utility/Solver Configuration'}, ...
                     {'UseLocalSolver','LocalSolverChoice','LocalSolverSampleTime'}
  'elec_ref',        {'ee_lib/Connectors & References/Electrical Reference', ...
                      'fl_lib/Electrical/Electrical Elements/Electrical Reference'}, {}
  'grounded_neutral',{'ee_lib/Connectors & References/Grounded Neutral (Three-Phase)'}, {}
  'phase_splitter',  {'ee_lib/Connectors & References/Phase Splitter'}, {}
  'source3',         {'ee_lib/Sources/Voltage Source (Three-Phase)', ...
                      ['ee_lib/Sources/Voltage' nl 'Source' nl '(Three-Phase)']}, ...
                     {'vline_rms','vline_rms_unit','shift','shift_unit','freq','freq_unit', ...
                      'impedance_option','SShortCircuit','SShortCircuit_unit','XR'}
  'line_pi3',        {'ee_lib/Passive/Lines/Transmission Line (Three-Phase)', ...
                      ['ee_lib/Passive/Lines/Transmission' nl 'Line' nl '(Three-Phase)']}, ...
                     {'length','length_unit','freq','freq_unit','R','R_unit','L','L_unit', ...
                      'M','M_unit','Cl','Cl_unit','Cg','Cg_unit','Rm','Rm_unit','N','ModelTwoSections'}
  'line_dist1',      {'ee_lib/Passive/Lines/Transmission Line'}, ...
                     {'model_type','freq','freq_unit','R','R_unit','Ll','Ll_unit','C','C_unit', ...
                      'G','G_unit','LEN','LEN_unit'}
  'fault3',          {'ee_lib/Utilities/Fault (Three-Phase)'}, ...
                     {'fault_type_option','R_pn_fault','R_pn_fault_unit','R_ng_fault','R_ng_fault_unit', ...
                      'enable_temporal_fault','fault_start_time','fault_start_time_unit', ...
                      'fault_duration','fault_duration_unit'}
  'vsensor3',        {'ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', ...
                      ['ee_lib/Sensors &' nl 'Transducers/Phase Voltage Sensor' nl '(Three-Phase)']}, {}
  'isensor3',        {'ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', ...
                      ['ee_lib/Sensors &' nl 'Transducers/Current Sensor' nl '(Three-Phase)']}, {}
  'pmu',             {'ee_sl_lib/Measurements/Phasor Measurement Unit (PMU, Three-Phase)', ...
                      ['eePMU/Phasor Measurement Unit' nl '(PMU, Three-Phase)']}, ...
                     {'frequency','Nsr','k'}
  'ps2sl',           {'nesl_utility/PS-Simulink Converter'}, {'Unit','VectorFormat'}
  'gain',            {'simulink/Math Operations/Gain'}, {'Gain'}
  'fcn',             {'simulink/User-Defined Functions/Fcn'}, {'Expr'}
  'mux',             {'simulink/Signal Routing/Mux'}, {'Inputs'}
  'demux',           {'simulink/Signal Routing/Demux'}, {'Outputs'}
  'dot',             {'simulink/Math Operations/Dot Product'}, {}
  'terminator',      {'simulink/Sinks/Terminator'}, {}
};

libs = {'ee_lib','ee_sl_lib','nesl_utility','fl_lib','simulink','eePMU'};
for k = 1:numel(libs)
    try, load_system(libs{k}); catch, end %#ok<NOCOM> missing libs are reported per role
end

scratch = sprintf('scratch_block_map_%d', round(1e6*rand));
new_system(scratch);
cleanup = onCleanup(@() close_system(scratch, 0));

map = struct();
for r = 1:size(roles, 1)
    role = roles{r,1}; cands = roles{r,2}; need = roles{r,3};
    found = '';
    tried = {};
    for c = 1:numel(cands)
        dst = sprintf('%s/%s_%d', scratch, role, c);
        try
            add_block(cands{c}, dst);
            dp = get_param(dst, 'DialogParameters');
            if isempty(dp), names = {}; else, names = fieldnames(dp); end
            missing = setdiff(need, names);
            if ~isempty(missing)
                tried{end+1} = sprintf('%s (loaded, but missing parameters: %s)', ...
                    strrep(cands{c}, nl, ' '), strjoin(missing, ', ')); %#ok<AGROW>
                continue
            end
            found = cands{c};
            break
        catch e
            tried{end+1} = sprintf('%s (%s)', strrep(cands{c}, nl, ' '), e.message); %#ok<AGROW>
        end
    end
    if isempty(found)
        error('block_map:notFound', 'No library block found for role "%s". Tried:\n  %s', ...
            role, strjoin(tried, sprintf('\n  ')));
    end
    map.(role) = found;
end

% Port roles. Simscape port handles carry no names, so these were found by
% connecting each port to a composite three-phase node, a single electrical
% node or a physical signal converter and checking which networks compile
% (R2025b). test_model_builds re-checks them because a wrong port fails to
% compile. 'L1' means LConn(1), 'R2' means RConn(2).
map.port.source3        = struct('n','L1', 'abc','R1');
map.port.line_pi3       = struct('abc1','L1', 'g1','L2', 'abc2','R1', 'g2','R2');
map.port.line_dist1     = struct('p1','L1', 'n1','L2', 'p2','R1', 'n2','R2');
map.port.fault3         = struct('abc','L1');
map.port.vsensor3       = struct('abc1','L1', 'v','R1', 'abc2','R2');
map.port.isensor3       = struct('abc1','L1', 'i','R1', 'abc2','R2');   % + current flows abc1 -> abc2
map.port.phase_splitter = struct('abc','L1', 'a','R1', 'b','R2', 'c','R3');
map.port.grounded_neutral = struct('abc','L1');
map.port.elec_ref       = struct('v','L1');
map.port.solver         = struct('ref','R1');
map.port.ps2sl          = struct('ps','L1');

% PLL block inside the PMU (its InputNormalization is switched on by build_model)
map.pmu_inner_pll = 'Sinusoidal Measurement (PLL, Three-Phase)';
if isempty(find_system(map.pmu, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'SearchDepth', 1, 'Name', map.pmu_inner_pll))
    error('block_map:pmuInner', 'PMU block has no inner block "%s".', map.pmu_inner_pll);
end
dpi = get_param([map.pmu '/' map.pmu_inner_pll], 'DialogParameters');
if ~isfield(dpi, 'InputNormalization')
    error('block_map:pmuInner', 'Inner PLL block has no InputNormalization parameter.');
end

% Enumerated values discovered from mask visibility (R2025b), see README
map.enum.line_dist1_model_distributed = '5';
map.enum.source3_impedance_none   = '0';
map.enum.source3_impedance_seriesRL = '4';
map.enum.fault3_none = '0';
map.enum.fault3_abcg = '11';

cache = map;
if verbose, print_map(map); end
end

function print_map(map)
f = setdiff(fieldnames(map), {'port','enum','pmu_inner_pll'}, 'stable');
for k = 1:numel(f)
    fprintf('  %-17s %s\n', f{k}, strrep(map.(f{k}), newline, ' '));
end
end
