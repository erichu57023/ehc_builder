classdef EmptyTrial < TrialInterface
% EMPTYTRIAL An empty trial for use in testing. Will display only a blank screen, and pass on either
%    timeout or by pressing any keyboard button.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    timeout - The duration in seconds that the trial should run until a timeout is triggered
%    instructions - A struct containing elements to be displayed during the instruction phase.
%    preRound - Always empty.
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
        instructions
        preRound
        elements
        target
        failzone
    end

    methods
        function self = EmptyTrial(timeout)
            arguments
                timeout (1,1) {mustBeNonnegative} = 60;
            end
            % Constructs an EmptyTrial instance.
            % INPUTS:
            %    timeout (optional) - The number of seconds to play before timeout

            self.numRounds = 1;
            self.timeout = timeout;
        end
        
        function generate(self)
            % Populates all element variables with empty structs.
            
            self.instructions = struct([]);
            self.preRound = struct([]);

            self.elements.ElementType = 'text';
            self.elements.Location = [0, 0];
            self.elements.Color = [255 255 255];
            self.elements.Font = 'Ariel';
            self.elements.FontSize = 40;
            self.elements.VerticalSpacing = 2;
            self.elements.Text = ['Empty trial', newline, ...
                'Press SPACE to end'];

            self.target = struct([]);
            self.failzone = struct([]);
        end

        function conditionFlag = check(~, ~)
            % Returns true if any key is pressed.
            
            [~, ~, keyCode] = KbCheck;
            conditionFlag = keyCode(32); % spacebar press
        end
    end
end
