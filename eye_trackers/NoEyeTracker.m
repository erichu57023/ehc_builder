classdef NoEyeTracker < EyeTrackerInterface
% NOEYETRACKER A dummy implementation for use when no eye tracker is required for the experiment.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%
% METHODS:
%    establish - Does nothing.
%    calibrate - Does nothing.
%    available - Does nothing.
%    poll - Always returns [timestamp, 0, 0]
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
            self.calibrationFcn = @(x) x(2:end);
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
            self.state = [GetSecs, 0, 0];
            state = self.state; 
        end

        function driftCorrect(self)
            disp('NoEyeTracker: drift-corrected')
        end

        function self = close(self); end
    end
end
