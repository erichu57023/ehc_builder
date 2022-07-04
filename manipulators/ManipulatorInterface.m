classdef (Abstract) ManipulatorInterface < handle
    methods (Abstract)
        establish
        calibrate
        available
        poll
        close
    end
end
