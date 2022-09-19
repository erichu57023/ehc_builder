classdef ManipulatorInterface < handle & matlab.mixin.Heterogeneous
% MANIPULATORINTERFACE Abstract implementation of a wrapper for a manipulator hardware interface.
% All manipulators must inherit this class.
%
% PROPERTIES:
%    calibrationFcn - A function handle which transforms the raw sample data output by poll() to a
%       pixel coordinate relative to the screen center
%    homePosition - A raw sample in the sensor domain, which represents the home position of the
%       experiment
%    homeRadius - The radius of the home position in sensor units.
%
% METHODS:
%    establish - Sets up a connection with the manipulator hardware.
%    calibrate - Runs a calibration routine which determines how the raw manipulator data relates
%       to on-screen coordinates.
%    available - Returns true if a new sample is ready to be polled.
%    poll - Polls the most recent sample from the hardware as raw timestamped data.
%    reset - Returns the manipulator to the home position. This should only be used for manipulators
%       whose positions can be set through code.
%    isHome - Checks whether the manipulator is in the home position.
%    close - Closes the connection to the hardware interface.
%
% See also: EYETRACKERINTERFACE, TRIALINTERFACE
    
    properties (Abstract)
        calibrationFcn
        homePosition
        homeRadius
    end
    
    methods (Abstract)
        establish
        calibrate
        available
        poll
        reset
        isHome
        close
    end

    % Sealed operations compatible with heterogenous subclass arrays
    methods (Sealed)
        function successFlags = establishAll(manipList, display)
            successFlags = zeros(1, numel(manipList));
            for kk = 1 : numel(manipList)
                successFlags(kk) = manipList(kk).establish(display);
            end
        end
        function successFlags = calibrateAll(manipList)
            successFlags = zeros(1, numel(manipList));
            for kk = 1 : numel(manipList)
                successFlags(kk) = manipList(kk).calibrate();
            end
        end
        function availFlags = availableAll(manipList)
            availFlags = zeros(1, numel(manipList));
            for kk = 1 : numel(manipList)
                availFlags(kk) = manipList(kk).available();
            end
        end
        function states = pollAll(manipList)
            states = cell(1, numel(manipList));
            for kk = 1 : numel(manipList)
                states{kk} = manipList(kk).poll();
            end
        end
        function resetAll(manipList)
            for manip = manipList
                manip.reset();
            end
        end
        function homeFlags = isHomeAll(manipList)
            homeFlags = zeros(1, numel(manipList));
            for kk = 1 : numel(manipList)
                homeFlags(kk) = manipList(kk).isHome();
            end
        end
        function closeAll(manipList)
            for manip = manipList
                manip.close();
            end
        end
    end
end
