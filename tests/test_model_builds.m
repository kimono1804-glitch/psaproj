function tests = test_model_builds
%TEST_MODEL_BUILDS Model builds, compiles and has no unconnected ports.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src'));
warning('off', 'all');
tc.TestData.p = params();
end

function teardown(~)
for m = {'two_area_pmu'}
    if bdIsLoaded(m{1}), close_system(m{1}, 0); end
end
end

function testStagesCompile(tc)
for s = {'skeleton', 'line', 'full'}
    mdl = build_model(tc.TestData.p, 'stage', s{1}, 'save', false);
    try
        set_param(mdl, 'SimulationCommand', 'update');
        ok = true; msg = '';
    catch e
        ok = false; msg = e.message;
    end
    verifyTrue(tc, ok, sprintf('stage %s failed to compile: %s', s{1}, msg));
    close_system(mdl, 0);
end
end

function testBothLineModelsCompile(tc)
for lm = {'pi', 'distributed'}
    p = params('line_model', lm{1});
    mdl = build_model(p, 'save', false);
    set_param(mdl, 'SimulationCommand', 'update');   % errors fail the test
    close_system(mdl, 0);
end
end

function testNoUnconnectedPorts(tc)
mdl = build_model(tc.TestData.p, 'save', false);
blocks = find_system(mdl, 'SearchDepth', 1, 'Type', 'block');
% Any line without both ends is a dangling connection
dangling = find_system(mdl, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off');
verifyEmpty(tc, dangling, 'Model has lines with an open end.');
% Every port of every block (signal and physical) must have a line attached
nolines = {};
for k = 1:numel(blocks)
    if strcmp(blocks{k}, mdl), continue; end
    ph = get_param(blocks{k}, 'PortHandles');
    all = [ph.Inport ph.Outport ph.LConn ph.RConn];
    for h = all
        if get_param(h, 'Line') == -1
            nolines{end+1} = sprintf('%s', strrep(blocks{k}, newline, ' ')); %#ok<AGROW>
        end
    end
end
verifyEmpty(tc, nolines, sprintf('Ports with no line:\n%s', strjoin(unique(nolines), newline)));
close_system(mdl, 0);
end

function testPmuSettings(tc)
p = tc.TestData.p;
mdl = build_model(p, 'save', false);
m = block_map();
pm = find_system(mdl, 'SearchDepth', 1, 'MaskType', 'Phasor Measurement Unit (PMU, Three-Phase)');
verifyNumElements(tc, pm, 4, 'Expected four PMU blocks (V and I at each bus).');
for k = 1:numel(pm)
    verifyEqual(tc, get_param(pm{k}, 'frequency'), num2str(p.f_Hz));
    verifyEqual(tc, get_param(pm{k}, 'Nsr'), num2str(p.pmu_samples_per_cycle));
    verifyEqual(tc, get_param(pm{k}, 'k'), 'P.pmu_report_ratio');
    verifyEqual(tc, get_param([pm{k} '/' m.pmu_inner_pll], 'InputNormalization'), 'on');
end
verifyEqual(tc, p.pmu_report_ratio, 64);
close_system(mdl, 0);
end

function testLoggedSignals(tc)
mdl = build_model(tc.TestData.p, 'save', false);
need = {};
for q = {'v', 'i'}
    for k = 1:2
        for o = {'freq', 'angle', 'mag'}
            need{end+1} = sprintf('pmu_%s%d_%s', q{1}, k, o{1}); %#ok<AGROW>
        end
        need{end+1} = sprintf('%s_bus%d_abc', q{1}, k); %#ok<AGROW>
    end
end
need = [need, {'P_bus1', 'Q_bus1', 'P_bus2', 'Q_bus2'}];
lines = find_system(mdl, 'FindAll', 'on', 'Type', 'line');
names = {};
for h = lines'
    src = get_param(h, 'SrcPortHandle');
    if src > 0 && strcmp(get_param(src, 'DataLogging'), 'on')
        names{end+1} = get_param(h, 'Name'); %#ok<AGROW>
    end
end
verifyEmpty(tc, setdiff(need, names), 'Some required signals are not logged.');
close_system(mdl, 0);
end
