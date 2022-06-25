classdef (Abstract) ManipulatorInterface < handle
    methods (Abstract)
        establish
        poll
        close
    end
end
