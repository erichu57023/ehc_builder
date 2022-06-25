classdef NoEyeTracker < EyeTrackerInterface
    properties (Access = private)
        state
    end

    methods
        function self = NoEyeTracker(); end

        function self = establish(self)
            self.state = [0, 0];
        end

        function state = poll(self)
            state = self.state; 
        end

        function self = close(self)
            self.state = nan;
        end
    end
end
