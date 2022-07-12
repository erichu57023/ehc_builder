classdef NavonTask < TrialInterface
    % A class encoding a Navon task where the player chooses between two
    % targets sharing either a global or a local feature.

    properties
        numRounds
        timeout
        elements
        target
        failzone
    end
    properties (Access = private)
        mode
        allowedLetters
        letterText
        fontSize
        distFromCenter
        randomizeFlag
    end
    properties(Constant)
        instructions = [];
    end

    methods
        function self = NavonTask(numRounds, timeout, mode, allowedLetters, fontSize, distFromCenter)
            % Defines a phase of trials.
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive}
                timeout (1,1) {mustBeNonnegative}
                mode {mustBeMember(mode, ["random", "global", "local"])} = "random";
                allowedLetters {mustBeText} = 'abcdefghijklmnopqrstuvwxyz';
                fontSize (1,1) {mustBeInteger, mustBePositive} = 40;
                distFromCenter (1,1) {mustBeInteger, mustBePositive} = 300;
            end
            self.numRounds = numRounds;
            self.timeout = timeout;
            self.fontSize = fontSize;
            self.mode = mode;
            self.allowedLetters = unique(lower(allowedLetters));
            self.distFromCenter = distFromCenter;

            if length(self.allowedLetters) < 3
                error('NavonTask: must provide at least 3 unique allowed letters');
            end
            
            self.letterText = load("navon_letters.mat").letters;
        end
        
        function generate(self)
            % Generates a new trial, produces a list of all visual elements
            % and their locations (relative to the center of screen), and 
            % stores it in self.elements for display.
            if self.mode == "random"
                trialMode = ["global", "local"];
                trialMode = trialMode(randi(2));
            else
                trialMode = self.mode;
            end

            trialLetters = self.allowedLetters(randperm(length(self.allowedLetters), 3));

            if trialMode == "global"
                smalls = trialLetters(randi(3));
                bigs = trialLetters(trialLetters ~= smalls);
                bigs = bigs(randperm(2));
            else
                bigs = trialLetters(randi(3));
                smalls = trialLetters(trialLetters ~= bigs);
                smalls = smalls(randperm(2));
            end
                
            idx = 1;
            locations = self.distFromCenter .* [-1 0; 1 0];
            for big = bigs
                for small = smalls
                    letterIdx = 'abcdefghijklmnopqrstuvwxyz' == big;
                    text = self.letterText{letterIdx};
                    text = strrep(text, 'a', upper(small));
                    self.elements(idx).ElementType = 'navon';
                    self.elements(idx).Location = locations(idx, :);
                    self.elements(idx).Text = text;
                    self.elements(idx).Color = [255 255 255];
                    self.elements(idx).FontSize = self.fontSize;
                    idx = idx + 1;
                end
            end
        end

        function conditionFlag = check(self, state)
            % Generates a conditionFlag based on input state. If
            % check passes, returns 1. If check fails, returns -1.
            % Otherwise, return 0. Input XY must be relative to screen 
            % center
            conditionFlag = 0;
        end
    end
end
