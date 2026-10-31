function file = make_report(varargin)
%MAKE_REPORT Write results/report.html from the saved results.
%   file = make_report() reads results/summary.csv, the dashboard PNGs and
%   results/analytic_reference.json (if present) and writes one
%   self-contained HTML page (images embedded) with headline numbers, the
%   results table, the verification table and all plots.
%   make_report('open', true) also opens it in the default browser.
%   No simulation is run.

opts = struct('open', false);
for k = 1:2:numel(varargin), opts.(varargin{k}) = varargin{k+1}; end

root = fileparts(fileparts(mfilename('fullpath')));
rd = fullfile(root, 'results');
p = params();
S = readtable(fullfile(rd, 'summary.csv'), 'TextType', 'string');
refFile = fullfile(rd, 'analytic_reference.json');
V = [];
if isfile(refFile)
    V = compare_with_analytic(S, jsondecode(fileread(refFile)), p);
end

h = {};
h{end+1} = head_html();
h{end+1} = '<body><main>';
h{end+1} = sprintf(['<header><h1>Two-area transmission line with two PMUs</h1>' ...
    '<p class="sub">%g kV, %g Hz, %g km line, source impedance %g GVA at X/R %g, ' ...
    'three-phase fault at the midpoint %.2f to %.2f s. Generated %s with MATLAB %s.</p></header>'], ...
    p.V1_LL_rms_V/1e3, p.f_Hz, p.line_length_km, p.src_Ssc_VA/1e9, p.src_XR, ...
    p.fault_t_on_s, p.fault_t_off_s, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version('-release'));

% Headline numbers
c2 = S(S.case_id == 2, :); c3 = S(S.case_id == 3, :); c4 = S(S.case_id == 4, :); c5 = S(S.case_id == 5, :);
h{end+1} = '<section class="tiles">';
ang2 = p.sim_cases([p.sim_cases.id] == 2).V2_angle_deg;
h{end+1} = tile('Power transfer, case 2', sprintf('%.1f MW', c2.P1_MW), sprintf('source 2 at %g&deg;', ang2));
h{end+1} = tile('Angle across the line, case 2', sprintf('%.2f&deg;', c2.dtheta_deg), 'from the two voltage PMUs');
h{end+1} = tile('Fault current', sprintf('%.2f kA', c4.I1_A_rms/1e3), ...
    sprintf('voltage falls to %.0f kV (%.0f %%)', c4.V1_kV_LL_rms, 100*c4.V1_kV_LL_rms/c2.V1_kV_LL_rms));
if ~isempty(V)
    nchk = nnz(V.Status ~= "info"); npass = nnz(V.Status == "pass");
    h{end+1} = tile('Checks against the analytic solution', sprintf('%d of %d pass', npass, nchk), ...
        sprintf('voltage %g %%, angle %g&deg;, power %g %%', 100*p.tol_V_rel, p.tol_dtheta_deg, 100*p.tol_P_rel));
else
    h{end+1} = tile('Checks against the analytic solution', 'not run', 'analytic_reference.json missing');
end
h{end+1} = '</section>';

% Findings
h{end+1} = '<section><h2>What the cases show</h2><ul class="find">';
h{end+1} = sprintf('<li><b>Case 1, equal source angles:</b> almost no active power (%.2f MW). Each end takes in about %.0f Mvar of line charging.</li>', ...
    S.P1_MW(S.case_id == 1), -S.Q1_Mvar(S.case_id == 1));
h{end+1} = sprintf(['<li><b>Cases 2 and 3:</b> power flows from bus 1 to bus 2 (%.0f and %.0f MW) and the PMU angle ' ...
    'difference is positive (%.2f&deg; and %.2f&deg;). It is smaller than the source angle because part of the ' ...
    'angle sits across the source impedances.</li>'], c2.P1_MW, c3.P1_MW, c2.dtheta_deg, c3.dtheta_deg);
