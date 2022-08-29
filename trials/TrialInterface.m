classdef (Abstract) TrialInterface < handle
% TRIALINTERFACE Abstract implementation of a trial manager. All trials must inherit this class.
%
% PROPERTIES:
%    numRounds - The number of rounds to generate in this set of trials.
%    trialType - A specifier indicating how the look and reach portions of the trial should be
%       handled. Supported values are 'look' for look-only, 'reach' for reach-only, 'segmented' to
%       separate look and reach stages, or 'free' (by default).
%    timeout - The duration in seconds that the user is allowed to play during the trial phase
%       before triggering a timeout.
%    intro - A struct containing elements to be displayed during the intro phase (information on
%       targets, instruction text, etc.) of the current round.
%    elements - A struct containing elements to be displayed during the trial phase of the current
%       round.
%    target - A struct containing elements that represent target zones, where a success condition
%       may be met.
%    failzone - A struct containing elements that represent failure zones, where a failure condition
%       may be met.
%
% METHODS:
%    generate - Runs once per round, and populates the intro, elements, target and failzone
%       properties with new values.
%    check - Runs continuously during the trial phase, and checks whether an input state matches a
%       pass condition. The output reflects the nature of the pass condition: >0 for success, <0 for
%       failure, and 0 for timeout.
%
% See also: EYETRACKERINTERFACE, MANIPULATORINTERFACE, DISPLAYMANAGER

    properties (Abstract)
        numRounds
        trialType
        timeout
        intro
        elements
        target
        failzone
    end

    methods (Abstract)
        generate
        check
    end
end
