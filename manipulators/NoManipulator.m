classdef NoManipulator < ManipulatorInterface
    properties (Access = private)
        display
    end

    methods
        function self = NoManipulator(); end

        function successFlag = establish(self, display)
            self.display = display;
            successFlag = true;
        end

        function successFlag = calibrate(self)
            successFlag = true;
        end

        function availFlag = available(self)
            availFlag = true;
        end

        function state = poll(self)
            state = [GetSecs, 0, 0]; 
        end

        function close(self); end
    end
end
