%% Polar (Arctic or Antarctic) Iceberg Meltrate Estimation Pipeline
% Ellyn Enderlin (ellynenderlin@boisestate.edu)
% Last edited: 09 Nov. 2022
% 
% This file serves as a wrapper for the iceberg melt estimation codes.
% Run the following codes in order to estimate iceberg melt rates 
% from digital elevation models.
%
% Before trying to use this pipeline, you must have the following
% independent data downloaded for your region (Greenland or Antarctica):
% 1) RACMO surface mass balance model ouputs: daily temperature, runoff, &
% surface mass balance ideally for the full time period (but the code will
% work, interpolating to fill time gaps, if data available for only part of the time period)
% NOTE: If focusing on Antarctica, both the 27 km-resolution RACMO outputs
% for the full continent and the 5.5 km-resolution RACMO outputs for the
% Antarctic Peninsula can be used together (code auto-selects by coordinates).
% 2) Polar Stereo EPSG .prj text files: copy proj4 text description of EPSG
% projection parameters from https://www.spatialreference.org/ 
% and paste into a plain-text file called EPSG3031.prj for Antarctica or EPSG3413.prg for Greenland
% 3) (for Antarctica only) Firn Density Model outputs from Ligtenberg et
% al., 2011 (doi:10.5194/tc-5-809-2011): firn density and air content data
% produced in conjunction with RACMO datasets necessary for estimation of
% iceberg density 

%% specify site- and directory-specific information

clearvars; close all;

% ----------MODIFY VARIABLES BELOW----------
% site name and region abbreviation used for file names
region_name = 'Edgeworth-LarsenA'; 
region_abbrev = 'LA';
% path to codes
dir_repo = '/Users/ellynenderlin/Research/NSF_Antarctic-Icebergs/iceberg-melt-code/'; %Github repo containing custom iceberg melt code
dir_code = '/Users/ellynenderlin/Research/miscellaneous/general-code/'; %directory containing miscellaneous codes
% path to DEM files in directory
dir_DEM = ['/Users/ellynenderlin/Research/NSF_Antarctic-Icebergs/iceberg-melt/',region_name,'/DEMs/'];
% path to outputs folder (where you would like all outputs saved)
dir_output = ['/Users/ellynenderlin/Research/NSF_Antarctic-Icebergs/iceberg-melt/',region_name,'/'];
% DEM time stamps (DEM1 = earlier, DEM2 = later) used in file names (YYYYMMDDhhmmss)
DEM1.time = '20191012101214'; DEM2.time = '20200927092713';

%----------Specify Region------------
answer = questdlg('Where are you working?',...
    'Iceberg Location','1) Greenland','2) Antarctica','1) Greenland');
switch answer
    case '1) Greenland'
        geography = 0;
    case '2) Antarctica'
        geography = 1;
end

% ----------INITIAL SET-UP----------
% General DEM filenames (no suffixes) - Ensure filenames match this format
DEM1.filename = [region_abbrev,'_',DEM1.time];
DEM2.filename = [region_abbrev,'_',DEM2.time];

% add paths to necessary functions and datasets
addpath(dir_repo);
addpath(dir_code);
addpath([dir_code,'RACMO2.3_Antarctica/']);

%decide if you want to estimate fjord surface elevation differences with the TMD tidal model (not recommended)
tidemodel_flag = 0; %specifies whether you want to attempt to correct sea level using a tidal model: 0 = no (default), 1 = yes
if tidemodel_flag == 1
    % path to TMD folder in directory
    dir_TMD = [dir_code,'TMD/']; %may need to modify this path from the default if using the tidal model
    addpath(dir_TMD); addpath([dir_TMD,'FUNCTIONS/']); 
end

%% 1. Convert DEMs & accompanying images to mat-files
cd_to_sitedir = ['cd ',dir_output]; eval(cd_to_sitedir);

% create matfiles from geotiffs for the earlier date DEM
[DEM1,IM1] = convert_ASP_tifs_to_matfiles(DEM1,dir_DEM,dir_output);
% Plot
figure(1); set(gcf,'position',[0 200 800 800]);
ax1 = subplot(2,2,1);  
    imagesc(ax1,IM1.x/10^3,IM1.y/10^3,IM1.z); axis xy equal; colormap gray;
    ax1.YLabel.String = 'Northing (km)'; ax1.FontSize = 14; title('DEM1');
ax3 = subplot(2,2,3);
    imagesc(ax3,DEM1.x/10^3,DEM1.y/10^3,DEM1.z); axis xy equal; colormap hot;
    ax3.YLabel.String = 'Northing (km)'; ax3.XLabel.String='Easting (km)'; ax3.FontSize = 14;

% create matfiles from geotiffs for the earlier date DEM
[DEM2,IM2] = convert_ASP_tifs_to_matfiles(DEM2,dir_DEM,dir_output);
% Plot
ax2 = subplot(2,2,2); 
    imagesc(ax2,IM2.x./10^3,IM2.y./10^3,IM2.z); axis xy equal; colormap gray;
    ax2.YLabel.String = 'Northing (km)'; ax2.FontSize = 14; title('DEM2'); 
ax4 = subplot(2,2,4); 
    imagesc(ax4, DEM2.x./10^3,DEM2.y./10^3,DEM2.z); axis xy equal; colormap hot;
    ax4.YLabel.String = 'Northing (km)'; ax4.XLabel.String='Easting (km)'; ax4.FontSize = 14;
    %colorbar;

