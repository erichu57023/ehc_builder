classdef ExperimentManager < handle
% EXPERIMENTMANAGER A centralized manager for EHC experiments. This function handles setup and 
% calibration for any eye trackers or manipulators, and provides a main loop for coordinating trials 
% with data collection and display updates.
%
% PROPERTIES:
%    data (struct) - Stores all experiment data
%
% METHODS:
%    addTrial - Adds a trial to the ongoing experiment
%    calibrate - Connects and calibrates designated hardware
%    run - Plays each trial in the order they were added
%    close - Closes all connections and cleans up the experiment
%
% See also: DISPLAYMANAGER, EYETRACKERINTERFACE, MANIPULATORINTERFACE, TRIALINTERFACE

    properties
        data = struct
    end
    properties (Access = private)
        display
        eyeTracker
        manipulators; numManipulators
        filename
        trials
        introTargetRadius = 50;
    end

    methods
        function self = ExperimentManager(screenID, eyeTracker, manipulatorList, filename, backgroundRGB)     % Init function
            arguments
                screenID (1,1) {mustBeInteger, mustBeNonnegative}
                eyeTracker (1,1) {mustBeA(eyeTracker, 'EyeTrackerInterface')}
                manipulatorList (1,:) {mustBeA(manipulatorList, 'ManipulatorInterface')}
                filename {mustBeText}
                backgroundRGB (1,3) {mustBeInteger, mustBeNonnegative, mustBeLessThan(backgroundRGB, 256)} = [0, 0, 0];
            end
            % Constructs an ExperimentManager instance.
            % INPUTS:
            %    screenID - The ID of the screen to display to, as returned by PsychToolbox
            %    eyeTracker - An instance of EyeTrackerInterface
            %    manipulatorList - An array of ManipulatorInterface objects.
            %    filename - A filepath to which output data will be saved.
            %    backgroundRGB - An RGB triplet defining the background color

            self.display = DisplayManager(screenID, backgroundRGB/255);
            self.eyeTracker = eyeTracker;
            self.manipulators = manipulatorList;
            self.numManipulators = length(manipulatorList);
            self.filename = filename;
            self.trials = {};
            
            self.data.EyeTracker.Class = class(self.eyeTracker);
            self.data.Manipulators.Class = arrayfun(@(obj)class(obj), self.manipulators, 'UniformOutput', false);
            self.data.NumTrials = 0;
        end

        function addTrial(self, trial)
            arguments
                self
                trial (1,1) {mustBeA(trial, 'TrialInterface')}
            end
            % Adds a trial to the end of the trial queue. 
            % INPUTS:
            %    trial - An instance of TrialInterface

            self.trials{size(self.trials,2) + 1} = trial;
            self.data.NumTrials = self.data.NumTrials + 1;
            
        end

        function successFlag = calibrate(self)
            % Initializes display and hardware interfaces, and runs all calibration routines.
            % Returns prematurely if an error occurs.
            % OUTPUTS:
            %    successFlag - Returns true if all calibrations completed without error

            successFlag = false;
            
            % Open a window and save properties of the detected display
            if ~self.display.openWindow(); return; end
            prop = properties('DisplayManager');
            for ii = 1 : length(prop)
                self.data.Display.(prop{ii}) = self.display.(prop{ii});
            end

            % Set up eye tracker
            if ~self.eyeTracker.establish(self.display); return; end
            if ~self.eyeTracker.calibrate(); return; end
            self.data.EyeTracker.calibrationFcn = self.eyeTracker.calibrationFcn;

            % Set up manipulators
            if ~all(self.manipulators.establishAll(self.display)); return; end
            if ~all(self.manipulators.calibrateAll()); return; end
            self.data.Manipulators.calibrationFcn = arrayfun(@(obj)obj.calibrationFcn, self.manipulators, 'UniformOutput', false);

            successFlag = true;
        end

        function run(self)
            % Runs each trial in the order they were added, using the following process:
            % 1) Ask the trial to generate a series of on-screen elements, target and fail zones,
            % and an optional intro screen.
            % 2) Play the intro screen, which requires the manipulator to be in a defined
            % position, and drift-correct the eye tracker on that position
            % 3) Play the trial, displaying all elements on screen, collecting eye and manipulator 
            % data each loop, and passing that into the trial object to check for pass/fail
            % conditions
            % 4) Saves data to the output file after completion of each trial
            
            for ii = 1:length(self.trials)
                runTrial(self.trials{ii});
            end

            function runTrial(trial)
                % Runs a single trial defined by TrialInterface

                self.data.TrialData(ii).NumRounds = trial.numRounds;
                self.data.TrialData(ii).Timeout = trial.timeout;
                self.data.TrialData(ii).Outcomes = zeros(1, trial.numRounds);

                for jj = 1:trial.numRounds
                    % Generate a new round, which populates the instance properties of the
                    % Trial object with new elements
                    trial.generate();
                    self.data.TrialData(ii).Elements{jj, 1} = trial.elements;
                    self.data.TrialData(ii).Targets{jj, 1} = trial.target;
                    self.data.TrialData(ii).Failzones{jj, 1} = trial.failzone;
                    
                    % Clear the display
                    self.display.emptyScreen();
                    self.display.update();

                    % Provide instructions and perform gaze correction on center target
                    playIntroPhase(); 

                    % Correct for error in eye tracking data due to drift
                    self.eyeTracker.driftCorrect() 

                    % Play the trial and record all data
                    playTrialPhase(); 
                end

                % Save data for each completed trial during runtime
                Data = self.data;
                save(self.filename, 'Data');

                function playIntroPhase()
                    % Display trial instructions and perform gaze correction on center target
                    
                    manipCenterXYZ = nan(1,3);
                    eyeCenterXY = nan(1,2);

                    if ~isempty(trial.intro)
                        % Require the primary manipulator to be on the center target for 1-3 
                        % seconds, randomized to avoid prediction of stimulus onset
                        startTime = GetSecs;
                        readySetGo = 1 + 2 * rand;
                        while (GetSecs - startTime < readySetGo)
                            % Poll the eye tracker
                            if self.eyeTracker.available()
                                eyeRawState = self.eyeTracker.poll();
                                eyeCenterXY = self.eyeTracker.calibrationFcn(eyeRawState);
                            end

                            % Poll the primary manipulator
                            if self.manipulators(1).available()
                                manipRawState = self.manipulators(1).poll();
                                manipCenterXYZ = self.manipulators(1).calibrationFcn(manipRawState);
                            end
    
                            % Prime the target in the screen center
                            if self.display.asyncReady() > 0
                                self.display.drawElements(trial.intro);
                                self.display.drawDotsFastAt([manipCenterXYZ(1:2); eyeCenterXY]);
                                self.display.updateAsync();
                            end
                            
                            % Reset timer if manipulator is not in center target
                            distFromCenter = norm(manipCenterXYZ(1:2));
                            if distFromCenter > self.introTargetRadius
                                startTime = GetSecs;
                            end
                        end
                    end
                end

                function playTrialPhase()
                    % Present trial stimuli, and stop when either a pass/fail condition is met, or
                    % timeout is reached. Record all data to the output struct.

                    startTime = GetSecs;
                    timestamp = 0;

                    % Set up sized buffers for data recording
                    eyeRawState = self.eyeTracker.poll();
                    eyeTrace = nan(trial.timeout * 1000, length(eyeRawState));
                    eyeTraceIdx = 1; 
                    manipRawStates = self.manipulators.pollAll();
                    manipTraces = cell(1, self.numManipulators);
                    for kk = 1 : self.numManipulators
                        manipTraces{kk} = nan(trial.timeout * 1000, length(manipRawStates{kk}));
                    end
                    manipTraceIdxs = ones(1, self.numManipulators);
                    manipCenterXYZs = nan(self.numManipulators, 3);
                    
                    while (timestamp < trial.timeout)
                        % Poll the eye tracker
                        if self.eyeTracker.available()
                            eyeRawState = self.eyeTracker.poll();
                            eyeTrace(eyeTraceIdx, :) = eyeRawState;
                            eyeTraceIdx = eyeTraceIdx + 1;
                            eyeCenterXY = self.eyeTracker.calibrationFcn(eyeRawState);
                        end

                        % Poll all manipulators
                        for kk = 1 : self.numManipulators
                            if self.manipulators(kk).available()
                                manipRawStates{kk} = self.manipulators(kk).poll();
                                manipTraces{kk}(manipTraceIdxs(kk), :) = manipRawStates{kk};
                                manipTraceIdxs(kk) = manipTraceIdxs(kk) + 1;
                                manipCenterXYZs(kk, :) = self.manipulators(kk).calibrationFcn(manipRawStates{kk});
                            end
                        end

                        % End if a pass/fail condition is met
                        outcome = trial.check(manipCenterXYZs, eyeCenterXY);
                        if outcome ~= 0
                            break
                        end
                        
                        % Prepare the next frame to draw
                        if self.display.asyncReady() > 0
                            self.display.drawDotsFastAt([manipCenterXYZs(1, 1:2); eyeCenterXY])
                            self.display.drawElements(trial.elements);
                            self.display.updateAsync();
                        end
                        timestamp = GetSecs - startTime;
                    end
                    
                    % Record data in an output struct, to be saved at the end of each trial.
                    eyeTrace = eyeTrace(~isnan(eyeTrace(:,1)), :);
                    self.data.TrialData(ii).EyeTrackerData{jj, 1} = eyeTrace;

                    for kk = 1 : self.numManipulators
                        manipTraces{kk} = manipTraces{kk}(~isnan(manipTraces{kk}(:,1)), :);
                        self.data.TrialData(ii).ManipulatorData{jj, kk} = manipTraces{kk};
                    end
                    
                    self.data.TrialData(ii).Outcomes(jj) = outcome;
                end
            end
        end

        function close(self)
            % Closes all hardware, waits for last display frame to end, and closes the window
            % (cleaning up all loaded textures).

            self.eyeTracker.close();
            self.manipulators.closeAll();
            self.display.asyncEnd();
            self.display.close();
        end
    end
end

