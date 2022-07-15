classdef (Abstract) EyeTrackerInterface < handle
    properties (Abstract)
        calibrationFcn
    end
    methods (Abstract)
        establish
        calibrate
        available
        poll
        driftCorrect
        close
    end
end
