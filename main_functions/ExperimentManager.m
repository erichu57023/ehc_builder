classdef ExperimentManager < handle
% EXPERIMENTMANAGER A centralized manager for EHC experiments. This function handles setup and 
% calibration for any eye trackers or manipulators, and provides a main loop for coordinating trials 
% with data collection and display updates.
%
% PROPERTIES:
%    data (struct) - Stores all experiment data
%
% METHODS:
%    addTrial - Adds a trial to the ongoing experiment
%    calibrate - Connects and calibrates designated hardware
%    run - Plays each trial in the order they were added
%    close - Closes all connections and cleans up the experiment
%
% See also: DISPLAYMANAGER, EYETRACKERINTERFACE, MANIPULATORINTERFACE, TRIALINTERFACE

    properties
        data = struct
        options = struct
    end
    properties (Access = private)
        display
        eyeTracker
        manipulators; numManipulators
        filename
        practiceTrials; practiceClasses;
        trials
        state
    end

    methods (Static, Access = private)
        function options = SetDefaultOptions(overrideOptions)
            % Set default options
            options.background8BitRGB = [0, 0, 0];
            options.driftCorrKey = 'M';
            options.calibrateKey = 'N';
            options.escapeKey = 'Escape';
            options.feedbackColors = [255, 102, 102; 102, 255, 102]; % [failColor; successColor]
            options.feedbackDuration = 0.5; % Duration of visual feedback for target outcome in secs
            options.successBeep = @(~) Beeper(1000, 0.7, 0.1);
            options.failBeep = @(~) Beeper(200, 0.7, 0.1);

            options.preRoundMinDuration = 1;
            options.preRoundMaxDuration = 3;
            options.eyeFixateRadius = 25;
            options.eyeFixateMinDuration = 0.2;
            options.eyeMaintainRadius = 50;
            options.eyeMaintainMaxMisses = 5;

            % Override specific options
            if ~isempty(overrideOptions)
                optionsToSet = fieldnames(overrideOptions);
                for ii = 1:length(optionsToSet)
                    if isfield(options, optionsToSet{ii})
                        options.(optionsToSet{ii}) = overrideOptions.(optionsToSet{ii});
                    else
                        error('ExperimentManager:invalidOption', '%s is not a valid option', optionsToSet{ii});
                    end
                end
            end
        end
    end

    methods
        function self = ExperimentManager(screenID, eyeTracker, manipulatorList, filename, options)     % Init function
            arguments
                screenID (1,1) {mustBeInteger, mustBeNonnegative}
                eyeTracker (1,1) {mustBeA(eyeTracker, 'EyeTrackerInterface')}
                manipulatorList (1,:) {mustBeA(manipulatorList, 'ManipulatorInterface')}
                filename {mustBeText}
                options = struct([]);
            end
            % Constructs an ExperimentManager instance.
            % INPUTS:
            %    screenID - The ID of the screen to display to, as returned by PsychToolbox
            %    eyeTracker - An instance of EyeTrackerInterface
            %    manipulatorList - An array of ManipulatorInterface objects.
            %    filename - A filepath to which output data will be saved.
            %    options - A struct containing options to be overridden (valid fields are shown in
            %       SetDefaultOptions().

            self.options = ExperimentManager.SetDefaultOptions(options);
            self.options.activeKeys = arrayfun(@KbName, {self.options.driftCorrKey, self.options.calibrateKey, self.options.escapeKey});

            self.display = DisplayManager(screenID, self.options.background8BitRGB/255);
            self.eyeTracker = eyeTracker;
            self.manipulators = manipulatorList;
            self.numManipulators = length(manipulatorList);
            self.filename = filename;
            self.trials = {};
            self.practiceTrials = {};
            self.practiceClasses = {};
            
            self.data.EyeTracker.Class = class(self.eyeTracker);
            self.data.Manipulators.Class = arrayfun(@(obj)class(obj), self.manipulators, 'UniformOutput', false);
            self.data.NumTrials = 0;
        end

        function addPractice(self, trial, targetAccuracy)
            arguments
                self
                trial (1,1) {mustBeA(trial, 'TrialInterface')}
                targetAccuracy {mustBeScalarOrEmpty, mustBeNonnegative} = [];
            end
            % Adds a trial to the end of the practice queue, along with its requested accuracy
            % INPUTS:
            %    trial - An instance of TrialInterface
            %    targetAccuracy - A value from 0 to 1 that denotes the desired accuracy of this
            %       trial type. This will be used to automatically adjust trial parameters using
            %       data saved in the practiceData struct.

            if ismember(class(trial), self.practiceClasses)
                error('ExperimentManager:trialInvalid', 'Only one practice trial of any particular class is allowed')
            end
            self.practiceTrials{end + 1} = {trial, targetAccuracy};
            self.practiceClasses{end + 1} = class(trial);
        end

        function addTrial(self, trial)
            arguments
                self
                trial (1,1) {mustBeA(trial, 'TrialInterface')}
            end
            % Adds a trial to the end of the trial queue. 
            % INPUTS:
            %    trial - An instance of TrialInterface

            self.trials{end + 1} = trial;
            self.data.NumTrials = self.data.NumTrials + 1;
        end

        function successFlag = calibrate(self)
            % Initializes display and hardware interfaces, and runs all calibration routines.
            % Returns prematurely if an error occurs.
            % OUTPUTS:
            %    successFlag - Returns true if all calibrations completed without error

            successFlag = false;
            
            % Open a window and save properties of the detected display
            if ~self.display.openWindow(); return; end
            prop = properties('DisplayManager');
            for ii = 1 : length(prop)
                self.data.Display.(prop{ii}) = self.display.(prop{ii});
            end

            % Set up eye tracker
            if ~self.eyeTracker.establish(self.display); return; end
            if ~self.eyeTracker.calibrate(); return; end
            self.data.EyeTracker.calibrationFcn = self.eyeTracker.calibrationFcn;
            self.data.EyeTracker.homePosition = self.eyeTracker.homePosition;
            self.data.EyeTracker.homeRadius = self.eyeTracker.homeRadius;

            % Set up manipulators
            if ~all(self.manipulators.establishAll(self.display)); return; end
            if ~all(self.manipulators.calibrateAll()); return; end
            self.data.Manipulators.calibrationFcn = arrayfun(@(obj)obj.calibrationFcn, self.manipulators, 'UniformOutput', false);
            self.data.Manipulators.homePosition = arrayfun(@(obj)obj.homePosition, self.manipulators, 'UniformOutput', false);
            self.data.Manipulators.homeRadius = arrayfun(@(obj)obj.homeRadius, self.manipulators, 'UniformOutput', false);
            
            successFlag = true;
        end

        function run(self)
            % Runs each practice and actual trial in the order they were added, using the following 
            % process:
            % 1) Ask the trial to generate a series of on-screen elements, target and fail zones,
            % and an optional pre-round screen.
            % 2) Play the pre-round screen, which requires the manipulator to be in a defined
            % position, and drift-correct the eye tracker on that position
            % 3) Play the trial, displaying all elements on screen, collecting eye and manipulator 
            % data each loop, and passing that into the trial object to check for pass/fail
            % conditions
            % 4) For all rounds in the trial that do not pass with success (outcome ~= 1), save them
            % in a temporary buffer to be replayed later. (actual trial only)
            % 5) Saves data to the output file after completion of each trial
            
            % Tell the operator that they can perform drift correction/calibration during
            % pre-round phase.
            cprintf('RED*','%s: drift correction, %s: calibration, %s: terminate\n', ...
                self.options.driftCorrKey, self.options.calibrateKey, self.options.escapeKey);

            % Run each practice trial
            practiceData = struct();
            practiceData.EyeTracker = self.data.EyeTracker;
            practiceData.Manipulators = self.data.Manipulators;
            for ii = 1:length(self.practiceTrials)
                trial = self.practiceTrials{ii}{1};
                practiceData(ii).TargetAccuracy = self.practiceTrials{ii}{2};
                trial.instructions.Text = ['PRACTICE::: ', trial.instructions.Text];
                displayInstructions(trial)
                runTrial(trial, true);

                % Ask the trial class to evaluate the outcome
                practiceOutcome = trial.evaluatePractice(practiceData(ii));
                self.data.PracticeData(ii).Class = class(trial);
                self.data.PracticeData(ii).TargetAccuracy = practiceData(ii).TargetAccuracy;
                self.data.PracticeData(ii).Outcome = practiceOutcome;
            end
            
            % Save practice data to output file
            Data = self.data;
            save(self.filename, 'Data');

            % Run each actual trial
            for ii = 1:length(self.trials)
                trial = self.trials{ii};
                displayInstructions(trial);
                runTrial(trial, false);
            end

            function displayInstructions(trial)
                if ~isempty(trial.instructions)
                    cprintf('BLUE*', 'SPACE to continue\n');
                    while true
                        self.display.drawElements(trial.instructions);
                        self.display.update();

                        [~, ~, keyCode] = KbCheck();
                        if keyCode(32)
                            break
                        elseif keyCode(KbName(self.options.escapeKey))
                            self.close();
                            sca;
                            error('ExperimentManager:manualTermination', '%s detected, only the last completed trial will be saved', ...
                                self.options.escapeKey);
                        end
                    end
                    self.manipulators.resetAll();
                end
            end

            function runTrial(trial, practiceFlag)
                % Runs a single trial defined by TrialInterface

                failBuffer = {};
                
                if practiceFlag
                    practiceData(ii).NumRounds = trial.numRounds;
                    practiceData(ii).Timeout = trial.timeout;
                    practiceData(ii).Outcomes = zeros(1, trial.numRounds);
                else
                    self.data.TrialData(ii).Class = class(trial);
                    self.data.TrialData(ii).NumRounds = trial.numRounds;
                    self.data.TrialData(ii).Timeout = trial.timeout;
                    self.data.TrialData(ii).Outcomes = zeros(1, trial.numRounds);
                end

                jj = 1;
                while (jj <= trial.numRounds) || ~isempty(failBuffer)
                    % Generate a new round, which populates the instance properties of the
                    % Trial object with new elements
                    trial.generate();

                    % If all the rounds have been completed and there are some that failed, rerun
                    % those.
                    if (jj > trial.numRounds) && ~isempty(failBuffer)
                        trial.preRound = failBuffer{1}.preRound;
                        trial.elements = failBuffer{1}.elements;
                        trial.target = failBuffer{1}.target;
                        trial.failzone = failBuffer{1}.failzone;
                        failBuffer(1) = [];
                    end
                    
                    % Save the trial details
                    if practiceFlag
                        practiceData(ii).Elements{jj, 1} = trial.elements;
                        practiceData(ii).Targets{jj, 1} = trial.target;
                        practiceData(ii).Failzones{jj, 1} = trial.failzone;
                    else
                        self.data.TrialData(ii).Elements{jj, 1} = trial.elements;
                        self.data.TrialData(ii).Targets{jj, 1} = trial.target;
                        self.data.TrialData(ii).Failzones{jj, 1} = trial.failzone;
                    end

                    % Clear the display
                    self.display.emptyScreen();
                    self.display.update();

                    % Provide instructions and perform gaze correction on center target
