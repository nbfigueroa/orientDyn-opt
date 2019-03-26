%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Demo Script for Couple Orientation Dynamics Learning introduced in :    %
% ........                                                                %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright (C) 2018 Learning Algorithms and Systems Laboratory,          %
% EPFL, Switzerland                                                       %
% Author:  Nadia Figueroa                                                 % 
% email:   nadia.figueroafernandez@epfl.ch                                %
% website: http://lasa.epfl.ch                                            %
%                                                                         %
% This work was supported by the EU project Cogimon H2020-ICT-23-2014.    %
%                                                                         %
% Permission is granted to copy, distribute, and/or modify this program   %
% under the terms of the GNU General Public License, version 2 or any     %
% later version published by the Free Software Foundation.                %
%                                                                         %
% This program is distributed in the hope that it will be useful, but     %
% WITHOUT ANY WARRANTY; without even the implied warranty of              %
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General%
% Public License for more details                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  Demo Script for Learning Couple Orientation Dynamics from Demos %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%    Step 1: Load 6DOF Dataset     %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all; clc; close all;
pkg_dir         = '/home/nbfigueroa/Dropbox/PhD_papers/CoRL-2018-Extension/code/orientDS-opt/';
%%%%%%%%%%%%%%%%%%% Choose a Dataset %%%%%%%%%%%%%%%%%%%%%                     
choosen_dataset = 1; % 1: Demos from Gazebo Simulations
                     % 2: Demos from Real iCub 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub_sample      = 5; % To sub-sample trajectories                   
[Data, Data_sh, att, x0_all, ... 
dt, data, qdata, Hdata, Data_QX] = load_6DOF_datasets(pkg_dir, choosen_dataset, sub_sample);

%%%%% Plot Position/Velocitty Trajectories %%%%%
vel_samples = 80; vel_size = 0.75; 
[h_data, h_att, h_vel] = plot_reference_trajectories_DS(Data, att, vel_samples, vel_size);
axis equal;
limits = axis;

%%%%% Draw Obstacle %%%%%
rectangle('Position',[-1 1 6 1], 'FaceColor',[.85 .85 .85]); hold on;
h_att = scatter(att(1),att(2), 150, [0 0 0],'d','Linewidth',2); hold on;

%%%%% Plot 6DoF trajectories %%%%%
ori_samples = 300; frame_size = 0.25; box_size = [0.45 0.15 0.05];
plot_6DOF_reference_trajectories(Hdata, ori_samples, frame_size, box_size, 'r'); 

%%%%% Plot Quaternion trajectories %%%%%
title_name = 'Quaternion Trajectories from Gazebo Demonstrations ';
[h] = plot_Quaternion_trajectories(Data_QX, title_name);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%    Step 2: Learn Joint Distr. of Quats+Pos as GMM of p(quat,\xi)     %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Choose type of GMM to learn for p(quat,\xi)
quat_gmm_type = 1; % 0: Standard (Euclidean) GMM
                   % 1: Riemannian GMM

