classdef EyeLink2 < EyeTrackerInterface
    % A wrapper class to access and manage EyeLink2 samples

    properties (Access = private)
        state
        window
        settings
    end

    methods
        function self = EyeLink2(); end

        function successFlag = establish(self, display)
            if (Eyelink('Initialize') ~= 0)
	            disp('Problem initializing Eyelink.');
                sca;
                successFlag = false;
	            return;
            end
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

            self.settings.backgroundcolour = bgcolor;
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
        end

        function successFlag = calibrate(self)
            successFlag = 1;
            Eyelink('StopRecording');
            Eyelink('NewestFloatSample');
            EyelinkDoTrackerSetup(self.settings);
            Eyelink('StartRecording');    
            while Eyelink('NewFloatSampleAvailable') == 0; end
            sample = Eyelink('NewestFloatSample');
            self.EYEnow = [];
            while isempty(self.EYEnow)
                self.EYEnow = find(and(abs(sample.pa)>0,abs(sample.pa)<32768)); %1:Leye, 2:Reye
            end
            for Enow=1:2
                self.Ccoords{1,Enow} = nan(1,2);
            end
            for Enow=self.EYEnow
                self.Ccoords{1,Enow}=[0 0]; 
            end
            self.Neye=length(self.EYEnow);
        end

        function state = poll(self)
            loops = 1; 
            tmpcell = cell(2,1); 
            drained = 1;
            while drained == 1 
                [tmpcell{loops}, ~, drained]=Eyelink('GetQueuedData');
                if ~isempty(tmpcell{loops})
		            tmpcell{loops}=tmpcell{loops}(:,tmpcell{loops}(1,:)~=-32768)';
		            loops = loops + 1;
                    disp(tmpcell)
                end
            end
            state = [GetSecs, 0, 0];
%             %need to cell2mat the cell vect, and then sort using:
%             newmat=cell2mat(tmpcell);
%             if ~isempty(newmat)
%                 newmat(newmat == -32768) = nan;
%                 newmat = sortrows(newmat, 1);
%                 newmat(all(isnan(newmat(:, 14:15)), 2), :)=[]; 
%             end
% 
%             sz=size(newmat,1); 
%             if sz>0 
%                 dataavailable=2; 
%                 ELxy = nan(1,2); 
%                 Sexp.jE = Sexp.jE + 1:sz; 
%                 OST = t + (newmat(:, 1) - max(newmat(:, 1))) / 1000; %OST uses time relative in sec to correct when multiple data per poll
% 	            for Enow = Sexp.EYEnow
% 		            Etmp{Enow}(Sexp.jE, 1:Sexp.nsampEL-1)=[newmat(:,Sexp.LRElist(:,Enow)) OST]; %X/Y/PA/T/v [note vel is computed only at trial end]
% 		            ELxy = nanmean([ELxy; Etmp{Enow}(Sexp.jE(end),[1 2])],1); 
%                 end
% 	            ELxy=[ELxy t]; 
%                 Sexp.jE=Sexp.jE(end);
%             else 
%                 dataavailable = 0; 
%             end
        end

        function self = close(self); end
    end
end
