classdef EmptyTrial < TrialInterface
% EMPTYTRIAL An empty trial for use in testing. Will display only a blank screen, and pass on either
%    timeout or by pressing any keyboard button.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    timeout - The duration in seconds that the trial should run until a timeout is triggered
%    intro - Always empty.
%    elements - Always empty.
%    target - Always empty.
%    failzone - Always empty.
%
% METHODS:
%    generate - Does nothing.
%    check - Checks if any keyboard key is pressed.

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
            arguments
                timeout (1,1) {mustBeNonnegative}
            end
            % Constructs an EmptyTrial instance.
            % INPUTS:
            %    timeout - The number of seconds to play before timeout

            self.numRounds = 1;
            self.timeout = timeout;
        end
        
        function generate(self)
            % Populates all element variables with empty structs.

            self.intro = struct([]);
            self.elements = struct([]);
            self.target = struct([]);
            self.failzone = struct([]);
        end

        function conditionFlag = check(self, state)
            % Generates a conditionFlag based on input state.
            % INPUTS:
            %    state - A vector whose first two columns must be XY data relative to screen center.
            %       The contents of other columns is not guaranteed.
            % OUTPUTS:
            %    conditionFlag - 1 if success, 0 if timeout, -1 if failure.
            
            conditionFlag = KbCheck; % Keyboard press
        end
    end
end
