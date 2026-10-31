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

cache = map;
if verbose, print_map(map); end
end

function print_map(map)
f = fieldnames(map);
for k = 1:numel(f)
    fprintf('  %-17s %s\n', f{k}, strrep(map.(f{k}), newline, ' '));
end
end
