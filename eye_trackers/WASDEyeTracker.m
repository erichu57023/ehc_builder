classdef WASDEyeTracker < EyeTrackerInterface
% NOEYETRACKER A debug class where the WASD keys substitute for the eye tracker.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw XY data.
%
% METHODS:
%    establish - Does nothing.
%    calibrate - Sets the output to [0, 0]
%    available - Does nothing.
%    poll - Checks to see if an active keypress is WASD, adjusts the cursor position accordingly,
%       and returns the output.
%    driftCorrect - Sets the output to [0, 0]
%    close - Does nothing.

    properties
        calibrationFcn
    end
    properties (Access = private)
        state
        display
        delta_speed = 0.1;
    end
    properties (Constant)
        wKey = KbName('w');
        aKey = KbName('a');
        sKey = KbName('s');
        dKey = KbName('d');
    end

    methods
        function self = WASDEyeTracker(); end

        function successFlag = establish(self, display)
            self.display = display;
            successFlag = true;
            self.state = [0, 0, 0, 0];
            self.calibrationFcn = @(x) x(1:2);
            disp('WASDEyeTracker: established! Use WASD to control the eye tracker')
        end

        function successFlag = calibrate(self)
            disp('WASDEyeTracker: calibrated')
            successFlag = true;
        end    

        function successFlag = available(self)
            successFlag = true;
        end

        function state = poll(self)
            [~, ~, keyCode] = KbCheck();
            delta = self.delta_speed * [keyCode(self.dKey) - keyCode(self.aKey), keyCode(self.wKey) - keyCode(self.sKey)];
            self.state = self.state + [delta, delta];
            state = [self.state, GetSecs];
        end

        function driftCorrect(self)
            disp('WASDEyeTracker: drift-corrected')
            self.state = [0, 0, 0, 0];
        end

        function self = close(self); end
    end
end
