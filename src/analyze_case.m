function a = analyze_case(r)
%ANALYZE_CASE Delta-theta, power and summary numbers for one simulation.
%
%   Sign convention (used in every plot and table):
%     Delta-theta(t) = theta_PMU1(t) - theta_PMU2(t), wrapped to +-180 deg.
%     With source 2 at -10 deg, source 1 leads, active power flows from
%     bus 1 to bus 2 and Delta-theta is positive.
%     Current is positive flowing out of a bus into the line, at both ends,
%     so P2 < 0 when power arrives at bus 2 and the line loss is P1 + P2.
%
%   PMU magnitudes are peak values. Tables use line-to-line RMS voltage
%   (peak * sqrt(3)/sqrt(2)) and RMS current (peak / sqrt(2)).
%
%   a = analyze_case(r) returns:
%     a.t, a.dtheta_deg, a.rocof1/2_Hz_per_s, a.V1/2_kV, a.I1/2_A  (PMU time series)
%     a.rows    summary rows (struct array), one per reported case
%     a.windows struct of named windows used (pre/faulton/post or steady)

p = r.p;
v1 = r.pmu.v1; v2 = r.pmu.v2; i1 = r.pmu.i1; i2 = r.pmu.i2;

a.t = v1.t;
a.dtheta_deg = wrap180(v1.angle - v2.angle);
a.V1_kV = v1.mag*sqrt(3)/sqrt(2)/1e3;
a.V2_kV = v2.mag*sqrt(3)/sqrt(2)/1e3;
a.I1_A = i1.mag/sqrt(2);
a.I2_A = i2.mag/sqrt(2);
a.f1_Hz = v1.freq; a.f2_Hz = v2.freq;
a.rocof1_Hz_per_s = [NaN; diff(v1.freq)./diff(v1.t)];
a.rocof2_Hz_per_s = [NaN; diff(v2.freq)./diff(v2.t)];
% P from the PMU phasors, as a cross-check of the instantaneous P
a.P1_pmu_MW = 1.5*v1.mag.*i1.mag.*cosd(v1.angle - i1.angle)/1e6;
a.P2_pmu_MW = 1.5*v2.mag.*i2.mag.*cosd(v2.angle - i2.angle)/1e6;

if p.fault_enabled
    a.windows = struct('prefault', p.prefault_window_s, 'faulton', p.faulton_window_s, ...
                       'postfault', p.postfault_window_s);
    a.prefault = row(r, a, p.prefault_window_s, p.case_id, 'pre-fault (reference)');
    a.rows = [row(r, a, p.faulton_window_s, 4, 'three-phase fault at midpoint, fault-on window'), ...
              row(r, a, p.postfault_window_s, 5, 'fault cleared at 1.10 s, post-fault window')];
else
    a.windows = struct('steady', p.ss_window_s);
    a.rows = row(r, a, p.ss_window_s, p.case_id, ...
        sprintf('source 2 at %g deg, steady state', p.V2_angle_deg));
end
end

function s = row(r, a, w, id, desc)
in = a.t >= w(1) & a.t <= w(2);
s.case_id = id;
s.description = desc;
s.window_start_s = w(1);
s.window_end_s = w(2);
s.n_pmu_reports = nnz(in);
s.V1_kV_LL_rms = mean(a.V1_kV(in));
s.V2_kV_LL_rms = mean(a.V2_kV(in));
s.I1_A_rms = mean(a.I1_A(in));
s.I2_A_rms = mean(a.I2_A(in));
s.dtheta_deg = mean(a.dtheta_deg(in));
s.f1_Hz = mean(a.f1_Hz(in));
s.f2_Hz = mean(a.f2_Hz(in));
s.P1_MW = wmean(r.pq.P_bus1, w)/1e6;
s.Q1_Mvar = wmean(r.pq.Q_bus1, w)/1e6;
s.P2_MW = wmean(r.pq.P_bus2, w)/1e6;
s.Q2_Mvar = wmean(r.pq.Q_bus2, w)/1e6;
s.loss_MW = s.P1_MW + s.P2_MW;
s.P1_from_PMU_MW = mean(a.P1_pmu_MW(in));
end

function m = wmean(sig, w)
% Time-weighted mean over a window (the solver step is variable)
in = sig.t >= w(1) & sig.t <= w(2);
t = sig.t(in); x = sig.x(in);
m = trapz(t, x)/(t(end) - t(1));
end

function y = wrap180(x)
y = mod(x + 180, 360) - 180;
end
