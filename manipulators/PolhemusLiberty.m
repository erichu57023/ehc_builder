classdef PolhemusLiberty < ManipulatorInterface
% POLHEMUSLIBERTY A wrapper class to access the Polhemus Liberty position sensor hardware interface.
%
% PROPERTIES:
%    calibrationFcn - Converts XYZ position data to screen coordinates based on a calibration
%       routine.
%    homePosition - Raw XYZ of the designated home position.
%    homeRadius - 3D radius of the designated home position in mm.
%
% METHODS:
%    establish - Opens a TCP client on a port where six-axis P&O data is being published.
%    calibrate - Runs a 9-point calibration routine and calculates a best-fit transform to 2D screen
%       coordinates.
%    available - Returns true if a new sample is available on the TCP buffer to poll.
%    poll - Poll and interpret most recent sample, and update an internal FIFO buffer of data for
%       calibration purposes.
%    reset - Does nothing.
%    isHome - Checks if the most recent sample is in the home position.
%    close - Flushes the TCP client.

    properties
        calibrationFcn
        homePosition
        homeRadius
    end
    properties (Access = private)
        display
        ipAddress
        tcpPort
        calibrationScale
        client
        tableLevel
        ringBuffer; ringIdx; ringSize
    end

    methods
        function self = PolhemusLiberty(ipAddress, tcpPort, homeRadius, bufferSize, calibrationScale)
            arguments
                ipAddress {mustBeTextScalar} = 'localhost';
                tcpPort (1,1) {mustBeInteger, mustBeNonnegative} = 7234;
                homeRadius {mustBeFloat, mustBeScalarOrEmpty} = 15;
                bufferSize (1,1) {mustBeInteger, mustBePositive} = 500;
                calibrationScale (1,1) {mustBeFloat} = 0.5
            end
            % Constructs a PolhemusLiberty instance.
            % INPUTS:
            %    ipAddress - The IP address of the TCP server.
            %    tcpPort - The input port of the TCP server.
            %    bufferSize - The size of a ring buffer used to store sample data for calibration.
            %    calibrationScale - A 0-1 float representing the position of each calibration point
            %       along the line from the center to the edge of the screen.

            self.ipAddress = ipAddress;
            self.tcpPort = tcpPort;
            self.homeRadius = homeRadius;
            self.ringSize = bufferSize;
            self.calibrationScale = calibrationScale;
            self.client = [];

            self.homePosition = nan(1,3);
        end

        function successFlag = establish(self, display)
            % Sets up a FIFO buffer for new samples and connects to the TCP server.
            % INPUTS:
            %    display - An instance of DisplayManager
            self.display = display;
            self.ringIdx = 0;
            self.ringBuffer = zeros(self.ringSize, 4);
            try 
                % Establish TCP/IP connection 
                self.client = tcpclient(self.ipAddress, self.tcpPort, 'ConnectTimeout', 5);
                configureTerminator(self.client, 'CR/LF');
                successFlag = true;
            catch
                disp("Failed to connect to the limb tracker at " + self.ipAddress + ":" + num2str(self.tcpPort));
                successFlag = false;
            end
        end

        function successFlag = calibrate(self)
            % Runs a calibration routine that collects sensor XYZ data from 9 points, and produces a
            % best-fit linear transformation from 3D sensor data to XYZ coordinates. This function
            % assumes that all calibration points are roughly coplanar, and uses PCA to determine
            % the minor axis. While data along the two major axes are scaled and rotated to fit into
            % screen coordinates (pixels), the minor axis is kept in sensor coordinates (mm).
            % If a liberty_calibration.mat file is found, calibration is skipped.
            % OUTPUTS:
            %    successFlag - Returns true if nothing went wrong.

            % Skip calibration if an existing calibration file is found
            if isfile('liberty_calibration.mat')
                cprintf('text', 'Detected previous Liberty calibration, loading...\n')
                load('liberty_calibration.mat', 'Date', 'CalibrationFunction', 'HomePosition');
                
                % Warn the experimenter if the calibration file is from a previous day
                if Date ~= datetime('today')
                    warning('The provided Polhemus calibration is not from today. Output values may be inaccurate!');
                end
                self.calibrationFcn = CalibrationFunction;
                self.homePosition = HomePosition;
                successFlag = true;
                return
            end

            self.display.update();
            
            isMovingColor = [102, 102, 255; 255, 102, 102];
            targets = [[-1 0 1 -1 0 1 -1 0 1] * self.display.xCenter * self.calibrationScale; ...
                       [1 1 1 0 0 0 -1 -1 -1] * self.display.yCenter * self.calibrationScale];

            % Run the 9-point calibration routine
            [sampleMat] = hitCalibrationTargets();
            sampleMat = sampleMat';
            
            % Calculate vectors of XY points relative to centroid
            centroid = mean(sampleMat, 2);
            sampleMatCentered = sampleMat - centroid;

            % Calculate distances of calibration points along the minor (Z) axis (assumes points are 
            % coplanar) using SVD
            [u, ~, ~] = svd(sampleMatCentered); % u = 3x3 orthonormal basis
            normalVec = u(:, 3);        % axis unit vector with smallest variance
            targetZs = normalVec' * sampleMatCentered;  % projections of points onto this unit vector
            
            % Calculate 3x3 linear least-squares transform matrix using pseudoinverse. This matrix 
            % will transform XY sensor coordinates to center coordinates.
            targetsExtended = [targets; targetZs];
            linearTransform = targetsExtended / sampleMatCentered;

            % Calculate final calibration function
            self.calibrationFcn = @(sample) (linearTransform * (sample(1:3)' - centroid))';
            
            % Save calibration details to manipulator_calibration.mat
            Date = datetime('today');
            CalibrationFunction = self.calibrationFcn;
            HomePosition = self.homePosition;
            save('liberty_calibration.mat', 'Date', 'CalibrationFunction', 'HomePosition');

            successFlag = true;
            
            function sampleMat = hitCalibrationTargets()
                % Handles display of 9 targets positioned in the same aspect ratio as the experiment 
                % display.
                % OUTPUTS:
                %    sampleMat - A 9x3 matrix representing the 3 mean XYZ values for all 9 targets.
                
                cprintf('RED*','Press SPACE when each target is covered and finger is still.\n');
                
                % Define a threshold for motion in each axis using the last half-second of data, at
                % 5 standard deviations (25x variance) from the mean.
                while true
                    self.poll();
                    if self.display.asyncReady()
                        self.display.drawDotsFastAt([0, 0], 63, isMovingColor(1, :) / 255);
                        self.display.updateAsync();
                    end
                    [~, ~, keyCode] = KbCheck();
                    if keyCode(32)
                        break
                    end
                end
                lastHalfSecond = self.ringBuffer(:, 4) > (GetSecs - 0.5);
                samples = self.ringBuffer(lastHalfSecond, 1:3);
                varThreshold = 25 * max(var(samples));
                KbReleaseWait;

                % Use motion threshold to gather points for each target with feedback
                sampleMat = zeros(9, 3); matIdx = 1; 
                for ii = 1:length(targets)
                    x = targets(1, ii); y = targets(2, ii);
                    while true
                        self.poll();
                        lastHalfSecond = self.ringBuffer(:, 4) > (GetSecs - 0.5);
                        samples = self.ringBuffer(lastHalfSecond, 1:3);
                        isMoving = any(var(samples) > varThreshold);

                        if self.display.asyncReady()
                            self.display.drawDotsFastAt([x, y], 63, isMovingColor(isMoving + 1, :) / 255);
                            self.display.updateAsync();
                        end
                        [~, ~, keyCode] = KbCheck();
                        if (keyCode(32) && ~isMoving)
                            KbReleaseWait;
                            break
                        end
                    end
                    sampleMat(matIdx, :) = mean(samples);
                    matIdx = matIdx + 1;
                end

                hitHomePosition();

                function hitHomePosition()
                    % Generate home text element
                    homeText.ElementType = 'text';
                    homeText.Location = [0, 0];
                    homeText.Text = 'HOME';
                    homeText.Font = 'Consolas';
                    homeText.FontSize = 40;
                    homeText.VerticalSpacing = 1;
    
                    % Gather data for home position
                    while true
                        self.poll();
                        lastHalfSecond = self.ringBuffer(:, 4) > (GetSecs - 0.5);
                        samples = self.ringBuffer(lastHalfSecond, 1:3);
                        isMoving = any(var(samples) > varThreshold);
                        homeText.Color = isMovingColor(isMoving + 1, :);
    
                        if self.display.asyncReady()
                            self.display.drawElements(homeText)
                            self.display.updateAsync();
                        end
                        [~, ~, keyCode] = KbCheck();
                        if (keyCode(32) && ~isMoving)
                            KbReleaseWait;
                            break
                        end
                    end
                    self.display.asyncEnd();
                    self.homePosition = mean(samples);
                end
            end
        end

        function availFlag = available(self)
            % Check if a new sample is available.
            % OUTPUTS: 
            %    availFlag - Returns true if a new sample is available.

            availFlag = self.client.NumBytesAvailable;
        end

        function state = poll(self)
            % Poll the most recent sample. If the polling function returns incomplete data, return
            % the most recent sample from the ring buffer instead.
            % OUTPUTS: 
            %    state - a 1x4 vector containing a timestamp, values for X and Y relative
            %       to center coordinates, and a Z value in mm above the operational plane.

            state = updateInputBuffer(self);
            if isempty(state)       % Returns most recent complete sample if newest poll is incomplete data
                state = self.ringBuffer(max(self.ringIdx, 1), :);
            end
        end

        function reset(self)
            % Does nothing.
        end

        function homeFlag = isHome(self)
            % Checks if the last polled sample is within the home position.
            % OUTPUTS:
            %    homeFlag - Returns true if the most recent sample is in the home position.
            
            stateXYZ = self.ringBuffer(max(self.ringIdx, 1), 1:3);
            homeFlag = norm(stateXYZ - self.homePosition) <= self.homeRadius;
        end

        function close(self)
            % Flush the TCP client.

            if ~isempty(self.client)
                flush(self.client);
            end
        end
    end

    methods (Access = private)
        function stateRaw = updateInputBuffer(self)
            % Polls raw data bytes from the TCP client, checks if the data is complete, converts it
            % to numerical data, and saves it in the ring buffer.
            % OUTPUTS:
            %    stateRaw - 1x4 vector of most recent sample (in mm), or empty if data was
            %    incomplete, with a timestamp.

            stateRaw = [];
            rcvd_str = readline(self.client);
            rcvd_bytes = uint8(char(rcvd_str));
            if length(rcvd_bytes) ~= 40; return; end
            
            stateRaw = [25.4 * double(typecast(rcvd_bytes(17:28), 'single')), GetSecs];
            if length(stateRaw) ~= 4
                stateRaw = [];
                return
            end
            self.ringIdx = self.ringIdx + 1;
            self.ringBuffer(self.ringIdx, :) = stateRaw;
            
            % Test code that uses mouse data instead for debugging
%             [x, y] = GetMouse(self.display.window);
%             x = min(x, self.display.xMax) - self.display.xMax/2;
%             y = -(min(y, self.display.yMax) - self.display.yMax/2);
%             stateRaw = [x, y, 0, GetSecs];
%             self.ringIdx = self.ringIdx + 1;
%             self.ringBuffer(self.ringIdx, :) = stateRaw;
        end
    end
end
