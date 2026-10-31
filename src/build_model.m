function mdl = build_model(p, varargin)
%BUILD_MODEL Create and save the two-area PMU model from scratch.
%   mdl = build_model(p) builds the full model from the params struct p.
%   mdl = build_model(p, 'stage', s) builds a partial model, used by the
%   build plan checks:
%     'skeleton'  two sources joined by one 300 km pi line, nothing else
%     'line'      sources, two 150 km sections (p.line_model) and the
%                 midpoint fault block, no measurement
%     'full'      everything: sensors, four PMUs, power, logging (default)
%
%   Block values are expressions of the struct P in the model workspace,
%   so set_case can change a case without rebuilding. Every number comes
%   from params.m. Enumerated settings come from block_map.
%
%   Current direction: positive when flowing out of a bus into the line.
%   Each current sensor has abc1 on the bus side and abc2 on the line side.

opts = struct('stage', 'full', 'save', true);
for k = 1:2:numel(varargin), opts.(varargin{k}) = varargin{k+1}; end

m = block_map();
root = fileparts(fileparts(mfilename('fullpath')));
mdl = p.model_name;

if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'P', p);

B = struct();   % name -> struct(path, role)

%% Network reference and solver
B.solver = addb('Solver', 'solver', [40 40]);
B.ref0   = addb('Ref0', 'elec_ref', [40 120]);
conn('solver', 'ref', 'ref0', 'v');

%% Sources (ideal source behind series R-L, wye with grounded neutral)
B.src1 = addb('Source1', 'source3', [140 240]);
B.src2 = addb('Source2', 'source3', [1500 240]);
B.ref_s1 = addb('RefS1', 'elec_ref', [140 360]);
B.ref_s2 = addb('RefS2', 'elec_ref', [1500 360]);
set_source('src1', 'P.V1_LL_rms_V', 'P.V1_angle_deg');
set_source('src2', 'P.V2_LL_rms_V', 'P.V2_angle_deg');
conn('src1', 'n', 'ref_s1', 'v');
conn('src2', 'n', 'ref_s2', 'v');
% Tie this network to the solver's reference node
conn('ref0', 'v', 'ref_s1', 'v');

%% Line
switch opts.stage
    case 'skeleton'
        B.line = addb('Line', 'line_pi3', [800 240]);
        set_pi(B.line.path, 'P.line_length_km', 'P.line_pi_segments_per_section');
        ground_pi('line', [800 360]);
        conn('src1', 'abc', 'line', 'abc1');
        conn('line', 'abc2', 'src2', 'abc');
    case {'line', 'full'}
        [endA, endB] = build_line();
        if strcmp(opts.stage, 'line')
            conn('src1', 'abc', endA{:});
            conn('src2', 'abc', endB{:});
        else
            build_measurement(endA, endB);
        end
    otherwise
        error('build_model:stage', 'Unknown stage "%s".', opts.stage);
end

%% Case-dependent settings (P, source impedance, fault, solver)
set_case(mdl, p);

%% Logging settings
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', 'SaveFormat', 'Dataset', ...
    'SaveTime', 'off', 'SaveOutput', 'off', 'SaveState', 'off', ...
    'SimscapeLogType', 'none');

if opts.save
    out = fullfile(root, 'models');
    if ~isfolder(out), mkdir(out); end
    save_system(mdl, fullfile(out, [mdl '.slx']));
end

