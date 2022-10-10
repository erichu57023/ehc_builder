classdef TouchScreen < ManipulatorInterface
% TOUCHSCREEN A wrapper class for a touchscreen.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%    homePosition - Always set to coordinates of screen center
%    homeRadius - The radius around the screen center that counts as home.
%
% METHODS:
%    establish - Sets the cursor position to the active display window.
%    calibrate - Does nothing.
%    available - Does nothing.
%    poll - Returns the current position of the cursor, corrected to center coordinates, along with
%       whether the screen is currently being touched.
%    reset - Sets the cursor position to screen center.
%    isHome - Checks if the cursor position is close to the center of the screen.
%    close - Does nothing.
    
    properties
        calibrationFcn
        homePosition
        homeRadius
    end
    properties (Access = private)
        window
        xMax; yMax
        deviceID
        state
    end

    methods
        function self = TouchScreen(homeRadius, deviceID)
            arguments
                homeRadius {mustBeFloat, mustBeScalarOrEmpty} = 50;
                deviceID {mustBeNonnegative, mustBeScalarOrEmpty} = [];
            end
            self.homeRadius = homeRadius;
            self.deviceID = deviceID;
        end

        function successFlag = establish(self, display)
            % Establishes a connection with the device
            self.window = display.window;
            self.xMax = display.xMax;
            self.yMax = display.yMax;
            self.homePosition = [0, 0];
            self.state = nan(1,3);
            SetMouse(0, 0, self.window);

            if isempty(self.deviceID)
                self.deviceID = max(GetTouchDeviceIndices);
                disp(self.deviceID)
            end
            TouchQueueCreate(self.window, self.deviceID);
            TouchQueueStart(self.deviceID);

            self.calibrationFcn = @(x) x(1:3);
            successFlag = true;
            disp('TouchScreen: established')
        end

        function successFlag = calibrate(~)
            disp('TouchScreen: calibrated')
            successFlag = true;
        end

        function availFlag = available(self)
            availFlag = true;
        end

        function state = poll(self)
            % Polls manipulator coordinates relative to screen center
            evt = TouchEventGet(self.deviceID, self.window);
            if isempty(evt)
                state = [self.state, GetSecs]; 
                return; 
            end

            x = min(evt.MappedX, self.xMax) - self.xMax/2;
            y = -(min(evt.MappedY, self.yMax) - self.yMax/2);
            self.state = [x, y, evt.Pressed];
            state = [self.state, evt.Time];
        end

        function reset(self)
            TouchEventFlush(self.deviceID);
            self.state = [0, 0, 0];
            SetMouse(self.xMax/2, self.yMax/2, self.window);
        end

        function homeFlag = isHome(self)
            homeFlag = norm(self.state(1:2) - self.homePosition) <= self.homeRadius;
        end

        function self = close(self)
            TouchQueueStop(self.deviceID);
            TouchQueueRelease(self.deviceID);
        end
    end
end
