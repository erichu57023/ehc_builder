classdef NavonTask < TrialInterface
% NAVONTASK A trial requiring the player to select the correct Navon element where a specific letter
% is either a global or local feature.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    trialType - A specifier indicating how the look and reach portions of the trial should be
%       handled. Supported values are 'look' for look-only, 'reach' for reach-only, 'segmented' to
%       separate look and reach stages, or 'free' (by default).
%    timeout - The duration in seconds that the trial should run until a timeout is triggered.
%    instructions - A struct containing elements to be displayed during the instruction phase of the
%       current trial.
%    preRound - Includes 2 elements: a center target letter and instructions.
%    elements - Includes 2 formatted text boxes with Navon elements.
%    target - Defines the correct Navon element
%    failzone - Defines elements whose surrounding zones are failure zones.

% METHODS:
%    generate - Populates all element variables with new Navon elements each round.
%    check - Checks if the input state is within any of the target or failzones.

    properties
        numRounds
        trialType
        timeout
        instructions
        preRound
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
        localColor; globalColor
    end

    methods
        function self = NavonTask(numRounds, timeout, mode, allowedLetters, distFromCenter, fontSize, monospaceFont, targetDimensions, localColor, globalColor)
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
                localColor (1,3) = [128, 128, 255];
                globalColor (1,3) = [255, 128, 128];
            end
            % Constructs a NavonTask instance.
            % INPUTS:
            %    numRounds - The number of rounds to generate in this set of trials.
            %    timeout - The duration in seconds that the trial should run until a timeout is 
            %       triggered.
            %    mode - Defines whether the experimental condition is testing for identification of
            %       local features, global features, or a random mix of the two. Allowed: "random",
            %       "global", "local"
            %    allowedLetters - A character array containing specific letters to be randomly drawn
            %       from. Defaults to the entire English alphabet.
            %    distFromCenter - The distance in pixels from the center of both element to the 
            %       center of the screen.
            %    fontSize - The font size of the local letters in the Navon element, in pts.
            %    monospaceFont - The name of an installed font for use by the text renderer. For
            %       Navon elements to be displayed properly, this must be a monospace font (all
            %       characters have the same width)
            %    targetDimensions - The dimensions of invisible bounding boxes centered at the
            %       center of each text box, which represent target zones for a pass/fail condition.
            %    localColor - An RGB triplet defining the color of the pre-round target if the 
            %       target is a local feature
            %    globalColor - An RGB triplet defining the color of the pre-round target if the 
            %       target is a global feature

            self.numRounds = numRounds;
            self.trialType = 'free';
            self.timeout = timeout;
            self.font = monospaceFont;
            self.fontSize = fontSize;
            self.mode = mode;
            self.allowedLetters = unique(lower(allowedLetters));
            self.distFromCenter = distFromCenter;
            self.targetDimensions = targetDimensions;
            self.localColor = localColor;
            self.globalColor = globalColor;

            if length(self.allowedLetters) < 3
                error('NavonTask: must provide at least 3 unique allowed letters');
            end

            % Pull data on Navon elements from navon_letters.mat. If it does not exist, call the
            % helper function.
            if ~isfile("navon_letters.mat")
                GenerateNavonLetters();
            end
            self.letterText = load("navon_letters.mat").letters;

            % Generate a constant pre-round screen
            self.preRound.ElementType = 'text';
            self.preRound.Location = [0, 0];
            self.preRound.Text = '';
            self.preRound.Color = [255 255 255];
            self.preRound.Font = self.font;
            self.preRound.FontSize = self.fontSize;
            self.preRound.VerticalSpacing = 2;

            self.generateInstructions();
        end

        function generate(self)
            % Generates a new trial, by producing a list of all visual elements and their locations 
            % (relative to the center of screen), and populating the element variables.

            if self.mode == "random"
                trialMode = ["global", "local"];
                trialMode = trialMode(randi(2));
            else
                trialMode = self.mode;
            end

            trialLetters = self.allowedLetters(randperm(length(self.allowedLetters), 3));
            targetLetterIdx = randi(2);

            if trialMode == "global"
                % If global, set the small letter constant, and randomize the other two
                smalls = trialLetters(randi(3));
                bigs = trialLetters(trialLetters ~= smalls);
                bigs = bigs(randperm(2));
                targetLetter = bigs(targetLetterIdx);
            else
                % If local, set the big letter constant, and randomize the other two
                bigs = trialLetters(randi(3));
                smalls = trialLetters(trialLetters ~= bigs);
                smalls = smalls(randperm(2));
                targetLetter = smalls(targetLetterIdx);
            end
                
            idx = 1;
            locations = self.distFromCenter .* [-1 0; 1 0];
            for big = bigs
                for small = smalls
                    % Choose the correct Navon outline from the preset list of 26
                    letterIdx = 'abcdefghijklmnopqrstuvwxyz' == big;
                    text = self.letterText{letterIdx};

                    % Fill the Navon outline with the correct small letter
                    text = strrep(text, 'a', upper(small));

                    % Populate the elements struct
                    self.elements(idx).ElementType = 'text';
                    self.elements(idx).Location = locations(idx, :);
                    self.elements(idx).Text = text;
                    self.elements(idx).Color = [255 255 255];
                    self.elements(idx).Font = self.font;
                    self.elements(idx).FontSize = self.fontSize;
                    self.elements(idx).VerticalSpacing = 1;

                    % Populate the target struct
                    if idx == targetLetterIdx
                        self.target = self.elements(idx);
                        self.target.Dimensions = self.targetDimensions;
                    end
                    idx = idx + 1;
                end
            end

            % Change center target on pre-round screen to display the target letter
            self.preRound(1).Text = upper(targetLetter);
            
            % Change pre-round color based on trial type
            if trialMode == "local"
                self.preRound(1).Color = self.localColor;
            else
                self.preRound(1).Color = self.globalColor;
            end
        end

        function conditionFlag = check(self, manipState, ~, ~, ~)
            % Generates a conditionFlag based on input state.
            % INPUTS:
            %    manipState - A vector whose first three columns are XYZ data, with XY in screen 
            %       coordinates. Each row corresponds to a unique manipulator.
            %    eyeState - A vector whose first twp columns are XY data, with XY in screen 
            %       coordinates.
            % OUTPUTS:
            %    conditionFlag - 1 if success (state within target position), 0 if timeout.
            
            xy = manipState(1, 1:2);
            lim = 0.5 * self.targetDimensions;
            targetLoc = self.target.Location;
            conditionFlag = all(xy >= targetLoc - lim) && all(xy <= targetLoc + lim);
        end
    end

    methods (Access = private)
        function generateInstructions(self)
            % Places instruction text in the center of the screen

            self.instructions.ElementType = 'text';
            self.instructions.Location = [0, 0];
            self.instructions.Color = [255 255 255];
            self.instructions.Font = 'Ariel';
            self.instructions.FontSize = 40;
            self.instructions.VerticalSpacing = 2;

            switch self.mode
                case "local"
                    instructText = ['Navon task: LOCAL', newline, ...
                        'Two big letters, each made of smaller letters, will appear.', newline, ...
                        'Touch the side where the smaller letters match the target letter.'];
                case "global"
                    instructText = ['Navon task: GLOBAL', newline, ...
                        'Two big letters, each made of smaller letters, will appear.', newline, ...
                        'Touch the side where the big letter matches the target letter.'];
                case "random"
                    instructText = ['Navon task: RANDOM', newline, ...
                        'Two big letters, each made of smaller letters, will appear.', newline, ...
                        'Touch the side that contains the target letter (may be big or small).'];
            end
            
            self.instructions.Text = instructText;
        end
    end
end
