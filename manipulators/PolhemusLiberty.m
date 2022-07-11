classdef PolhemusLiberty < ManipulatorInterface
    properties
        calibrationFcn
    end
    properties (Access = private)
        display
        ipAddress
        tcpPort
        client
        tableLevel
        ringBuffer; ringIdx; ringSize
    end

    methods
        function self = PolhemusLiberty(ipAddress, tcpPort, bufferSize)
            arguments
                ipAddress {mustBeTextScalar} = 'localhost';
                tcpPort {mustBeInteger, mustBeNonnegative} = 7234;
                bufferSize {mustBeInteger, mustBePositive} = 500;
            end
            self.ipAddress = ipAddress;
            self.tcpPort = tcpPort;
            self.ringSize = bufferSize;
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

        function successFlag = calibrate(self, importCalibration)
            % Assumes that the YZ plane of the sensor coincides with the XY
            % plane of the manipulator controls. If the optional
            % calibration function is provided, skips calibration.
            arguments
                self
                importCalibration (1, 1) {mustBeA(importCalibration, 'function_handle')} = @(x) 'default'
            end
            if ~ischar(importCalibration(zeros(4)))
                self.calibrationFcn = importCalibration;
                successFlag = true;
                return
            end

            self.display.update();
            
            movingColor = [255, 102, 102] / 255;
            stillColor = [102, 102, 255] / 255;
            targets = [[-1 0 1 -1 0 1 -1 0 1] * 216.375, -293.6875; ...
                       [1 1 1 0 0 0 -1 -1 -1] * 119.0625, -147.6375];
            sampleMat = hitCalibrationTargets();
            
            % zColumn should have the smallest variance
            [~, zColumn] = min(var(sampleMat));
            zOffset = [0, 0, mean(sampleMat(:, zColumn))];

            % Calculate vectors of XY points relative to center point
            xyColumn = find(1:3 ~= zColumn);
            xyMat = sampleMat(:, xyColumn)';
            xyIn = xyMat(:, [1:4, 6:end]) - xyMat(:, 5);
            xyOut = targets(:, [1:4, 6:end]);

            % Calculate 2x2 linear least-squares transform matrix using
            % pseudoinverse (self.xyTransform * xyIn ~~ xyOut). This matrix
            % will transform XY sensor coordinates to center coordinates.
            xyzLinear = xyOut * pinv(xyIn);

            % Calculate final calibration function; zColumn will remain in
            % native sensor units with constant offset subtracted
            xyzLinear(3, 3) = 1;
            self.calibrationFcn = @(sample) sample([xyColumn zColumn] + 1) * xyzLinear' - zOffset;
            
            successFlag = true;

            function sampleMat = hitCalibrationTargets()
                % Returns a 10x3 matrix representing the 3 mean XYZ values for
                % all 10 targets.
                
                cprintf('RED*','Press SPACE when each target is covered and finger is still.\n');
                % Define a threshold for motion in each axis
                while true
                    state = self.poll();
                    lastSecond = self.ringBuffer(:, 1) > (GetSecs - 1);

                    lastFrameTime = self.display.asyncReady();
                    if lastFrameTime
                        self.display.drawDotsFastAt([0, 0; state(2:3)], [63 10], [movingColor; [1 1 1] * self.display.white]);
                        self.display.updateAsync(lastFrameTime);
                    end
                    [~, ~, keyCode] = KbCheck();
                    if keyCode(32)
                        KbReleaseWait;
                        break
                    end
                end
                samples = self.ringBuffer(lastSecond, 2:4);
                varThreshold = 1.25 * var(samples);

                % Use motion threshold to gather points for each target with
                % feedback
                sampleMat = zeros(9, 3); matIdx = 1; 
                for ii = 1:length(targets)
                    x = targets(1, ii); y = targets(2, ii);
                    while true
                        state = self.poll();
                        lastSecond = self.ringBuffer(:, 1) > (GetSecs - 1);
                        samples = self.ringBuffer(lastSecond, 2:4);
                        isMoving = ~all(var(samples) <= varThreshold);

                        lastFrameTime = self.display.asyncReady();
                        if lastFrameTime
                            if isMoving
                                self.display.drawDotsFastAt([x, y; state(2:3)], [63 10], [movingColor; [1 1 1] * self.display.white]);
                            else
                                self.display.drawDotsFastAt([x, y; state(2:3)], [63 10], [stillColor; [1 1 1] * self.display.white]);
                            end
                            self.display.updateAsync(lastFrameTime);
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
                self.display.asyncEnd();
            end
        end

        function availFlag = available(self)
            availFlag = self.client.NumBytesAvailable;
        end

        function state = poll(self)
            state = updateInputBuffer(self);
            if ~state       % Returns most recent complete sample if newest poll is incomplete data
                state = self.ringBuffer(max(self.ringIdx, 1));
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
            rcvd_str = readline(self.client);
            rcvd_bytes = uint8(char(rcvd_str));
            
            if length(rcvd_bytes) < 40
                stateRaw = [];
                return
            end
            stateRaw = [GetSecs, double(typecast(rcvd_bytes(17:28), 'single'))];

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
