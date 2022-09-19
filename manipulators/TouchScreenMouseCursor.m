classdef TouchScreenMouseCursor < ManipulatorInterface
% TOUCHSCREENMOUSECURSOR A wrapper class representing an interface for a touch screen or mouse.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%    homePosition - Always set to coordinates of screen center
%    homeRadius - The radius around the screen center that counts as home.
%
% METHODS:
%    establish - Sets the mouse position to the active display window.
%    calibrate - Does nothing.
%    available - Does nothing.
%    poll - Returns the current position of the mouse, corrected to center coordinates.
%    reset - Sets the mouse position to screen center.
%    isHome - Checks if the mouse position is close to the center of the screen.
%    close - Does nothing.
    
    properties
        calibrationFcn
        homePosition
        homeRadius
    end
    properties (Access = private)
        window
        xMax; yMax
    end

    methods
        function self = TouchScreenMouseCursor(homeRadius)
            arguments
                homeRadius {mustBeFloat, mustBeScalarOrEmpty} = 50;
            end
            self.homeRadius = homeRadius;
        end

        function successFlag = establish(self, display)
            % Establishes a connection with the device
            self.window = display.window;
            self.xMax = display.xMax;
            self.yMax = display.yMax;
            self.homePosition = [0, 0];
            SetMouse(0, 0, self.window);
            successFlag = true;
            self.calibrationFcn = @(x) x(1:3);
            disp('TouchScreenMouseCursor: established')
        end

        function successFlag = calibrate(self)
            disp('TouchScreenMouseCursor: calibrated')
            successFlag = true;
        end

        function availFlag = available(self)
            availFlag = true;
        end

        function state = poll(self)
            % Polls manipulator coordinates relative to screen center
            [x, y, buttons] = GetMouse(self.window);
            x = min(x, self.xMax) - self.xMax/2;
            y = -(min(y, self.yMax) - self.yMax/2);
            state = [x, y, any(buttons), GetSecs];
        end

        function reset(self)
            SetMouse(self.xMax/2, self.yMax/2, self.window);
        end

        function homeFlag = isHome(self)
            state = self.poll();
            homeFlag = norm(state(1:2) - self.homePosition) <= self.homeRadius;
        end

        function self = close(self); end
    end
end
