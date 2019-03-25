%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%        Data Processing Script      %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all; clc; close all
pkg_dir         = '/home/nbfigueroa/Dropbox/PhD_papers/CoRL-2018/code/ds-opt/';
load(strcat(pkg_dir,'datasets/icub_gazebo_demos/raw_data'))

data = []; 
odata = [];
window_size = 151; crop_size = (window_size+1)/2; 
dt = mean(abs(diff(raw_data{1}(1,:))));

for i=1:length(raw_data)
    
        % Smooth position and compute velocities
        dx_nth = sgolay_time_derivatives(raw_data{i}(2:3,:)', dt, 2, 2, window_size);
        X     = dx_nth(:,:,1)';
        X_dot = dx_nth(:,:,2)';               
        data{i} = [X; X_dot];
        
        % Extract original orientation data
        theta_angles = raw_data{i}(4,crop_size:end-crop_size);
        odata{i} = theta_angles;
        
        % Compute rotation data in different forms
        R = zeros(3,3,length(theta_angles));
        H = zeros(4,4,length(theta_angles));
        for r=1:length(theta_angles)
            % Populate R matrix
            R(:,:,r)  = eul2rotm([theta_angles(r),0,0]');
            
            % Populate H matrix
            H(:,:,r)     = eye(4);
            H(1:3,1:3,r) = R(:,:,r);
            H(1:3,4,r)   = [data{i}(1:2,r); 0] ;
            
        end
        q = quaternion(R,1);
        Rdata{i} = R;
        Hdata{i} = H;
        qdata{i} = q;                
end

% Trajectories to use
left_traj = 0;
if ~left_traj
    data(4:end) = [];
    odata(4:end) = [];
    qdata(4:end) = [];
    Rdata(4:end) = [];
    Hdata(4:end) = [];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%     Sub-sample measurements and Process for Learning      %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub_sample = 5;
[Data, Data_sh, att, x0_all, dt, data, Hdata] = processDataStructureOrient(data, Hdata, sub_sample);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Visualize 2D reference trajectories %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Position/Velocity Trajectories
vel_samples = 80; vel_size = 0.75; 
[h_data, h_att, h_vel] = plot_reference_trajectories_DS(Data, att, vel_samples, vel_size);
axis equal

% Draw Obstacles
rectangle('Position',[-1 1 6 1], 'FaceColor',[.85 .85 .85]); hold on;
h_att = scatter(att(1),att(2), 150, [0 0 0],'d','Linewidth',2); hold on;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Visualize 6DoF data in 3d %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Extract Position and Velocities
M          = size(Data,1)/2;    
Xi_ref     = Data(1:M,:);
Xi_dot_ref = Data(M+1:end,:);   

% Make 3D
M = 3;
Xi_ref(M,:)     = 0;
Xi_dot_ref(M,:) = 0;
Data_xi = [Xi_ref; Xi_dot_ref];
att_xi = att; att_xi(M,1) = 0;

%%%%% Plot 3D Position/Velocity Trajectories %%%%%
vel_samples = 50; vel_size = 0.75; 
[h_data, h_att, h_vel] = plot_reference_trajectories_DS(Data_xi, att_xi, vel_samples, vel_size); 
hold on;

%%%%%% Plot Wall %%%%%%
cornerpoints = [-1 1 0;  5 1 0; 5 2 0; -1 2 0;
                -1 1 0.25;  5 1 0.25; 5 2 0.25; -1 2 0.25];            
plotminbox(cornerpoints,[0.5 0.5 0.5]); hold on;


%%%%% Plot 6DoF trajectories %%%%%
ori_samples = 300; frame_size = 0.25; box_size = [0.45 0.15 0.05];
plot_6DOF_reference_trajectories(Hdata, ori_samples, frame_size, box_size); 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   Playing around with quaternions   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure('Color',[1 1 1])
for i=1:length(qdata)   
    qData_ = qdata{i};
    qdata_shift = zeros(4,length(qData_ ));
    qdata_shift(1,:)   = qData_(4,:);
    qdata_shift(2:4,:) = qData_(1:3,:);
    plot(1:length(qdata_shift),qdata_shift(1,:),'r-.','LineWidth',2); hold on;
    plot(1:length(qdata_shift),qdata_shift(2,:),'g-.','LineWidth',2); hold on;
    plot(1:length(qdata_shift),qdata_shift(3,:),'b-.','LineWidth',2); hold on;
    plot(1:length(qdata_shift),qdata_shift(4,:),'m-.','LineWidth',2); hold on;
    legend({'$q_1$','$q_2$','$q_3$','$q_4$'},'Interpreter','LaTex', 'FontSize',14)
    xlabel('Time-stamp','Interpreter','LaTex', 'FontSize',14);
    ylabel('Quaternion','Interpreter','LaTex', 'FontSize',14);    
    grid on;
    axis tight;
end
title_name =strcat('Demonstration',{' '},num2str(demo_id));
title('Demonstrations from Gazebo','Interpreter','LaTex', 'FontSize',14);