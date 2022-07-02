classdef (Abstract) ManipulatorInterface < handle
    methods (Abstract)
        establish
        calibrate
        poll
        close
    end
end
