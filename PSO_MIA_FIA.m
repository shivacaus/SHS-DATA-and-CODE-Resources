%%%---PART A
%% 1. Load and Prepare Data
filename = 'Epidemic and meteorological data_Nepal.xlsx';
data = readtable(filename);
% Extrac variables (time-dependent)
I = data.I;            % Infected (active)
R = data.R_c;          %  Recovered = Removed - Deaths (all cummulative)
D = data.Death_Cum;    % Deaths (cum)
DD = data.Death_Daily; % Daily Death
N = data.N_Living;     % Living Population (time-varying)
T2M = data.T2M;        % Temperature (2m)
RH2M = data.RH2M;      % Relative Humidity (2m)
WS2M = data.WS2M;      % Wind Speed (2m)
dates = data.Date;     % datetime vector
%% 2. Parameters and Initial Setup 
% Vital Dynamics (year-wise)
alpha_2020 = 5.65479e-05; alpha_2021 = 5.60274e-05; alpha_2022 = 5.52329e-05;
y = year(dates);   alpha = zeros(size(dates));  
alpha(y==2020) = alpha_2020; alpha(y==2021) = alpha_2021; alpha(y==2022) = alpha_2022;

% Nominal epidemiology parameters (literature anchors)
rho_0     = 1/7;          % Recovery rate (~7–14 days)
epsilon_0 = 1/5;           % Incubation rate (~2–14 days)
vaccine_efficacy = 0.60;  % Average of diferent brands of vaccines,(assumed)

% Bounds (biological/plausible)
r_min = 1/21; r_max = 1/3;      % Recovery bounds
e_min = 1/21; e_max = 1/3;     % Incubation bounds
b_min = 0.0001; b_max = 0.5;    % Transmission bounds            
d_min = 0;  d_max = 0.0002;    % Mortality bounds
u_min = 0.05;  u_max = 0.90;   % Intervention bounds

% Time lag parameter (7 days)
time_lag = 7;

% Bounds struct 
bds = struct('b_max', b_max, 'b_min', b_min, ...
             'r_max', r_max, 'r_min', r_min, ...
             'e_max', e_max, 'e_min', e_min, ...
             'd_max', d_max, 'd_min', d_min, ...
             'u_max', u_max, 'u_min', u_min);

% Smoothing / filters 
span       = 11;   % Savitzky–Golay window (odd)
polyorder  = 3;
ma_window  = 11;    % moving average window
windowSize = 11;   % for bad value replacement
%% 3. Intervention Efficacy: NPI (u) and vaccination (v) Timeline
% Phases: {Date_start, Date_end, u_min, u_max, v_at_end_of_phase}
phases = {
    {datetime(2020,03,24), datetime(2020,07,21), 0.65, 0.85, 0.00};  % 1 Nationwide lockdown
    {datetime(2020,07,22), datetime(2020,08,18), 0.40, 0.55, 0.00};  % 2 Gradual reopening after lifting lockdown
    {datetime(2020,08,19), datetime(2020,10,15), 0.50, 0.60, 0.00};  % 3 Capital city preventive orders
    {datetime(2020,10,16), datetime(2020,10,31), 0.20, 0.35, 0.00};  % 4 Dashain 2020 festival guidance
    {datetime(2020,11,01), datetime(2020,11,20), 0.40, 0.55, 0.00};  % 5 Post-festival local NPIs
    {datetime(2020,11,21), datetime(2021,01,26), 0.30, 0.40, 0.00};  % 6 Winter NPIs (local level)
    {datetime(2021,01,27), datetime(2021,03,31), 0.35, 0.45, 0.066}; % 7 Vaccination campaign begins (first & second phases)
    {datetime(2021,04,01), datetime(2021,04,28), 0.45, 0.50, 0.070}; % 8 Rising cases pre-Delta warnings
    {datetime(2021,04,29), datetime(2021,08,31), 0.70, 0.85, 0.170}; % 9 Delta-prohibitory lockdown
    {datetime(2021,09,01), datetime(2021,09,29), 0.35, 0.45, 0.180}; % 10 Reopening (moderate NPIs; schools conditional)
    {datetime(2021,09,30), datetime(2021,11,11), 0.20, 0.30, 0.230}; % 11 Dashain, Tihar 2021 (festival guidelines)
    {datetime(2021,11,12), datetime(2022,01,06), 0.40, 0.50, 0.360}; % 12 Post-festival period (vaccination scale-up)
    {datetime(2022,01,07), datetime(2022,02,06), 0.55, 0.65, 0.400}; % 13 Omicron response (vax card for services)
    {datetime(2022,02,07), datetime(2022,03,04), 0.35, 0.45, 0.440}; % 14 Pre-lifting transition
    {datetime(2022,03,05), datetime(2022,09,25), 0.05, 0.25, 0.650}; % 15 All restrictions lifted (endemic transition)
    {datetime(2022,09,26), datetime(2022,10,31), 0.05, 0.20, 0.700}; % 16 Dashain, Tihar 2022 (normal)
    {datetime(2022,11,01), datetime(2022,11,30), 0.00, 0.15, 0.710}; % 17 Post-festival period (normal)
    {datetime(2022,12,01), datetime(2022,12,31), 0.05, 0.20, 0.730}; % 18 Post-pandemic normalization
};

% reproducibility for phase jitter
rng(2025,'twister');

% Build intervention/vaccination daily series
u_t = zeros(size(dates));
v_t = zeros(size(dates));
for i = 1:numel(phases)
    ph = phases{i};
    idx = (dates >= ph{1}) & (dates <= ph{2});
    if any(idx)
        nd = sum(idx);
        daily_ut = linspace(ph{3}, ph{4}, nd);
        daily_ut = daily_ut + 0.02*randn(size(daily_ut));
        daily_ut = min(max(daily_ut, u_min), u_max);   % clamp per-day NPI
        u_t(idx) = daily_ut;
        v_t(idx) = ph{5};
    end
end
%% 4(i) Combined intervention effect with time lag (7 days)
u_combined = 1 - (1 - u_t) .* (1 - v_t .* vaccine_efficacy);
n_days = numel(dates);

% Lag interventions by 'time_lag' days 
u_pad = [nan(time_lag,1); u_combined(1:end-time_lag)];
u_ts  = movmean(u_pad, ma_window, 'omitnan','Endpoints','shrink');
u_ts  = min(max(u_ts, u_min), u_max);   % clamp after smoothing

%% 4(ii) Apply time lag to WEATHER (features: T2M, RH2M, WS2M)
weather_features = [T2M, RH2M, WS2M]; % strictly 3 features
wf_pad = [nan(time_lag,3); weather_features(1:end-time_lag,:)];
weather_features_lagged = wf_pad;

%% 4(iii) Remove days without full lag data (first 'time_lag' rows)
keep_idx = (time_lag+1):n_days;

