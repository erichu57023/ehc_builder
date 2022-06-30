classdef TouchScreenMouseCursor < ManipulatorInterface
    properties (Access = private)
        window
        xMax; yMax
    end

    methods
        function self = TouchScreenMouseCursor(); end

        function self = establish(self, window)
            % Establishes a connection with the device
            self.window = window;
            [self.xMax, self.yMax] = Screen('WindowSize', self.window);
            SetMouse(0, 0, self.window);
        end

        function state = poll(self)
            % Polls manipulator coordinates relative to screen center
            [x, y, buttons] = GetMouse(self.window);
            x = min(x, self.xMax) - self.xMax/2;
            y = -(min(y, self.yMax) - self.yMax/2);
            state = [GetSecs, x, y, any(buttons)];
        end

        function self = close(self)
            % Closes the connection with the device
        end
    end
end
