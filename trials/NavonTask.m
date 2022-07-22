classdef NavonTask < TrialInterface
    % A class encoding a Navon task where the player chooses between two
    % targets sharing either a global or a local feature.

    properties
        numRounds
        timeout
        intro
        elements
        target
        failzone
    end
    properties (Access = private)
        mode
        allowedLetters
        letterText
        font
        fontSize
        distFromCenter
        randomizeFlag
        targetDimensions
    end
    properties(Constant)
        instructions = ['To begin, hold your cursor on the letter.', newline ...
                        '2 letters made up of smaller letters will appear.', newline ...
                        'Touch the side with the correct letter (big or small).'];
    end

    methods
        function self = NavonTask(numRounds, timeout, mode, allowedLetters, distFromCenter, fontSize, monospaceFont, targetDimensions)
            % Defines a phase of trials.
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive}
                timeout (1,1) {mustBeNonnegative}
                mode {mustBeMember(mode, ["random", "global", "local"])} = "random";
                allowedLetters {mustBeText} = 'abcdefghijklmnopqrstuvwxyz';
                distFromCenter (1,1) {mustBeInteger, mustBePositive} = 300;
                fontSize (1,1) {mustBeInteger, mustBePositive} = 40;
                monospaceFont {mustBeText} = 'Consolas';
                targetDimensions (1,2) {mustBeInteger, mustBePositive} = [200, 200]
            end
            self.numRounds = numRounds;
            self.timeout = timeout;
            self.font = monospaceFont;
            self.fontSize = fontSize;
            self.mode = mode;
            self.allowedLetters = unique(lower(allowedLetters));
            self.distFromCenter = distFromCenter;
            self.targetDimensions = targetDimensions;

            if length(self.allowedLetters) < 3
                error('NavonTask: must provide at least 3 unique allowed letters');
            end

            if ~isfile("navon_letters.mat")
                GenerateNavonLetters();
            end
            self.letterText = load("navon_letters.mat").letters;

            self.intro(1).ElementType = 'text';
            self.intro(1).Location = [0, 0];
            self.intro(1).Text = '';
            self.intro(1).Color = [255 255 255];
            self.intro(1).Font = self.font;
            self.intro(1).FontSize = self.fontSize;
            self.intro(1).VerticalSpacing = 2;

            self.intro(2) = self.intro(1);
            self.intro(2).Text = self.instructions;
            self.intro(2).Location = [0, 400];
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
            targetLetterIdx = randi(2);

            if trialMode == "global"
                smalls = trialLetters(randi(3));
                bigs = trialLetters(trialLetters ~= smalls);
                bigs = bigs(randperm(2));
                targetLetter = bigs(targetLetterIdx);
            else
                bigs = trialLetters(randi(3));
                smalls = trialLetters(trialLetters ~= bigs);
                smalls = smalls(randperm(2));
                targetLetter = smalls(targetLetterIdx);
            end
                
            idx = 1;
            locations = self.distFromCenter .* [-1 0; 1 0];
            for big = bigs
                for small = smalls
                    letterIdx = 'abcdefghijklmnopqrstuvwxyz' == big;
                    text = self.letterText{letterIdx};
                    text = strrep(text, 'a', upper(small));
                    self.elements(idx).ElementType = 'text';
                    self.elements(idx).Location = locations(idx, :);
                    self.elements(idx).Text = text;
                    self.elements(idx).Color = [255 255 255];
                    self.elements(idx).Font = self.font;
                    self.elements(idx).FontSize = self.fontSize;
                    self.elements(idx).VerticalSpacing = 1;
                    if idx == targetLetterIdx
                        self.target = self.elements(idx);
                        self.target.Dimensions = self.targetDimensions;
                    end
                    idx = idx + 1;
                end
            end

            % Set up intro screen based on target letter
            self.intro(1).Text = upper(targetLetter);
        end

        function conditionFlag = check(self, manipState, eyeState)
            % Generates a conditionFlag based on input state. If
            % check passes, returns 1. If check fails, returns -1.
            % Otherwise, return 0. Input XY must be relative to screen 
            % center
            xy = manipState(1:2);
            lim = 0.5 * self.targetDimensions;
            targetLoc = self.target.Location;
            conditionFlag = all(xy >= targetLoc - lim) && all(xy <= targetLoc + lim);
        end
    end
end