switch quat_gmm_type
   case 0       
       %%%%%%%%%%%%%%%% Standard GMM Estimation Algorithm %%%%%%%%%%%%%%%
       % 0: Physically-Consistent Non-Parametric (Collapsed Gibbs Sampler)
       % 1: GMM-EM Model Selection via BIC
       % 2: CRP-GMM (Collapsed Gibbs Sampler)
       est_options = [];
       est_options.type             = 1;   % GMM Estimation Alorithm Type
       est_options.maxK             = 20;  % Maximum Gaussians for Type 1
       est_options.fixed_K          = [];  % Fix K and estimate with EM for Type 1
       est_options.samplerIter      = 50;  % Maximum Sampler Iterations
       est_options.do_plots         = 1;   % Plot Estimation Statistics
       est_options.sub_sample       = 5;   % Size of sub-sampling of trajectories
       % 1/2 for 2D datasets, >2/3 for real
       % Metric Hyper-parameters
       est_options.estimate_l       = 1;   % '0/1' Estimate the lengthscale, if set to 1
       est_options.l_sensitivity    = 2;   % lengthscale sensitivity [1-10->>100]
       est_options.length_scale     = [];  % if estimate_l=0 you can define your own

       % Fit GMM to Trajectory Data
       [Priors, Mu, Sigma] = fit_gmm(Data_QX, [], est_options);

       % Generate GMM data structure for Mapping Function
       clear qx_gmm; qx_gmm.Mu = Mu; qx_gmm.Sigma = Sigma; qx_gmm.Priors = Priors;
       qx_gmr          = @(x) gmr_regressor(qx_gmm.Priors, qx_gmm.Mu, qx_gmm.Sigma,x, 5:6, 1:4);
       regress_approach = 'standard GMM';
    case 1       
       %%%%%%%%%%%%%%%% Riemannian GMM Estimation Algorithm %%%%%%%%%%%%%%%
       regress_approach = 'Riemannian GMM';
       
       % Parameters for Riemannian GMM        
       nbData    = 50; %Number of datapoints
       nbSamples = 4; %Number of demonstrations
       nbIter    = 10; %Number of iteration for the Gauss Newton algorithm
       nbIterEM  = 10; %Number of iteration for the EM algorithm
       
       clear qx_rgmm
       qx_rgmm.nbStates = 6; %Number of states in the GMM
       qx_rgmm.dt       = dt; %Time step duration
       
       qx_rgmm.nbVar    = 5; %Dimension of the tangent space (incl. time)
       qx_rgmm.nbVarMan = 6; %Dimension of the manifold (incl. time)
       
       qx_rgmm.params_diagRegFact = 1E-4; %Regularization of covariance       
       
       % My data
       uOut = Data_QX(1:4,:);
       uIn  = Data_QX(5:6,:);       
       
       % Convert to there format
       xOut = expmap(uOut, [0; 1; 0; 0]);
       xIn = uIn;
       u = [uIn; uOut];
       x = [xIn; xOut];
       
       % Init model with standard-GMM
       est_options = [];
       est_options.type             = 1;   % GMM Estimation Alorithm Type
       est_options.maxK             = 20;  % Maximum Gaussians for Type 1
       est_options.fixed_K          = qx_rgmm.nbStates;  % Fix K and estimate with EM for Type 1
       est_options.samplerIter      = 50;  % Maximum Sampler Iterations
       est_options.do_plots         = 1;   % Plot Estimation Statistics
       est_options.sub_sample       = 5;   % Size of sub-sampling of trajectories
       [Priors0, Mu0, Sigma0] = fit_gmm(u, [], est_options);       
       qx_rgmm.Priors = Priors0; qx_rgmm.Mu = Mu0; qx_rgmm.Sigma = Sigma0;
       
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %     Learn Riemannian GMM parameters   %
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       
       qx_rgmm.MuMan = [qx_rgmm.Mu(1:2,:); expmap(qx_rgmm.Mu(3:end,:), [0; 1; 0; 0])]; %Center on the manifold %Data(1,nbData/2)
       qx_rgmm.Mu = zeros(qx_rgmm.nbVar,qx_rgmm.nbStates); %Center in the tangent plane at point MuMan of the manifold
       
       uTmp = zeros(qx_rgmm.nbVar,length(u),qx_rgmm.nbStates);
       for nb=1:nbIterEM
           %E-step
           L = zeros(qx_rgmm.nbStates,size(x,2));
           for i=1:qx_rgmm.nbStates
               L(i,:) = qx_rgmm.Priors(i) * gaussPDF([xIn-qx_rgmm.MuMan(1:2,i); logmap(xOut, qx_rgmm.MuMan(3:end,i))], qx_rgmm.Mu(:,i), qx_rgmm.Sigma(:,:,i));
           end
           GAMMA = L ./ repmat(sum(L,1)+realmin, qx_rgmm.nbStates, 1);
           GAMMA2 = GAMMA ./ repmat(sum(GAMMA,2),1,length(u));
           %M-step
           for i=1:qx_rgmm.nbStates
               %Update Priors
               qx_rgmm.Priors(i) = sum(GAMMA(i,:)) / (length(u));
               %Update MuMan
               for n=1:nbIter
                   uTmp(:,:,i) = [xIn-qx_rgmm.MuMan(1:2,i); logmap(xOut, qx_rgmm.MuMan(3:end,i))];
                   qx_rgmm.MuMan(:,i) = [(qx_rgmm.MuMan(1:2,i)+uTmp(1:2,:,i))*GAMMA2(i,:)'; expmap(uTmp(3:end,:,i)*GAMMA2(i,:)', qx_rgmm.MuMan(3:end,i))];
               end
               %Update Sigma
               qx_rgmm.Sigma(:,:,i) = uTmp(:,:,i) * diag(GAMMA2(i,:)) * uTmp(:,:,i)' + eye(size(u,1)) * qx_rgmm.params_diagRegFact;
           end
       end
       
       %Eigendecomposition of Sigma
       for i=1:qx_rgmm.nbStates
           [V,D] = eig(qx_rgmm.Sigma(:,:,i));
           U0(:,:,i) = V * D.^.5;
       end
       
       
       