h{end+1} = sprintf(['<li><b>Case 4, fault on:</b> both bus voltages fall to about %.0f kV and the currents rise ' ...
    'about %.0f times, to %.1f kA. The angle difference rises to about %.1f&deg;.</li>'], ...
    c4.V1_kV_LL_rms, c4.I1_A_rms/c2.I1_A_rms, c4.I1_A_rms/1e3, c4.dtheta_deg);
h{end+1} = sprintf(['<li><b>Case 5, after clearing:</b> voltage, current and angle return to the case 2 values ' ...
    '(%.1f kV, %.0f A, %.2f&deg;)%s.</li>'], c5.V1_kV_LL_rms, c5.I1_A_rms, c5.dtheta_deg, settle_text(rd, p));
h{end+1} = '</ul></section>';

% Results table
h{end+1} = '<section><h2>Results</h2>';
h{end+1} = ['<p class="note">PMU voltage (line-to-line RMS) and current (RMS), averaged over the window. P and Q are ' ...
    'time averages of the instantaneous three-phase power. Current is positive flowing out of a bus into the line, ' ...
    'so P2 is negative when power arrives at bus 2 and the loss is P1 + P2. &Delta;&theta; = &theta;<sub>PMU1</sub> &minus; &theta;<sub>PMU2</sub>.</p>'];
h{end+1} = '<div class="scroll"><table><thead><tr>';
cols = {'Case', 'Condition', 'Window (s)', 'V1 (kV)', 'V2 (kV)', 'I1 (A)', 'I2 (A)', '&Delta;&theta; (&deg;)', ...
        'P1 (MW)', 'Q1 (Mvar)', 'P2 (MW)', 'Q2 (Mvar)', 'Loss (MW)'};
h{end+1} = strjoin(cellfun(@(x) ['<th>' x '</th>'], cols, 'UniformOutput', false), '');
h{end+1} = '</tr></thead><tbody>';
for i = 1:height(S)
    s = S(i, :);
    h{end+1} = sprintf(['<tr><td>%d</td><td class="l">%s</td><td>%.2f to %.2f</td><td>%.2f</td><td>%.2f</td>' ...
        '<td>%.1f</td><td>%.1f</td><td>%.3f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td></tr>'], ...
        s.case_id, esc(s.description), s.window_start_s, s.window_end_s, s.V1_kV_LL_rms, s.V2_kV_LL_rms, ...
        s.I1_A_rms, s.I2_A_rms, s.dtheta_deg, s.P1_MW, s.Q1_Mvar, s.P2_MW, s.Q2_Mvar, s.loss_MW); %#ok<AGROW>
end
h{end+1} = '</tbody></table></div>';
h{end+1} = ['<p class="note">Fault-on values come from only three PMU reports during a transient with ' ...
    'decaying DC offset, so they are approximate.</p></section>'];

% Verification table
h{end+1} = '<section><h2>Verification against the analytic solution</h2>';
if isempty(V)
    h{end+1} = '<p>Run <code>reference/analytic_check.py</code> (run_all does this when Python with numpy is found).</p>';
else
    h{end+1} = ['<p class="note">The analytic solution solves the same circuit in phasors with the exact long-line ' ...
        '(ABCD) model, in Python with numpy, without Simulink. Rows marked info are reported without a tolerance.</p>'];
    checked = V(~strcmp(V.Status, 'info'), :);
    info = V(strcmp(V.Status, 'info'), :);
    h{end+1} = verification_table(checked, true);
    h{end+1} = sprintf(['<details><summary>%d further values reported without a tolerance ' ...
        '(Q, current, loss, fault-on angle)</summary>%s</details>'], height(info), verification_table(info, false));
end
h{end+1} = '</section>';

% Plots
h{end+1} = '<section><h2>Plots</h2>';
for sc = p.sim_cases
    img = fullfile(rd, [sc.name '_dashboard.png']);
    if isfile(img)
        h{end+1} = sprintf('<figure><figcaption>%s</figcaption><img alt="%s dashboard" src="%s"></figure>', ...
            caption(sc), sc.name, data_uri(img)); %#ok<AGROW>
    end
