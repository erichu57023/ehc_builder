classdef NoManipulator < ManipulatorInterface
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
            state = [GetSecs, nan, nan]; 
        end

        function close(self); end
    end
end
