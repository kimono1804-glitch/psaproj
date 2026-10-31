function summary = run_all(varargin)
%RUN_ALL Build the model, run every case, write plots and the summary.
%   summary = run_all() builds the model from params(), runs simulation
%   cases 1 to 4 (cases 4 and 5 are one run), writes
%     results/<case>_dashboard.png, results/case45_fault_zoom.png,
%     results/summary.csv, results/<case>_simout.mat
%   run_all('skip_distributed', false) also re-runs cases 1 to 3 with the
%   distributed line (results/summary_distributed.csv). Off by default:
%   in R2025b that model fails at about 1.257 s even without a fault
%   (see README, Deviations); failures are reported, not hidden.

opts = struct('skip_distributed', true);
for k = 1:2:numel(varargin), opts.(varargin{k}) = varargin{k+1}; end

here = fileparts(mfilename('fullpath'));
addpath(here);
root = fileparts(here);
outdir = fullfile(root, 'results');
if ~isfolder(outdir), mkdir(outdir); end

fprintf('MATLAB %s\n', version);
base = params();
fprintf('Building model (%s line)...\n', base.line_model);
mdl = build_model(base);

rows = [];
for sc = base.sim_cases
    fprintf('Running %s...\n', sc.name);
    r = run_case(mdl, sc.id, base);
    fprintf('  %s, %.1f s wall\n', r.stop_event, r.wall_s);
    if ~strcmp(r.stop_event, 'ReachedStopTime')
        error('run_all:sim', '%s stopped early: %s', sc.name, r.stop_event);
    end
    a = analyze_case(r);
    save(fullfile(outdir, [sc.name '_analysis.mat']), 'a');
    files = plot_case(r, a, outdir);
    fprintf('  plots: %s\n', strjoin(cellfun(@(f) rel(f, root), files, 'UniformOutput', false), ', '));
    rows = [rows, a.rows]; %#ok<AGROW>
end
close_system(mdl, 0);

summary = struct2table(rows);
writetable(summary, fullfile(outdir, 'summary.csv'));
fprintf('\nWrote %s\n', rel(fullfile(outdir, 'summary.csv'), root));
show(summary);

if ~opts.skip_distributed
    fprintf('\nComparison: cases 1 to 3 with the distributed line...\n');
    pd = params(base, 'line_model', 'distributed', 'model_name', [base.model_name '_dist']);
    mdl = build_model(pd);
    drows = [];
    for sc = pd.sim_cases(~[pd.sim_cases.fault_enabled])
        try
            r = run_case(mdl, sc.id, pd);
            a = analyze_case(r);
            drows = [drows, a.rows]; %#ok<AGROW>
            fprintf('  %s: %s, %.1f s wall\n', sc.name, r.stop_event, r.wall_s);
        catch e
            msg = e.message;
            if ~isempty(e.cause), msg = [msg ' ' e.cause{1}.message]; end
            fprintf('  %s: FAILED: %s\n', sc.name, regexprep(msg, '\s+', ' '));
        end
    end
    close_system(mdl, 0);
    if ~isempty(drows)
        dsum = struct2table(drows);
        writetable(dsum, fullfile(outdir, 'summary_distributed.csv'));
        fprintf('Wrote %s\n', rel(fullfile(outdir, 'summary_distributed.csv'), root));
        show(dsum);
    end
end
end

function show(t)
cols = {'case_id', 'V1_kV_LL_rms', 'V2_kV_LL_rms', 'I1_A_rms', 'I2_A_rms', 'dtheta_deg', ...
        'P1_MW', 'Q1_Mvar', 'P2_MW', 'Q2_Mvar', 'loss_MW'};
disp(t(:, cols));
end

function s = rel(f, root)
s = strrep(f, [root filesep], '');
end
