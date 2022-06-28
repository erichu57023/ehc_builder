classdef NoEyeTracker < EyeTrackerInterface
    properties (Access = private)
        state
    end

    methods
        function self = NoEyeTracker(); end

        function self = establish(self); end

        function state = poll(self)
            self.state = [GetSecs, 0, 0];
            state = self.state; 
        end

        function self = close(self); end
    end
end
