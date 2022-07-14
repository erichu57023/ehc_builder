classdef (Abstract) TrialInterface < handle
    properties (Abstract)
        numRounds
        timeout
        intro
        elements
        target
        failzone
    end

    methods (Abstract)
        generate
        check
    end
end
