classdef SingleShapeRingTrial < TrialInterface
% SINGLESHAPERINGTRIAL A trial requiring the player to pick the correct shape out of a single
%    radially-symmetric ring of equidistant shapes.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    trialType - A specifier indicating how the look and reach portions of the trial should be
%       handled. Supported values are 'look' for look-only, 'reach' for reach-only, 'segmented' to
%       separate look and reach stages, or 'free' (by default).
%    timeout - The duration in seconds that the trial should run until a timeout is triggered
%    instructions - A struct containing elements to be displayed during the instruction phase of the
%       current trial.
%    preRound - Includes 2 elements: a center target shape and instructions
%    elements - Includes a specified number of shapes arranged in a ring pattern.
%    target - Defines the target shape whose surrounding zone is a pass zone.
%    failzone - Defines target shapes whose surrounding zones are failure zones.
%    allowedShapes (Constant) - Defines the names of all allowed shapes, which are used to specify 
%        textures to be drawn by a DisplayManager.
%
% METHODS:
%    generate - Populates all element variables with new shapes and locations each round.
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
        numTargets
        targetRadius
        distFromCenter
        axis
        checkFcn; segment; preCheck;
    end
    properties(Constant)
        allowedShapes = {'Circle', 'Triangle', 'Square', 'Cross'};
        startLookBeep = @(~) Beeper(400, 0.7, 0.1);
        successBeep = @(~) Beeper(1000, 0.7, 0.1);
        failBeep = @(~) Beeper(200, 0.7, 0.1)
    end

    methods
        function self = SingleShapeRingTrial(numRounds, trialType, timeout, numTargets, targetRadius, axis, distFromCenter)
            arguments
                numRounds (1,1) {mustBeInteger, mustBePositive};
                trialType {mustBeMember(trialType, {'look', 'reach', 'free', 'segmented'})}
                timeout (1,1) {mustBeNonnegative};
                numTargets (1,1) {mustBeInteger, mustBePositive};
                targetRadius (1,1) {mustBeInteger, mustBePositive} = 25
                axis (1,1) {mustBeInteger, mustBeNonnegative} = 0
                distFromCenter (1,1) {mustBeInteger, mustBeGreaterThan(distFromCenter, targetRadius)} = 200
            end
            % Constructs a SingleShapeRingTrial instance.
            % INPUTS:
            %    numRounds - The number of rounds to generate in this set of trials.
            %    trialType - A specifier indicating how the look and reach portions of the trial 
            %       should be handled. Supported values are 'look' for look-only, 'reach' for 
            %       reach-only, 'segmented' to separate look and reach stages, or 'free'.
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

            self.trialType = trialType;
            switch trialType
                case 'look'
                    self.checkFcn = @self.checkLookOnly;
                case 'reach'
                    self.checkFcn = @self.checkReachOnly;
                case 'free'
                    self.checkFcn = @self.checkFree;
                case 'segmented'
                    self.segment = 1;
                    self.checkFcn = @self.checkSegmented;
            end

            self.numTargets = numTargets;
            self.targetRadius = targetRadius;
            self.distFromCenter = distFromCenter;
            self.axis = axis;
            self.generateInstructions();
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

            % Add the target to the end of the elements struct so that it can be hidden to signal
            % start of a reach segment
            self.elements(self.numTargets + 1) = self.target;
            self.elements(self.numTargets + 1).Location = [0, 0];

            % Populate the preRound struct and change the center shape based on the target shape
            self.preRound = self.target;
            self.preRound.Location = [0, 0];

            % Reset the segment stage for segmented mode.
            self.segment = 1;
            self.preCheck = 0;
        end

        function conditionFlag = check(self, manipState, eyeState, manipHomeFlags, eyeHomeFlag)
            % Generates a conditionFlag based on input state. 
            % INPUTS:
            %    manipState - A vector whose first three columns are XYZ data, with XY in screen 
            %       coordinates. Each row corresponds to a unique manipulator.
            %    eyeState - A vector whose first two columns are XY data, with XY in screen 
            %       coordinates.
            %    manipHomeFlags - A boolean that indicates if manipulators are in home positions.
            %    eyeHomeFlag - A boolean that indicates if eye tracker is in home position.
            %
            % OUTPUTS:
            %    conditionFlag - 1 if success (state within target position), 0 if timeout.

            % This pre-check stage will only run once, and hides the element on the center of the
            % screen for the trial types that don't require a visual cue to begin reaching.
            if ~self.preCheck
                switch self.trialType
                    case 'look'
                        self.startLookBeep()
                    case 'reach'
                        self.elements(self.numTargets + 1).ElementType = 'hide';
                    case 'free'
                        self.startLookBeep()
                        self.elements(self.numTargets + 1).ElementType = 'hide';
                    case 'segmented'
                        self.startLookBeep()
                end
                self.preCheck = 1;
            end

            % This runs every time.
            if any(isnan(manipState), 'all') || any(isnan(eyeState), 'all'); conditionFlag = 0; return; end

            % Only check the end-trial manipulator (the last one in the list)
            conditionFlag = self.checkFcn(manipState, eyeState, manipHomeFlags, eyeHomeFlag);
            if conditionFlag == 1
                self.successBeep();
            elseif conditionFlag == -1
                self.failBeep();
            end
        end
    end

    methods (Access = private)
        % self.check() split into different check functions for each trial type for runtime efficiency.

        function conditionFlag = checkLookOnly(self, ~, eyeState, manipHomeFlags, ~)
            % Checks if the look is on-target, and fails if the manipulator leaves the center 
            % target.
            targetLoc = self.target.Location;
            
            noReach = manipHomeFlags(1);
            if ~noReach; conditionFlag = -1; return; end
            
            distFromTarget = norm(eyeState(1:2) - targetLoc);
            conditionFlag = distFromTarget <= self.target.Radius * 2;
        end

        function conditionFlag = checkReachOnly(self, manipState, ~, ~, eyeHomeFlag)
            % Checks if the reach is on-target, and fails if the eye position leaves the center 
            % target.
            targetLoc = self.target.Location;
            
            noLook = eyeHomeFlag;
            if ~noLook; conditionFlag = -1; return; end
            
            distFromTarget = norm(manipState(end, 1:2) - targetLoc);
            conditionFlag = distFromTarget <= self.target.Radius;
        end

        function conditionFlag = checkFree(self, manipState, ~, ~, ~)
            % Checks if the reach is on-target, with no fail condition.
            targetLoc = self.target.Location;
            distFromTarget = norm(manipState(end, 1:2) - targetLoc);
            conditionFlag = distFromTarget <= self.target.Radius;
        end

        function conditionFlag = checkSegmented(self, manipState, eyeState, manipHomeFlags, ~)
            % First checks if look is on-target, and then begins a reach check.
            targetLoc = self.target.Location;

            if (self.segment == 1)
                % Start with a look-only segment.
                conditionFlag = 0;
                
                noReach = manipHomeFlags(1);
                if ~noReach; conditionFlag = -1; return; end
            
                distFromTarget = norm(eyeState(1:2) - targetLoc);
                if distFromTarget <= self.target.Radius * 2
                    self.elements(self.numTargets + 1).ElementType = 'hide';
                    self.segment = 2;
                end
            elseif (self.segment == 2)
                % End with a free-reach segment.
                distFromTarget = norm(manipState(end, 1:2) - targetLoc);
                conditionFlag = distFromTarget <= self.target.Radius;
            end
        end

        function generateInstructions(self)
            % Places instruction text in the center of the screen

            self.instructions.ElementType = 'text';
            self.instructions.Location = [0, 0];
            self.instructions.Color = [255 255 255];
            self.instructions.Font = 'Ariel';
            self.instructions.FontSize = 40;
            self.instructions.VerticalSpacing = 2;
            
            switch self.trialType
                case 'look'
                    instructText = ['Shape ring: LOOK-ONLY', newline, ...
                        'An outer target matching the center target will appear.', newline, ...
                        'Look for the outer target when you hear the beep.', newline, ...
                        'Do not reach for the outer target.'];
                case 'reach'
                    instructText = ['Shape ring: REACH-ONLY', newline, ...
                        'An outer target matching the center target will appear.', newline, ...
                        'Touch the outer target when the center target disappears.', newline, ...
                        'Do not look for the outer target.'];
                case 'free'
                    instructText = ['Shape ring: FREE', newline, ...
                        'An outer target matching the center target will appear.', newline, ...
                        'Touch the outer target when the center target disappears.', newline, ...
                        'You may look for the outer target.'];
                case 'segmented'
                    instructText = ['Shape ring: SEGMENTED', newline, ...
                        'An outer target matching the center target will appear.', newline, ...
                        'Look for the outer target when you hear the beep.', newline, ...
                        'When the center target disappears, you may touch the outer target.'];
            end

            self.instructions.Text = instructText;
        end
    end
end
