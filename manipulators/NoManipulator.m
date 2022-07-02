classdef NoManipulator < ManipulatorInterface
    properties (Access = private)
        state
        display
    end

    methods
        function self = NoManipulator(); end

        function successFlag = establish(self, display)
            self.display = display;
            self.state = [GetSecs, 0, 0];
            successFlag = true;
        end

        function successFlag = calibrate(self)
            successFlag = true;
        end

        function state = poll(self)
            state = self.state; 
        end

        function self = close(self)
            self.state = nan;
        end
    end
end
