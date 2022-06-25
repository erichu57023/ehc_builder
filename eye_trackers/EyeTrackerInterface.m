classdef (Abstract) EyeTrackerInterface < handle
    methods (Abstract)
        establish
        poll
        close
    end
end
