classdef DisplayManager < handle
% DISPLAYMANAGER A centralized manager for handling display of EHC trial elements, using the
% PsychToolbox interface.
%
% PROPERTIES:
%    screen - Index of the active display
%    white, black - Float values between 0-1, representing the color range of the display
%    bgColor - An RGB float triplet (between 0-1), representing the default background color
%    window - A pointer to the active window
%    windowRect - A 4-element rect ([left top right bottom]) containing window dimensions
%    xMax, yMax - Maximum pixel values of the active window
%    xCenter, yCenter - Pixel values representing the center of the active window
%
% METHODS:
%    openWindow - Initializes a window on the screen specified during instantiation
%    update - Updates the display with all elements drawn since last update (blocking)
%    updateAsync - Same as update, but with asynchronous implementation (non-blocking)
%    asyncReady - Check whether a previously scheduled updateAsync has completed (non-blocking)
%    asyncEnd - Wait until a previously scheduled updateAsync has completed (blocking)
%    drawElementInCenter - Draws a single element in the center of the screen, with all other
%       settings intact
%    drawDotsFastAt - Draws a list of small circles with the fast graphics renderer
%    drawElements - Draws a list of elements, each defined by a struct
%    emptyScreen - Draws an empty rectangle over the whole window, with bgColor
%    close - Ends all scheduled updates, releases all textures and closes the window
%
% See also: EYETRACKERINTERFACE, MANIPULATORINTERFACE, TRIALINTERFACE

    properties
        screen
        white; black; bgColor
        window; windowRect
        xMax; yMax; xCenter; yCenter
        ifi
    end

    properties (Access = private)
        textures
        vertices
    end

    methods
        function self = DisplayManager(screenID, backgroundWeightedRGB)
            arguments
                screenID (1,1) {mustBeInteger, mustBePositive}
                backgroundWeightedRGB (1,3) = [0, 0, 0];
            end
            Screen('Preference', 'SkipSyncTests', 1);
            Screen('Preference', 'Verbosity', 0);
            Screen('Preference', 'TextRenderer', 1);
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
                [bitmaps, self.vertices]= GenerateShapeBitmaps();
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

        function updateAsync(self)
            % Queues the next frame of the screen asynchronously
            Screen('AsyncFlipBegin', self.window, GetSecs + self.ifi/2);
        end

        function ready = asyncReady(self)
            % Checks if there is currently an async frame update scheduled
            ready = Screen('AsyncFlipCheckEnd', self.window);
        end

        function asyncEnd(self)
            % Blocks until previously scheduled async frame is complete
            Screen('AsyncFlipEnd', self.window);
            WaitSecs(self.ifi);
            Screen('Flip', self.window);
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
                elementColor = elements(ii).Color / 255 * self.white - self.black;

                switch elements(ii).ElementType
                    case 'texture'
                        texture = self.textures.(elements(ii).Shape);
                        elementRadius = elements(ii).Radius;
                        self.drawTexture(texture, location, elementRadius, elementColor);
                    
                    case 'text'
                        text = elements(ii).Text;
                        font = elements(ii).Font;
                        fontSize = elements(ii).FontSize;
                        vSpacing = elements(ii).VerticalSpacing;
                        self.drawText(text, location, elementColor, font, fontSize, vSpacing);
                    
                    case 'framepoly'
                        shape = elements(ii).Shape;
                        elementRadius = elements(ii).Radius;
                        lineWidth = elements(ii).LineWidth;
                        if strcmp(shape, 'Circle')
                            self.drawFrameCircle(location, elementRadius, elementColor, lineWidth);
                        else
                            self.drawFramePoly(self.vertices.(shape), elementRadius, elementColor, lineWidth);
                        end
                end
            end
        end
        
        function emptyScreen(self)
            Screen('FillRect', self.window, self.bgColor);
        end

        function self = close(self)
            Screen('Close', self.window);
            Priority(0);
        end
    end

    methods (Access = private)
        function drawTexture(self, texture, location, radius, color)
            baseRect = [0, 0, 256, 256] * radius / 50;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('DrawTexture', self.window, texture, [], destRect, [], [], [], color);
        end

        function drawText(self, text, location, color, font, fontSize, vSpacing)
            Screen('TextFont', self.window, font);
            Screen('TextSize', self.window, fontSize);
            bbox = [location - 50, location + 50];
            DrawFormattedText(self.window, text, 'centerblock', 'center', color, [], 0, 0, vSpacing, 0, bbox);
        end

        function drawFrameCircle(self, location, radius, color, lineWidth)
            baseRect = [0, 0, 2, 2] * radius;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('FrameOval', self.window, color, destRect, lineWidth, lineWidth)
        end

        function drawFramePoly(self, vertices, radius, color, lineWidth)
            vertsCorrected = self.centerToScreen(vertices .* radius / 50);
            Screen('FramePoly', self.window, color, vertsCorrected, lineWidth);
        end

        function screenCoords = centerToScreen(self, centerCoords)
            screenCoords = centerCoords .* [1, -1] + [self.xCenter, self.yCenter];
        end

        function centerCoords = screenToCenter(self, screenCoords)
            centerCoords = (screenCoords - [self.xCenter, self.yCenter]) .* [1, -1];
        end
    end
end