%                     self.eyeTracker.driftCorrect() 
                    playPreRoundPhase(); 

                    % Reset all non-primary manipulators
                    if self.numManipulators > 1
                        self.manipulators(2:end).resetAll();
                    end

                    % Play the trial and record all data
                    playTrialPhase(); 
                    
                    jj = jj + 1;
                end

                % Save data for each completed trial during runtime
                if ~practiceFlag
                    Data = self.data;
                    save(self.filename, 'Data');
                end

                function playPreRoundPhase()
                    % Display trial instructions and perform gaze correction on center target
                    
                    manipCenterXYZ = nan(1,3);
                    eyeCenterXY = nan(1,2);
                    eyeMaintainMisses = 0;
                    manipResetFlag = true;
                    eyeResetFlag = true;

                    if ~isempty(trial.preRound)                        
                        % Require the primary manipulator to be on the center target for a random
                        % number of seconds, to avoid prediction of stimulus onset
                        startTime = GetSecs;
                        readySetGo = self.options.preRoundMinDuration + ...
                            rand * (self.options.preRoundMaxDuration - self.options.preRoundMinDuration);

                        while (GetSecs - startTime < readySetGo)
                            % Check if operator wants to do eye tracker drift-correction or
                            % recalibration
                            operatorInterruptCheck();

                            % Poll the eye tracker
                            if self.eyeTracker.available()
                                eyeRawState = self.eyeTracker.poll();
                                eyeCenterXY = self.eyeTracker.calibrationFcn(eyeRawState);

                                % Eye check pt 1: fixation on a small central target
                                if (GetSecs - startTime) <= self.options.eyeFixateMinDuration
                                    eyeResetFlag = norm(eyeCenterXY) > self.options.eyeFixateRadius;
                                
                                % Eye check pt 2: maintenance on a larger central target
                                else
                                    if norm(eyeCenterXY) > self.options.eyeMaintainRadius
                                        eyeMaintainMisses = eyeMaintainMisses + 1;
                                    end
                                    eyeResetFlag = eyeMaintainMisses > self.options.eyeMaintainMaxMisses;
                                end
                            end

                            % Poll the primary manipulator
                            if self.manipulators(1).available()
                                manipRawState = self.manipulators(1).poll();
                                manipCenterXYZ = self.manipulators(1).calibrationFcn(manipRawState);

                                % Reset timer if manipulator is not in home position
                                manipResetFlag = ~(self.manipulators(1).isHome);
                            end
    
                            % Prime the target in the screen center
                            if self.display.asyncReady() > 0
                                self.display.drawElements(trial.preRound);
                                self.display.drawDotsFastAt([manipCenterXYZ(1:2); eyeCenterXY], [10, 10], [255, 0, 0; 0, 0, 255]);
                                self.display.updateAsync();
                            end
                            
                            % Reset the timer if either manipulator or eye tracker isn't ready
                            if manipResetFlag || eyeResetFlag
                                eyeMaintainMisses = 0;
                                startTime = GetSecs;
                            end
                        end
                    end

                    function operatorInterruptCheck()
                        % Checks if operator presses a keyboard button
                        [~, ~, keyCode] = KbCheck();
                        if any(ismember(find(keyCode), self.options.activeKeys))
                            self.display.asyncEnd();
                            KbReleaseWait;
                            
                            if keyCode(KbName(self.options.driftCorrKey))
                                self.eyeTracker.driftCorrect();
                            elseif keyCode(KbName(self.options.calibrateKey))
                                self.eyeTracker.calibrate();
                            elseif keyCode(KbName(self.options.escapeKey))
                                self.close();
                                sca;
                                error('ExperimentManager:manualTermination', ['%s detected, only the last completed trial will be saved,' ...
                                    self.options.escapeKey]);
                            end

                            % Reset all manipulators
                            self.manipulators.resetAll();

                            % Reset timer and restart loop
                            startTime = GetSecs;
                            self.display.update();
                        end
                    end
                end

                function playTrialPhase()
                    % Present trial stimuli, and stop when either a pass/fail condition is met, or
                    % timeout is reached. Record all data to the output struct.

                    startTime = Inf;
                    timestamp = -Inf;

                    % Set up sized buffers for data recording
                    eyeRawState = self.eyeTracker.poll();
                    eyeTrace = nan(trial.timeout * 1000, length(eyeRawState));
                    eyeTraceIdx = 1; 
                    manipRawStates = self.manipulators.pollAll();
                    manipTraces = cell(1, self.numManipulators);
                    for kk = 1 : self.numManipulators
                        manipTraces{kk} = nan(trial.timeout * 1000, length(manipRawStates{kk}));
                    end
                    manipTraceIdxs = ones(1, self.numManipulators);
                    
                    self.state.eyeXY = nan(1, 2);
                    self.state.manipXY = nan(self.numManipulators, 2);
                    
                    % Used for extra dimensions, such as Z-coordinate or mouse click.
                    self.state.manipExtra = ones(self.numManipulators, 1); 

                    
                    while (timestamp < trial.timeout)
                        % Poll the eye tracker
                        if self.eyeTracker.available()
                            eyeRawState = self.eyeTracker.poll();
                            eyeTrace(eyeTraceIdx, :) = eyeRawState;
                            eyeTraceIdx = eyeTraceIdx + 1;
                            self.state.eyeXY = self.eyeTracker.calibrationFcn(eyeRawState);
                        end
                        self.state.eyeHomeFlag = self.eyeTracker.isHome();

                        % Poll all manipulators
                        for kk = 1 : self.numManipulators
                            if self.manipulators(kk).available()
                                manipRawStates{kk} = self.manipulators(kk).poll();
                                manipTraces{kk}(manipTraceIdxs(kk), :) = manipRawStates{kk};
                                manipTraceIdxs(kk) = manipTraceIdxs(kk) + 1;
                                manipState = self.manipulators(kk).calibrationFcn(manipRawStates{kk});
                                self.state.manipXY(kk, :) = manipState(1:2);
                                if length(manipState) == 3
                                    self.state.manipExtra(kk) = manipState(3);
                                end
                            end
                        end
                        self.state.manipHomeFlag = self.manipulators.isHomeAll();
                        
                        % Only start the timeout timer if the player has moved either eye tracker or
                        % manipulator out of the central zone
                        if (startTime == inf) && ~(self.state.eyeHomeFlag && self.state.manipHomeFlag(1))
                            startTime = GetSecs;
                        end

                        % End if a pass/fail condition is met
                        outcome = trial.check(self.state);
                        if outcome ~= 0; break; end
                        
                        % Prepare the next frame to draw
                        if self.display.asyncReady() > 0
                            self.display.drawElements(trial.elements);
                            self.display.drawDotsFastAt([self.state.manipXY(1, :); self.state.eyeXY], [10, 10], [255, 0, 0; 0, 0, 255])
                            self.display.updateAsync();
                        end
                        timestamp = GetSecs - startTime;
                    end
                    
                    % Record data in an output struct, to be saved at the end of each trial.
                    eyeTrace = eyeTrace(~isnan(eyeTrace(:,1)), :);

                    if practiceFlag
                        practiceData(ii).Outcomes(jj) = outcome;
                        practiceData(ii).EyeTrackerData{jj, 1} = eyeTrace;
    
                        for kk = 1 : self.numManipulators
                            manipTraces{kk} = manipTraces{kk}(~isnan(manipTraces{kk}(:,1)), :);
                            practiceData(ii).ManipulatorData{jj, kk} = manipTraces{kk};
                        end
                    else
                        self.data.TrialData(ii).Outcomes(jj) = outcome;
                        self.data.TrialData(ii).EyeTrackerData{jj, 1} = eyeTrace;
    
                        for kk = 1 : self.numManipulators
                            manipTraces{kk} = manipTraces{kk}(~isnan(manipTraces{kk}(:,1)), :);
                            self.data.TrialData(ii).ManipulatorData{jj, kk} = manipTraces{kk};
                        end
                    end

                    % Save original trial information to the failbuffer if the trial didn't succeed
                    if ~practiceFlag
                        if outcome ~= 1
                            failedTrial.preRound = trial.preRound;
                            failedTrial.elements = self.data.TrialData(ii).Elements{jj, 1};
                            failedTrial.target = self.data.TrialData(ii).Targets{jj, 1};
                            failedTrial.failzone = self.data.TrialData(ii).Failzones{jj, 1};
                            failBuffer{length(failBuffer) + 1} = failedTrial;
    
                            self.options.failBeep();
                        else
                            self.options.successBeep();
                        end
                    end

                    % Display the actual target, color-coded based on trial outcome
                    if ~practiceFlag && ~isempty(trial.target)
                        self.display.update();
                        startTime = GetSecs;
                        while (GetSecs < startTime + self.options.feedbackDuration)
                            trial.target.Color = self.options.feedbackColors((outcome == 1) + 1, :);
                            self.display.drawElements(trial.target);
                            self.display.update();
                        end
                    end
                end
            end
        end

        function close(self)
            % Closes all hardware, waits for last display frame to end, and closes the window
            % (cleaning up all loaded textures).

            self.eyeTracker.close();
            self.manipulators.closeAll();
            self.display.asyncEnd();
            self.display.close();
        end
    end
end

