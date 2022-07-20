classdef PolhemusLiberty < ManipulatorInterface
    properties
        calibrationFcn
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
        function self = PolhemusLiberty(ipAddress, tcpPort, bufferSize, calibrationScale)
            arguments
                ipAddress {mustBeTextScalar} = 'localhost';
                tcpPort (1,1) {mustBeInteger, mustBeNonnegative} = 7234;
                bufferSize (1,1) {mustBeInteger, mustBePositive} = 500;
                calibrationScale (1,1) {mustBeFloat} = 0.5
            end
            self.ipAddress = ipAddress;
            self.tcpPort = tcpPort;
            self.ringSize = bufferSize;
            self.calibrationScale = calibrationScale;
            self.client = [];
        end

        function successFlag = establish(self, display)
            self.display = display;
            self.ringIdx = 0;
            self.ringBuffer = zeros(self.ringSize, 4);
            self.calibrationFcn = @(x) x(2:3);
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
            % Assumes that the YZ plane of the sensor coincides with the XY
            % plane of the manipulator controls. If the optional
            % calibration function is provided, skips calibration.

            if isfile('manipulator_calibration.mat')
                cprintf('text', 'Detected previous manipulator calibration, loading...\n')
                load('manipulator_calibration.mat', 'Date', 'CalibrationFunction');
                if Date ~= datetime('today')
                    warning('The provided Polhemus calibration is not from today. Output values may be inaccurate!');
                end
                self.calibrationFcn = CalibrationFunction;
                successFlag = true;
                return
            end

            self.display.update();
            
            isMovingColor = [102, 102, 255; 255, 102, 102] / 255;

            targets = [[-1 0 1 -1 0 1 -1 0 1] * self.display.xCenter * self.calibrationScale; ...
                       [1 1 1 0 0 0 -1 -1 -1] * self.display.yCenter * self.calibrationScale];
            sampleMat = hitCalibrationTargets();
            
            % zColumn should have the smallest range
            [~, zColumn] = min(range(sampleMat));

            % Calculate vectors of XY points relative to center point
            xyColumn = find(1:3 ~= zColumn);
            xyMat = sampleMat(:, xyColumn)';
            xyzOffset = sampleMat(5, [xyColumn zColumn]);
            xyIn = xyMat(:, [1:4, 6:end]) - xyMat(:, 5);
            xyOut = targets(:, [1:4, 6:end]);
            
            % Calculate 2x2 linear least-squares transform matrix using
            % pseudoinverse (self.xyTransform * xyIn ~~ xyOut). This matrix
            % will transform XY sensor coordinates to center coordinates.
            xyzLinear = xyOut * pinv(xyIn);

            % Calculate final calibration function; zColumn will remain in
            % native sensor units with constant offset subtracted
            xyzLinear(3, 3) = 1;
            self.calibrationFcn = @(sample) (sample([xyColumn zColumn] + 1) - xyzOffset) * xyzLinear';
            
            Date = datetime('today');
            CalibrationFunction = self.calibrationFcn;
            save('manipulator_calibration.mat', 'Date', 'CalibrationFunction');

            successFlag = true;

            function sampleMat = hitCalibrationTargets()
                % Returns a 9x3 matrix representing the 3 mean XYZ values for
                % all 9 targets.
                
                cprintf('RED*','Press SPACE when each target is covered and finger is still.\n');
                % Define a threshold for motion in each axis
                while true
                    self.poll();
                    if self.display.asyncReady()
                        self.display.drawDotsFastAt([0, 0], 63, isMovingColor(2, :));
                        self.display.updateAsync();
                    end
                    [~, ~, keyCode] = KbCheck();
                    if keyCode(32)
                        break
                    end
                end
                lastHalfSecond = self.ringBuffer(:, 1) > (GetSecs - 0.5);
                samples = self.ringBuffer(lastHalfSecond, 2:4);
                varThreshold = 25 * max(var(samples));
                KbReleaseWait;

                % Use motion threshold to gather points for each target with
                % feedback
                sampleMat = zeros(9, 3); matIdx = 1; 
                for ii = 1:length(targets)
                    x = targets(1, ii); y = targets(2, ii);
                    while true
                        self.poll();
                        lastHalfSecond = self.ringBuffer(:, 1) > (GetSecs - 0.5);
                        samples = self.ringBuffer(lastHalfSecond, 2:4);
                        isMoving = any(var(samples) > varThreshold);

                        if self.display.asyncReady()
                            self.display.drawDotsFastAt([x, y], 63, isMovingColor(isMoving + 1, :));
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
            end
        end

        function availFlag = available(self)
            availFlag = self.client.NumBytesAvailable;
        end

        function state = poll(self)
            state = updateInputBuffer(self);
            if isempty(state)       % Returns most recent complete sample if newest poll is incomplete data
                state = self.ringBuffer(max(self.ringIdx, 1), :);
            end
        end

        function close(self)
            if ~isempty(self.client)
                flush(self.client);
            end
        end
    end

    methods (Access = private)
        function stateRaw = updateInputBuffer(self)
            stateRaw = [];
            rcvd_str = readline(self.client);
            rcvd_bytes = uint8(char(rcvd_str));
            if length(rcvd_bytes) ~= 40; return; end
            
            stateRaw = [GetSecs, 10 * double(typecast(rcvd_bytes(17:28), 'single'))];
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
%             stateRaw = [GetSecs, x, y, 0];
%             self.ringIdx = self.ringIdx + 1;
%             self.ringBuffer(self.ringIdx, :) = stateRaw;
        end
    end
end
