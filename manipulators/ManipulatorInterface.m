classdef (Abstract) ManipulatorInterface < handle
    properties (Abstract)
        calibrationFcn
    end
    
    methods (Abstract)
        establish
        calibrate
        available
        poll
        close
    end
end
