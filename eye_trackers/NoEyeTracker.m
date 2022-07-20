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
%    poll - Always returns [timestamp, nan, nan]
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
        end

        function successFlag = calibrate(self)
            successFlag = true;
        end    

        function successFlag = available(self)
            successFlag = true;
        end

        function state = poll(self)
            self.state = [GetSecs, nan, nan];
            state = self.state; 
        end

        function driftCorrect(self); end

        function self = close(self); end
    end
end
