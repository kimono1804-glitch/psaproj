function files = plot_case(r, a, outdir, varargin)
%PLOT_CASE Plots for one simulation.
%   files = plot_case(r, a, outdir) saves PNG files in outdir.
%   plot_case(r, a, outdir, 'show', true) also leaves the figures open as
%   normal (zoomable) MATLAB figures; 'save', false skips the PNG files.
%   Dashboard (one per simulation), one axis per measure:
%     voltage magnitude, current magnitude, PMU phase angles, Delta-theta,
%     frequency, ROCOF, active power, reactive power.
%   For the fault case, a second figure zooms on the fault-on and
%   post-fault response with the fault window shaded.
%   Delta-theta = theta_PMU1 - theta_PMU2 (see analyze_case).

opts = struct('show', false, 'save', true);
for kk = 1:2:numel(varargin), opts.(varargin{kk}) = varargin{kk+1}; end
vis = ternary(opts.show, 'on', 'off');

p = r.p;
if ~isfield(p, 'plot_min_span')          % results saved before this setting existed
    d = params(); p.plot_min_span = d.plot_min_span;
end
c = colors();
files = {};
tmin = p.settle_cycles*p.T_cycle_s;      % ignore the PMU start-up cycle
k = a.t >= tmin;

f = figure('Visible', vis, 'Color', c.surface, 'Position', [40 40 1400 1500], ...
    'Name', [strrep(p.case_name, '_', ' ') ' dashboard'], 'NumberTitle', 'off');
if ~opts.show, f.Position(1:2) = [0 0]; end
try, theme(f, 'light'); catch, end
tl = tiledlayout(f, 4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('%s  (source 2 at %g deg%s)', strrep(p.case_name, '_', ' '), p.V2_angle_deg, ...
    ternary(p.fault_enabled, sprintf(', fault %.2f to %.2f s', p.fault_t_on_s, p.fault_t_off_s), '')), ...
    'Color', c.ink, 'FontWeight', 'bold');

ax = nexttile(tl); two(ax, a.t(k), a.V1_kV(k), a.V2_kV(k), c);
span(ax, p.plot_min_span.V_kV); style(ax, 'Voltage magnitude (PMU)', 'kV, line-to-line RMS', c, p); leg(ax, {'bus 1', 'bus 2'}, c);

ax = nexttile(tl); two(ax, a.t(k), a.I1_A(k), a.I2_A(k), c);
span(ax, p.plot_min_span.I_A); style(ax, 'Current magnitude (PMU)', 'A, RMS', c, p); leg(ax, {'terminal 1', 'terminal 2'}, c);

ax = nexttile(tl); two(ax, a.t(k), r.pmu.v1.angle(k), r.pmu.v2.angle(k), c);
span(ax, p.plot_min_span.angle_deg); style(ax, 'Voltage phase angle (PMU, system clock reference)', 'deg', c, p); leg(ax, {'\theta_1', '\theta_2'}, c);

ax = nexttile(tl); plot(ax, a.t(k), a.dtheta_deg(k), '-', 'Color', c.s3, 'LineWidth', 1.5);
span(ax, p.plot_min_span.dtheta_deg); style(ax, '\Delta\theta = \theta_{PMU1} - \theta_{PMU2}', 'deg', c, p); leg(ax, {'\Delta\theta'}, c);

ax = nexttile(tl); two(ax, a.t(k), a.f1_Hz(k), a.f2_Hz(k), c);
span(ax, p.plot_min_span.f_Hz); style(ax, 'Frequency (PMU)', 'Hz', c, p); leg(ax, {'bus 1', 'bus 2'}, c);

kr = k & ~isnan(a.rocof1_Hz_per_s);
kr(find(kr, 1)) = false;                 % first difference straddles start-up
ax = nexttile(tl); two(ax, a.t(kr), a.rocof1_Hz_per_s(kr), a.rocof2_Hz_per_s(kr), c);
span(ax, p.plot_min_span.rocof_Hz_per_s); style(ax, 'ROCOF (difference of PMU frequency)', 'Hz/s', c, p); leg(ax, {'bus 1', 'bus 2'}, c);

ax = nexttile(tl); two_raw(ax, r.pq.P_bus1, r.pq.P_bus2, 1e-6, tmin, c);
span(ax, p.plot_min_span.P_MW); style(ax, 'Active power, out of bus into line', 'MW', c, p); leg(ax, {'P_1', 'P_2'}, c);

ax = nexttile(tl); two_raw(ax, r.pq.Q_bus1, r.pq.Q_bus2, 1e-6, tmin, c);
span(ax, p.plot_min_span.Q_Mvar); style(ax, 'Reactive power, out of bus into line', 'Mvar', c, p); leg(ax, {'Q_1', 'Q_2'}, c);
xlabel(ax, 'time (s)', 'Color', c.ink2);

files = finish(f, fullfile(outdir, [p.case_name '_dashboard.png']), files, opts, c);

