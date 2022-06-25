classdef TouchScreenMouseCursor < ManipulatorInterface
    properties (Access = private)
        state
        window
        xMax; yMax
    end

    methods
        function self = TouchScreenMouseCursor() 
            self.state = [];
        end

        function self = establish(self, window)
            % Establishes a connection with the device
            self.window = window;
            [self.xMax, self.yMax] = Screen('WindowSize', self.window);
            SetMouse(0, 0, window);
        end

        function state = poll(self)
            % Polls manipulator coordinates relative to screen center
            [x, y, buttons] = GetMouse(self.window);
            x = min(x, self.xMax) - self.xMax/2;
            y = -(min(y, self.yMax) - self.yMax/2);
            self.state = [x, y, any(buttons)];
            state = self.state; 
        end

        function self = close(self)
            % Closes the connection with the device
            self.state = [];
        end
    end
end