clear ax*;

disp('Advance to the next step');
disp('------------------------');

%% 2. Vertically coregister DEMs to account for satellite uncertainty & tidal change between dates
cd_to_sitedir = ['cd ',dir_output]; eval(cd_to_sitedir);
close all;

% Option to reload MAT files from previous step if previously completed but
% variables are not in workspace
reload = input('Would you like to load DEM and IM variables from file (y/n)?','s');
if strcmp(reload,'y')
    DEM1 = load([dir_output,region_abbrev,'_',DEM1.time,'-DEM.mat']).DEM;
    IM1 = load([dir_output,region_abbrev,'_',DEM1.time,'-orthoimage.mat']).IM;
    DEM2 = load([dir_output,region_abbrev,'_',DEM2.time,'-DEM.mat']).DEM;
    IM2 = load([dir_output,region_abbrev,'_',DEM2.time,'-orthoimage.mat']).IM;
end
disp('Files loaded');
%coregister
if tidemodel_flag == 0
    [DEM1,DEM2] = coregister_iceberg_DEM_pairs(DEM1,DEM2,IM1,IM2,geography,region_abbrev,dir_output);
else
    [DEM1,DEM2] = coregister_iceberg_DEM_pairs(DEM1,DEM2,IM1,IM2,geography,region_abbrev,dir_output,dir_TMD);
end

%% 3. Identify and save iceberg coordinates
cd_to_sitedir = ['cd ',dir_output]; eval(cd_to_sitedir);
close all; 

%create a date-specific directory as necessary
if not(isfolder([dir_output,'/',DEM1.time,'-',DEM2.time,'/']))
    mkdir([dir_output,'/',DEM1.time,'-',DEM2.time,'/']) % make models folder if it doesn't exist
    disp('date-specific folder created.');
end

% Option to reload MAT files from previous step if previously completed but
% variables are not in workspace
reload = input('Would you like to load DEM and IM variables from file (y/n)?','s');
if strcmp(reload,'y')
    DEM1 = load([dir_output,region_abbrev,'_',DEM1.time,'-DEM.mat']).DEM;
    IM1 = load([dir_output,region_abbrev,'_',DEM1.time,'-orthoimage.mat']).IM;
    DEM2 = load([dir_output,region_abbrev,'_',DEM2.time,'-DEM.mat']).DEM;
    IM2 = load([dir_output,region_abbrev,'_',DEM2.time,'-orthoimage.mat']).IM;
    disp('files loaded');
end

[PSx_early,PSy_early,PSx_late,PSy_late] = track_icebergs(DEM1,DEM2,IM1,IM2,dir_output); 

%% 4. Extract elevation change, convert to volume change, then estimate melt rate
cd_to_sitedir = ['cd ',dir_output]; eval(cd_to_sitedir);
close all; 

% Select step to run in estimate_iceberg_meltrates function:
%   1 = Estimate elevation change for each iceberg
%   2 = UPDATE individual icebergs and/or remove icebergs with anomalous melt rate estimates
answer = questdlg('Calculating melt rates the first time or updating/removing iceberg data?',...
    'Melt Calculation Options','1) First time','2) Updating','3) Just checking plots','1) First time');
switch answer
    case '1) First time'
        option_no = 1;
    case '2) Updating'
        option_no = 2;
    case '3) Just checking plots'
        option_no = 3;
end
clear answer;

% Option to reload MAT files from previous step if previously completed but
% variables are not in workspace
answer = questdlg('Would you like to load DEM and IM variables from file?',...
    'DEM and Image Data Source','1) Yes: load them!','2) No: already in workspace','1) Yes: load them!');
switch answer
    case '1) Yes: load them!'
        DEM1 = load([dir_output,region_abbrev,'_',DEM1.time,'-DEM.mat']).DEM;
        IM1 = load([dir_output,region_abbrev,'_',DEM1.time,'-orthoimage.mat']).IM;
        DEM2 = load([dir_output,region_abbrev,'_',DEM2.time,'-DEM.mat']).DEM;
        IM2 = load([dir_output,region_abbrev,'_',DEM2.time,'-orthoimage.mat']).IM;
        disp('DEM and IM variables loaded');
    case '2) No: already in workspace'
        disp('no need to load!')
end
clear answer;

% estimate iceberg melt rates
[DEM1,DEM2] = estimate_iceberg_meltrates(DEM1,DEM2,IM1,IM2,dir_output,dir_code,geography,region_abbrev,region_name,option_no);


%% 5. (As needed) Remove icebergs with unfixable sea level corrections & wonky melt rates
cd_to_sitedir = ['cd ',dir_output]; eval(cd_to_sitedir);

%replace bad melt rate (dHdt) and area (TA) estimates with empty matrices
disp('Specify the icebergs to remove as "iceberg_refs=[A B C etc]; dbcont"');
keyboard
[SL] = remove_bad_iceberg_meltrates(DEM1,DEM2,region_abbrev,iceberg_refs,dir_output);

 disp(['Iceberg melt rate estimation complete for ',region_abbrev,' from ',num2str(DEM1.time(1:8)),'-',num2str(DEM2.time(1:8))]);
