% 事件触发一致性 + ASV 3DOF 动力学模型（固定时间外环-稳态增强版）
% 说明：
% 1) 外环采用固定时间项 + 线性阻尼项，抑制振荡：
%    u = -k0*z - k1*sig(z)^alpha - k2*sig(z)^beta, 0<alpha<1<beta
% 2) 触发机制采用“前疏后密”并加入滞回 + 动态最小间隔，减少触发抖动
% 3) 去除统计打印输出，仅保留必要曲线

clear all
close all
clc
clear ASV1_multi

%% 网络与初值
x=[-3 -2 0 2 -3 4];
L=[3 0 0 -1 -1 -1;
   -1 1 0 0 0 0;
   -1 -1 2 0 0 0;
   -1 0 0 1 0 0;
   0 0 0 -1 1 0;
   0 0 0 0 -1 1];

xhat = x;
N = 6;

%% 仿真参数
t = 10;
h = 0.01;
Ts = 0:h:t;
K = numel(Ts);

%% 外环固定时间一致性控制（稳态增强）
alpha_ft = 0.95;        % 0<alpha_ft<1（更接近线性，减小近零抖振）
beta_ft  = 1.10;        % beta_ft>1（进一步减弱大幅激励）
k0_ft = 1.05;           % 线性阻尼项（显著增强，提升收敛）
k1_ft = 0.16;           % 低阶幂项（适中）
k2_ft = 0.08;           % 高阶幂项（适中）
u_lim = 0.90;           % 外环速度参考限幅（保证收敛驱动力）

Tf_u = 0.20;            % 外环指令滤波时间常数
alpha_u = h/(Tf_u+h);
u_filt = zeros(1,N);
du_max = 0.035;         % 每步最大变化量（rate limit）

%% 触发参数（前疏后密 + 抗抖）
line_hi = 0.24;         % 初期阈值（高）
line_lo = 0.015;        % 后期阈值（提高，减少末段触发）
lambda_th = 0.30;       % 阈值衰减速率（更慢）

sigma_rel = 0.022;      % 相对项：th_i = sigma_rel*|x_i| + line(t)
eta_hys  = 0.45;        % 滞回比例（增大，减抖动）
z_dead_hi = 0.12;       % 初期死区（更大）
z_dead_lo = 0.03;       % 后期死区（适中，避免末段抖动）
lambda_z = 0.35;        % 死区收缩速率（更慢）

tau_min_hi = 0.24;      % 初期最小触发间隔（更大）
tau_min_lo = 0.05;      % 后期最小触发间隔（避免过密）
lambda_min = 0.22;      % 最小间隔收缩速率（更慢）

tau_max_hi = 1.00;      % 初期最大静默时间（很大：前期稀）
tau_max_lo = 0.08;      % 后期最大静默时间（适中：后期更密但不过密）
lambda_tau = 0.45;      % 最大静默时间收缩速率（更平缓）

last_trig = -1e6*ones(1,N);
armed = true(1,N);

%% ASV内环参数
k_u_track = 2.4;
k_r = 3.2;
k_psi = 2.2;
k_v = 0.8;

%% 数据存储
x1 = zeros(K,N);
x1hat = zeros(K,N);
E = zeros(K,N);
U = zeros(K,N);
line1 = zeros(K,1);
cons_err = zeros(K,1);

T_1=[];T_2=[];T_3=[];T_4=[];T_5=[];T_6=[];

% 每个智能体状态: [u, v, r, x_n, y_n, psi]
asv_state = zeros(N,6);
asv_state(:,4) = x.';