% Trim all time series to aligned window with valid lagged inputs
dates = dates(keep_idx);
I   = I(keep_idx);   R = R(keep_idx);  D = D(keep_idx);  
DD = DD(keep_idx); N = N(keep_idx);
weather_features_lagged = weather_features_lagged(keep_idx, :);
u_ts = u_ts(keep_idx);alpha=alpha(keep_idx);
% Update day count
n_days = numel(dates);
% smooth alpha and clip
alpha = sgolayfilt(alpha, polyorder, span);
alpha = max(alpha,0);
%% 4(iv) Smooth/normalize weather (lagged) & epidemiology
weather_smoothed   = sgolayfilt(weather_features_lagged, polyorder, span);
meteo_data         = normalize(weather_smoothed, 'zscore'); % m_d in later code

% Smooth epidemiological signals
I_s = sgolayfilt(I, polyorder, span);
R_s = sgolayfilt(R, polyorder, span);
DD_s = sgolayfilt(DD, polyorder, span);

% delta_t = deaths per infected 
delta_t = zeros(size(I_s));
valid_idx = I_s > 0;
delta_t(valid_idx) = DD_s(valid_idx) ./ I_s(valid_idx);
delta_t(~valid_idx) = median(delta_t(valid_idx), 'omitnan');
delta_t = sgolayfilt(delta_t, polyorder, span);
delta_t = min(max(delta_t, d_min), d_max);  % bound
%% 4(v) Normalize, differentiate I_s and R_s/smooth derivatives
I_sn = I_s ./ N; I_safe = max(I_sn, 1e-6);  R_sn = R_s ./ N;
dI   = gradient(I_sn);
dR   = gradient(R_sn);
dI_s = sgolayfilt(dI, polyorder, span);
dR_s = sgolayfilt(dR, polyorder, span);

%% 5. SEIR Compartment Reconstruction (with lagged weather and u_ts)
% reconstruct exposed fraction using i'(t)
E_n  = ( dI_s + (rho_0 + delta_t + alpha).*I_sn - delta_t.*I_sn.^2 ) / epsilon_0;
E_n  = max(E_n, 1e-6);                          % avoid negative exposed
E_sn = sgolayfilt(E_n, polyorder, span);        % smooth reconstructed E

% clip to [0,1] before renormalization
E_sn = max(0, min(1, E_sn));
I_sn = max(0, min(1, I_sn));
R_sn = max(0, min(1, R_sn));

% provisional susceptible
S_sn  = 1 - E_sn - I_sn - R_sn;

%  renormalize (S,E,I,R) to sum to 1 each day 
total_sn = S_sn + E_sn + I_sn + R_sn;
total_sn = max(total_sn, 1e-6);  % avoid divide-by-zero

S_sn = S_sn ./ total_sn;
E_sn = E_sn ./ total_sn;
I_sn = I_sn ./ total_sn;
R_sn = R_sn ./ total_sn;

% final safety clip
S_sn = max(S_sn,0); E_sn=max(E_sn,0); I_sn=max(I_sn,0); R_sn=max(R_sn,0);

% derivatives (for later β, ε, ρ calc)
dE   = gradient(E_sn);
dS   = gradient(S_sn);
dE_s = sgolayfilt(dE, polyorder, span);
dS_s = sgolayfilt(dS, polyorder, span);

%% 6. Parameter Calculation (normalized system)
% Safety guards
den_si = max((1 - u_ts).*S_sn.*I_sn, 1e-8);
E_safe = max(E_sn, 1e-6);

% ρ(t)
rho_SEIR = ( dR_s + (alpha - delta_t.* I_sn).*R_sn ) ./ I_safe;

% ε(t)
epsilon_SEIR = ( dI_s + (rho_SEIR + delta_t + alpha).*I_sn - delta_t.*I_sn.^2) ./ E_safe;

% β(t)
beta_SEIR = ( dE_s + (epsilon_SEIR + alpha).*E_sn - delta_t.*I_sn.*E_sn) ./ den_si;

% Smooth & clean diagnostics
rho_SEIR      = sgolayfilt(rho_SEIR, polyorder, span);
epsilon_SEIR  = sgolayfilt(epsilon_SEIR, polyorder, span);
beta_SEIR     = sgolayfilt(beta_SEIR, polyorder, span);

[beta_SEIR, rho_SEIR, epsilon_SEIR] = replaceBadValues(windowSize, beta_SEIR, rho_SEIR, epsilon_SEIR);

rho_SEIR      = min(max(rho_SEIR,      bds.r_min), bds.r_max);
epsilon_SEIR  = min(max(epsilon_SEIR,  bds.e_min), bds.e_max);
beta_SEIR     = min(max(beta_SEIR,     bds.b_min), bds.b_max);

beta_SEIR_eff = (1 - u_ts) .* beta_SEIR;
[beta_SEIR_eff] = replaceBadValues(windowSize, beta_SEIR_eff);

% === Fixed initial conditions ===
% S_init = max(S_sn(1), 0.9);
% E_init = max(E_sn(1), 1e-5);
% I_init = max(I_sn(1), 1e-5);
% R_init = max(R_sn(1), 1e-4);
% x0_init = [S_init, E_init, I_init, R_init];
% x0_init = x0_init / sum(x0_init);
% x0_init = [S_sn(1), E_sn(1), I_sn(1), R_sn(1)];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
days_mean = 7;  % first week
S0 = max(mean(S_sn(1:days_mean)), 0.9);
E0 = max(mean(E_sn(1:days_mean)), 1e-6);
I0 = max(mean(I_sn(1:days_mean)), 1e-6);
R0 = max(mean(R_sn(1:days_mean)), 1e-6);
x0_init = [S0, E0, I0, R0];
x0_init = x0_init / sum(x0_init);

%%%---PART B
%% 7. PSO + Pattern Search Optimization (18 params incl. u_scale)
fprintf('\n=== PSO (Global+Local) Optimization Phase with 7-Day Lag & u_ts ===\n');

m_d = meteo_data;                                 % features (lagged+smoothed+zscored)
o_d = [S_sn, E_sn, I_sn, R_sn];                   % observed compartments
c_p = [beta_SEIR_eff, epsilon_SEIR, rho_SEIR, u_ts, delta_t]; % computed param trajectories
% Fixed initial conditions and computed params passed separately
cp = c_p; init_cond = x0_init;
t_sp = (1:n_days)';    % time index
n_meteo_ftr = 3;  % T2M, RH2M, WS2M only

% Parameter vector structure (18 total):
% [b0, b_T,b_{RH},b_{WS},  r0, r_T,r_{RH},r_{WS},  e0, e_T,e_{RH},e_{WS},  d0, d_T,δ_{RH},d_{WS},  u_scale, ep_hold]
% ep_hold is a non-functional placeholder to keep the parameter vector dimension consistent (18 elements) for PSO, fixed at 0 via bounds.
coef_low  = -0.90;  coef_high = 0.90;   % beta, eho, epsilon coefficients
dcoef_low =  -1e-6; dcoef_high = 1e-6;  % delta coefficients

lb = [b_min, coef_low*ones(1,n_meteo_ftr), ...
      r_min, coef_low*ones(1,n_meteo_ftr), ...
      e_min, coef_low*ones(1,n_meteo_ftr), ...
      d_min, dcoef_low*ones(1,n_meteo_ftr), ...
      u_min,   0];               % u_scale in [0.05,0.95]

