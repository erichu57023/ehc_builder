classdef SingleShapeRingTrial < TrialInterface
% SINGLESHAPERINGTRIAL A trial requiring the player to pick the correct shape out of a single
%    radially-symmetric ring of equidistant shapes.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    timeout - The duration in seconds that the trial should run until a timeout is triggered
%    intro - Includes 2 elements: a center target shape and instructions
%    elements -Includes a specified number of shapes arranged in a ring pattern.
%    target - Defines the target shape whose surrounding zone is a pass zone.
%    failzone - Defines target shapes whose surrounding zones are failure zones.
%    allowedShapes (Constant) - Defines the names of all allowed shapes, which are used to specify 
%        textures to be drawn by a DisplayManager.
%    instructions (Constant) - The text to be displayed in the instruction text box during the intro
%        phase.
%
% METHODS:
%    generate - Populates all element variables with new shapes and locations each round.
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
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive};
                timeout (1,1) {mustBeNonnegative};
                numTargets (1,1) {mustBeInteger, mustBePositive};
                targetRadius (1,1) {mustBeInteger, mustBePositive} = 25
                axis (1,1) {mustBeInteger, mustBeNonnegative} = 0
                distFromCenter (1,1) {mustBeInteger, mustBeGreaterThan(distFromCenter, targetRadius)} = 200
            end
            % Constructs a SingleShapeRingTrial instance.
            % INPUTS:
            %    numRounds - The number of rounds to generate in this set of trials.
            %    timeout - The duration in seconds that the trial should run until a timeout is 
            %       triggered.
            %    numTargets - The number of shapes to display each round.
            %    targetRadius - The radius of each shape to be displayed, represented as the radius 
            %       of a circle with the same area.
            %    axis - The angular skew in degrees by which the ring should be offset. Can be used 
            %       to make trials horizontally symmetric, for example.
            %    distFromCenter - The distance in pixels from the center of each shape to the center
            %       of the screen.
            
            self.numRounds = numRounds;
            self.timeout = timeout;
            self.numTargets = numTargets;
            self.targetRadius = targetRadius;
            self.distFromCenter = distFromCenter;
            self.axis = axis;
        end
        
        function generate(self)
            % Generates a new trial, by producing a list of all visual elements and their locations 
            % (relative to the center of screen), and populating the element variables.

            if self.numTargets == 1
                % If only 1 target, randomize axis in 45 degree increments
                targetShapeIdx = randi(length(self.allowedShapes));
                shapeIdxList = targetShapeIdx;
                self.axis = 45 * (randi(8) - 1);

            elseif self.numTargets == 2
                % If only 2 targets, select 2 shapes at random and make one of them the target
                shapeIdxList = randperm(length(self.allowedShapes), 2);
                targetShapeIdx = shapeIdxList(randi(2));

            else
                % Generate a random list of shapes to display, based on how many targets are wanted.
                % The target must only show up once, and all other targets must be represented at
                % least twice.
                totalNumShapes = min(length(self.allowedShapes), ceil(self.numTargets/2));
                validShapeIdxs = randperm(length(self.allowedShapes), totalNumShapes);
                targetShapeIdx = validShapeIdxs(randi(totalNumShapes));
                nonTargetShapes = validShapeIdxs(validShapeIdxs ~= targetShapeIdx);
    
                % Ensure non-target shapes are represented at least twice by even distribution
                % (only the target can be displayed singly)
                shapeIdxList = repmat(nonTargetShapes, 1, 1 + self.numTargets);
                shapeIdxList = shapeIdxList(1 : self.numTargets-1); 
                shapeIdxList = shapeIdxList(randperm(length(shapeIdxList)));
    
                % Add target back into element list and permute to fully randomize
                shapeIdxList(end + 1) = targetShapeIdx;
                shapeIdxList = shapeIdxList(randperm(self.numTargets));
            end
            
            % Calculate location of all elements relative to screen center
            thetaList = linspace(0, 360, self.numTargets + 1) + self.axis;
            xList = self.distFromCenter * cosd(thetaList);
            yList = self.distFromCenter * sind(thetaList);

            % Populate the elements struct
            for ii = 1:self.numTargets
                self.elements(ii).ElementType = 'texture';
                self.elements(ii).Shape = self.allowedShapes{shapeIdxList(ii)};
                self.elements(ii).Location = [xList(ii), yList(ii)];
                self.elements(ii).Radius = self.targetRadius;
                self.elements(ii).Color = [255, 255, 255];

                % Populate the target struct
                if shapeIdxList(ii) == targetShapeIdx
                    self.target = self.elements(ii);
                end
            end

            % Populate the intro struct and change the center shape based on the target shape
            self.intro = self.target;
            self.intro.Location = [0 0];
            self.intro(2).ElementType = 'text';
            self.intro(2).Location = [0, 400];
            self.intro(2).Text = self.instructions;
            self.intro(2).Color = [255 255 255];
            self.intro(2).Font = 'Consolas';
            self.intro(2).FontSize = 40;
            self.intro(2).VerticalSpacing = 2;

            % No failzones are implemented; they may be added here.
        end

        function conditionFlag = check(self, stateXYZ)
            % Generates a conditionFlag based on input state.
            % INPUTS:
            %    stateXYZ - A vector whose first three columns are XYZ data (usually manipulator
            %    state), with XY in screen coordinates.
            % OUTPUTS:
            %    conditionFlag - 1 if success (state within target position), 0 if timeout.

            targetLoc = self.target.Location;
            distFromTarget = norm(stateXYZ(1:2) - targetLoc);
            conditionFlag = distFromTarget <= self.target.Radius;
        end
    end
end
