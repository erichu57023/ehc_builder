classdef TraceShapeTrial < TrialInterface
    % A class encoding a trial where the player traces the outline of a
    % shape

    properties
        numRounds
        timeout
        intro
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
        instructions = ['To begin, hold your cursor on the target. A shape will appear.', newline ...
                        'Trace the outline of the shape, and return to the center target.'];
        requiredSweepDegrees = 360;
    end

    methods
        function self = TraceShapeTrial(numRounds, timeout, shapeType, shapeRadius)
            % Defines a phase of trials.
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive}
                timeout (1,1) {mustBeNonnegative}
                shapeType {mustBeText, mustBeMember(shapeType, {'Random', 'Circle', 'Triangle', 'Square', 'Cross'})} = 'Random';
                shapeRadius (1,1) {mustBeInteger, mustBePositive} = 200
            end
            self.numRounds = numRounds;
            self.timeout = timeout;
            self.shapeType = shapeType;
            self.shapeRadius = shapeRadius;
            self.thresholdRadius = shapeRadius / 3;
        end
        
        function generate(self)
            % Generates a new trial, produces a list of all visual elements
            % and their locations (relative to the center of screen), and 
            % stores it in self.elements for display.
                
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
            generateIntro();
            self.hasBegun = false;
            self.hasFinished = false;

            function generateIntro()
                % Create intro screen
                
                self.intro(1).ElementType = 'texture';
                self.intro(1).Shape = self.elements(1).Shape;
                self.intro(1).Location = [0, 0];
                self.intro(1).Radius = 25;
                self.intro(1).Color = [255, 255, 255];

                self.intro(2).ElementType = 'text';
                self.intro(2).Location = [0, 400];
                self.intro(2).Text = self.instructions;
                self.intro(2).Color = [255 255 255];
                self.intro(2).Font = 'Consolas';
                self.intro(2).FontSize = 40;
                self.intro(2).VerticalSpacing = 2;
            end
        end

        function conditionFlag = check(self, manipState, eyeState)
            % Generates a conditionFlag based on input state. If
            % check passes, returns 1. If check fails, returns -1.
            % Otherwise, return 0. Input XY must be relative to screen 
            % center.
            x = manipState(1); y = manipState(2);
            theta = atan2d(y, x);
            conditionFlag = 0;

            if self.hasFinished && norm([x, y]) <= self.thresholdRadius
                conditionFlag = 1;
                return
            end

            if ~self.hasBegun
                if norm([x, y]) > self.thresholdRadius
                    self.hasBegun = true;
                    self.sweptAngle = 0;
                    self.lastAngle = theta;
                end
            else
                dTheta = theta - self.lastAngle + [-360, 0, 360];
                [~, mindex] = min(abs(dTheta));
                self.sweptAngle = self.sweptAngle + dTheta(mindex);
                self.lastAngle = theta;
                if abs(self.sweptAngle) >= self.requiredSweepDegrees
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
end
