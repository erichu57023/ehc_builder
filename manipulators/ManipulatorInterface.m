classdef (Abstract) ManipulatorInterface < handle
% MANIPULATORINTERFACE Abstract implementation of a wrapper for a manipulator hardware interface.
% All manipulators must inherit this class.
%
% PROPERTIES:
%    calibrationFcn - A function handle which transforms the raw sample data output by poll() to a
%       pixel coordinate relative to the screen center
%
% METHODS:
%    establish - Sets up a connection with the manipulator hardware.
%    calibrate - Runs a calibration routine which determines how the raw manipulator data relates
%       to on-screen coordinates.
%    available - Returns true if a new sample is ready to be polled.
%    poll - Polls the most recent sample from the hardware as raw timestamped data.
%    close - Closes the connection to the hardware interface.
%
% See also: EYETRACKERINTERFACE, TRIALINTERFACE
    properties (Abstract)
        calibrationFcn
    end
    
    methods (Abstract)
        establish
        calibrate
        available
        poll
        close
    end
end
