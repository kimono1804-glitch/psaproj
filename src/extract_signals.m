function r = extract_signals(out, p)
%EXTRACT_SIGNALS Pull the logged signals out of a SimulationOutput.
%   r = extract_signals(out, p) returns:
%     r.p                 case params
%     r.stop_event        why the simulation stopped
%     r.pmu.<q><bus>      PMU outputs, q = v or i, bus = 1 or 2, with
%                         fields t, freq (Hz), angle (deg), mag_pu,
%                         mag (mag_pu times the peak base, so V or A peak)
%     r.raw.<q>_bus<k>    raw three-phase signals, fields t, abc (N x 3)
%     r.pq.<P|Q>_bus<k>   instantaneous three-phase P (W) and Q (var)
%   Used by run_case after a simulation and by show_results to redraw
%   plots from a saved results/<case>_simout.mat.

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
end

function ts = get_ts(logs, name)
el = logs.getElement(name);
if isempty(el)
    error('extract_signals:missingSignal', 'Logged signal "%s" not found.', name);
end
if isa(el, 'Simulink.SimulationData.Dataset'), el = el{1}; end
ts = el.Values;
end