end

%% Compute quat_dist error on training data
mean_quat_error = mean(quat_error(qx_gmr, Data_QX));
fprintf('Standard GMR with got quat_dist on training set: %d \n', mean_quat_error);

% Compare Quaternions from Demonstration vs Regressor
h_quat = visualizeEstimatedQuaternions(Data_QX, qx_gmr, regress_approach);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%    Step 3: Simulate 6DOF learned motions    %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ==> Assume an lpv-ds model was learned,  load it <== %%
DS_name = 'icub-Object-DS-1';
matfile = strcat(pkg_dir,'/models/', DS_name,'.mat');
load(matfile)
if constr_type == 1
    ds_lpv = @(x) lpv_ds(x-repmat(att,[1 size(x,2)]), ds_gmm, A_g, b_g);
else
    ds_lpv = @(x) lpv_ds(x, ds_gmm, A_k, b_k);
end

% Extract Position and Velocities
M          = size(Data,1)/2;    
Xi_ref     = Data(1:M,:);
Xi_dot_ref = Data(M+1:end,:); 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  Visualize DS with Regressed Orientation on Demonstration Data %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Plot DS Vector Field %%%%%
ds_plot_options = [];
x0_all_new  = [x0_all + [0.25 0.25]'  x0_all-[-0.25 0.75]'];
limits_new  = limits + [0 1.5 0 0];
ds_plot_options.sim_traj  = 1;        
ds_plot_options.x0_all    = x0_all_new;       
ds_plot_options.limits    = limits_new;
ds_plot_options.init_type = 'cube';       
ds_plot_options.nb_points = 30;           
ds_plot_options.plot_vol  = 1;            
[hd, hs, hr, x_sim] = visualizeEstimatedDS(Xi_ref, ds_lpv, ds_plot_options);
rectangle('Position',[-1 1 6 1], 'FaceColor',[.85 .85 .85]); hold on;
h_att = scatter(0,3, 150, [0 0 0],'d','Linewidth',2); hold on;

%% %%% Plot 6DoF trajectories of Training Data %%%%%
demo_quats = qx_gmr(Data_QX(5:6,:));
demo_x     = Data_QX(5:6,:)+att;
demo_H     = get_Hdata(demo_quats, demo_x);
demo_Hdata{1} = demo_H; 
ori_samples = 50; frame_size = 0.25; box_size = [0.45 0.15 0.05];
plot_6DOF_reference_trajectories(demo_Hdata, ori_samples, frame_size, box_size, 'r'); 

%% %%% Plot 6DoF trajectories of Simulations %%%%%
x_sim_vect = reshape(x_sim, [2 size(x_sim,2)*size(x_sim,3)]);
x_sim_vect = x_sim_vect(:,1:5:end);
demo_quats = qx_gmr(x_sim_vect - att);
demo_H     = get_Hdata(demo_quats, x_sim_vect);
demo_Hdata{1} = demo_H; 

%%%%% Plot 6DoF trajectories %%%%%
ori_samples = 50; frame_size = 0.25; box_size = [0.45 0.15 0.05];
plot_6DOF_reference_trajectories(demo_Hdata, ori_samples, frame_size, box_size, 'k'); 
title('Learned 6DoF Motion (Pos. LPV-DS + Quat-GMR)', 'Interpreter','LaTex','FontSize',20)
