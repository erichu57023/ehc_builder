classdef PolhemusLiberty < ManipulatorInterface
    properties (Access = private)
        display
        ipAddress
        tcpPort
        client
    end

    methods
        function self = PolhemusLiberty(ipAddress, tcpPort)
            arguments
                ipAddress {mustBeTextScalar} = '127.0.0.1';
                tcpPort {mustBeInteger, mustBeNonnegative} = 7234;
            end
            self.ipAddress = ipAddress;
            self.tcpPort = tcpPort;
        end

        function successFlag = establish(self, display)
            successFlag = true;
            self.display = display;
            try 
                % Establish TCP/IP connection 
                self.client = tcpclient(self.ipAddress, self.tcpPort, 'ConnectTimeout', 5);
                configureTerminator(self.client, 'CR/LF');
            catch
                disp('Failed to connect to the limb tracker at ' + self.ipAddress + ':' + num2str(self.tcpPort));
                successFlag = false;
            end
        end

        function successFlag = calibrate(self)
            %TODO
            successFlag = false;
        end

        function availFlag = available(self)
            availFlag = self.client.NumBytesAvailable >= 26;
        end

        function state = poll(self)
            %TODO
            state = self.pollRaw();
        end

        function self = close(self)
            self.state = nan;
            flush(self.client)
            self.client = [];
        end
    end

    methods (Access = private)
        function stateRaw = pollRaw(self)
            stateRaw = read(self.client, 6, 'single');
            read(self.client, 2);   % Clear CR/LF bytes
        end
    end
end
