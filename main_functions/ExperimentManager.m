classdef ExperimentManager < handle
    properties (Access = private)
        display
        eyeTracker
        manipulator
        trials
    end

    methods
        function self = ExperimentManager(screenID, eyeTracker, manipulator)     % Init function
            arguments
                screenID (1,1) {mustBeInteger, mustBeNonnegative}
                eyeTracker (1,1) {mustBeA(eyeTracker, 'EyeTrackerInterface')}
                manipulator (1,1) {mustBeA(manipulator, 'ManipulatorInterface')}
            end
            self.display = DisplayManager(screenID);
            self.eyeTracker = eyeTracker;
            self.manipulator = manipulator;
            self.trials = {};
        end

        function self = addTrial(self, trial)
            arguments
                self
                trial (1,1) {mustBeA(trial, 'TrialInterface')}
            end
            self.trials{size(self.trials,2) + 1} = trial;
        end

        function run(self)
            self.display.openWindow();
            self.eyeTracker.establish();
            self.manipulator.establish(self.display.window);

            for ii = 1:length(self.trials)
                self.runTrial(self.trials{ii});
            end
        end

        function close(self)
            self.display.close();
        end
    end

    methods (Access = private)
        function self = runTrial(self, trial)
            for ii = 1:trial.numRounds
                % Generate a new round
                trial.generate();

                % Require the mouse cursor to be on the center target for
                % at least 1 second
                startTime = GetSecs;
                while (GetSecs - startTime < 1)
                    % Prime the target in the screen center
                    self.display.drawElementInCenter(trial.target);

                    % Poll and draw the manipulator
                    manXYB = self.manipulator.poll();
                    self.display.drawDotAt(manXYB([1,2]));
                    
                    % Reset timer if manipulator is not in center target
                    distFromCenter = norm(manXYB);
                    if distFromCenter > trial.target{4}
                        startTime = GetSecs;
                    end
                    
                    self.display.update();
                end
                
                % Play the round
                startTime = GetSecs;
                timestamp = 0;
                while (timestamp < trial.timeout)
                    % Poll and draw the manipulator
                    manXYB = self.manipulator.poll();
                    self.display.drawDotAt(manXYB([1,2]));
                    self.display.drawElements(trial.elements);
                    
                    if trial.check(manXYB) ~= 0; break; end
                    self.display.update();
                    timestamp = GetSecs - startTime;
                end
            end
        end
    end
end