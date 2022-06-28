classdef ExperimentManager < handle
    properties
        data = struct
    end
    properties (Access = private)
        display
        eyeTracker
        manipulator
        trials
    end

    methods
        function self = ExperimentManager(screenID, eyeTracker, manipulator, backgroundRGB)     % Init function
            arguments
                screenID (1,1) {mustBeInteger, mustBeNonnegative}
                eyeTracker (1,1) {mustBeA(eyeTracker, 'EyeTrackerInterface')}
                manipulator (1,1) {mustBeA(manipulator, 'ManipulatorInterface')}
                backgroundRGB (1,3) {mustBeInteger, mustBeNonnegative, mustBeLessThan(backgroundRGB, 256)} = [0, 0, 0];
            end
            self.display = DisplayManager(screenID, backgroundRGB/255);
            self.eyeTracker = eyeTracker;
            self.manipulator = manipulator;
            self.trials = {};

            self.data.Display = self.display;
            self.data.EyeTrackerClass = class(self.eyeTracker);
            self.data.ManipulatorClass = class(self.manipulator);
            self.data.NumTrials = 0;
        end

        function addTrial(self, trial)
            arguments
                self
                trial (1,1) {mustBeA(trial, 'TrialInterface')}
            end
            self.trials{size(self.trials,2) + 1} = trial;
            self.data.NumTrials = self.data.NumTrials + 1;
        end

        function run(self)
            self.display.openWindow();
            self.eyeTracker.establish();
            self.manipulator.establish(self.display.window);

            for ii = 1:length(self.trials)
                runTrial(self.trials{ii});
            end

            function runTrial(trial)
                self.data.TrialData(ii).NumRounds = trial.numRounds;
                self.data.TrialData(ii).Timeout = trial.timeout;

                for jj = 1:trial.numRounds
                    % Generate a new round
                    trial.generate();
                    self.data.TrialData(ii).Elements{jj, 1} = trial.elements;
                    self.data.TrialData(ii).Targets{jj, 1} = trial.target;
                    self.data.TrialData(ii).Failzones{jj, 1} = trial.failzone;

                    % Require the mouse cursor to be on the center target for
                    % 1-3 seconds
                    startTime = GetSecs;
                    readySetGo = 1 + 2 * rand;
                    while (GetSecs - startTime < readySetGo)
                        % Prime the target in the screen center
                        self.display.drawElementInCenter(trial.target);
    
                        % Poll and draw the manipulator
                        manipulatorState = self.manipulator.poll();
                        self.display.drawDotAt(manipulatorState([2,3]));
                        
                        % Reset timer if manipulator is not in center target
                        distFromCenter = norm(manipulatorState([2,3]));
                        if distFromCenter > trial.target.Radius
                            startTime = GetSecs;
                        end
                        
                        self.display.update();
                    end
                    
                    % Play the round
                    startTime = GetSecs;
                    timestamp = 0;
                    eyeTrace = nan(trial.timeout * 1000, length(self.eyeTracker.poll()));
                    manipulatorTrace = nan(trial.timeout * 1000, length(self.manipulator.poll()));
                    traceIdx = 1;
                    while (timestamp < trial.timeout)
                        % Poll the eye tracker
                        eyeTrackerState = self.eyeTracker.poll();
                        
                        % Poll and draw the manipulator
                        manipulatorState = self.manipulator.poll();
                        eyeTrace(traceIdx, :) = eyeTrackerState;
                        manipulatorTrace(traceIdx, :) = manipulatorState;
                        traceIdx = traceIdx + 1;

                        if trial.check(manipulatorState) ~= 0; break; end
                        
                        if self.display.asyncReady
                            self.display.drawDotAt(manipulatorState([2,3]));
                            self.display.drawElements(trial.elements);
                            self.display.updateAsync();
                        end
                        timestamp = GetSecs - startTime;
                    end

                    self.data.TrialData(ii).EyeTrackerData{jj, 1} = eyeTrace(~isnan(eyeTrace(:,1)), :);
                    self.data.TrialData(ii).ManipulatorData{jj, 1} = manipulatorTrace(~isnan(manipulatorTrace(:,1)), :);
                end
            end
        end

        function close(self)
            self.display.close();
        end
    end
end
