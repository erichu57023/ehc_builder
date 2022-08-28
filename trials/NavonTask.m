classdef NavonTask < TrialInterface
% NAVONTASK A trial requiring the player to select the correct Navon element where a specific letter
% is either a global or local feature.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    timeout - The duration in seconds that the trial should run until a timeout is triggered.
%    intro - Includes 2 elements: a center target letter and instructions.
%    elements - Includes 2 formatted text boxes with Navon elements.
%    target - Defines the correct Navon element
%    failzone - Defines elements whose surrounding zones are failure zones.
%    instructions (Constant) - The text to be displayed in the instruction text box during the intro
%        phase.
%
% METHODS:
%    generate - Populates all element variables with new Navon elements each round.
%    check - Checks if the input state is within any of the target or failzones.

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

            % Pull data on Navon elements from navon_letters.mat. If it does not exist, call the
            % helper function.
            if ~isfile("navon_letters.mat")
                GenerateNavonLetters();
            end
            self.letterText = load("navon_letters.mat").letters;

            % Generate a constant intro screen
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

            % Change center target on intro screen to display the target letter
            self.intro(1).Text = upper(targetLetter);
        end

        function conditionFlag = check(self, manipState, eyeState)
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
end
