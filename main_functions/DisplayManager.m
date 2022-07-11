classdef DisplayManager < handle
    properties
        screen
        white; black; bgColor
        window; windowRect
        xMax; yMax; xCenter; yCenter
        ifi
    end

    properties (Access = private)
        textures
    end

    methods
        function self = DisplayManager(screenID, backgroundWeightedRGB)
            arguments
                screenID (1,1) {mustBeInteger, mustBePositive}
                backgroundWeightedRGB (1,3) = [0, 0, 0];
            end
            
            % Higher verbosity increases slow console printouts and may
            % cause unexpected timing errors
            Screen('Preference', 'Verbosity', 1);
            Screen('Preference', 'ConserveVRAM', 4096);
            Screen('Preference', 'SkipSyncTests', 2);
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
            PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');

            self.screen = screenID;
            self.white = WhiteIndex(screenID);
            self.black = BlackIndex(screenID);
            self.bgColor = backgroundWeightedRGB * (self.white - self.black) + self.black;
        end

        function successFlag = openWindow(self)
            % Create window and adjust settings
            try
                [self.window, self.windowRect] = PsychImaging('OpenWindow', self.screen, self.bgColor);
                [self.xMax, self.yMax] = Screen('WindowSize', self.window);
                [self.xCenter, self.yCenter] = RectCenter(self.windowRect);
                self.ifi = Screen('GetFlipInterval', self.window);
                Screen('TextFont', self.window, 'Ariel');
                Screen('TextSize', self.window, 50);
                Screen('BlendFunction', self.window, 'GL_ONE', 'GL_DST_ALPHA');
                HideCursor(self.window);
                Priority(MaxPriority(self.window));
    
                % Load shape textures into window for fast display
                bitmaps = GenerateShapeBitmaps();
                shapeNames = fieldnames(bitmaps);
                for ii = 1:length(shapeNames)
                    self.textures.(shapeNames{ii}) = Screen('MakeTexture', self.window, bitmaps.(shapeNames{ii}));
                end
                Screen('PreloadTextures', self.window);
                successFlag = true;
            catch
                successFlag = false;
            end
        end

        function update(self)
            % Draws the next frame of the screen
            Screen('Flip', self.window);
        end

        function updateAsync(self, t)
            % Queues the next frame of the screen asynchronously
            Screen('AsyncFlipBegin', self.window, t + self.ifi/2);
        end

        function ready = asyncReady(self)
            % Checks if there is currently an async frame update scheduled
            ready = Screen('AsyncFlipCheckEnd', self.window);
        end

        function asyncEnd(self)
            % Blocks until previously scheduled async frame is complete
            Screen('AsyncFlipEnd', self.window);
%             WaitSecs(self.ifi);
%             Screen('Flip', self.window);
        end

        function drawElementInCenter(self, element)
            % Draws only the target shape in the center of the screen
            if isempty(element); return; end
            element.Location = [0, 0];
            self.drawElements(element);
        end
        
        function drawDotsFastAt(self, centerCoordsList, sizeList, colorList, relativeTo)
            arguments
                self
                centerCoordsList (:, 2)
                sizeList(:, 1) = 10 * ones(size(centerCoordsList, 1), 1);
                colorList (:, 3) = self.white * size(centerCoordsList, 1);
                relativeTo (1, 2) = [self.xCenter, self.yCenter];
            end
            Screen('DrawDots', self.window, centerCoordsList' .* [1; -1], sizeList, colorList', relativeTo, 1);
        end

        function drawElements(self, elements)
            % Draws a list of elements on the next frame. All strings in
            % the first column of elements must be valid textures.
           
            if isempty(elements); return; end
            for ii = 1:length(elements)
                location = self.centerToScreen(elements(ii).Location);
                elementRadius = elements(ii).Radius;
                elementColor = elements(ii).Color;

                switch elements(ii).ElementType
                    case 'texture'
                        texture = self.textures.(elements(ii).Shape);
                        self.drawTexture(texture, location, elementRadius, elementColor);
                    case 'vertices'

                    otherwise
                end
            end
        end
        
        function emptyScreen(self)
            Screen('FillRect', self.window, self.bgColor);
        end

        function self = close(self)
            Priority(0);
            Screen('Close', self.window);
        end
    end

    methods (Access = private)
        function drawTexture(self, texture, location, radius, color)
            baseRect = [0, 0, 256, 256] * radius / 100;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('DrawTexture', self.window, texture, [], destRect, [], [], [], color);
        end

        function screenCoords = centerToScreen(self, centerCoords)
            screenCoords = centerCoords .* [1, -1] + [self.xCenter, self.yCenter];
        end

        function centerCoords = screenToCenter(self, screenCoords)
            centerCoords = (screenCoords - [self.xCenter, self.yCenter]) .* [1, -1];
        end
    end
end
