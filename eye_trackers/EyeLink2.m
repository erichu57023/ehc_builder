classdef EyeLink2 < EyeTrackerInterface
% EYELINK2 A wrapper class to access the EyeLink II hardware interface
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%
% METHODS:
%    establish - Establishes connection through PsychToolbox Eyelink interface.
%    calibrate - Sends control to the Host PC to complete calibration/validation routines.
%    available - Returns true if a sample is available for poll.
%    poll - Returns the XY data of both eyes, which the Eyelink has already converted to
%       screen coordinates.
%    driftCorrect - Sends a command to the Host PC to perform online zeroing.
%    close - Shuts down the connection.

    properties
        calibrationFcn
    end
    properties (Access = private)
        display
        settings
%         xCorr; yCorr; % For naive drift correction
    end

    methods
        function self = EyeLink2(); end

        function successFlag = establish(self, display)
            % Configures settings and establishes connection through PsychToolbox Eyelink interface.
            % INPUTS:
            %    display - An instance of DisplayManager
            
            successFlag = false;
            if (Eyelink('Initialize') ~= 0)
	            disp('Problem initializing Eyelink.');
                sca;
	            return
            end
            self.display = display;
            self.settings = EyelinkInitDefaults(display.window);

            dummymode=0;
            if ~EyelinkInit(dummymode)
                disp('EyelinkInit aborted.');
                sca;
                return; 
            end

            % Configure settings based on size of the display.
            Eyelink('Command','screen_pixel_coords = %d, %d, %d, %d', 0, 0, display.xMax-1, display.yMax-1);
            Eyelink('Message','DISPLAY_COORDS %d, %d, %d, %d', 0, 0, display.xMax-1, display.yMax-1);

            Eyelink('Command',sprintf('calibration_area_proportion = %f %f',.35,.35));
            Eyelink('Command',sprintf('validation_area_proportion = %f %f',.3,.3));
            
            Eyelink('Command','calibration_type = HV13');
            Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
            Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,AREA');

            % Enable online drift correction to the screen center using a trigger command.
            Eyelink('Command', 'drift_correct_cr_disable = OFF');
            Eyelink('Command', sprintf('online_dcorr_refposn  %u %u', self.display.xCenter, self.display.yCenter));


            % Make sure connection is still active.
            if Eyelink('IsConnected') ~= 1 
	            disp('EyeLink2: EyeLink not connected, shutting down...');
	            Eyelink('Shutdown');
	            sca;
            end

            self.settings.backgroundcolour = display.bgColor;
            self.settings.calibrationtargetcolour = [.3 .4 .7];
            self.settings.calibrationtargetsize = 1.25;
            self.settings.calibrationtargetwidth = .75;

            % Beep sounds for the calibration routine
            % parameters are in frequency, volume, and duration
            % set the second value in each line to 0 to turn off the sound
            self.settings.cal_target_beep=[600 0.5 0.05];
            self.settings.drift_correction_target_beep=[600 0.5 0.05];
            self.settings.calibration_failed_beep=[400 0.5 0.25];
            self.settings.calibration_success_beep=[800 0.5 0.25];
            self.settings.drift_correction_failed_beep=[1 0 0];% [400 0.5 0.25];
            self.settings.drift_correction_success_beep=[1 0 0]; %[800 0.5 0.25];

            % Apply the changes from above
            EyelinkUpdateDefaults(self.settings); 

            disp('EyeLink2: established')
            successFlag = true;
        end

        function successFlag = calibrate(self)
            % Send control of the display to the Host PC for calibration. Returns when "Exit Setup"
            % is clicked on the Host PC.
            % OUTPUTS:
            %    successFlag - Returns true if nothing went wrong.
            
            try
                Eyelink('StopRecording');
                Eyelink('NewestFloatSample');
                EyelinkDoTrackerSetup(self.settings);
                Eyelink('StartRecording');
                self.calibrationFcn = @generateCalFcn;
%                 self.xCorr = 0; self.yCorr = 0;   % For naive drift correction
                disp('EyeLink2: calibrated')
                successFlag = true;
            catch
                successFlag = false;
            end

            function calSample = generateCalFcn(rawSample)
                % Calculates the mean XY coordinate of all valid eye samples
                xLR = rawSample([1,3]); yLR = rawSample([2,4]);
                xLR = mean(xLR(xLR ~= -32768)); yLR = mean(yLR(yLR ~= -32768));
                calSample = [xLR, yLR];
            end
        end

        function availFlag = available(self)
            % Check if a new sample is available.
            % OUTPUTS: 
            %    availFlag - Returns true if a new sample is available.

            availFlag = Eyelink('NewFloatSampleAvailable') == 1;
        end

        function state = poll(self)
            % Poll the most recent sample.
            % OUTPUTS: 
            %    state - a 1x5 vector containing [Lx, Ly, Rx, Ry, timestamp]

            sample = Eyelink('NewestFloatSample');
            xLR = sample.gx; 
            yLR = sample.gy;
            xLR(xLR ~= -32768) = xLR(xLR ~= -32768) - self.display.xMax/2;
            yLR(yLR ~= -32768) = -yLR(yLR ~= -32768) + self.display.yMax/2;
            state = [xLR(1), yLR(1), xLR(2), yLR(2), GetSecs];
        end

        function driftCorrect(self)
            % Send a command to the Host PC to perform an online drift-correction.
% %           For naive drift correction
%             state = self.poll(); 
%             self.xCorr = state(2);
%             self.yCorr = state(3);

            Eyelink('Command', 'online_dcorr_trigger');
            disp('EyeLink2: drift corrected')
        end

        function close(self)
            % Shuts down the Eyelink connection.

            Eyelink('StopRecording');
            Eyelink('Shutdown');
        end
    end
end