%% ------------------------------------------------------------------
    function [endA, endB] = build_line()
        % Two sections of P.line_section_length_km with the fault at the
        % junction. Returns the connection points at the bus 1 and bus 2
        % ends as {blockKey, portName}.
        % Fault type, resistances and trigger are applied by set_case
        B.fault = addb('Fault', 'fault3', [800 80]);

        switch p.line_model
            case 'pi'
                B.lineA = addb('LineA', 'line_pi3', [560 240]);
                B.lineB = addb('LineB', 'line_pi3', [1040 240]);
                set_pi(B.lineA.path, 'P.line_section_length_km', 'P.line_pi_segments_per_section');
                set_pi(B.lineB.path, 'P.line_section_length_km', 'P.line_pi_segments_per_section');
                ground_pi('lineA', [560 360]);
                ground_pi('lineB', [1040 360]);
                conn('lineA', 'abc2', 'lineB', 'abc1');
                conn('fault', 'abc', 'lineA', 'abc2');
                endA = {'lineA', 'abc1'};
                endB = {'lineB', 'abc2'};
            case 'distributed'
                % One single-phase distributed line per phase, positive
                % sequence data, no coupling (see README, Deviations).
                B.splA = addb('SplitBus1', 'phase_splitter', [480 240]);
                B.splM = addb('SplitMid',  'phase_splitter', [800 240]);
                B.splB = addb('SplitBus2', 'phase_splitter', [1120 240]);
                ph = {'a','b','c'};
                for k = 1:3
                    a = sprintf('lineA_%s', ph{k});
                    b = sprintf('lineB_%s', ph{k});
                    y = 160 + 80*k;
                    B.(a) = addb(sprintf('LineA_%s', ph{k}), 'line_dist1', [640 y]);
                    B.(b) = addb(sprintf('LineB_%s', ph{k}), 'line_dist1', [960 y]);
                    set_dist(B.(a).path);
                    set_dist(B.(b).path);
                    conn('splA', ph{k}, a, 'p1');
                    conn(a, 'p2', 'splM', ph{k});
                    conn('splM', ph{k}, b, 'p1');
                    conn(b, 'p2', 'splB', ph{k});
                    % Return conductors to the reference at both ends
                    ra = sprintf('ref_%s', a); rb = sprintf('ref_%s', b);
                    B.(ra) = addb(sprintf('Ref_%s', a), 'elec_ref', [640 y+40]);
                    B.(rb) = addb(sprintf('Ref_%s', b), 'elec_ref', [960 y+40]);
                    conn(a, 'n1', ra, 'v'); conn(a, 'n2', ra, 'v');
                    conn(b, 'n1', rb, 'v'); conn(b, 'n2', rb, 'v');
                end
                conn('fault', 'abc', 'splM', 'abc');
                endA = {'splA', 'abc'};
                endB = {'splB', 'abc'};
            otherwise
                error('build_model:lineModel', 'Unknown line_model "%s".', p.line_model);
        end
    end

    function build_measurement(endA, endB)
        % Bus k: voltage sensor across bus to ground, current sensor in
        % series between bus (abc1) and line (abc2).
        x = struct('bus1', 300, 'bus2', 1340);
        for busc = {'bus1', 'bus2'}
            bus = busc{1};
            n = bus(end);
            src = ['src' n];
            if n == '1', lineEnd = endA; else, lineEnd = endB; end
            vs = ['vsen' n]; is = ['isen' n]; gn = ['gnd' n];
            B.(vs) = addb(['VSensor' n], 'vsensor3', [x.(bus) 400]);
            B.(is) = addb(['ISensor' n], 'isensor3', [x.(bus) 240]);
            B.(gn) = addb(['GndV' n], 'grounded_neutral', [x.(bus) 520]);
            conn(src, 'abc', is, 'abc1');
            conn(is, 'abc2', lineEnd{:});
            conn(vs, 'abc1', src, 'abc');
            conn(vs, 'abc2', gn, 'abc');

            % Physical signal to Simulink
            cv = ['ps_v' n]; ci = ['ps_i' n];
            B.(cv) = addb(['PS_V' n], 'ps2sl', [x.(bus) 620]);
            B.(ci) = addb(['PS_I' n], 'ps2sl', [x.(bus)+80 620]);
            setp(B.(cv).path, 'Unit', 'V', 'VectorFormat', '1-D array');
            setp(B.(ci).path, 'Unit', 'A', 'VectorFormat', '1-D array');
            conn(vs, 'v', cv, 'ps');
            conn(is, 'i', ci, 'ps');

            % PMUs on voltage and current
            for q = {'v', 'i'}
                key = sprintf('pmu_%s%s', q{1}, n);
                yq = 700 + 120*strcmp(q{1}, 'i');
                B.(key) = addb(sprintf('PMU_%s%s', upper(q{1}), n), 'pmu', [x.(bus) yq]);
                setp(B.(key).path, 'frequency', num2str(p.f_Hz), ...
                    'Nsr', num2str(p.pmu_samples_per_cycle), 'k', 'P.pmu_report_ratio');
                if p.pmu_input_normalization
                    % The PMU mask fixes its inner PLL's input normalisation
                    % off. Turn it on in this copy only (library untouched).
                    set_param(B.(key).path, 'LinkStatus', 'inactive');
                    inner = [B.(key).path '/' m.pmu_inner_pll];
                    set_param(inner, 'LinkStatus', 'inactive');
                    setp(inner, 'InputNormalization', 'on');
                end
                % Raw SI signal (logged), then scaled to per unit for the PMU,
                % whose PLL gains assume per-unit input.
                src_blk = B.(['ps_' q{1} n]).path;
                gk = sprintf('%s/PU_%s%s', mdl, upper(q{1}), n);
                if q{1} == 'v', base = 'P.pmu_V_base_peak_V'; else, base = 'P.pmu_I_base_peak_A'; end
                add_block(m.gain, gk, 'Gain', ['1/' base], 'Position', box([x.(bus)-100 yq+10], [40 30]));
                sig(src_blk, 1, gk, 1, sprintf('%s_%s_abc', q{1}, bus));
                ps_ = get_param(gk, 'PortHandles'); pd_ = get_param(B.(key).path, 'PortHandles');
                lh = add_line(mdl, ps_.Outport(1), pd_.Inport(1), 'autorouting', 'smart');
                set_param(lh, 'Name', sprintf('%s_%s_pu', q{1}, bus));
                outs = {'freq', 'angle', 'mag'};
                for o = 1:3
                    t = addterm(sprintf('T_%s_%s', key, outs{o}), [x.(bus)+200 yq+30*(o-1)]);
                    sig(B.(key).path, o, t, 1, sprintf('pmu_%s%s_%s', q{1}, n, outs{o}));
                end
            end

            % Instantaneous three-phase P and Q from the raw signals.
            % For balanced sinusoids these equal the three-phase P and Q.
            mx = [mdl '/Mux_VI' n];
            add_block(m.mux, mx, 'Inputs', '2', 'Position', box([x.(bus)+300 640], [10 60]));
            add_line(mdl, [get_param(B.(cv).path, 'Name') '/1'], ['Mux_VI' n '/1'], 'autorouting', 'smart');
            add_line(mdl, [get_param(B.(ci).path, 'Name') '/1'], ['Mux_VI' n '/2'], 'autorouting', 'smart');
            fP = [mdl '/P_calc' n]; fQ = [mdl '/Q_calc' n];
            add_block(m.fcn, fP, 'Expr', 'u(1)*u(4)+u(2)*u(5)+u(3)*u(6)', ...
                'Position', box([x.(bus)+380 620], [120 30]));
            add_block(m.fcn, fQ, 'Expr', '((u(2)-u(3))*u(4)+(u(3)-u(1))*u(5)+(u(1)-u(2))*u(6))/sqrt(3)', ...
                'Position', box([x.(bus)+380 680], [120 30]));
            add_line(mdl, ['Mux_VI' n '/1'], ['P_calc' n '/1'], 'autorouting', 'smart');
            add_line(mdl, ['Mux_VI' n '/1'], ['Q_calc' n '/1'], 'autorouting', 'smart');
            tP = addterm(['T_P' n], [x.(bus)+540 620]);
            tQ = addterm(['T_Q' n], [x.(bus)+540 680]);
            sig(fP, 1, tP, 1, sprintf('P_%s', bus));
            sig(fQ, 1, tQ, 1, sprintf('Q_%s', bus));
        end
    end

