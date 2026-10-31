function r = run_case(mdl, id, base)
%RUN_CASE Simulate one case and return the logged signals.
%   r = run_case(mdl, id) applies simulation case id (see params.m
%   sim_cases), runs it, saves the Simulink.SimulationOutput to
%   results/<case_name>_simout.mat and returns the struct described in
%   extract_signals (PMU, raw and P/Q signals), plus r.wall_s.
%   r = run_case(mdl, id, base) starts from params struct base.

if nargin < 3, base = params(); end
root = fileparts(fileparts(mfilename('fullpath')));
p = set_case(mdl, id, base);

tic;
out = sim(mdl);
wall = toc;
r = extract_signals(out, p);
r.wall_s = wall;

outdir = fullfile(root, 'results');
if ~isfolder(outdir), mkdir(outdir); end
simout = out; %#ok<NASGU>
tag = '';
if ~strcmp(p.line_model, 'pi'), tag = ['_' p.line_model]; end
save(fullfile(outdir, [p.case_name tag '_simout.mat']), 'simout', 'p', '-v7.3');
end