%% 主循环
for k = 1:K
    G = Ts(k);

    % 阈值：高->低
    line_1 = line_lo + (line_hi-line_lo)*exp(-lambda_th*G);
    line1(k) = line_1;

    % 动态最小间隔：大->小
    tau_min_t = tau_min_lo + (tau_min_hi-tau_min_lo)*exp(-lambda_min*G);
    N_min_t = max(1, ceil(tau_min_t/h));

    % 最大静默时间：大->小（前疏后密）
    tau_max_t = tau_max_lo + (tau_max_hi-tau_max_lo)*exp(-lambda_tau*G);
    N_max_t = max(N_min_t+1, ceil(tau_max_t/h));

    % 死区：大->小（前期抑制触发，后期放开）
    z_dead_t = z_dead_lo + (z_dead_hi-z_dead_lo)*exp(-lambda_z*G);

    % 一致性误差
    cons_err(k) = norm(L*x.',2);

    % 外环固定时间一致性控制（使用触发保持值 xhat）
    z = (L*xhat.').';
    u_raw = -k0_ft*z - k1_ft*sig_pow(z, alpha_ft) - k2_ft*sig_pow(z, beta_ft);
    u_cmd = u_lim*tanh(u_raw/u_lim);

    % 一阶滤波 + 斜率限制，抑制控制输入振荡
    u_tar = (1-alpha_u)*u_filt + alpha_u*u_cmd;
    du = u_tar - u_filt;
    du = min(max(du, -du_max), du_max);
    u_filt = u_filt + du;

    % ASV 3DOF 推进
    for i = 1:N
        u_ref = u_filt(i);

        m11_est = 25.8;
        m33_est = 2.76;
        tu_cmd = m11_est*k_u_track*(u_ref - asv_state(i,1));
        tr_cmd = m33_est*(-k_r*asv_state(i,3) - k_psi*asv_state(i,6) - k_v*asv_state(i,2));

        tau_i = [tu_cmd; tr_cmd];
        tau_w = [0;0;0];

        [x_next, ~, ~, ~] = ASV1_multi(i, asv_state(i,:).', tau_i, tau_w, h);
        asv_state(i,:) = x_next.';
        x(i) = asv_state(i,4);
    end

    % 采样误差（按更新后的 x 计算）
    e = xhat - x;
    E(k,:) = e;

    x1(k,:) = x;
    x1hat(k,:) = xhat;
    U(k,:) = u_filt;

    % 事件触发判据：误差触发 + 超时触发（滞回 + 死区）
    for i = 1:N
        dt = k - last_trig(i);
        th_i = sigma_rel*abs(x(i)) + line_1;

        if abs(e(i)) <= (1-eta_hys)*th_i
            armed(i) = true;
        end

        can_check = (dt >= N_min_t);
        near_consensus = abs(z(i)) <= z_dead_t;
        trig_by_err = can_check && armed(i) && (~near_consensus) && (abs(e(i)) >= th_i);
        trig_by_timeout = (dt >= N_max_t);
        trig_init = (k == 1);

        if trig_by_err || trig_by_timeout || trig_init
            xhat(i) = x(i);
            last_trig(i) = k;
            armed(i) = false;

            if i==1, T_1=[T_1;k]; end
            if i==2, T_2=[T_2;k]; end
            if i==3, T_3=[T_3;k]; end
            if i==4, T_4=[T_4;k]; end
            if i==5, T_5=[T_5;k]; end
            if i==6, T_6=[T_6;k]; end
        end
    end
end

%% 触发时刻映射
T1=h*T_1; T2=h*T_2; T3=h*T_3;
T4=h*T_4; T5=h*T_5; T6=h*T_6;
B1=ones(size(T_1,1),1);
B2=2*ones(size(T_2,1),1);
B3=3*ones(size(T_3,1),1);
B4=4*ones(size(T_4,1),1);
B5=5*ones(size(T_5,1),1);
B6=6*ones(size(T_6,1),1);

%% 绘图
figure(1)
plot(Ts,x1,'LineWidth',1);
xlabel('time(s)');ylabel({'positions of agents';'x_i'});
legend('Agent1','Agent2','Agent3','Agent4','Agent5','Agent6');
grid on

figure(2)
for i=1:6
    subplot(3,2,i);
    plot(Ts,abs(E(:,i)),'LineWidth',1); hold on
    plot(Ts,line1,'LineWidth',1);
    xlabel('time(s)');ylabel(['|e_',num2str(i),'|']);
    legend(['|e_',num2str(i),'|'],'threshold');
    grid on
end

figure(3)
stairs(Ts,U,'LineWidth',1);
xlabel('time(s)');ylabel('control input');
legend('Agent1','Agent2','Agent3','Agent4','Agent5','Agent6');
grid on

figure(4)
plot(T1,B1,'+r',T2,B2,'*b',T3,B3,'oy',T4,B4,'squarem',T5,B5,'diamondk',T6,B6,'^c');
xlabel('time(s)');ylabel('agent id');
title('Event-triggering instants');
grid on

figure(5)
plot(Ts,cons_err,'LineWidth',1.2);
xlabel('time(s)');ylabel('||Lx||_2');
title('Consensus error');
grid on


function y = sig_pow(s, p)
% y = sign(s).*|s|^p （逐元素）
y = sign(s).*(abs(s).^p);
end


function [x_next, tau_k, tau_j, out] = ASV1_multi(id, x0, tau, tau_w, ts)
%% 多智能体版本：每个 id 一套 persistent（避免多条船串状态）
persistent x_store tu1_store tr1_store printed_store
if isempty(x_store)
    x_store = {};
    tu1_store = [];
    tr1_store = [];
    printed_store = [];
end

if numel(x_store) < id || isempty(x_store{id}) || any(~isfinite(x_store{id}))
    x_store{id} = double(x0(:));
end
if numel(tu1_store) < id || ~isfinite(tu1_store(id)), tu1_store(id) = 0; end
if numel(tr1_store) < id || ~isfinite(tr1_store(id)), tr1_store(id) = 0; end
if numel(printed_store) < id, printed_store(id) = false; end

x = x_store{id};
tu1 = tu1_store(id);
tr1 = tr1_store(id);
printed_once = printed_store(id);

x0    = double(x0(:));
tau   = double(tau(:));
tau_w = double(tau_w(:));
ts    = double(ts);

tu_w = tau_w(1);
tv_w = tau_w(2);
tr_w = tau_w(3);

% 输入限幅
tu_max = 40; tr_max = 10.0;
tu = tau(1); tr = tau(2);
tu = min(max(tu, -tu_max), tu_max);
tr = min(max(tr, -tr_max), tr_max);

% 一阶执行器动态
T_act = 0.015;
tu1 = tu1 + ts*(tu - tu1)/T_act;
tr1 = tr1 + ts*(tr - tr1)/T_act;
tu1 = min(max(tu1, -tu_max), tu_max);
tr1 = min(max(tr1, -tr_max), tr_max);
tu = tu1;
tr = tr1;

% 参数（Table 2）
m = 23.8; Iz = 1.76; xg = 0.046;
Xdu = -2; Ydv = -10; Ndr = -1; Ydr = 0;
Xu = -0.7225; Xuu = -1.3274; Xuuu = -5.8664;
Yv = -0.8612; Yvv = -36.2823; Yrv = 2; Yr = 0.1079; Yvr = 1; Yrr = 3;
Nv = 0.1052; Nvv = 5.0437; Nrv = 5; Nr = 4; Nvr = 0.5; Nrr = 0.8;

m11 = m - Xdu;
m22 = m - Ydv;
m33 = Iz - Ndr;
m23 = m*xg - Ydr;
m32 = m23;

Mk_nom = [m11 0   0;
          0   m22 m23;
          0   m32 m33];

u    = double(x(1));
v    = double(x(2));
r    = double(x(3));
psin = double(x(6));

c13 = -(m22*v + m23*r);
c23 =  (m11*u);
Ck_nom_nu = [c13*r;
             c23*r;
            -c13*u - c23*v];

u2 = u*u;
d11 = -(Xu + Xuu*abs(u) + Xuuu*u2);
d22 = -(Yv + Yvv*abs(v) + Yrv*abs(r));
d23 = -(Yr + Yvr*abs(v) + Yrr*abs(r));
d32 = -(Nv + Nvv*abs(v) + Nrv*abs(r));
d33 = -(Nr + Nvr*abs(v) + Nrr*abs(r));
Dk_nom_nu = [d11*u;
             d22*v + d23*r;
             d32*v + d33*r];

F_DC = -(Ck_nom_nu + Dk_nom_nu);

pert = 0.0;
M_act    = (1+pert)*Mk_nom;
F_act_DC = (1+pert)*F_DC;

tau_k_act = [tu; 0; tr];
tau_w_act = [tu_w; tv_w; tr_w];

nu_dot = M_act \ (tau_k_act + tau_w_act + F_act_DC);

if ~printed_once
    printed_once = true;
end

out.M0 = Mk_nom;
out.F0 = F_DC;
nu_dot_nom  = Mk_nom \ (tau_k_act + F_DC);
Delta_true  = nu_dot - nu_dot_nom;
out.Omega_true = norm(Delta_true([1,3]),2);

R = [cos(psin) -sin(psin) 0;
     sin(psin)  cos(psin) 0;
     0          0         1];

x1 = [u; v; r];
x_dot = [nu_dot; R*x1];

x = x + ts*x_dot;
x(6) = mod(x(6) + pi, 2*pi) - pi;

if any(~isfinite(x))
    x = x0;
end

x_next = x;
tau_k  = [tu; tr];
tau_j  = nu_dot;

x_store{id} = x;
tu1_store(id) = tu1;
tr1_store(id) = tr1;
printed_store(id) = printed_once;
end
