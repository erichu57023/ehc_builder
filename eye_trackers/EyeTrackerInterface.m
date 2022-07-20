classdef (Abstract) EyeTrackerInterface < handle
% EYETRACKERINTERFACE Abstract implementation of a wrapper for an eye tracker hardware interface.
% All eye trackers must inherit this class.
%
% PROPERTIES:
%    calibrationFcn - A function handle which transforms the raw sample data output by poll() to a
%       pixel coordinate relative to the screen center
%
% METHODS:
%    establish - Sets up a connection with the eye tracking hardware.
%    calibrate - Runs a calibration routine which determines how the raw eye-tracking data relates
%       to on-screen coordinates.
%    available - Returns true if a new sample is ready to be polled.
%    poll - Polls the most recent sample from the hardware as raw timestamped data.
%    driftCorrect - Zeros the incoming data on the screen center to correct for drift in head/camera
%       position between trials.
%    close - Closes the connection to the hardware interface.
%
% See also: MANIPULATORINTERFACE, TRIALINTERFACE
    
    properties (Abstract)
        calibrationFcn
    end
    methods (Abstract)
        establish
        calibrate
        available
        poll
        driftCorrect
        close
    end
end
