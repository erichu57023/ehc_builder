classdef NoManipulator < ManipulatorInterface
% NOEYETRACKER A dummy implementation for use when no manipulator is required for the experiment.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%    homePosition - Always set to [0, 0, 0]
%    homeRadius - Always set to Inf.
%
% METHODS:
%    establish - Does nothing.
%    calibrate - Does nothing.
%    available - Does nothing.
%    poll - Always returns [0, 0, 0, timestamp]
%    reset - Does nothing.
%    isHome - Always returns true.
%    close - Does nothing.

    properties
        calibrationFcn
        homePosition = [0, 0, 0];
        homeRadius = Inf;
    end
    properties (Access = private)
        display
    end

    methods
        function self = NoManipulator(); end

        function successFlag = establish(self, display)
            self.display = display;
            successFlag = true;
            self.calibrationFcn = @(x) x(1:3);
            disp('NoManipulator: established')
        end

        function successFlag = calibrate(self)
            disp('NoManipulator: calibrated')
            successFlag = true;
        end

        function availFlag = available(self)
            availFlag = true;
        end

        function state = poll(self)
            state = [zeros(1,3), GetSecs]; 
        end

        function reset(self); end

        function homeFlag = isHome(self)
            homeFlag = true;
        end

        function close(self); end
    end
end