%% Helpers -----------------------------------------------------------
    function s = addb(name, role, xy)
        path = [mdl '/' name];
        add_block(m.(role), path, 'Position', box(xy, [60 50]));
        s = struct('path', path, 'role', role);
    end

    function t = addterm(name, xy)
        t = [mdl '/' name];
        add_block(m.terminator, t, 'Position', box(xy, [20 20]));
    end

    function conn(a, pa, b, pb)
        add_line(mdl, porth(a, pa), porth(b, pb), 'autorouting', 'smart');
    end

    function h = porth(key, pname)
        blk = B.(key);
        spec = m.port.(blk.role).(pname);
        ph = get_param(blk.path, 'PortHandles');
        idx = str2double(spec(2:end));
        if spec(1) == 'L', h = ph.LConn(idx); else, h = ph.RConn(idx); end
    end

    function sig(srcBlk, srcPort, dstBlk, dstPort, name)
        ps = get_param(srcBlk, 'PortHandles');
        pd = get_param(dstBlk, 'PortHandles');
        lh = add_line(mdl, ps.Outport(srcPort), pd.Inport(dstPort), 'autorouting', 'smart');
        set_param(lh, 'Name', name);
        set_param(ps.Outport(srcPort), 'DataLogging', 'on', 'DataLoggingNameMode', 'SignalName');
    end

    function set_source(key, vexpr, angexpr)
        % Impedance option and R, L are applied by set_case
        setp(B.(key).path, 'vline_rms', vexpr, 'vline_rms_unit', 'V', ...
            'shift', angexpr, 'shift_unit', 'deg', 'freq', 'P.f_Hz', 'freq_unit', 'Hz');
    end

    function set_pi(path, lenexpr, nexpr)
        setp(path, 'length', lenexpr, 'length_unit', 'km', 'freq', 'P.f_Hz', 'freq_unit', 'Hz', ...
            'R', 'P.line_pi_R_ohm_per_km', 'R_unit', 'Ohm/km', ...
            'Rm', 'P.line_pi_Rm_ohm_per_km', 'Rm_unit', 'Ohm/km', ...
            'L', 'P.line_pi_L_H_per_km', 'L_unit', 'H/km', ...
            'M', 'P.line_pi_M_H_per_km', 'M_unit', 'H/km', ...
            'Cg', 'P.line_pi_Cg_F_per_km', 'Cg_unit', 'F/km', ...
            'Cl', 'P.line_pi_Cl_F_per_km', 'Cl_unit', 'F/km', ...
            'N', nexpr);
    end

    function ground_pi(key, xy)
        r = ['ref_' key];
        B.(r) = addb(['Ref_' key], 'elec_ref', xy);
        conn(key, 'g1', r, 'v');
        conn(key, 'g2', r, 'v');
    end

    function set_dist(path)
        setp(path, 'model_type', m.enum.line_dist1_model_distributed);
        setp(path, 'freq', 'P.f_Hz', 'freq_unit', 'Hz', ...
            'R', 'P.line_R1_ohm_per_km', 'R_unit', 'Ohm/km', ...
            'Ll', 'P.line_L1_H_per_km', 'Ll_unit', 'H/km', ...
            'C', 'P.line_C1_F_per_km', 'C_unit', 'F/km', ...
            'G', 'P.line_G1_S_per_km', 'G_unit', 'S/km', ...
            'LEN', 'P.line_section_length_km', 'LEN_unit', 'km');
    end

end

function setp(blk, varargin)
set_block_params(blk, varargin{:});
end

function b = box(xy, wh)
b = [xy(1) xy(2) xy(1)+wh(1) xy(2)+wh(2)];
end
