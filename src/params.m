function p = params(varargin)
%PARAMS All model numbers in one struct. Units are in the field names.
%   p = params() returns the base case (source 2 at -10 deg, no fault).
%   p = params('V2_angle_deg', -20, 'fault_enabled', true) overrides base
%   fields before the derived values are computed.
%
%   Values are illustrative, not from a real line. See README for the
%   assumptions that the brief did not give.

%% Base inputs
p = struct();

% System
p.f_Hz = 50;

% Sources (equivalent grids: ideal source behind series R-L)
p.V1_LL_rms_V  = 400e3;
p.V1_angle_deg = 0;
p.V2_LL_rms_V  = 400e3;
p.V2_angle_deg = -10;

% Source impedance from short-circuit level and X/R (assumption, see README)
p.src_Ssc_VA = 10e9;
p.src_XR     = 10;
p.src_impedance_enabled = true;   % false gives an ideal source (useful test case)

% Line, positive sequence, per km
p.line_length_km    = 300;
p.line_R1_ohm_per_km = 0.03;
p.line_L1_H_per_km   = 0.9e-3;
p.line_C1_F_per_km   = 0.012e-6;

% Zero-sequence placeholders (not given in the brief, used only if a block demands them)
p.line_R0_ohm_per_km = 3   * p.line_R1_ohm_per_km;
p.line_L0_H_per_km   = 3   * p.line_L1_H_per_km;
p.line_C0_F_per_km   = 0.6 * p.line_C1_F_per_km;

% Line model: 'distributed' (reference) or 'pi'
p.line_model = 'distributed';
p.line_n_sections = 2;            % split at the midpoint for the fault block

% Fault (assumption, see README)
p.fault_enabled = false;
p.fault_R_ohm   = 0.01;
p.fault_t_on_s  = 1.00;
p.fault_t_off_s = 1.10;

% PMU
p.pmu_reports_per_s    = 50;
p.pmu_samples_per_cycle = 64;     % spec asks for at least 32; block allows only 24, 48, 64

% Simulation and solver
p.t_stop_s        = 2;
p.solver          = 'ode23t';
p.solver_max_step_s = 1e-4;
p.solver_rel_tol  = 1e-4;
p.solver_abs_tol  = 1e-6;
p.settle_cycles   = 1;            % PMU start-up window ignored in checks

% Steady-state averaging window for cases 1 to 3 (after start-up transients die out)
p.ss_window_s = [1.5 2.0];

%% Overrides
if mod(numel(varargin), 2) ~= 0
    error('params:args', 'Overrides must be name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~isfield(p, name)
        error('params:unknownField', 'Unknown parameter "%s".', name);
    end
    p.(name) = varargin{k+1};
end

%% Derived values (never hard-coded)
p.w_rad_s = 2*pi*p.f_Hz;
p.T_cycle_s = 1/p.f_Hz;

p.V1_ph_rms_V  = p.V1_LL_rms_V/sqrt(3);
p.V2_ph_rms_V  = p.V2_LL_rms_V/sqrt(3);
p.V1_ph_peak_V = p.V1_ph_rms_V*sqrt(2);
p.V2_ph_peak_V = p.V2_ph_rms_V*sqrt(2);

% Source impedance, same at both ends, based on source 1 voltage
p.src_Z_ohm = p.V1_LL_rms_V^2/p.src_Ssc_VA;
p.src_R_ohm = p.src_Z_ohm/sqrt(1 + p.src_XR^2);
p.src_X_ohm = p.src_R_ohm*p.src_XR;
p.src_L_H   = p.src_X_ohm/p.w_rad_s;
if ~p.src_impedance_enabled
    p.src_R_ohm = 0; p.src_X_ohm = 0; p.src_L_H = 0;
end

% Whole line totals
p.line_R_total_ohm = p.line_R1_ohm_per_km*p.line_length_km;
p.line_L_total_H   = p.line_L1_H_per_km*p.line_length_km;
p.line_X_total_ohm = p.w_rad_s*p.line_L_total_H;
p.line_C_total_F   = p.line_C1_F_per_km*p.line_length_km;
p.line_B_total_S   = p.w_rad_s*p.line_C_total_F;
p.line_Q_charging_var = p.V1_LL_rms_V^2*p.line_B_total_S;

% Lossless surge impedance, loading and wave behaviour
p.line_Zc_lossless_ohm = sqrt(p.line_L1_H_per_km/p.line_C1_F_per_km);
p.line_SIL_W = p.V1_LL_rms_V^2/p.line_Zc_lossless_ohm;
p.line_wave_speed_km_per_s = 1/sqrt(p.line_L1_H_per_km*p.line_C1_F_per_km);
p.line_travel_time_s = p.line_length_km/p.line_wave_speed_km_per_s;
p.line_electrical_length_deg = rad2deg(p.w_rad_s*p.line_travel_time_s);

% Sections
p.line_section_length_km = p.line_length_km/p.line_n_sections;

% PMU timing. The block samples at Ts = 1/(f*Nsr) and reports every k*Ts.
if ~ismember(p.pmu_samples_per_cycle, [24 48 64])
    error('params:pmu', 'PMU block only supports 24, 48 or 64 samples per cycle.');
end
p.pmu_Ts_s = p.T_cycle_s/p.pmu_samples_per_cycle;
p.pmu_report_period_s = 1/p.pmu_reports_per_s;
p.pmu_report_ratio = round(p.pmu_report_period_s/p.pmu_Ts_s);
if abs(p.pmu_report_ratio*p.pmu_Ts_s - p.pmu_report_period_s) > 1e-12
    error('params:pmu', 'Reporting period is not a whole number of PMU samples.');
end
end