end
img = fullfile(rd, 'case45_fault_fault_zoom.png');
if isfile(img)
    h{end+1} = sprintf('<figure><figcaption>Cases 4 and 5: fault-on and post-fault response, fault window shaded</figcaption><img alt="fault zoom" src="%s"></figure>', data_uri(img));
end
h{end+1} = '</section>';

% Notes
h{end+1} = ['<section><h2>Model notes</h2><ul class="find">' ...
    sprintf('<li>Line capacitance is %g &micro;F/km instead of 0.012: the brief''s value makes the wave faster than light, which Simscape refuses.</li>', p.line_C1_F_per_km*1e6) ...
    '<li>The line is two 150 km nominal pi sections. The distributed line model could not simulate the fault in this release.</li>' ...
    '<li>PMU inputs are scaled to per unit and the PMU''s internal PLL has its input normalisation switched on, so current phasors stay locked through the fault.</li>' ...
    '<li>PMU: 50 Hz, 64 samples per cycle, one report every 20 ms. Magnitudes are peak values, shown here as RMS.</li>' ...
    '<li>Full details: README.md, section Deviations.</li></ul></section>'];
h{end+1} = '</main></body></html>';

file = fullfile(rd, 'report.html');
fid = fopen(file, 'w', 'n', 'UTF-8');
fwrite(fid, strjoin(h, newline), 'char');
fclose(fid);
if opts.open
    open_external(file);
end
end

function s = verification_table(V, withResult)
s = '<div class="scroll"><table><thead><tr><th>Case</th><th>Quantity</th><th>Simulink</th><th>Analytic</th><th>Difference</th>';
if withResult, s = [s '<th>Tolerance</th><th>Result</th>']; end
s = [s '</tr></thead><tbody>'];
for i = 1:height(V)
    v = V(i, :);
    q = strrep(v.Quantity{1}, 'Delta-theta', '&Delta;&theta;');
    s = [s sprintf('<tr><td>%d</td><td class="l">%s (%s)</td><td>%.3f</td><td>%.3f</td><td>%+.3f</td>', ...
        v.Case, q, v.Unit{1}, v.Simulink, v.Analytic, v.Difference)]; %#ok<AGROW>
    if withResult
        s = [s sprintf('<td>%s</td><td>%s</td>', v.Tolerance{1}, badge(v.Status{1}))]; %#ok<AGROW>
    end
    s = [s '</tr>']; %#ok<AGROW>
end
s = [s '</tbody></table></div>'];
end

function s = settle_text(rd, p)
% Time after clearing until every later PMU voltage report at bus 1 stays
% within 1 percent of its post-fault mean. Empty if the analysis is missing.
s = '';
f = fullfile(rd, 'case45_fault_analysis.mat');
if ~isfile(f), return; end
A = load(f); a = A.a;
w = p.postfault_window_s;
ref = mean(a.V1_kV(a.t >= w(1) & a.t <= w(2)));
after = find(a.t > p.fault_t_off_s);
bad = after(abs(a.V1_kV(after) - ref) > 0.01*ref);
if isempty(bad), ts = a.t(after(1)); else, ts = a.t(bad(end) + 1); end
s = sprintf(' within %.2f s of clearing (bus 1 voltage within 1 %% from %.2f s)', ts - p.fault_t_off_s, ts);
end

function s = caption(sc)
if sc.fault_enabled
    s = 'Cases 4 and 5: source 2 at -10&deg; with a three-phase fault at the midpoint, 1.00 to 1.10 s';
else
    s = sprintf('Case %d: source 2 at %g&deg;, steady state', sc.id, sc.V2_angle_deg);
end
end

function s = tile(label, value, sub)
s = sprintf('<div class="tile"><div class="tl">%s</div><div class="tv">%s</div><div class="ts">%s</div></div>', label, value, sub);
end

