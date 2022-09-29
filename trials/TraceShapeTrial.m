classdef TraceShapeTrial < TrialInterface
% TRACESHAPETRIAL A trial requiring the player to trace the outline of a shape.

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
%    allowedShapes (Constant) - Defines the names of all allowed shapes, which are used to specify 
%        textures to be drawn by a DisplayManager.
%    requiredSweepDegrees (Constant) - The angular distance in degrees that the user must trace
%        through before the trial may be counted as complete.
%
% METHODS:
%    generate - Populates all element variables each round.
%    check - Checks if the input state has completed all directives.

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
        shapeType
        shapeRadius
        hasBegun; hasFinished
        thresholdRadius
        lastAngle; sweptAngle
    end
    properties(Constant)
        allowedShapes = {'Circle', 'Triangle', 'Square', 'Cross'};
        requiredSweepDegrees = 360;
    end

    methods
        function self = TraceShapeTrial(numRounds, timeout, shapeType, shapeRadius)
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive}
                timeout (1,1) {mustBeNonnegative}
                shapeType {mustBeText, mustBeMember(shapeType, {'Random', 'Circle', 'Triangle', 'Square', 'Cross'})} = 'Random';
                shapeRadius (1,1) {mustBeInteger, mustBePositive} = 200
            end
            % Constructs a TraceShapeTrial instance.
            % INPUTS: 
            %    numRounds - The number of rounds to generate in this set of trials.
            %    timeout - The duration in seconds that the trial should run until a timeout is 
            %       triggered.
            %    shapeType - The shape that should be generated for this trial. Allowed: 'Random',
            %    'Circle', 'Triangle', 'Square', 'Cross'.
            %    shapeRadius - The radius of the shape, if it were a circle of equal area.

            self.numRounds = numRounds;
            self.timeout = timeout;
            self.trialType = 'free';
            self.shapeType = shapeType;
            self.shapeRadius = shapeRadius;
            self.thresholdRadius = shapeRadius / 4;
            self.generateInstructions();
        end
        
        function generate(self)
            % Generates a new trial, by producing a list of all visual elements and their locations 
            % (relative to the center of screen), and populating the element variables.
                
            self.elements = struct();
            self.elements(1).ElementType = 'framepoly';
            if strcmp(self.shapeType, 'Random')
                self.elements(1).Shape = self.allowedShapes{randi(length(self.allowedShapes))};
            else
                self.elements(1).Shape = self.shapeType;
            end
            self.elements(1).Location = [0, 0];
            self.elements(1).Radius = self.shapeRadius;
            self.elements(1).Color = [255, 102, 102];
            self.elements(1).LineWidth = 2;

            self.target = self.elements(1);            
            generatePreRound();
            self.hasBegun = false;
            self.hasFinished = false;

            function generatePreRound()
                % Create pre-round screen based on the target shape
                
                self.preRound.ElementType = 'texture';
                self.preRound.Shape = self.elements(1).Shape;
                self.preRound.Location = [0, 0];
                self.preRound.Radius = 25;
                self.preRound.Color = [255, 255, 255];
            end
        end

        function conditionFlag = check(self, manipState, ~, ~, ~)
            % Generates a conditionFlag based on input state.
            % INPUTS:
            %    manipState - A matrix whose first three columns are XYZ data, with XY in screen 
            %       coordinates. Each row corresponds to a unique manipulator.
            %    eyeState - A vector whose first twp columns are XY data, with XY in screen 
            %       coordinates.
            % OUTPUTS:
            %    conditionFlag - 1 if success (state within target position), 0 if timeout.
            
            % Measure input angle
            x = manipState(1, 1); y = manipState(1, 2);
            theta = atan2d(y, x);
            conditionFlag = 0;

            % Check if tracing has finished and state has returned to center.
            if self.hasFinished && norm([x, y]) <= self.thresholdRadius
                conditionFlag = 1;
                return
            end

            if ~self.hasBegun
                % Check if state is close enough to the shape to begin tracing.
                if norm([x, y]) > self.shapeRadius * 0.9
                    self.hasBegun = true;
                    self.sweptAngle = 0;
                    self.lastAngle = theta;
                end
            else
                % Calculate sweep angle since last sample, and add it to the sweep angle.
                dTheta = theta - self.lastAngle + [-360, 0, 360];
                [~, mindex] = min(abs(dTheta));
                self.sweptAngle = self.sweptAngle + dTheta(mindex);
                self.lastAngle = theta;

                % Check if sweep angle is at least the required amount to stop tracing
                if abs(self.sweptAngle) >= self.requiredSweepDegrees
                    % Set target color from red to blue and add a new target in the center for
                    % player to return to
                    self.elements(1).Color = [102, 102, 255];
                    self.elements(2).ElementType = 'texture';
                    self.elements(2).Shape = self.elements(1).Shape;
                    self.elements(2).Location = [0, 0];
                    self.elements(2).Radius = 25;
                    self.elements(2).Color = [255, 255, 255];

                    self.hasFinished = true;
                end
            end
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
            
            instructText = ['Trace shape task', newline, ...
                'The outline of a shape matching the center target will appear.', newline, ...
                'Trace the shape until the center target reappears, and return to the center.'];

            self.instructions.Text = instructText;
        end
    end
end
