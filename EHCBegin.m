% EHCBEGIN Startup script for an EHC experiment, defining hardware interfaces and a list of trials

addpath eye_trackers main_functions helper_functions manipulators trials

% Clear the workspace and the screen
sca;
close all;
clear;

%% Query user for name to generate a filepath for saved data
filepath = GenerateFilePath();


%% Psychtoolbox settings
PsychDefaultSetup(2);

% Assign a display screen (zero-indexed)
screenID = max(Screen('Screens'));

%% Define an eye tracker (see eye_trackers folder)
eyeHomeRadius = 50; % Home radius in pixels
% eyeTracker = NoEyeTracker();
% eyeTracker = WASDEyeTracker(eyeHomeRadius);
eyeTracker = EyeLink2(eyeHomeRadius);
    

%% Define one or more manipulators (see manipulators folder)
manipHomeRadiusPixels = 50; % Home radius (in pixels) for on-screen home positions.
manipHomeRadiusMills = 25; % Home radius (in mm) for 3D coordinate home positions.
forcePLCalibration = true; % Forces PolhemusLiberty to call calibration even if liberty_calibration.mat is present

% manipulator = MouseCursor(manipHomeRadiusPixels);
% manipulator = TouchScreen(manipHomeRadiusPixels);
% manipulator = PolhemusLiberty('localhost', 7234, forcePLCalibration, manipHomeRadiusMills);
manipulator = [PolhemusLiberty('localhost', 7234, forcePLCalibration, manipHomeRadiusMills), ...
                TouchScreen(manipHomeRadiusPixels)];


%% Set overall experiment options (see ExperimentManager.SetDefaultOptions())
% Assign a background color as an 8-bit RGB value (0 to 255)
managerOptions.background8BitRGB = [0, 0, 0];

% Set the min and max duration of the pre-round check.
managerOptions.preRoundMinDuration = 1;     % seconds
managerOptions.preRoundMaxDuration = 3;     % seconds

% Set the behavior of the pre-round eye tracker check.
managerOptions.eyeFixateRadius = 25;        % pixels
managerOptions.eyeFixateMinDuration = 0.2;  % seconds
managerOptions.eyeMaintainRadius = 50;      % pixels
managerOptions.eyeMaintainMaxMisses = 5;    % count
manager = ExperimentManager(screenID, eyeTracker, manipulator, filepath, managerOptions);


%% Define trial parameters
timeout = 5;
stimulusSize = 25;
eyeTargetSize = stimulusSize * 2;
reachTargetSize = []; % If empty, will use data from practice trial
clickToPass = ismember(class(manipulator(end)), {'TouchScreen', 'MouseCursor'}); % Denotes whether a click is required to pass the trial

% Add a target practice trial (only one of each class is allowed)
numPracticeRounds = 10;
targetAccuracy = 0.7;
manager.addPractice(SingleShapeRingTrial(numPracticeRounds, 'free', timeout, 1, clickToPass, stimulusSize, eyeTargetSize, stimulusSize), targetAccuracy);

% Add a set of trials (see trials folder)
% manager.addTrial(EmptyTrial(60));
manager.addTrial(SingleShapeRingTrial(5, 'look', timeout, 1, clickToPass, stimulusSize, eyeTargetSize, reachTargetSize));
manager.addTrial(SingleShapeRingTrial(5, 'reach', timeout, 1, clickToPass, stimulusSize, eyeTargetSize, reachTargetSize));
manager.addTrial(SingleShapeRingTrial(5, 'free', timeout, 1, clickToPass, stimulusSize, eyeTargetSize, reachTargetSize));
manager.addTrial(SingleShapeRingTrial(5, 'segmented', timeout, 1, clickToPass, stimulusSize, eyeTargetSize, reachTargetSize));
% manager.addTrial(SingleShapeRingTrial(3, 'free', timeout, 2, clickToPass, visualTargetSize, eyeTargetSize, reachTargetSize, 90));
% manager.addTrial(SingleShapeRingTrial(3, 'free', timeout, 4, clickToPass, visualTargetSize, eyeTargetSize, reachTargetSize));
% manager.addTrial(SingleShapeRingTrial(3, 'free', timeout, 8, clickToPass, visualTargetSize, eyeTargetSize, reachTargetSize));
% manager.addTrial(NavonTask(3, 5, "random"))
% manager.addTrial(NavonTask(3, 5, "local"))
% manager.addTrial(NavonTask(3, 5, "global"))
% manager.addTrial(TraceShapeTrial(1, 15, 'Random', 200))


%% Run the experiment 
try
    if manager.calibrate()
        manager.run();
    end
    manager.close();
catch exception
    % Close open windows
    sca;
    rethrow(exception)
end

%% Display output data
outputData = manager.data;