if p.fault_enabled
    zoom = [p.fault_t_on_s - 0.1, p.fault_t_off_s + 0.4];
    f = figure('Visible', vis, 'Color', c.surface, 'Position', [80 80 1400 900], ...
        'Name', 'fault zoom', 'NumberTitle', 'off');
    try, theme(f, 'light'); catch, end
    tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Fault-on and post-fault response (fault window shaded)', 'Color', c.ink, 'FontWeight', 'bold');
    kz = a.t >= zoom(1) & a.t <= zoom(2);

    ax = nexttile(tl); two(ax, a.t(kz), a.V1_kV(kz), a.V2_kV(kz), c, '.-');
    span(ax, p.plot_min_span.V_kV); style(ax, 'Voltage magnitude (PMU)', 'kV, line-to-line RMS', c, p, zoom); leg(ax, {'bus 1', 'bus 2'}, c);
    ax = nexttile(tl); two(ax, a.t(kz), a.I1_A(kz), a.I2_A(kz), c, '.-');
    span(ax, p.plot_min_span.I_A); style(ax, 'Current magnitude (PMU)', 'A, RMS', c, p, zoom); leg(ax, {'terminal 1', 'terminal 2'}, c);
    ax = nexttile(tl); plot(ax, a.t(kz), a.dtheta_deg(kz), '.-', 'Color', c.s3, 'LineWidth', 1.5, 'MarkerSize', 12);
    span(ax, p.plot_min_span.dtheta_deg); style(ax, '\Delta\theta = \theta_{PMU1} - \theta_{PMU2}', 'deg', c, p, zoom); leg(ax, {'\Delta\theta'}, c);
    xlabel(ax, 'time (s)', 'Color', c.ink2);
    ax = nexttile(tl);
    w = r.raw.v_bus1; kk = w.t >= zoom(1) & w.t <= zoom(2);
    plot(ax, w.t(kk), w.abc(kk, :)/1e3, 'LineWidth', 1);
    colororder(ax, [c.s1; c.s2; c.s3]);
    style(ax, 'Raw phase voltages at bus 1', 'kV', c, p, zoom); leg(ax, {'a', 'b', 'c'}, c);
    xlabel(ax, 'time (s)', 'Color', c.ink2);

    files = finish(f, fullfile(outdir, [p.case_name '_fault_zoom.png']), files, opts, c);
end
end

function files = finish(f, file, files, opts, c)
% Save the PNG and/or leave the figure open
if opts.save
    exportgraphics(f, file, 'Resolution', 110, 'BackgroundColor', c.surface);
    files{end+1} = file;
end
if ~opts.show, close(f); end
end

function two(ax, t, y1, y2, c, mk)
if nargin < 6, mk = '-'; end
plot(ax, t, y1, mk, 'Color', c.s1, 'LineWidth', 1.5, 'MarkerSize', 12); hold(ax, 'on');
plot(ax, t, y2, strrep(mk, '-', '--'), 'Color', c.s2, 'LineWidth', 1.5, 'MarkerSize', 12);
end

function two_raw(ax, s1, s2, scale, tmin, c)
k1 = s1.t >= tmin; k2 = s2.t >= tmin;
plot(ax, s1.t(k1), s1.x(k1)*scale, '-', 'Color', c.s1, 'LineWidth', 1.2); hold(ax, 'on');
plot(ax, s2.t(k2), s2.x(k2)*scale, '--', 'Color', c.s2, 'LineWidth', 1.2);
end

function style(ax, ttl, ylab, c, p, xl)
if nargin < 6, xl = [0 p.t_stop_s]; end
hold(ax, 'on');
if p.fault_enabled
    yl = ylim(ax);
    h = patch(ax, [p.fault_t_on_s p.fault_t_off_s p.fault_t_off_s p.fault_t_on_s], ...
        [yl(1) yl(1) yl(2) yl(2)], c.shade, 'EdgeColor', 'none', 'FaceAlpha', 0.5, ...
        'HandleVisibility', 'off');
    uistack(h, 'bottom');
    ylim(ax, yl);
end
xlim(ax, xl);
title(ax, ttl, 'Color', c.ink, 'FontWeight', 'normal');
ylabel(ax, ylab, 'Color', c.ink2);
set(ax, 'Color', c.surface, 'XColor', c.axis, 'YColor', c.axis, 'GridColor', c.grid, ...
    'GridAlpha', 1, 'Box', 'off', 'FontSize', 10);
grid(ax, 'on');
ax.XAxis.Label.Color = c.ink2; ax.YAxis.Label.Color = c.ink2;
end

function span(ax, s)
% Widen the y-axis to at least s, centred on the data
yl = ylim(ax);
if diff(yl) < s
    m = mean(yl);
    ylim(ax, m + [-s s]/2);
end
end

function c = colors()
% Default validated palette, categorical slots 1 to 3 in fixed order
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3])/255;
c.s1 = hex('#2a78d6');      % bus 1 (solid)
c.s2 = hex('#eb6834');      % bus 2 (dashed)
c.s3 = hex('#1baf7a');      % Delta-theta
c.surface = hex('#fcfcfb');
c.ink = hex('#0b0b0b');
c.ink2 = hex('#52514e');
c.axis = hex('#898781');
c.grid = hex('#e1e0d9');
c.shade = hex('#e1e0d9');
end

function leg(ax, labels, c)
% Legend in the chart's own colours (R2025b's default theme draws it dark)
legend(ax, labels, 'Location', 'best', 'Color', c.surface, 'TextColor', c.ink2, 'EdgeColor', c.grid);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