ub = [b_max, coef_high*ones(1,n_meteo_ftr), ...
      r_max, coef_high*ones(1,n_meteo_ftr), ...
      e_max, coef_high*ones(1,n_meteo_ftr), ...
      d_max, dcoef_high*ones(1,n_meteo_ftr), ...
      u_max,   0];

% Ensure parallel pool (optional)
if isempty(gcp('nocreate'))
    try parpool; catch, warning('Parallel pool unavailable; continuing serially.'); end
end
 
% PSO options  
pso_opt = optimoptions('particleswarm', ...
    'Display','iter', 'MaxIterations', 300, 'SwarmSize', 180 , ...
    'FunctionTolerance',1e-5, 'MaxStallIterations',20, ...
    'SelfAdjustmentWeight',1.49, 'SocialAdjustmentWeight',1.49, ...
    'InertiaRange',[0.3 1.0], 'UseParallel', ~isempty(gcp('nocreate'))); 

% Pattern search options  
ps_options = optimoptions('patternsearch', ...
    'Display','iter', 'MaxIterations', 100, 'FunctionTolerance',1e-5, ...
    'StepTolerance',1e-5, 'UseParallel', ~isempty(gcp('nocreate')));

rng(1); tic;
% Objective 
obj_fun = @(x) seir_objective_function(x, m_d, o_d, alpha, t_sp, false, c_p, x0_init, bds, u_ts);

fprintf('\n--- STAGE 1: PSO GLOBAL SEARCH ---\n');
[pso_prm, pso_fval] = particleswarm(obj_fun, numel(lb), lb, ub, pso_opt);

fprintf('\n--- STAGE 2: PATTERN SEARCH REFINEMENT ---\n');
[optm_prm, fval] = patternsearch(obj_fun, pso_prm, [], [], [], [], lb, ub, [], ps_options);
optimization_time = toc;

% Results summary
fprintf('\nHYBRID OPTIMIZATION RESULTS WITH 7-DAY LAG (3 features, u_ts-aware):\n');
fprintf(' PSO Objective: %.6f\n', pso_fval);
fprintf(' Final Objective: %.6f (%.2f%%%% improvement)\n', fval, 100*(pso_fval-fval)/max(pso_fval,eps));
fprintf(' Total Optimization Time: %.2f seconds\n', optimization_time);

% Unpack for display
beta_params  = optm_prm(1: 4);
rho_params   = optm_prm(5: 8);
eps_params   = optm_prm(9:12);
delta_params = optm_prm(13:16);
u_scale      = optm_prm(17);

fprintf('\nOptimal Parameters:\n');
fprintf('Beta:    β0=%.4f, [β_T,β_{RH},β_{WS}]=[%s]\n', beta_params(1),  num2str(beta_params(2:4), '%.4f '));
fprintf('Rho:     ρ0=%.4f, [ρ_T,ρ_{RH},ρ_{WS}]=[%s]\n', rho_params(1),   num2str(rho_params(2:4),  '%.4f '));
fprintf('Epsilon: ε0=%.4f, [ε_T,ε_{RH},ε_{WS}]=[%s]\n', eps_params(1),   num2str(eps_params(2:4), '%.4f '));
fprintf('Delta:   δ0=%.4f, [δ_T,δ_{RH},δ_{WS}]=[%s]\n', delta_params(1), num2str(delta_params(2:4), '%.4f '));
fprintf('u_scale: %.4f  (u_eff = clamp(u_scale * u_ts))\n', u_scale);

%%%---PART C
%% 8. Post-optimization Simulation 

% Simulate with the  Helper:simulate_seir_model
[S_model, E_model, I_model, R_model, u_eff] = simulate_seir_model( ...
    optm_prm, m_d, alpha, t_sp, x0_init, bds, u_ts);

modeled_data = [S_model, E_model, I_model, R_model];   % R_model is r_c

% ---- Environment-dependent parameter trajectories ----
% Unpack optimized parameters
beta_params  = optm_prm( 1: 4);
rho_params   = optm_prm( 5: 8);
eps_params   = optm_prm( 9:12);
delta_params = optm_prm(13:16);
u_scale      = optm_prm(17);  % scaling already reflected in u_eff

