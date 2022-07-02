classdef (Abstract) EyeTrackerInterface < handle
    methods (Abstract)
        establish
        calibrate
        poll
        close
    end
end
