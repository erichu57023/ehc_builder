classdef EmptyTrial < TrialInterface
    % A class encoding an empty test trial

    properties
        numRounds
        timeout
        intro
        elements
        target
        failzone
    end

    methods
        function self = EmptyTrial(timeout)
            % Defines a phase of trials.
            arguments
                timeout (1,1) {mustBeNonnegative}
            end
            self.numRounds = 1;
            self.timeout = timeout;
        end
        
        function generate(self)
            % Generates a new trial, produces a list of all visual elements
            % and their locations (relative to the center of screen), and 
            % stores it in self.elements for display.
            self.intro = struct([]);
            self.elements = struct([]);
            self.target = struct([]);
            self.failzone = struct([]);
        end

        function conditionFlag = check(self, state)
            % Generates a conditionFlag based on input state. If
            % check passes, returns 1. If check fails, returns -1.
            % Otherwise, return 0. Input XY must be relative to screen 
            % center.
            conditionFlag = KbCheck; % Keyboard press
        end
    end
end