% 1) intrinsic trajectories from meteorology
beta_intr  = beta_params(1)  * exp(m_d * beta_params(2:4)');   % beta(t)
rho_env    = rho_params(1)   * exp(m_d * rho_params(2:4)');    % rho(t)
eps_env    = eps_params(1)   * exp(m_d * eps_params(2:4)');    % epsilon(t)
delta_env  = delta_params(1) * exp(m_d * delta_params(2:4)');  % delta(t)

% 2) clamp to biological bounds
beta_intr  = max(min(beta_intr,  bds.b_max), bds.b_min);
rho_env    = max(min(rho_env,    bds.r_max), bds.r_min);
eps_env    = max(min(eps_env,    bds.e_max), bds.e_min);
delta_env  = max(min(delta_env,  bds.d_max), bds.d_min);

% 3) effective transmission 
beta_env = (1 - u_eff) .* beta_intr;   % beta_eff(t) used in the simulator
%% 9. Performance Metrics
fprintf('\n=== CALCULATING PERFORMANCE METRICS ===\n');

[rmse_vals, mae_vals, r2_vals] = calculate_goodness_of_fit(o_d, modeled_data);
param_computed = [beta_SEIR_eff, epsilon_SEIR, rho_SEIR, u_ts, delta_t];
param_modeled  = [beta_env, eps_env,  rho_env, u_eff, delta_env];
[rmse_params, mae_params, r2_params] = calculate_goodness_of_fit(param_computed, param_modeled);

% Display
fprintf('\nCompartment Performance (Obs vs Model):\n');
labels = {'S','E','I','R'};
for k = 1:4
    fprintf('%s: RMSE=%.6f, MAE=%.6f, R^2=%.6f\n', labels{k}, rmse_vals(k), mae_vals(k), r2_vals(k));
end

fprintf('\nParameter Performance (Computed vs Optimized):\n');
plabs = {'Beta','Epsilon','Rho','U','Delta'};
for k = 1:5
    fprintf('%s: RMSE=%.6f, MAE=%.6f, R^2=%.6f\n', plabs{k}, rmse_params(k), mae_params(k), r2_params(k));
end

%% 10. Advanced Analyses
fprintf('\n=== ADVANCED ANALYSES (Lag-aware) ===\n');

analyze_environmental_effects(beta_params, rho_params, eps_params, ...
    delta_params, u_scale, m_d, dates, time_lag, u_ts, bds);

% Cross-Validation (time-aware; fold-wise normalization; uses u_ts)
k_folds = 5;
[cv_errors, cv_r2] = perform_cross_validation( ...
    weather_smoothed, ...   % raw (pre-normalized) meteo features
    o_d, alpha, k_folds, lb, ub, x0_init, [], bds, [], [], u_ts);

% Forecasting (ensemble)
n_ensembles   = 200;
jitter_pct    = 0.10;
extend_mode   = 'trend';
forecast_days = 60;
[all_dates, median_SEIR, low_SEIR, high_SEIR, ~] = ...
    generate_forecast(optm_prm, m_d, alpha, forecast_days, x0_init, dates, bds, n_ensembles, jitter_pct, extend_mode, u_ts);

%%%---PART D
%% 11. PLOTS 
fprintf('\n=== GENERATING PLOTS ===\n');
createFigure = @(n) figure('Units','normalized','OuterPosition',[0.05+n*0.02 0.05+n*0.02 0.85 0.75]);

% folder for exported figures 
outdir = 'fig';
if ~exist(outdir,'dir'), mkdir(outdir); end

%% ------------------- Plot 1: Parameters (Computed vs Optimized) -------------------
fprintf('Plot 1...\n');

fig = figure('Name','SEIR Parameters: Computed vs Optimized', ...
             'Position',[120, 80, 1400, 900]);  
t = tiledlayout(fig, 3, 1, 'TileSpacing','compact', 'Padding','compact');

param_titles  = {'Beta (7-day lag)', 'Epsilon', 'Rho'};
param_ylabels = {'Transmission ($\\beta$)', 'Incubation ($\\epsilon$)', 'Recovery ($\\rho$)'};

% Only three params 
obsP = {beta_SEIR_eff,  epsilon_SEIR,  rho_SEIR};
mdlP = {beta_env,       eps_env,       rho_env};

axArr = gobjects(1,3);
for k = 1:3
    ax = nexttile(t);  axArr(k) = ax;
    plot(ax, dates, obsP{k}, 'b--', 'LineWidth', 2.0); hold(ax, 'on');
    plot(ax, dates, mdlP{k}, 'r-',  'LineWidth', 1.5);
    ylabel(ax, param_ylabels{k}, 'Interpreter','latex');
    title(ax, param_titles{k}, 'Interpreter','none');
    grid(ax, 'on');
    xlim(ax, [dates(1), dates(end)]);
    ax.XAxis.TickLabelFormat = 'MMM yyyy';
    legend(ax, {'Computed','Optimized'}, 'Location','best', 'Box','off', 'Interpreter','none');
end

% Shared x-label and single-page title
xlabel(t, 'Date', 'Interpreter','none');
sgtitle(t, 'SEIR Parameters: Computed vs Optimized (7-day lag, $u_{\mathrm{eff}} = u_{\mathrm{scale}}\cdot u_{ts}$)', ...
        'Interpreter','latex');

linkaxes(axArr, 'x');


%% ------------------- Plot 2: Compartments (Obs. vs Model) -------------------
fprintf('Plot 2...\n');
createFigure(1);
comp_names = {'Susceptible','Exposed','Infected','Recovered'};
obs = {S_sn,E_sn,I_sn,R_sn}; 
mdl = {S_model,E_model,I_model,R_model};

for k = 1:4
    subplot(2,2,k);
    plot(dates, obs{k}, 'b--','LineWidth',2.0); hold on;
    plot(dates, mdl{k}, 'r-','LineWidth',1.5);
    ylabel([comp_names{k},' Fraction'], 'Interpreter','none'); 
    xlabel('Date', 'Interpreter','none'); 
    legend('Observed','Modeled','Location','best','Interpreter','none','Box','off'); 
    grid on;
    title(comp_names{k}, 'Interpreter','none');
end
sgtitle('SEIR Compartments (Obs vs Modeled) -- 7-day lag, $u_{ts}$-aware', 'Interpreter','latex');


%% ------------------- Plot 3: Environmental effects (multiplicative) -------------------
fprintf('Plot 3...\n');

% Figure size in inches
FIG3_W = 7.0;  FIG3_H = 3.0;

env_range  = linspace(-3, 3, 200)';                     % standardized feature value
param_sets = {beta_params, rho_params, eps_params};
panel_lbls = {'Transmission ($\beta$)', 'Recovery ($\rho$)', 'Incubation ($\epsilon$)'};
feat_lbls  = {'T','RH','WS'};

fig3 = figure('Name','Plot3_EnvEffects','Color','w', ...
              'Units','inches','Position',[1 1 FIG3_W FIG3_H]);

tiledlayout(fig3, 1, 3, 'Padding','compact','TileSpacing','compact');

for k = 1:3
    nexttile; hold on;
    p    = param_sets{k};
    base = p(1);  cT = p(2);  cRH = p(3);  cWS = p(4);

    yT  = base * exp(env_range * cT);
    yRH = base * exp(env_range * cRH);
    yWS = base * exp(env_range * cWS);

    plot(env_range, yT,  'LineWidth', 1.8);
    plot(env_range, yRH, 'LineWidth', 1.8);
    plot(env_range, yWS, 'LineWidth', 1.8);

    grid on; box off;
    xlabel('Standardized feature value ($z$)', 'Interpreter','latex');
    ylabel('Rate', 'Interpreter','latex');
    title(panel_lbls{k}, 'Interpreter','latex');
    legend(feat_lbls, 'Location','best', 'Box','off', 'Interpreter','none'); % no LaTeX needed here
    set(gca,'FontSize',9,'LineWidth',0.8);
end

% --- Export as vector EPS (Plot 3 only) ---
exportgraphics(fig3, fullfile(outdir,'meteo_effects.eps'), 'ContentType','vector');


%% ------------------- Plot 4: Feature importance (|exp. coefficients|) -------------------
fprintf('Plot 4...\n');

FIG4_W = 6.8;  FIG4_H = 3.2;

beta_coeffs = abs(beta_params(2:4));
rho_coeffs  = abs(rho_params(2:4));
eps_coeffs  = abs(eps_params(2:4));
feature_names = {'T2M','RH2M','WS2M'};

fig4 = figure('Name','Plot4_FeatureImportance','Color','w', ...
              'Units','inches','Position',[1 1 FIG4_W FIG4_H]);

tiledlayout(fig4, 1, 2, 'Padding','compact','TileSpacing','compact');

% Left: per-parameter bars
nexttile;
B = [beta_coeffs; rho_coeffs; eps_coeffs]';   % 3x3
bar(B, 'LineWidth',0.5);
set(gca,'XTickLabel',feature_names,'XTickLabelRotation',0);
ylabel('$|\mathrm{Coefficient}|$ (per $z$-unit)', 'Interpreter','latex');
legend({'$\beta$','$\rho$','$\epsilon$'}, 'Interpreter','latex', 'Location','best', 'Box','off');
title('Feature Importance (Exponential Coefficients)', 'Interpreter','latex');
grid on; box off; set(gca,'FontSize',9,'LineWidth',0.8);

% Right: overall mean across parameters
nexttile;
overall_imp = mean(B,2);               % 3x1
[sorted_imp, order] = sort(overall_imp,'descend');
bar(sorted_imp, 'LineWidth',0.5);
set(gca,'XTickLabel',feature_names(order));
ylabel('Avg $|\mathrm{Coeff}|$ (per $z$-unit)', 'Interpreter','latex');
title('Overall Feature Importance', 'Interpreter','latex');
grid on; box off; set(gca,'FontSize',9,'LineWidth',0.8);

% --- Export as vector EPS  ---
exportgraphics(fig4, fullfile(outdir,'feature_importance.eps'), 'ContentType','vector');
  
%% ------------------- Plot 5: Forecast with 95% bands -------------------
fprintf('Plot 5...\n');
createFigure(4);

x_all      = all_dates;             % datetime
x_hist_end = dates(end);            % datetime of last observed point

cS = [0.0000 0.4470 0.7410]; % blue
cE = [0.4940 0.1840 0.5560]; % purple
cI = [0.8500 0.3250 0.0980]; % orange-red
cR = [0.4660 0.6740 0.1880]; % green
fa = 0.18;                    % band lightening factor (no transparency)

subplot(2,2,1);
shaded_band_eps(gca, x_all, low_SEIR(:,1), median_SEIR(:,1), high_SEIR(:,1), ...
                cS, 'Susceptible', 'S', fa);
xline(x_hist_end,'--','Color',[.2 .2 .2]);

subplot(2,2,2);
shaded_band_eps(gca, x_all, low_SEIR(:,2), median_SEIR(:,2), high_SEIR(:,2), ...
                cE, 'Exposed', 'E', fa);
xline(x_hist_end,'--','Color',[.2 .2 .2]);

subplot(2,2,3);
shaded_band_eps(gca, x_all, low_SEIR(:,3), median_SEIR(:,3), high_SEIR(:,3), ...
                cI, 'Infected', 'I', fa);
xline(x_hist_end,'--','Color',[.2 .2 .2]);

subplot(2,2,4);
shaded_band_eps(gca, x_all, low_SEIR(:,4), median_SEIR(:,4), high_SEIR(:,4), ...
                cR, 'Recovered', 'R', fa);
xline(x_hist_end,'--','Color',[.2 .2 .2]);

sgtitle(sprintf(['%d-Day SEIR Forecast with 95\\%% Bands (n=%d, jitter=%.0f\\%%, ' ...
                 '%s meteo, $u_{ts}$-aware)'], ...
                 forecast_days, n_ensembles, 100*jitter_pct, extend_mode), ...
        'Interpreter','latex');

%%%---PART E
%% 12. Final Summary & Recommendations 
fprintf('\n=== FINAL SUMMARY & RECOMMENDATIONS (7-DAY LAG, 3 FEATURES, u_{ts}-aware) ===\n');

% Environmental coefficient magnitudes (exp form)
env_effects = [abs(beta_params(2:4)); abs(rho_params(2:4)); abs(eps_params(2:4)); abs(delta_params(2:4))];
[sorted_effects, sort_idx] = sort(env_effects(:), 'descend');
param_types = {'β_T','β_{RH}','β_{WS}','ρ_T','ρ_{RH}','ρ_{WS}','ε_T','ε_{RH}','ε_{WS}','δ_T','δ_{RH}','δ_{WS}'};

fprintf('\nTop 5 Environmental Effects (exp coefficients, 7-day lag):\n');
for i = 1:min(5,numel(sorted_effects))
    fprintf('%d. %s: %.4f\n', i, param_types{sort_idx(i)}, sorted_effects(i));
end

fprintf('\nTime Lag Applied: %d days (weather & interventions influence day t from t-%d)\n', time_lag, time_lag);
fprintf('u_scale = %.3f  -> scales empirical u_{ts}.\n', u_scale);

overall_rmse = mean(rmse_vals);
overall_r2   = mean(r2_vals);
fprintf('\nModel Quality: RMSE=%.4f, R^2=%.3f\n', overall_rmse, overall_r2);

env_factors = {'Temperature','Humidity','Windspeed'};
par_sets = {beta_params, rho_params, eps_params};
par_names = {'Transmission (β)','Recovery (ρ)','Incubation (ε)'};
for i = 1:3
    fprintf('\n%s (lagged, exp effects):\n', par_names{i});
    for j = 2:4
        c = par_sets{i}(j);
        if c > 1e-3,   fprintf('  + Higher %s increases %s\n', env_factors{j-1}, par_names{i});
        elseif c < -1e-3, fprintf('  - Higher %s reduces %s\n',  env_factors{j-1}, par_names{i});
        else,           fprintf('  ~ No clear effect of %s on %s\n', env_factors{j-1}, par_names{i});
        end
    end
end
fprintf('\nPolicy note: use u_{ts} (empirical) directly with a learned u_{scale}; this respects the measured NPI/vaccine trajectory and typically improves E & I fits and the parameter R^2s.\n');
fprintf('=== ANALYSIS COMPLETE ===\n');

%%%---PART F
%% Helper Functions Below  %%
%%% HELPER FUNCTION 1 %%%
function analyze_environmental_effects(beta_params, rho_params, eps_params, delta_params, u_scale, meteo_data, ~, time_lag, u_ts, bds)
    fprintf('\n=== ENVIRONMENTAL EFFECTS (7-DAY LAG) ===\n');
    env_factors = meteo_data(:,1:3); % normalized, lagged
    env_names = {'Temperature (lag)','Humidity (lag)','Wind (lag)'};

    % Multiplicative env effects
    beta_intr = (beta_params(1) * exp(meteo_data*beta_params(2:4)'));
    rho_env  =  rho_params(1)  * exp(meteo_data*rho_params(2:4)');
    eps_env  =  eps_params(1)  * exp(meteo_data*eps_params(2:4)');
    delta_env=  delta_params(1)* exp(meteo_data(:,1:3)*delta_params(2:4)');
    u_eff = min(max(u_scale .* u_ts, bds.u_min), bds.u_max);
    beta_env = (1 - u_eff) .* beta_intr;  
    param_env = [beta_env, rho_env, eps_env, delta_env];
    param_names = {'Beta','Rho','Epsilon','Delta'};

    fprintf('\nCorrelation (env vs params):\n');
    fprintf('%-10s%14s%14s%14s\n','Param',env_names{1},env_names{2},env_names{3});
    for i = 1:4
        fprintf('%-10s', param_names{i});
        for j = 1:3
            c = corr(env_factors(:,j), param_env(:,i), 'rows','complete');
            fprintf('%14.4f', c);
        end
        fprintf('\n');
    end

    fprintf('\nPrimary |exp-coeff| with %d-day lag:\n', time_lag);
    sens = [abs(beta_params(2:4)); abs(rho_params(2:4)); abs(eps_params(2:4)); abs(delta_params(2:4))];
    fprintf('%-10s%14s%14s%14s\n','Param','Temp','Humidity','Wind');
    for i = 1:4
        fprintf('%-10s%14.4f%14.4f%14.4f\n', param_names{i}, sens(i,1), sens(i,2), sens(i,3));
    end
end
%%% HELPER FUNCTION 2 %%%
function [cv_errors, cv_r2] = perform_cross_validation( ...
        meteo_raw, observed_data, alpha, k_folds, lb, ub, ...
        initial_conditions, ~, bds, min_train, gap, u_full)

    fprintf('\n=== %d-FOLD CROSS-VALIDATION (time-blocked; train-only z-score; uses u_{ts}) ===\n', k_folds);

    n = size(observed_data,1);
    if nargin < 12 || isempty(u_full),    u_full = zeros(n,1); end
    if nargin < 11 || isempty(gap),       gap    = 0;          end
    if nargin < 10 || isempty(min_train), min_train = max(20, ceil(0.20*n)); end

    cv_errors = zeros(k_folds,1);
    cv_r2     = zeros(k_folds,1);

    % Define test blocks 
    if min_train >= n-5
        warning('min_train too large relative to series length; reducing.');
        min_train = max(10, floor(0.10*n));
    end
    edges = round(linspace(min_train+1, n+1, k_folds+1));

    usePar = ~isempty(gcp('nocreate'));

    for f = 1:k_folds
        test_start = edges(f);
        test_end   = edges(f+1)-1;
        test_idx   = test_start:test_end;

        % Train only on the past
        train_end  = max(test_start - 1 - gap, 1);
        train_idx  = 1:train_end;

        % Enforce minimum training history and a small test size
        if numel(train_idx) < min_train || numel(test_idx) < 5
            cv_errors(f) = inf; cv_r2(f) = -inf;
            fprintf('  Fold %d/%d... [insufficient data: train=%d, test=%d]\n', ...
                    f, k_folds, numel(train_idx), numel(test_idx));
            continue;
        end

        fprintf('  Fold %d/%d...', f, k_folds);

        % --- Fold-wise z-score from TRAIN only---
        train_raw = meteo_raw(train_idx, :);
        test_raw  = meteo_raw(test_idx,  :);

        mu  = mean(train_raw, 1, 'omitnan');
        sig = std(train_raw, 0, 1, 'omitnan');
        sig(~isfinite(sig) | sig == 0) = 1;

        train_m = (train_raw - mu) ./ sig;
        test_m  = (test_raw  - mu) ./ sig;

        % Observed normalized compartments
        train_o = observed_data(train_idx, :);
        test_o  = observed_data(test_idx,  :);

        % Time vectors 
        tr_t = (1:numel(train_idx))';
        te_t = (1:numel(test_idx))';

        % Align interventions
        train_u = u_full(train_idx);
        test_u  = u_full(test_idx);

         alpha_train = alpha(train_idx);
         alpha_test  = alpha(test_idx);

        % --- Objective WITHOUT parameter-trajectory term ---
        pso_opt = optimoptions('particleswarm', ...
            'Display','off', 'MaxIterations', 10, 'SwarmSize', 40, ...
            'UseParallel', usePar);

        cp_train = []; % no param-trajectory guidance inside CV training
        obj = @(x) seir_objective_function( ...
            x, train_m, train_o, alpha_train, tr_t, false, ...
            cp_train, initial_conditions, bds, train_u);

        try
            % Optimize on the training block
            [theta, ~] = particleswarm(obj, numel(lb), lb, ub, pso_opt);

            % Evaluate on the contiguous test block 
            [S,E,I,R] = simulate_seir_model(theta, test_m, alpha_test, te_t, ...
                                            initial_conditions, bds, test_u);
            pred = [S,E,I,R];  % R is r_c

            % Metrics
            cv_errors(f) = sqrt(mean((test_o(:) - pred(:)).^2));
            ss_tot = sum((test_o(:) - mean(test_o(:))).^2);
            ss_res = sum((test_o(:) - pred(:)).^2);
            cv_r2(f) = 1 - ss_res / max(ss_tot, eps);

            fprintf(' RMSE=%.4f, R^2=%.4f\n', cv_errors(f), cv_r2(f));
        catch ME
            cv_errors(f) = inf; cv_r2(f) = -inf;
            fprintf(' [failed: %s]\n', ME.message);
        end
    end
end

%%% HELPER FUNCTION 3 %%%
function [all_dates, median_SEIR, low_SEIR, high_SEIR, sim_SEIR_all] = generate_forecast(optimal_params, meteo_data, alpha, forecast_days, initial_conditions, dates, bds, n_ensembles, jitter_pct, extend_mode, u_ts)
    if nargin < 9 || isempty(jitter_pct), jitter_pct = 0.10; end
    if nargin < 10 || isempty(extend_mode), extend_mode = 'persistence'; end

    rng(42,'twister');
    n_days = size(meteo_data,1); n_all = n_days + forecast_days; F = size(meteo_data,2);
    extended_meteo = zeros(n_all, F); extended_meteo(1:n_days,:) = meteo_data;

    switch lower(extend_mode)
        case 'trend'
            for f = 1:F
                recent = meteo_data(max(1,n_days-29):n_days, f);
                slope = (recent(end) - recent(1)) / max(1, numel(recent)-1);
                for j = 1:forecast_days
                    extended_meteo(n_days+j,f) = meteo_data(end,f) + slope*j;
                end
            end
        otherwise
            extended_meteo(n_days+1:end,:) = meteo_data(end,:);
    end

    % Extend u_ts by persistence for forecasting
    extended_u = [u_ts; repmat(u_ts(end), forecast_days, 1)];

    tspan = (1:n_all)';
    last_date = dates(end);
    forecast_dates = last_date + days(1:forecast_days);
    all_dates = [dates; forecast_dates(:)];
    extended_alpha = [alpha; repmat(alpha(end), forecast_days, 1)];

    % Build jitter bounds consistent with main lb/ub (18 params)
    coef_low  = -0.90; coef_high = 0.90;
    dcoef_low = -1e-6;  dcoef_high = 1e-6;
    lb = [bds.b_min, coef_low*ones(1,3), ...
          bds.r_min, coef_low*ones(1,3), ...
          bds.e_min, coef_low*ones(1,3), ...
          bds.d_min, dcoef_low*ones(1,3), ...
          bds.u_min, 0];
    ub = [bds.b_max, coef_high*ones(1,3), ...
          bds.r_max, coef_high*ones(1,3), ...
          bds.e_max, coef_high*ones(1,3), ...
          bds.d_max, dcoef_high*ones(1,3), ...
          bds.u_max, 0];

    P = numel(optimal_params);
    sim_SEIR_all = cell(n_ensembles,1);

    [S0,E0,I0,R0] = simulate_seir_model(optimal_params, extended_meteo, extended_alpha, tspan, initial_conditions, bds, extended_u);
    baseline = [S0,E0,I0,R0];
    sim_SEIR_all{1} = baseline;

    for k = 2:n_ensembles
        theta = optimal_params;
        for p = 1:min(P, numel(lb))
            theta(p) = theta(p) * (1 + jitter_pct*randn);
            theta(p) = min(max(theta(p), lb(p)), ub(p));
        end
        try
            [S,E,I,R] = simulate_seir_model(theta, extended_meteo, extended_alpha, tspan, initial_conditions, bds, extended_u);
            sim_SEIR_all{k} = [S,E,I,R];
        catch
            sim_SEIR_all{k} = baseline;
        end
    end

    S_mat = cat(3, sim_SEIR_all{:}); S_stack = squeeze(S_mat(:,1,:));
    E_stack = squeeze(S_mat(:,2,:)); I_stack = squeeze(S_mat(:,3,:)); R_stack = squeeze(S_mat(:,4,:));

    median_S = median(S_stack,2,'omitnan'); lo_S = quantile(S_stack,0.025,2); hi_S = quantile(S_stack,0.975,2);
    median_E = median(E_stack,2,'omitnan'); lo_E = quantile(E_stack,0.025,2); hi_E = quantile(E_stack,0.975,2);
    median_I = median(I_stack,2,'omitnan'); lo_I = quantile(I_stack,0.025,2); hi_I = quantile(I_stack,0.975,2);
    median_R = median(R_stack,2,'omitnan'); lo_R = quantile(R_stack,0.025,2); hi_R = quantile(R_stack,0.975,2);

    median_SEIR = [median_S, median_E, median_I, median_R];
    low_SEIR    = [lo_S,     lo_E,     lo_I,     lo_R];
    high_SEIR   = [hi_S,     hi_E,     hi_I,     hi_R];
end
%%% HELPER FUNCTION 4 %%%
function [rmse, mae, r2] = calculate_goodness_of_fit(observed, modeled)
    rmse = sqrt(mean((observed - modeled).^2, 1, 'omitnan'));
    mae  = mean(abs(observed - modeled), 1, 'omitnan');
    ss_res = sum((observed - modeled).^2, 1, 'omitnan');
    ss_tot = sum((observed - mean(observed, 1, 'omitnan')).^2, 1, 'omitnan');
    r2 = 1 - ss_res ./ max(ss_tot, eps);
    r2(~isfinite(r2)) = 0;
end
%%% HELPER FUNCTION 5 %%%
function [S, E, I, R, u_eff] = simulate_seir_model(params, meteo_data, alpha, ...
                                                   tspan, initial_conditions, bds, ...
                                                   u_series)
% SIMULATE_SEIR_MODEL (4-state, normalized)

    % ---- unpack params
    beta_params  = params( 1: 4);
    rho_params   = params( 5: 8);
    eps_params   = params( 9:12);
    delta_params = params(13:16);
    u_scale      = params(17);

    % ---- guards / defaults
    n = size(meteo_data,1);
    if nargin < 7 || isempty(u_series),  u_series  = zeros(n,1); end

    % default bounds for u if absent
    if ~isfield(bds,'u_min') || isempty(bds.u_min), bds.u_min = 0.05; end
    if ~isfield(bds,'u_max') || isempty(bds.u_max), bds.u_max = 0.95; end

    % ---- time-varying rates (log-linear meteorology effects)
    beta_t  = beta_params(1)  * exp(meteo_data * beta_params(2:4)');
    rho_t   = rho_params(1)   * exp(meteo_data * rho_params(2:4)');
    eps_t   = eps_params(1)   * exp(meteo_data * eps_params(2:4)');
    delta_t = delta_params(1) * exp(meteo_data * delta_params(2:4)');

    % clamp & repair 
    safebound = @(x,lo,hi) min(max(fillmissing(fillmissing(x,'previous'),'next'),lo),hi);
    beta_t  = safebound(beta_t,  bds.b_min, bds.b_max);
    rho_t   = safebound(rho_t,   bds.r_min, bds.r_max);
    eps_t   = safebound(eps_t,   bds.e_min, bds.e_max);
    delta_t = safebound(delta_t, bds.d_min, bds.d_max);

    % ---- interventions (scaled & clamped)
    u_eff = u_scale .* u_series(:);
    u_eff = min(max(u_eff, bds.u_min), bds.u_max);

    % Ensure alpha matches tspan length
    n_tspan = numel(tspan);
    n_alpha = numel(alpha);
    
    if isscalar(alpha)
        alpha = repmat(alpha, n_tspan, 1);
    elseif n_alpha == n_tspan
        alpha = alpha(:);   
    elseif n_alpha < n_tspan
        alpha_extended = [alpha(:); repmat(alpha(end), n_tspan - n_alpha, 1)];
        alpha = alpha_extended;
    else
        alpha = alpha(1:n_tspan);
    end

    % ---- initial conditions (normalized)
    y0 = initial_conditions(:)';           % [S0,E0,I0,R0] with R ≡ r_c
    if ~isfinite(sum(y0)) || sum(y0) <= 0, y0 = [0.99, 0.005, 0.005, 0]; end
    y0 = y0 ./ sum(y0);

    % ---- dimension checks
    need = [n_tspan, size(beta_t,1), size(rho_t,1), size(eps_t,1), ...
            size(delta_t,1), numel(u_eff), numel(alpha)];
    if any(need ~= need(1))
        error('Length mismatch: t=%d, β=%d, ρ=%d, ε=%d, δ=%d, u=%d, α=%d', need);
    end

    % ---- ODE solve
    opts = odeset('RelTol',1e-6,'AbsTol',1e-9,'MaxStep',1);
    rhs  = @(t,y) seir_rhs_4state(t, y, tspan, beta_t, rho_t, eps_t, delta_t, alpha, u_eff);

    try
        [~, Y] = ode15s(rhs, tspan, y0, opts);
        S = Y(:,1); E = Y(:,2); I = Y(:,3); R = Y(:,4);   % R ≡ r_c
    catch ME
        warning('SEIR:SolverFailed','SEIR solver failed: %s', ME.message);
        nd = numel(tspan); S=nan(nd,1); E=nan(nd,1); I=nan(nd,1); R=nan(nd,1);
    end
end

%%% HELPER FUNCTION 6 %%%
function dydt = seir_rhs_4state(t, y, tgrid, beta_t, rho_t, eps_t, delta_t, alpha, u_t)
    % Interpolate time-varying inputs at time t
    b  = interp1(tgrid, beta_t,  t, 'pchip', 'extrap');
    r  = interp1(tgrid, rho_t,   t, 'pchip', 'extrap');
    e  = interp1(tgrid, eps_t,   t, 'pchip', 'extrap');
    d  = interp1(tgrid, delta_t, t, 'pchip', 'extrap');
    u  = interp1(tgrid, u_t,     t, 'pchip', 'extrap');
    a  = interp1(tgrid, alpha,   t, 'pchip', 'extrap');

    % States 
    S = y(1); E = y(2); I = y(3); R = y(4);

    % Effective transmission
    beff = (1 - u) * b;

    % Normalized SEIR 
    dS = a*(1 - S) - beff*S*I + d*I*S;
    dE = beff*S*I - (e + a)*E + d*I*E;
    dI = e*E - (r + d + a)*I - d*I^2;
    dR = r*I - (a - d*I)*R;     

    dydt = [dS; dE; dI; dR];
end
%%% HELPER FUNCTION 7 %%%
function err = seir_objective_function(params, meteo_data, observed_data, ...
                                       alpha, tspan, verbose, ...
                                       computed_param, init_cond, bds, ...
                                       u_series)
% Objective for PSO (consistent with normalized model equations):
% - Simulate 4-state normalized SEIR 
% - Robust Huber state loss 
% - Optional parameter-trajectory penalty (since computed_param provided)
% - Smoothness penalty + weight decay

    % ----- defaults / guards
    if nargin < 9 || isempty(bds)
      error('Missing required argument: bds (bounds struct must be provided).'); end
    if nargin < 8  || isempty(init_cond),      init_cond      = observed_data(1,:); end
    if nargin < 7  || isempty(computed_param), computed_param = [];                 end
    if nargin < 10 || isempty(u_series),       u_series       = zeros(size(meteo_data,1),1); end

    try
        % ----- simulate model (Helper 5: δ·i; r ≡ r_c)
        init = init_cond(:)';   % [S0,E0,I0,R0] 
        [S,E,I,R] = simulate_seir_model(params, meteo_data, alpha, ...
                                        tspan, init, bds, u_series);
        if any(isnan(S)) || numel(S) ~= size(observed_data,1)
            err = 1e6; return;
        end
                model = [S,E,I,R];     

        % -----  state loss (Huber) with stronger focus on I(t) and outbreak peaks -----
        % 1.) Residuals
        res = (observed_data - model);   % [T x 4], columns = [S,E,I,R]

        % 2) State-level weights (relative importance of compartments)
        %    [S,   E,    I,    R]
        w_state = [0.05, 0.40, 0.50, 0.05];

        % 3) Time-level weights (higher during outbreak peak)
        I_obs   = observed_data(:,3);                % Infectious column
        I_max   = max(I_obs + eps);                  % Avoid division by zero
        rel_I   = I_obs ./ I_max;                    % Normalize to [0,1]
        time_w  = 1 + 4 * rel_I;                     % Scale 

        % 4) Combine state and time weights
        W_state = repmat(w_state, size(res,1), 1);  
        W_time  = repmat(time_w, 1, 4);              
        W_full  = W_state .* W_time;                 

        % 5) Huber threshold (robust loss)
        deltaH = 4 * std(res(:), 'omitnan');
        if ~isfinite(deltaH) || deltaH == 0
            deltaH = 1e-3;
        end

        % 6) Huber loss computation
        absr  = abs(res);
        huber = (absr <= deltaH) .* (0.5 .* res.^2) + ...
                (absr >  deltaH) .* (deltaH .* (absr - 0.5 * deltaH));

        % 7) Weighted mean root error across all states and time points
        state_err = sqrt( mean(huber .* W_full, 'all', 'omitnan') );

        % ----- parameter-trajectory penalty 
        % computed_param columns ( provided): [beta_eff, eps, rho, u_ts, delta_t]
        lambda_params = 0.05;
        cp = computed_param;

        % Reconstruct param trajectories
        beta_params  = params( 1: 4);
        rho_params   = params( 5: 8);
        eps_params   = params( 9:12);
        delta_params = params(13:16);
        u_scale      = params(17);

        % log-link meteo effects 
        beta_intr = beta_params(1)  * exp(meteo_data * beta_params(2:4)');
        rho_env   = rho_params(1)   * exp(meteo_data * rho_params(2:4)');
        eps_env   = eps_params(1)   * exp(meteo_data * eps_params(2:4)');
        delta_env = delta_params(1) * exp(meteo_data * delta_params(2:4)');

        % clamp to biological bounds
        beta_intr = max(min(beta_intr, bds.b_max), bds.b_min);
        rho_env   = max(min(rho_env,   bds.r_max), bds.r_min);
        eps_env   = max(min(eps_env,   bds.e_max), bds.e_min);
        delta_env = max(min(delta_env, bds.d_max), bds.d_min);

        % effective intervention & beta
        u_eff    = min(max(u_scale .* u_series(:), bds.u_min), bds.u_max);
        beta_eff = (1 - u_eff) .* beta_intr;

        if ~isempty(cp)
            T = min(size(cp,1), numel(beta_eff));
            Pobs = cp(1:T, :);
            Pmod = [beta_eff(1:T), eps_env(1:T), rho_env(1:T), u_eff(1:T), delta_env(1:T)];

            pres = Pobs - Pmod;
            wP = [1.0, 0.8, 0.8, 1.0, 0];          % no weight on delta
            wP = repmat(wP, T, 1);

            dH2 = 3*std(pres(:),'omitnan');
            if ~isfinite(dH2) || dH2==0, dH2 = 1e-3; end

            ap  = abs(pres);
            huber_p   = (ap<=dH2).*0.5.*pres.^2 + (ap>dH2).*(dH2*(ap - 0.5*dH2));
            param_err = sqrt(mean((huber_p .* wP), 'all', 'omitnan'));
        else
            param_err = 0;
        end

        % ----- smoothness penalty on rate paths 
        lambda_smooth = 0.002;     %  0.001–0.03
        sm = @(x) mean(diff(x).^2,'omitnan');
        smooth_pen = sm(beta_eff) + sm(rho_env) + sm(eps_env) + 0.2*sm(delta_env);

        % ----- weight decay on params
        reg = 0.01 * sqrt(mean(params.^2, 'omitnan'));

        err = state_err + lambda_params*param_err + lambda_smooth*smooth_pen + reg;
        if ~isfinite(err), err = 1e6; end

        if verbose
            fprintf('Objective=%.6f  (state=%.6f, param=%.6f, smooth=%.6f, reg=%.6f)\n', ...
                err, state_err, lambda_params*param_err, lambda_smooth*smooth_pen, reg);
        end

    catch ME
        warning('Objective failed: %s', getReport(ME,'basic','hyperlinks','off'));
        err = 1e6;
    end
end

%%% HELPER FUNCTION 8 %%%
function varargout = replaceBadValues(windowSize, varargin)
    % Replace Inf/NaN values with moving median + median filter; clamp to finite
    n = numel(varargin);
    varargout = cell(1,n);

    for k = 1:n
        x = varargin{k};
        x(~isfinite(x)) = NaN;

        % Fill missing with moving median
        try
            x = fillmissing(x, 'movmedian', max(3, windowSize));
        catch
            %
            x = fillmissing(x, 'linear');
        end

        % Additional smoothing via median 
        if numel(x) >= windowSize && mod(windowSize,2)==1
            try
                x = medfilt1(x, windowSize);
            catch
                x = movmean(x, windowSize, 'omitnan');
            end
        else
            x = movmean(x, max(3, floor(windowSize/2)*2+1), 'omitnan');
        end

        % Final clean
        x(~isfinite(x)) = nan;
        x = fillmissing(x, 'nearest');
        varargout{k} = x;
    end
end

%%% HELPER FUNCTION 9 %%% 
function shaded_band_eps(ax, x, ylo, ymed, yhi, rgb, title_str, ylab_sym, mix)
    if nargin < 9, mix = 0.2; end
    hold(ax,'on');
    band = 1 - mix*(1 - rgb);                  
    x = x(:); ylo = ylo(:); ymed = ymed(:); yhi = yhi(:);
    fill(ax, [x; flipud(x)], [ylo; flipud(yhi)], band, 'EdgeColor','none');
    plot(ax, x, ymed, 'Color', rgb, 'LineWidth', 1.8);
    grid(ax,'on'); box(ax,'off');
    ylabel(ax, ['$' ylab_sym '$'], 'Interpreter','latex');
    title(ax, sprintf('%s (95\\%% band)', title_str), 'Interpreter','latex');
    set(ax,'FontSize',9,'LineWidth',0.8);
end
