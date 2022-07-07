classdef PolhemusLiberty < ManipulatorInterface
    properties (Access = private)
        display
        ipAddress
        tcpPort
        client
        ringBuffer; ringIdx; ringSize
        tableLevel
        xyTransform
    end

    methods
        function self = PolhemusLiberty(ipAddress, tcpPort, bufferSize)
            arguments
                ipAddress {mustBeTextScalar} = '127.0.0.1';
                tcpPort {mustBeInteger, mustBeNonnegative} = 7234;
                bufferSize {mustBeInteger, mustBePositive} = 5000;
            end
            self.ipAddress = ipAddress;
            self.tcpPort = tcpPort;
            self.ringSize = bufferSize;
        end

        function successFlag = establish(self, display)
            self.display = display;
            self.ringIdx = 0;
            self.ringBuffer = zeros(self.ringSize, 7);
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
            %TODO
            successFlag = false;
        end

        function availFlag = available(self)
            availFlag = self.client.NumBytesAvailable;
        end

        function state = poll(self)
            state = pollRaw(self);
        end

        function close(self)
            flush(self.client)
            clear self
        end
    end

    methods (Access = private)
        function stateRaw = pollRaw(self)
            rcvd_str = readline(self.client);
            rcvd_bytes = uint8(char(rcvd_str));
            if length(rcvd_bytes) < 40
                stateRaw = [];
                return
            end
            stateRaw = [GetSecs, typecast(rcvd_bytes(17:end), 'single')];
            self.ringIdx = self.ringIdx + 1;
            self.ringBuffer(self.ringIdx, :) = stateRaw;
        end
    end
end
