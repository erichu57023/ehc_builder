% EHCBEGIN Startup script for an EHC experiment, defining hardware interfaces and a list of trials

addpath eye_trackers main_functions helper_functions manipulators trials

% Clear the workspace and the screen
sca;
close all;
clear;

% Query user for name to generate a filepath for saved data
filepath = GenerateFilePath();


% Psychtoolbox settings
PsychDefaultSetup(2);


% Assign a display screen (zero-indexed)
screenID = max(Screen('Screens'));


% Define an eye tracker (see eye_trackers folder)
eyeTrackerHomeRadius = 50; % Home radius in pixels
% eyeTracker = NoEyeTracker();
% eyeTracker = WASDEyeTracker(eyeTrackerHomeRadius);
eyeTracker = EyeLink2(eyeTrackerHomeRadius);
    

% Define one or more manipulators (see manipulators folder)
% manipulator = TouchScreenMouseCursor();
% manipulator = PolhemusLiberty();
 manipulator = [PolhemusLiberty(), TouchScreenMouseCursor()];


% Assign a background color as an 8-bit RGB value (0 to 255)
background8BitRGB = [0, 0, 0];


% Initialize the experiment
manager = ExperimentManager(screenID, eyeTracker, manipulator, filepath, background8BitRGB);


% Add a set of trials (see trials folder)
% manager.addTrial(EmptyTrial(60));
manager.addTrial(SingleShapeRingTrial(5, 'look', 5, 1, 25));
manager.addTrial(SingleShapeRingTrial(5, 'reach', 5, 1, 25));
manager.addTrial(SingleShapeRingTrial(5, 'free', 5, 1, 25));
manager.addTrial(SingleShapeRingTrial(5, 'segmented', 5, 1, 25));

% manager.addTrial(SingleShapeRingTrial(3, 'free', 5, 2, 25, 90));
% manager.addTrial(SingleShapeRingTrial(3, 'free', 5, 4, 25));
% manager.addTrial(SingleShapeRingTrial(3, 'free', 5, 8, 25));

% manager.addTrial(NavonTask(3, 5, "random"))
% manager.addTrial(NavonTask(3, 5, "local"))
% manager.addTrial(NavonTask(3, 5, "global"))

% manager.addTrial(TraceShapeTrial(3, 15, 'Random', 200))


% Run the experiment 
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

% Display output data
outputData = manager.data;