function s = badge(st)
switch st
    case 'pass', s = '<span class="b pass">&#10003; pass</span>';
    case 'fail', s = '<span class="b fail">&#10007; fail</span>';
    otherwise,   s = '<span class="b info">info</span>';
end
end

function s = data_uri(file)
fid = fopen(file, 'r'); b = fread(fid, inf, '*uint8'); fclose(fid);
s = ['data:image/png;base64,' matlab.net.base64encode(b')];
end

function s = esc(x)
s = char(x);
s = strrep(s, '&', '&amp;'); s = strrep(s, '<', '&lt;'); s = strrep(s, '>', '&gt;');
end

function open_external(file)
if ispc
    winopen(file);
else
    web(file, '-browser');
end
end

function s = head_html()
s = ['<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">' ...
'<meta name="viewport" content="width=device-width, initial-scale=1">' ...
'<title>Two-area PMU results</title><style>' ...
':root{--page:#f9f9f7;--surface:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--muted:#898781;--grid:#e1e0d9;--axis:#c3c2b7;' ...
'--accent:#2a78d6;--good:#006300;--goodbg:#e6f4e6;--bad:#b42323;--badbg:#fbe9e9}' ...
'@media (prefers-color-scheme:dark){:root{--page:#0d0d0d;--surface:#1a1a19;--ink:#f0efec;--ink2:#c3c2b7;--muted:#898781;' ...
'--grid:#2c2c2a;--axis:#383835;--accent:#3987e5;--good:#0ca30c;--goodbg:#132813;--bad:#e66767;--badbg:#3a1a1a}' ...
'figure img{background:#fcfcfb}}' ...
'*{box-sizing:border-box}body{margin:0;background:var(--page);color:var(--ink);' ...
'font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}' ...
'main{max-width:1180px;margin:0 auto;padding:32px 24px 64px}' ...
'h1{font-size:28px;margin:0 0 6px}h2{font-size:19px;margin:0 0 12px}.sub{color:var(--ink2);margin:0}' ...
'header{margin-bottom:24px}section{background:var(--surface);border:1px solid var(--grid);border-radius:10px;' ...
'padding:20px 22px;margin:18px 0}' ...
'.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px;background:none;border:0;padding:0}' ...
'.tile{background:var(--surface);border:1px solid var(--grid);border-radius:10px;padding:16px 18px}' ...
'.tl{color:var(--ink2);font-size:13px}.tv{font-size:30px;font-weight:650;margin:4px 0 2px;font-variant-numeric:tabular-nums}' ...
'.ts{color:var(--muted);font-size:13px}' ...
'.find{margin:0;padding-left:20px}.find li{margin:6px 0}.note{color:var(--ink2);font-size:13px;margin:0 0 12px}' ...
'.scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:13px;font-variant-numeric:tabular-nums}' ...
'th,td{padding:6px 7px;text-align:right;border-bottom:1px solid var(--grid);white-space:nowrap}' ...
'details{margin-top:14px}summary{cursor:pointer;color:var(--ink2);font-size:14px;margin-bottom:8px}' ...
'th{color:var(--ink2);font-weight:600;border-bottom:1px solid var(--axis)}td.l,th:nth-child(2){text-align:left}' ...
'tbody tr:hover{background:color-mix(in srgb,var(--accent) 7%,transparent)}' ...
'.b{display:inline-block;padding:1px 8px;border-radius:999px;font-size:12px;font-weight:600}' ...
'.pass{color:var(--good);background:var(--goodbg)}.fail{color:var(--bad);background:var(--badbg)}' ...
'.info{color:var(--ink2);background:color-mix(in srgb,var(--grid) 60%,transparent)}' ...
'figure{margin:0 0 26px}figcaption{color:var(--ink2);font-size:14px;margin-bottom:8px}' ...
'figure img{width:100%;height:auto;border:1px solid var(--grid);border-radius:8px}' ...
'code{background:color-mix(in srgb,var(--grid) 60%,transparent);padding:1px 5px;border-radius:4px}' ...
'</style></head>'];
end
