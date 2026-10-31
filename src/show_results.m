function fig = show_results()
%SHOW_RESULTS Open a MATLAB window with the project results.
%   show_results() opens a window that shows results/report.html (headline
%   numbers, results table, verification against the analytic solution,
%   all plots), with a toolbar to:
%     open any case as zoomable MATLAB figures (redrawn from the saved
%     simulation, no re-simulation),
%     open the same report in the web browser,
%     rebuild the report from the saved results.
%   Run run_all first. Needs the MATLAB desktop (not matlab -batch).

here = fileparts(mfilename('fullpath'));
addpath(here);
root = fileparts(here);
rd = fullfile(root, 'results');
if ~isfile(fullfile(rd, 'summary.csv'))
    error('show_results:noResults', 'No results yet. Run run_all first.');
end
report = fullfile(rd, 'report.html');
if ~isfile(report), report = make_report(); end

p = params();
items = {}; data = {};
for sc = p.sim_cases
    if sc.fault_enabled
        items{end+1} = 'Cases 4 and 5: fault at midpoint'; %#ok<AGROW>
    else
        items{end+1} = sprintf('Case %d: source 2 at %g deg', sc.id, sc.V2_angle_deg); %#ok<AGROW>
    end
    data{end+1} = sc.name; %#ok<AGROW>
end

% The window and the report both follow the operating system's light or
% dark setting, so the toolbar and the page always match.
fig = uifigure('Name', 'Two-area PMU results', 'Position', [60 40 1280 940]);
g = uigridlayout(fig, [2 1], 'RowHeight', {40, '1x'}, 'Padding', [10 8 10 10]);

bar = uigridlayout(g, [1 6], 'ColumnWidth', {'fit', 280, 'fit', '1x', 'fit', 'fit'}, ...
    'Padding', [0 0 0 0]);
uilabel(bar, 'Text', 'Zoomable figures for', 'FontWeight', 'bold');
dd = uidropdown(bar, 'Items', items, 'ItemsData', data);
uibutton(bar, 'Text', 'Open figures', 'ButtonPushedFcn', @(b, ~) open_figures(b, dd.Value, rd));
uilabel(bar, 'Text', '');
uibutton(bar, 'Text', 'Open in browser', 'ButtonPushedFcn', @(~, ~) web(report, '-browser'));
uibutton(bar, 'Text', 'Rebuild report', 'ButtonPushedFcn', @(~, ~) rebuild());

h = uihtml(g, 'HTMLSource', report);

    function rebuild()
        make_report();
        h.HTMLSource = '';
        h.HTMLSource = report;
    end
end

function open_figures(btn, name, rd)
% Redraw one simulation from its saved output (no re-simulation)
fig = ancestor(btn, 'figure');
f = fullfile(rd, [name '_simout.mat']);
if ~isfile(f)
    uialert(fig, sprintf('%s not found. Run run_all first.', f), 'Missing results');
    return
end
d = uiprogressdlg(fig, 'Title', 'Loading', 'Message', 'Reading the saved simulation...', 'Indeterminate', 'on');
cl = onCleanup(@() close(d));
L = load(f);
r = extract_signals(L.simout, L.p);
a = analyze_case(r);
plot_case(r, a, rd, 'show', true, 'save', false);
end
