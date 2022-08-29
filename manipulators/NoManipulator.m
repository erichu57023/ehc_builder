classdef NoManipulator < ManipulatorInterface
% NOEYETRACKER A dummy implementation for use when no manipulator is required for the experiment.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%
% METHODS:
%    establish - Does nothing.
%    calibrate - Does nothing.
%    available - Does nothing.
%    poll - Always returns [timestamp, 0, 0, 0]
%    close - Does nothing.

    properties
        calibrationFcn
    end
    properties (Access = private)
        display
    end

    methods
        function self = NoManipulator(); end

        function successFlag = establish(self, display)
            self.display = display;
            successFlag = true;
            self.calibrationFcn = @(x) x(2:end);
        end

        function successFlag = calibrate(self)
            successFlag = true;
        end

        function availFlag = available(self)
            availFlag = true;
        end

        function state = poll(self)
            state = [GetSecs, zeros(1,3)]; 
        end

        function close(self); end
    end
end
