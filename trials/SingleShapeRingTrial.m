classdef SingleShapeRingTrial < TrialInterface
    % A class encoding a trial for which a single radially-symmetric ring
    % of shapes is presented. 

    properties
        numRounds
        timeout
        elements
        target
        failzone
    end

    properties (Access = private)
        numTargets
        targetRadius
        distFromCenter
        axis
        allowedShapes = {'Circle', 'Triangle', 'Square', 'Cross'}
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
        
        function self = generate(self)
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
                totalNumShapes = min(length(self.allowedShapes), ceil(self.numTargets/2));
                validShapeIdxs = randperm(length(self.allowedShapes), totalNumShapes);
                targetShapeIdx = validShapeIdxs(randi(totalNumShapes));
                nonTargetShapes = validShapeIdxs(validShapeIdxs ~= targetShapeIdx);
    
                % Ensure non-target shapes are represented at least twice
                shapeIdxList = repmat(nonTargetShapes, 1, 1 + self.numTargets);
                shapeIdxList = shapeIdxList(1 : self.numTargets-1); 
                shapeIdxList = shapeIdxList(randperm(length(shapeIdxList)));
    
                % Add target back into list and permute to fully randomize
                shapeIdxList(end + 1) = targetShapeIdx;
                shapeIdxList = shapeIdxList(randperm(self.numTargets));
            end
            
            % Define location of all elements relative to center
            thetaList = linspace(0, 360, self.numTargets + 1) + self.axis;
            xList = self.distFromCenter * cosd(thetaList);
            yList = self.distFromCenter * sind(thetaList);
            for ii = 1:self.numTargets
                self.elements{ii, 1} = self.allowedShapes{shapeIdxList(ii)};
                self.elements{ii, 2} = [xList(ii), yList(ii)];
                self.elements{ii, 3} = self.targetRadius;
                if shapeIdxList(ii) == targetShapeIdx
                    self.target = {self.allowedShapes{targetShapeIdx}, [xList(ii), yList(ii)], self.targetRadius};
                end
            end
        end

        function conditionFlag = check(self, state)
            % Generates a conditionFlag based on manipulator state. If
            % check passes, returns 1. If check fails, returns -1.
            % Otherwise, return 0. IMPORTANT: coords XY is relative to
            % screen center.
            conditionFlag = 0;
            targetLoc = self.target{2};
            distFromTarget = norm(state([1,2]) - targetLoc);
            if state(3) && (distFromTarget <= self.targetRadius)
                conditionFlag = 1;
            end
        end
    end
end
