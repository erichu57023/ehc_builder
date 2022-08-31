classdef NoEyeTracker < EyeTrackerInterface
% NOEYETRACKER A dummy implementation for use when no eye tracker is required for the experiment.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%
% METHODS:
%    establish - Does nothing.
%    calibrate - Generates a function which always returns [0, 0].
%    available - Does nothing.
%    poll - Always returns [0, 0, 0, 0, timestamp]
%    driftCorrect - Does nothing.
%    close - Does nothing.

    properties
        calibrationFcn
    end
    properties (Access = private)
        state
        display
    end

    methods
        function self = NoEyeTracker(); end

        function successFlag = establish(self, display)
            self.display = display;
            successFlag = true;
            self.calibrationFcn = @(x) [0, 0];
            disp('NoEyeTracker: established')
        end

        function successFlag = calibrate(self)
            disp('NoEyeTracker: calibrated')
            successFlag = true;
        end    

        function successFlag = available(self)
            successFlag = true;
        end

        function state = poll(self)
            self.state = [0, 0, 0, 0, GetSecs];
            state = self.state; 
        end

        function driftCorrect(self)
            disp('NoEyeTracker: drift-corrected')
        end

        function self = close(self); end
    end
end
