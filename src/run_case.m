function r = run_case(mdl, id, base)
%RUN_CASE Simulate one case and return the logged signals.
%   r = run_case(mdl, id) applies simulation case id (see params.m
%   sim_cases), runs it, saves the Simulink.SimulationOutput to
%   results/<case_name>_simout.mat and returns a struct r:
%     r.p                 case params
%     r.pmu.<q><bus>      PMU outputs, q = v or i, bus = 1 or 2, with
%                         fields t, freq (Hz), angle (deg), mag_pu,
%                         mag (mag_pu times the peak base, so V or A peak)
%     r.raw.<q>_bus<k>    raw three-phase signals, fields t, abc (N x 3)
%     r.pq.<P|Q>_bus<k>   instantaneous three-phase P (W) and Q (var)
%   r = run_case(mdl, id, base) starts from params struct base.

if nargin < 3, base = params(); end
root = fileparts(fileparts(mfilename('fullpath')));
p = set_case(mdl, id, base);

tic;
out = sim(mdl);
r.wall_s = toc;
r.p = p;
r.stop_event = out.SimulationMetadata.ExecutionInfo.StopEvent;
logs = out.logsout;

for q = {'v', 'i'}
    for k = 1:2
        key = sprintf('%s%d', q{1}, k);
        s = struct();
        f = get_ts(logs, sprintf('pmu_%s_freq', key));
        a = get_ts(logs, sprintf('pmu_%s_angle', key));
        g = get_ts(logs, sprintf('pmu_%s_mag', key));
        s.t = f.Time(:);
        s.freq = squeeze(f.Data);  s.freq = s.freq(:);
        s.angle = squeeze(a.Data); s.angle = s.angle(:);
        s.mag_pu = squeeze(g.Data); s.mag_pu = s.mag_pu(:);
        if q{1} == 'v', base = p.pmu_V_base_peak_V; else, base = p.pmu_I_base_peak_A; end
        s.mag = s.mag_pu*base;     % SI, same scale as the per-unit base (peak)
        r.pmu.(key) = s;

        w = get_ts(logs, sprintf('%s_bus%d_abc', q{1}, k));
        r.raw.(sprintf('%s_bus%d', q{1}, k)) = struct('t', w.Time(:), 'abc', reshape(w.Data, [], 3));
    end
end
for q = {'P', 'Q'}
    for k = 1:2
        w = get_ts(logs, sprintf('%s_bus%d', q{1}, k));
        d = squeeze(w.Data);
        r.pq.(sprintf('%s_bus%d', q{1}, k)) = struct('t', w.Time(:), 'x', d(:));
    end
end

outdir = fullfile(root, 'results');
if ~isfolder(outdir), mkdir(outdir); end
simout = out; %#ok<NASGU>
tag = '';
if ~strcmp(p.line_model, 'pi'), tag = ['_' p.line_model]; end
save(fullfile(outdir, [p.case_name tag '_simout.mat']), 'simout', 'p', '-v7.3');
end

function ts = get_ts(logs, name)
el = logs.getElement(name);
if isempty(el)
    error('run_case:missingSignal', 'Logged signal "%s" not found.', name);
end
if isa(el, 'Simulink.SimulationData.Dataset'), el = el{1}; end
ts = el.Values;
end
