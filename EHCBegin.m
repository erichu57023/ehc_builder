addpath eye_trackers main_functions helper_functions manipulators trials

% Clear the workspace and the screen
sca;
close all;
clear;

% Psychtoolbox settings
PsychDefaultSetup(2);

% Assign a display screen (zero-indexed)
screenID = max(Screen('Screens'));

% Define an eye tracker
eyeTracker = NoEyeTracker();

% Define a manipulator
manipulator = TouchScreenMouseCursor();

% Initialize the experiment
manager = ExperimentManager(screenID, eyeTracker, manipulator);

% Add a set of trials
manager.addTrial(SingleShapeRingTrial(3, 3, 2, 50));
manager.addTrial(SingleShapeRingTrial(3, 3, 2, 50, 90));

% Run the experiment
manager.run();
manager.close();