classdef NoEyeTracker < EyeTrackerInterface
    properties (Access = private)
        state
        display
    end

    methods
        function self = NoEyeTracker(); end

        function successFlag = establish(self, display)
            self.display = display;
            successFlag = true;
        end

        function successFlag = calibrate(self)
            successFlag = true;
        end

        function state = poll(self)
            self.state = [GetSecs, 0, 0];
            state = self.state; 
        end

        function self = close(self); end
    end
end
