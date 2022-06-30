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
            Screen('Preference','SkipSyncTests', 1);
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
            PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');

            self.screen = screenID;
            self.white = WhiteIndex(screenID);
            self.black = BlackIndex(screenID);
            self.bgColor = backgroundWeightedRGB * (self.white - self.black) + self.black;
        end

        function self = openWindow(self)
            % Create window and adjust settings
            
            [self.window, self.windowRect] = PsychImaging('OpenWindow', self.screen, self.bgColor);
            [self.xMax, self.yMax] = Screen('WindowSize', self.window);
            [self.xCenter, self.yCenter] = RectCenter(self.windowRect);
            self.ifi = Screen('GetFlipInterval', self.window);
            disp(self.ifi)
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
        end

        function drawElementInCenter(self, element)
            % Draws only the target shape in the center of the screen
            element.Location = [0, 0];
            self.drawElements(element);
        end
        
        function drawDotAt(self, centerCoords)
            screenCoords = self.centerToScreen(centerCoords);
            Screen('DrawDots', self.window, screenCoords, 10, self.white, [], 1);
        end

        function drawElements(self, elements)
            % Draws a list of elements on the next frame. All strings in
            % the first column of elements must be valid textures.

            for ii = 1:length(elements)
                location = self.centerToScreen(elements(ii).Location);
                targetRadius = elements(ii).Radius;

                switch elements(ii).ElementType
                    case 'texture'
                        texture = self.textures.(elements(ii).Shape);
                        self.drawTexture(texture, location, targetRadius);
                    case 'vertices'

                    otherwise
                end
            end
        end
        
        function emptyScreen(self)
            Screen('FillRect', self.window, self.bgColor);
        end

        function self = close(self)
        end
    end

    methods (Access = private)
        function drawTexture(self, texture, location, targetRadius)
            baseRect = [0, 0, 256, 256] * targetRadius / 100;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('DrawTexture', self.window, texture, [], destRect);
        end

        function screenCoords = centerToScreen(self, centerCoords)
            screenCoords = centerCoords .* [1, -1] + [self.xCenter, self.yCenter];
        end

        function centerCoords = screenToCenter(self, screenCoords)
            centerCoords = (screenCoords - [self.xCenter, self.yCenter]) .* [1, -1];
        end
    end
end
