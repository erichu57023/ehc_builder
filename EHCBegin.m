addpath eye_trackers main_functions helper_functions manipulators trials

% Clear the workspace and the screen
sca;
close all;
clear;

% Psychtoolbox settings
PsychDefaultSetup(2);

% Assign a display screen (zero-indexed)
screenID = max(Screen('Screens'));

% Define an eye tracker (see eye_trackers folder)
eyeTracker = NoEyeTracker();
    
% Define a manipulator (see manipulators folder)
manipulator = TouchScreenMouseCursor();

% Assign a background color as an 8-bit RGB value (0 to 255)
background8BitRGB = [0, 0, 0];

% Initialize the experiment
manager = ExperimentManager(screenID, eyeTracker, manipulator, background8BitRGB);

% Add a set of trials (see trials folder)
manager.addTrial(SingleShapeRingTrial(2, 3, 2, 50));
% manager.addTrial(SingleShapeRingTrial(3, 3, 2, 50, 90));
manager.addTrial(SingleShapeRingTrial(2, 3, 8, 50));

% Run the experiment
manager.calibrate();
manager.run();
manager.close();

% Save output data
outputData = manager.data;