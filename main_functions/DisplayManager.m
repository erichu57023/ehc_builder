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
        audioDriver
        gaussShader
    end

    methods
        function self = DisplayManager(screenID, backgroundWeightedRGB)
            arguments
                screenID (1,1) {mustBeInteger, mustBePositive}
                backgroundWeightedRGB (1,3) = [0, 0, 0];
            end
            % Constructs an DisplayManager instance.
            % INPUTS:
            %    screenID - The ID of the screen to display to, as returned by PsychToolbox
            %    backgroundWeightedRGB (optional) - An RGB triplet defining the background color as
            %       floats between 0-1

            % Skip sync tests; timing will not be incredibly accurate on Windows anyways
            Screen('Preference', 'SkipSyncTests', 1);

            % ONLY use verbosity for debugging! If not, the constant print statements can mess up
            % the timing of screen updates and cause freezing/crashing
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
            % Opens a window for stimulus display on the screen specified during construction, and
            % loads all textures for fast drawing of complex shapes.
            % OUTPUTS:
            %    successFlag - Returns true if completed without error
            %
            % See also: GENERATESHAPEBITMAPS

            try
                [self.window, self.windowRect] = PsychImaging('OpenWindow', self.screen, self.bgColor);
                [self.xMax, self.yMax] = Screen('WindowSize', self.window);
                [self.xCenter, self.yCenter] = RectCenter(self.windowRect);
                self.ifi = Screen('GetFlipInterval', self.window);
                Screen('TextFont', self.window, 'Ariel');
                Screen('TextSize', self.window, 50);
                Screen('BlendFunction', self.window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
                HideCursor(self.window);
                Priority(MaxPriority(self.window));
    
                % Open an audio driver for feedback
                InitializePsychSound(1);
                self.audioDriver = PsychPortAudio('Open');
                Snd('Open', self.audioDriver, 1);
    
                % Load shape textures into window for fast display
                [bitmaps, self.vertices] = GenerateShapeBitmaps();
                shapeNames = fieldnames(bitmaps);
                for ii = 1:length(shapeNames)
                    self.textures.(shapeNames{ii}) = Screen('MakeTexture', self.window, bitmaps.(shapeNames{ii}));
                end
                Screen('PreloadTextures', self.window);
    
                self.textures.SmoothedCircle = CreateProceduralSmoothedDisc(self.window, 256, 256, [], 50, 30);
                successFlag = true;
            catch
                successFlag = false;
            end
        end

        function update(self)
            % Updates the screen with all elements that have been drawn since the previous update.
            % This function is blocking, and will halt code execution until the next vertical
            % retrace, locking the main loop frequency to the refresh rate of the monitor; to avoid 
            % losing samples during a trial, use updateAsync instead.
            
            Screen('Flip', self.window);
        end

        function updateAsync(self)
            % Schedules a screen update to occur at either the next vertical retrace, or the one
            % after that. This function is non-blocking and should be used for realtime purposes,
            % but may result in unexpected and cryptic bugs on different machines.
            
            Screen('AsyncFlipBegin', self.window, GetSecs + self.ifi/2);
        end

        function ready = asyncReady(self)
            % Checks if there is currently an async frame update scheduled.
            % OUTPUTS:
            %    ready - Returns 0 if an async is currently scheduled, otherwise returns the
            %       timestamp of the most recent screen flip
            
            ready = Screen('AsyncFlipCheckEnd', self.window);
        end

        function asyncEnd(self)
            % Blocks code execution and waits until all scheduled async frame updates are completed.
            % This function may cause freezing/crashing if timing is imprecise.
            Screen('AsyncFlipEnd', self.window);
            WaitSecs(self.ifi);
            Screen('Flip', self.window);
        end

        function drawElementInCenter(self, element)
            % Draws a single element in the center of the screen.
            % INPUTS:
            %    element - A struct containing information about how to draw the element. See
            %       drawElements for more details.
            
            if isempty(element); return; end
            element.Location = [0, 0];
            self.drawElements(element);
        end
        
        function drawDotsFastAt(self, centerCoordsList, sizeList, colorList, relativeTo)
            arguments
                self
                centerCoordsList (:, 2)
                sizeList (:, 1) = 10 * ones(size(centerCoordsList, 1), 1);
                colorList (:, 3) = self.white * size(centerCoordsList, 1);
                relativeTo (1, 2) = [self.xCenter, self.yCenter];
            end
            % Draws a list of solid-fill dots using the fast graphics renderer.
            % INPUTS:
            %    centerCoordsList - An Nx2 list of XY coodinates
            %    sizeList - An Nx1 list of pixel sizes for each dot. The maximum size may be limited
            %       by the graphics hardware. 
            %    colorList - An Nx3 list of RGB triplets as floats (0-1)
            %    relativeTo - A reference XY coordinate for all points in centerCoordsList 
            
            Screen('DrawDots', self.window, centerCoordsList' .* [1; -1], sizeList, colorList', relativeTo, 1);
        end

        function drawElements(self, elements)
            % Draws a list of elements for display at the next update. NOTE: if your trial includes
            % other ElementTypes, this function must be updated to support them. 
            % INPUTS:
            %    elements - A 1xN struct containing details for how to draw each element. Each
            %       element must define AT LEAST the following properties:
            %       ElementType - a char array describing the type of element to be drawn
            %       Location - an XY coodinate (relative to screen center)
            %       Color - an 8-bit RGB triplet (0-255)
           
            if isempty(elements); return; end
            for ii = 1:length(elements)
                location = self.centerToScreen(elements(ii).Location);
                elementColor = elements(ii).Color / 255 * self.white - self.black;

                switch elements(ii).ElementType
                    case 'hide'
                        % Skips over the current element.
                        continue
                        
                    case 'texture'
                        % Draws a pre-rendered texture (aka offscreen window). Use for fast display 
                        % of potentially complex shapes.
                        % REQUIRED PROPERTIES:
                        %    Shape - A char array describing the name of the texture. This name must
                        %       be a property in self.textures; see GENERATESHAPEBITMAPS
                        %    Radius - An int representing the size of the texture. The area
                        %       of the shape is normalized to that of a circle of radius 50.
                        
                        texture = self.textures.(elements(ii).Shape);
                        elementRadius = elements(ii).Radius;
                        self.drawTexture(texture, location, elementRadius, elementColor);
                    
                    case 'text'
                        % Draws text on the screen, in a box centered on the Location coordinate.
                        % REQUIRED PROPERTIES:
                        %    Text - A char array to be displayed on screen, newlines included
                        %    Font - A char array of the font to use. For Navon tasks, this MUST be a
                        %       monospace font ('Consolas' is likely to work)
                        %    FontSize - An int describing the font size in pts
                        %    VerticalSpacing - An int describing controlling the vertical separation
                        %       of lines

                        text = elements(ii).Text;
                        font = elements(ii).Font;
                        fontSize = elements(ii).FontSize;
                        vSpacing = elements(ii).VerticalSpacing;
                        self.drawText(text, location, elementColor, font, fontSize, vSpacing);
                    
                    case 'framepoly'
                        % Draws the outline of a shape defined by a set of vertices.
                        % REQUIRED PROPERTIES:
                        %    Shape - A char array describing the name of the shape. This name must
                        %       be a property in self.vertices; see GENERATESHAPEBITMAPS
                        %    Radius - An int representing the size of the shape in pixels. The area
                        %       of the shape is normalized to that of a circle of radius 50.
                        %    LineWidth - An int representing the width of the outline in pts.

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
            % Clears the screen to just the background color.

            Screen('FillRect', self.window, self.bgColor);
        end

        function self = close(self)
            % Releases all textures and closes the window.

            Snd('Close', 1);
            PsychPortAudio('Close', self.audioDriver);
            Screen('Close', self.window);
            Priority(0);
        end
    end

    methods (Access = private)
        function drawTexture(self, texture, location, radius, color)
            % Draws a texture defined in self.textures.
            % INPUTS:
            %    texture - The index of a texture created by Screen('MakeTexture'), and stored in
            %       self.textures.
            %    location - The XY coordinate of the texture, in screen coordinates.
            %    radius - The size of the texture; a 256x256 texture is defined as radius 50.
            %    color - An RGB float triplet.

            baseRect = [0, 0, 256, 256] * radius / 50;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('DrawTexture', self.window, texture, [], destRect, [], [], [], color);
        end

        function drawText(self, text, location, color, font, fontSize, vSpacing)
            % Draws a formatted text box.
            % INPUTS:
            %    text - The text to be drawn
            %    location - The XY coordinate of the text box, in screen coordinates.
            %    color - An RGB float triplet.
            %    font - A font name.
            %    fontSize - A font size in pts.
            %    vSpacing - Vertical line separation in points.

            Screen('TextFont', self.window, font);
            Screen('TextSize', self.window, fontSize);
            bbox = [location - 50, location + 50];
            DrawFormattedText(self.window, text, 'centerblock', 'center', color, [], 0, 0, vSpacing, 0, bbox);
        end

        function drawFrameCircle(self, location, radius, color, lineWidth)
            % Draws a circle outline.
            % INPUTS:
            %    location - The XY coordinate of the circle center, in screen coordinates.
            %    radius - The radius of the circle in pixels.
            %    color - An RGB float triplet.
            %    lineWidth - Line thickness in pts.

            baseRect = [0, 0, 2, 2] * radius;
            destRect = CenterRectOnPointd(baseRect, location(1), location(2));
            Screen('FrameOval', self.window, color, destRect, lineWidth, lineWidth)
        end

        function drawFramePoly(self, vertices, radius, color, lineWidth)
            % Draws a polygon outline connected by straight lines.
            % INPUTS:
            %    vertices - An Nx2 list of XY values, in screen coordinates.
            %    radius - Area of the shape is normalized to a circle of radius 50.
            %    color - An RGB float triplet.
            %    lineWidth - Line thickness in pts.

            vertsCorrected = self.centerToScreen(vertices .* radius / 50);
            Screen('FramePoly', self.window, color, vertsCorrected, lineWidth);
        end

        function screenCoords = centerToScreen(self, centerCoords)
            % Converts XY coordinates from center-origin to top-left-origin.
            % INPUTS:
            %    centerCoords - An Nx2 list of XY values, relative to screen center.
            % OUTPUTs:
            %    screenCoords - An Nx2 list of XY values, relative to top left.

            screenCoords = centerCoords .* [1, -1] + [self.xCenter, self.yCenter];
        end

        function centerCoords = screenToCenter(self, screenCoords)
            % Converts XY coordinates from top-left-origin to center-origin.
            % INPUTS:
            %    screenCoords - An Nx2 list of XY values, relative to top left.
            % OUTPUTs:
            %    centerCoords - An Nx2 list of XY values, relative to screen center.
            centerCoords = (screenCoords - [self.xCenter, self.yCenter]) .* [1, -1];
        end
    end
end
