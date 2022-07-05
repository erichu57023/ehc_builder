classdef EyeLink2 < EyeTrackerInterface
    % A wrapper class to access and manage EyeLink2 samples

    properties (Access = private)
        state
        display
        settings
    end

    methods
        function self = EyeLink2(); end

        function successFlag = establish(self, display)
            successFlag = false;
            if (Eyelink('Initialize') ~= 0)
	            disp('Problem initializing Eyelink.');
                sca;
	            return;
            end
            self.display = display;
            self.settings = EyelinkInitDefaults(display.window);

            dummymode=0;
            if ~EyelinkInit(dummymode)
                disp('EyelinkInit aborted.');
                sca;
                return; 
            end

            Eyelink('command','screen_pixel_coords = %d, %d, %d, %d', 0, 0, display.xMax-1, display.yMax-1);
            Eyelink('message','DISPLAY_COORDS %d, %d, %d, %d', 0, 0, display.xMax-1, display.yMax-1);

            Eyelink('command',sprintf('calibration_area_proportion = %f %f',.35,.35))
            Eyelink('command',sprintf('validation_area_proportion = %f %f',.3,.3))
            
            Eyelink('command','calibration_type = HV13');
            Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
            Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,AREA');

            % make sure we're still connected.
            if Eyelink('IsConnected') ~= 1 
	            disp('EyeLink not connected, shutting down...');
	            Eyelink('Shutdown');
	            sca;
            end

            self.settings.backgroundcolour = display.bgColor;
            self.settings.calibrationtargetcolour = [.3 .4 .7];
            self.settings.calibrationtargetsize = 1.25;
            self.settings.calibrationtargetwidth = .75;

            % parameters are in frequency, volume, and duration
            % set the second value in each line to 0 to turn off the sound
            self.settings.cal_target_beep=[600 0.5 0.05];
            self.settings.drift_correction_target_beep=[600 0.5 0.05];
            self.settings.calibration_failed_beep=[400 0.5 0.25];
            self.settings.calibration_success_beep=[800 0.5 0.25];
            self.settings.drift_correction_failed_beep=[1 0 0];% [400 0.5 0.25];
            self.settings.drift_correction_success_beep=[1 0 0]; %[800 0.5 0.25];

            EyelinkUpdateDefaults(self.settings); %apply the changes from above
            successFlag = true;
        end

        function successFlag = calibrate(self)
            try
                Eyelink('StopRecording');
                Eyelink('NewestFloatSample');
                EyelinkDoTrackerSetup(self.settings);
                Eyelink('StartRecording');
                successFlag = true;
            catch
                successFlag = false;
            end
        end

        function availFlag = available(self)
            availFlag = Eyelink('NewFloatSampleAvailable') == 1;
        end

        function state = poll(self)
            sample = Eyelink('NewestFloatSample');
            x = sample.gx(sample.gx ~= -32768); 
            y = sample.gy(sample.gx ~= -32768);
            x = mean(x) - self.display.xMax/2;
            y = -mean(y) + self.display.yMax/2;
            state = [GetSecs, x, y];
        end

        function self = close(self)
            Eyelink('StopRecording');
            Eyelink('Shutdown');
        end
    end
end
