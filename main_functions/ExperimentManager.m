classdef ExperimentManager < handle
% EXPERIMENTMANAGER A centralized manager for EHC experiments. This function handles setup and 
% calibration for any eye trackers or manipulators, and provides a main loop for coordinating trials 
% with data collection and display updates.
%
% Properties:
%    data (struct) - Stores all experiment data
%
% Methods:
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
        manipulator
        filename
        trials
        introTargetRadius = 50;
    end

    methods
        function self = ExperimentManager(screenID, eyeTracker, manipulator, filename, backgroundRGB)     % Init function
            arguments
                screenID (1,1) {mustBeInteger, mustBeNonnegative}
                eyeTracker (1,1) {mustBeA(eyeTracker, 'EyeTrackerInterface')}
                manipulator (1,1) {mustBeA(manipulator, 'ManipulatorInterface')}
                filename {mustBeText}
                backgroundRGB (1,3) {mustBeInteger, mustBeNonnegative, mustBeLessThan(backgroundRGB, 256)} = [0, 0, 0];
            end
            % Constructs an ExperimentManager instance.
            % Inputs:
            %    screenID - The ID of the screen to display to, as returned by PsychToolbox
            %    eyeTracker - An instance of EyeTrackerInterface
            %    manipulator - An instance of ManipulatorInterface
            %    filename - A filepath to which output data will be saved.
            %    backgroundRGB (optional) - An RGB triplet defining the background color

            self.display = DisplayManager(screenID, backgroundRGB/255);
            self.eyeTracker = eyeTracker;
            self.manipulator = manipulator;
            self.filename = filename;
            self.trials = {};

            self.data.Display = self.display;
            self.data.EyeTracker.Class = class(self.eyeTracker);
            self.data.Manipulator.Class = class(self.manipulator);
            self.data.NumTrials = 0;
        end

        function addTrial(self, trial)
            arguments
                self
                trial (1,1) {mustBeA(trial, 'TrialInterface')}
            end
            % Adds a trial to the end of the trial queue. 
            % Inputs:
            %    trial - An instance of TrialInterface

            self.trials{size(self.trials,2) + 1} = trial;
            self.data.NumTrials = self.data.NumTrials + 1;
            
        end

        function successFlag = calibrate(self)
            % Initializes display and hardware interfaces, and runs all calibration routines
            % Outputs:
            %    successFlag - Returns true if all calibrations completed without error

            successFlag = false;
            if ~self.display.openWindow(); return; end
            if ~self.eyeTracker.establish(self.display); return; end
            if ~self.eyeTracker.calibrate(); return; end
            if ~self.manipulator.establish(self.display); return; end
            if ~self.manipulator.calibrate(); return; end

            self.data.EyeTracker.calibrationFcn = self.eyeTracker.calibrationFcn;
            self.data.Manipulator.calibrationFcn = self.manipulator.calibrationFcn;
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
                        % Require the mouse cursor to be on the center target for 1-3
                        % seconds, randomized to avoid prediction
                        startTime = GetSecs;
                        readySetGo = 1 + 2 * rand;
                        while (GetSecs - startTime < readySetGo)
                            % Poll the eye tracker
                            if self.eyeTracker.available()
                                eyeRawState = self.eyeTracker.poll();
                                eyeCenterXY = self.eyeTracker.calibrationFcn(eyeRawState);
                            end

                            % Poll the manipulator
                            if self.manipulator.available()
                                manipRawState = self.manipulator.poll();
                                manipCenterXYZ = self.manipulator.calibrationFcn(manipRawState);
                            end
    
                            % Prime the target in the screen center
                            if self.display.asyncReady() > 0
                                self.display.drawElements(trial.intro);
                                self.display.drawDotsFastAt([manipCenterXYZ(1:2)]);
                                self.display.updateAsync();
                            end
                            
                            % Reset timer if manipulator is not in center target
                            distFromCenter = norm(manipCenterXYZ(1:2));
                            if distFromCenter > self.introTargetRadius
                                startTime = GetSecs;
                            end
                        end
%                         self.display.asyncEnd();
                    end
                end

                function playTrialPhase()
                    % Play the round
                    startTime = GetSecs;
                    timestamp = 0;
                    eyeRawState = self.eyeTracker.poll();
                    manipRawState = self.manipulator.poll();
                    eyeTrace = nan(trial.timeout * 1000, length(eyeRawState));
                    manipulatorTrace = nan(trial.timeout * 1000, length(manipRawState));
                    eyeTraceIdx = 1; manipTraceIdx = 1;
                    manipCenterXYZ = nan(1,3);
                    eyeCenterXY = nan(1,2);
                    
                    while (timestamp < trial.timeout)
                        % Poll the eye tracker
                        if self.eyeTracker.available()
                            eyeRawState = self.eyeTracker.poll();
                            eyeTrace(eyeTraceIdx, :) = eyeRawState;
                            eyeTraceIdx = eyeTraceIdx + 1;
                            eyeCenterXY = self.eyeTracker.calibrationFcn(eyeRawState);
                        end

                        % Poll the manipulator
                        if self.manipulator.available()
                            manipRawState = self.manipulator.poll();
                            manipulatorTrace(manipTraceIdx, :) = manipRawState;
                            manipTraceIdx = manipTraceIdx + 1;
                            manipCenterXYZ = self.manipulator.calibrationFcn(manipRawState);
                        end

                        % End if a pass/fail condition is met
                        outcome = trial.check(manipCenterXYZ);
                        if outcome ~= 0
                            break
                        end
                        
                        % Prepare the next frame to draw
                        if self.display.asyncReady() > 0
%                             self.display.drawDotsFastAt([eyeCenterXY(1:2); manipCenterXYZ(1:2)])
                            self.display.drawDotsFastAt(manipCenterXYZ(1:2))
                            self.display.drawElements(trial.elements);
                            self.display.updateAsync();
                        end
                        timestamp = GetSecs - startTime;
                    end
%                     self.display.asyncEnd();
                    
                    self.data.TrialData(ii).EyeTrackerData{jj, 1} = eyeTrace(~isnan(eyeTrace(:,1)), :);
                    self.data.TrialData(ii).ManipulatorData{jj, 1} = manipulatorTrace(~isnan(manipulatorTrace(:,1)), :);
                    self.data.TrialData(ii).Outcomes(jj) = outcome;
                end
            end
        end

        function close(self)
            self.eyeTracker.close();
            self.manipulator.close();
            self.display.asyncEnd();
            self.display.close();
        end
    end
end
