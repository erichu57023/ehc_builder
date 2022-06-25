classdef DisplayManager < handle
    properties
        screen
        white; black
        window; windowRect
        xMax; yMax; xCenter; yCenter
    end

    properties (Access = private)
        textures
    end

    methods
        function self = DisplayManager(screenID)
            arguments
                screenID (1,1) {mustBeInteger, mustBePositive}
            end
            Screen('Preference','SkipSyncTests', 1);
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');

            self.screen = screenID;
            self.white = WhiteIndex(screenID);
            self.black = BlackIndex(screenID);
        end

        function self = openWindow(self)
            % Create window and adjust settings
            [self.window, self.windowRect] = PsychImaging('OpenWindow', self.screen, self.black);
            [self.xMax, self.yMax] = Screen('WindowSize', self.window);
            [self.xCenter, self.yCenter] = RectCenter(self.windowRect);
            Screen('TextFont', self.window, 'Ariel');
            Screen('TextSize', self.window, 50);
            Screen('BlendFunction', self.window, 'GL_ONE', 'GL_DST_ALPHA');
            Priority(MaxPriority(self.window));

            % Load shape textures into window for fast display
            bitmaps = GenerateShapeBitmaps();
            shapeNames = fieldnames(bitmaps);
            for ii = 1:length(shapeNames)
                self.textures.(shapeNames{ii}) = Screen('MakeTexture', self.window, bitmaps.(shapeNames{ii}));
            end
        end

        function update(self)
            % Draws the next frame of the screen
            Screen('Flip', self.window);
        end

        function drawTargetInCenter(self, target)
            % Draws only the target shape in the center of the screen
            texture = self.textures.(target{1});
            location = [self.xCenter, self.yCenter];
            targetRadius = target{3};
            baseRect = [0, 0, 256, 256] * targetRadius / 100;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('DrawTexture', self.window, texture, [], destRect);
        end
        
        function drawDotAt(self, centerCoords)
            screenCoords = centerCoords .* [1, -1] + [self.xCenter, self.yCenter];
            Screen('DrawDots', self.window, screenCoords, 10, self.white, [], 1);
        end

        function drawElements(self, elements)
            % Draws a list of elements on the next frame. All strings in
            % the first column of elements must be valid textures.

            for el = 1:size(elements, 1)
                texture = self.textures.(elements{el, 1});
                location = elements{el, 2} .* [1, -1] + [self.xCenter, self.yCenter];
                targetRadius = elements{el, 3};
                baseRect = [0, 0, 256, 256] * targetRadius / 100;
                destRect = CenterRectOnPointd(baseRect, location(1), location(2));
                Screen('DrawTexture', self.window, texture, [], destRect);
            end
        end

        function self = close(self)
            Priority(0);
            sca;
        end
    end
end