%% Open user selected KML file
cd Route
[kmlFilename, kmlPath] = uigetfile('*.kml','Select the KML file for your route');
cd(kmlPath)
[lat1, lon1, z] = read_kml(kmlFilename);
clear kmlFilename kmlPath

%% Create distance vector and eliminate redundant positions
disp('*** Creating distance vector ***')

% get x and y position in meters, oriented from start to end along x axis
[x, y, transMatrix]     = reorientLatLon(lat1,lon1);
latMean = mean(lat1);

% get distance vector along original data and remove duplicates
[z_dist, ~, ~, remIdx]          = transDist2D(x, y);
lat1(remIdx) = [];
lon1(remIdx) = [];
x(remIdx)    = [];
y(remIdx)    = [];
z(remIdx)    = []; 
 
%% Decide how to handle elevation data
disp('*** Checking Elevation data ***')
licMapTB = checkToolbox('Mapping Toolbox');
noElev = and((max(z)==0),(min(z)==0));

if and(noElev,licMapTB)
    % data isn't included but user has mapping toolbox, so load using
    % mapping tool
    disp('Elevation data not included. Using Mapping Toolbox')
    [z, topo] = loadElevWithMappingToolbox(lat1, lon1);
elseif licMapTB
    % data is included but user has mapping toolbox, give option to use it
    questStr = 'You have the mapping toolbox, would you like to use it load new elevation data?';
    keepStr = 'Keep existing elevation data';
    replaceStr = 'Load new data and replace existing';
    desElevData = questdlg(questStr,'Elevation Data',keepStr,replaceStr,keepStr);
    if strcmp(desElevData,replaceStr)
        % replace existing elevation data
        [z, topo] = loadElevWithMappingToolbox(lat1, lon1);
    else
        % populate topography
        [~, topo] = loadElevWithMappingToolbox(lat1, lon1);
    end
    clear questStr keepStr replaceStr desElevData
elseif noElev
    % no elevation data and no mapping toolbox
    warning('There is no elevation data included in your kml file')
    warning('It is recommended to either:')
    warning('   - Use the Mapping Toolbox')
    warning('   - Supplement your KML file using www.gpsvisualizer.com') 
else
    % elevation data and no mapping toolbox
    warning('Using elevation data provided.')
    warning('You may get better results using the Mapping Toolbox')
end

clear licMapTB noElev

%% Populate elevation and height data assuming constant height above ground
constHeight = 2;
fprintf('*** Populating elevation data with constant %dm above ground level ***',constHeight)
z_elevTube  = z + constHeight*ones(size(z));
if checkToolbox('Curve Fitting Toolbox')
    fitElev  = fit(z_dist,z_elevTube,'smoothingspline','SmoothingParam',5E-7);
    z_dist   = refactorData(z_dist,ceil(max(diff(z_dist))/500),true);
    z_elevTube   = feval(fitElev,z_dist);
else
    warning('Curve fitting toolbox not available, consider smoothing your trajectory')
end

z_height    = constHeight*ones(size(z_elevTube));

clear z constHeight

%% Create higher resolution d,lat1 and lon1 data
% Create fit model of x,y data in order to increase resolution
if checkToolbox('Curve Fitting Toolbox')
    fitTraj = fit(x,y,'smoothingspline','SmoothingParam',5E-7);
    x   = refactorData(x,ceil(max(diff(z_dist))/100),true);
    y   = feval(fitTraj,x);
else
    warning('Curve fitting toolbox not available, consider smoothing your trajectory')
end

% get distance vector, eliminating redundant position points
[d, x, y]               = transDist2D(x, y);

% convert position points back to latitude and longitude
[lat1, lon1]            = reorientXY2LatLon(x,y,transMatrix,lat1(1),lon1(1),latMean);

clear x y transMatrix

%% Create velocity vector
disp('*** Populating velocity vector ***')
velDlg.prompt = {'Enter target velocity for route (mph)'};
velDlg.title = 'Target velocity';
velDlg.num_lines = 1;
velDlg.default = {'760'};
velDlg.options.Resize='on';
velDlg.options.WindowStyle='normal';
velDlg.options.Interpreter='tex';
vel_mph = inputdlg(velDlg.prompt,velDlg.title,velDlg.num_lines,...
    velDlg.default,velDlg.options);
clear velDlg

vel_mps = 0.44704*str2num(vel_mph{1});
[v, ~] = recalcVelocity(d,vel_mps*ones(size(d)),5,1);
warning('Simple velocity profile. Modify the d and v vectors to customize.')

%% Save the route data
disp('*** Saving route data ***')
saveDlg.prompt = {'Enter a filename for your route'};
saveDlg.title = 'Save Route';
saveDlg.num_lines = 1;
saveDlg.default = {'myFile'};
saveDlg.options.Resize='on';
saveDlg.options.WindowStyle='normal';
saveDlg.options.Interpreter='tex';
routeFilename = inputdlg(saveDlg.prompt,saveDlg.title,saveDlg.num_lines,...
    saveDlg.default,saveDlg.options);
save(routeFilename{1},'lat1','lon1','v','d','z_dist','z_elevTube','z_height','topo')
clear saveDlg

%% Return to project root folder
cd(projectRoot)
clearvars -except ProjectRoot