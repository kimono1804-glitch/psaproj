function py = find_python()
%FIND_PYTHON Python interpreter for reference/analytic_check.py.
%   Uses the PSAPROJ_PYTHON environment variable if set, then a miniconda
%   install in the user profile, then 'python' on the PATH. Returns '' if
%   none of them can import numpy.
cands = {getenv('PSAPROJ_PYTHON'), ...
         fullfile(getenv('USERPROFILE'), 'miniconda3', 'python.exe'), ...
         fullfile(getenv('USERPROFILE'), 'anaconda3', 'python.exe'), ...
         'python', 'python3'};
py = '';
for k = 1:numel(cands)
    c = cands{k};
    if isempty(c), continue; end
    [st, ~] = system(sprintf('"%s" -c "import numpy"', c));
    if st == 0
        py = c;
        return
    end
end
end
