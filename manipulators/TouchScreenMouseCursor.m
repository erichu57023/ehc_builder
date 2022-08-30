classdef TouchScreenMouseCursor < ManipulatorInterface
% TOUCHSCREENMOUSECURSOR A wrapper class representing an interface for a touch screen or mouse.
%
% PROPERTIES:
%    calibrationFcn - Simply strips the timestamps from the raw data.
%
% METHODS:
%    establish - Sets the mouse position to the active display window.
%    calibrate - Does nothing.
%    available - Does nothing.
%    poll - Returns the current position of the mouse, corrected to center coordinates.
%    close - Does nothing.
    
    properties
        calibrationFcn
    end
    properties (Access = private)
        window
        xMax; yMax
    end

    methods
        function self = TouchScreenMouseCursor(); end

        function successFlag = establish(self, display)
            % Establishes a connection with the device
            self.window = display.window;
            self.xMax = display.xMax;
            self.yMax = display.yMax;
            SetMouse(0, 0, self.window);
            successFlag = true;
            self.calibrationFcn = @(x) x(2:end);
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
            state = [GetSecs, x, y, any(buttons)];
        end

        function self = close(self); end
    end
end
