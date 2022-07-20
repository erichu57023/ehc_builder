function filepath = GenerateFilePath()
% GENERATEFILEPATH Queries user for their initials, and produces a filepath that is used to save data.
% OUTPUT:
%    filepath - a location relative to the ehc_builder directory where data can be saved.

    % Ask user for their initials
    subInput = inputdlg2({'Please enter initials here:'}, 'Initials', 1, {'XXX'});
    if isempty(subInput)
        disp('No initials were provided.');
        return
    end
    initials = char(subInput); 

    % Generate some strings based on the current date and time
    todayString = datestr(datetime('now'), 'yy-mm-dd');
    nowString = datestr(datetime('now'), 'HHMM');
    
    % Reserve a path under ehc_builder/data/<date>/<initials>_<time>.mat
    filepath = convertCharsToStrings(['data/', todayString, '/', initials, '_', nowString, '.mat']);
    
    % Create the necessary folders if they do not exist
    if ~isfolder(['data/', todayString])
        mkdir(['data/', todayString]);
    end
end