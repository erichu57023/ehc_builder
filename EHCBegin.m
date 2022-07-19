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
eyeTracker = EyeLink2();
% eyeTracker = NoEyeTracker();
    
% Define a manipulator (see manipulators folder)
manipulator = PolhemusLiberty();
% manipulator = TouchScreenMouseCursor();

% Assign a background color as an 8-bit RGB value (0 to 255)
background8BitRGB = [0, 0, 0];

% Initialize the experiment
manager = ExperimentManager(screenID, eyeTracker, manipulator, filepath, background8BitRGB);

% Add a set of trials (see trials folder)
manager.addTrial(EmptyTrial(60));
manager.addTrial(SingleShapeRingTrial(10, 5, 1, 25));
manager.addTrial(SingleShapeRingTrial(10, 5, 2, 25));
manager.addTrial(SingleShapeRingTrial(10, 5, 2, 25, 90));
manager.addTrial(SingleShapeRingTrial(10, 5, 4, 25));
manager.addTrial(SingleShapeRingTrial(10, 5, 8, 25));

manager.addTrial(NavonTask(10, 5, "local"))
manager.addTrial(NavonTask(10, 5, "global"))
manager.addTrial(NavonTask(10, 5, "random"))

manager.addTrial(TraceShapeTrial(10, 15, 'Random', 200))


% Run the experiment
if manager.calibrate()
    manager.run();
end
manager.close();

% Display output data
outputData = manager.data;