classdef SingleShapeRingTrial < TrialInterface
    % A class encoding a trial for which a single radially-symmetric ring
    % of shapes is presented. 

    properties
        numRounds
        timeout
        intro
        elements
        target
        failzone
    end
    properties (Access = private)
        numTargets
        targetRadius
        distFromCenter
        axis
    end
    properties(Constant)
        allowedShapes = {'Circle', 'Triangle', 'Square', 'Cross'};
        instructions = ['To begin, hold your cursor on the shape.', newline ...
                        'A number of targets will appear.', newline ...
                        'Touch the target that matches that shape.'];
    end

    methods
        function self = SingleShapeRingTrial(numRounds, timeout, numTargets, targetRadius, axis, distFromCenter)
            % Defines a phase of trials.
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive};
                timeout (1,1) {mustBeNonnegative};
                numTargets (1,1) {mustBeInteger, mustBePositive};
                targetRadius (1,1) {mustBeInteger, mustBePositive} = 50
                axis (1,1) {mustBeInteger, mustBeNonnegative} = 0
                distFromCenter (1,1) {mustBeInteger, mustBeGreaterThan(distFromCenter, targetRadius)} = 200
            end
            self.numRounds = numRounds;
            self.timeout = timeout;
            self.numTargets = numTargets;
            self.targetRadius = targetRadius;
            self.distFromCenter = distFromCenter;
            self.axis = axis;
        end
        
        function generate(self)
            % Generates a new trial, produces a list of all visual elements
            % and their locations (relative to the center of screen), and 
            % stores it in self.elements for display.

            if self.numTargets == 1
                % If only 1 target, randomize axis
                targetShapeIdx = randi(length(self.allowedShapes));
                shapeIdxList = targetShapeIdx;
                self.axis = 45 * (randi(8) - 1);

            elseif self.numTargets == 2
                shapeIdxList = randperm(length(self.allowedShapes), 2);
                targetShapeIdx = shapeIdxList(randi(2));

            else
                % Generate a random list of shapes to display
                totalNumShapes = min(length(self.allowedShapes), ceil(self.numTargets/2));
                validShapeIdxs = randperm(length(self.allowedShapes), totalNumShapes);
                targetShapeIdx = validShapeIdxs(randi(totalNumShapes));
                nonTargetShapes = validShapeIdxs(validShapeIdxs ~= targetShapeIdx);
    
                % Ensure non-target shapes are represented at least twice
                % (only the target can be displayed singly)
                shapeIdxList = repmat(nonTargetShapes, 1, 1 + self.numTargets);
                shapeIdxList = shapeIdxList(1 : self.numTargets-1); 
                shapeIdxList = shapeIdxList(randperm(length(shapeIdxList)));
    
                % Add target back into list and permute to fully randomize
                shapeIdxList(end + 1) = targetShapeIdx;
                shapeIdxList = shapeIdxList(randperm(self.numTargets));
            end
            
            % Define location of all elements relative to screen center
            thetaList = linspace(0, 360, self.numTargets + 1) + self.axis;
            xList = self.distFromCenter * cosd(thetaList);
            yList = self.distFromCenter * sind(thetaList);
            for ii = 1:self.numTargets
                self.elements(ii).ElementType = 'texture';
                self.elements(ii).Shape = self.allowedShapes{shapeIdxList(ii)};
                self.elements(ii).Location = [xList(ii), yList(ii)];
                self.elements(ii).Radius = self.targetRadius;
                self.elements(ii).Color = [255, 255, 255];
                if shapeIdxList(ii) == targetShapeIdx
                    self.target = self.elements(ii);
                end
            end

            % Change intro screen based on target shape
            self.intro = self.target;
            self.intro.Location = [0 0];

            self.intro(2).ElementType = 'text';
            self.intro(2).Location = [0, 400];
            self.intro(2).Text = self.instructions;
            self.intro(2).Color = [255 255 255];
            self.intro(2).Font = 'Consolas';
            self.intro(2).FontSize = 40;
            self.intro(2).VerticalSpacing = 2;
        end

        function conditionFlag = check(self, stateXYZ)
            % Generates a conditionFlag based on input state. If
            % check passes, returns 1. If check fails, returns -1.
            % Otherwise, return 0. Input XY must be relative to screen 
            % center.

            targetLoc = self.target.Location;
            distFromTarget = norm(stateXYZ(1:2) - targetLoc);
            conditionFlag = distFromTarget <= self.target.Radius;
        end
    end
end
