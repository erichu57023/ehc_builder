classdef (Abstract) EyeTrackerInterface < handle
    methods (Abstract)
        establish
        calibrate
        available
        poll
        close
    end
end
