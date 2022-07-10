classdef TouchScreenMouseCursor < ManipulatorInterface
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
        end

        function successFlag = calibrate(self)
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
