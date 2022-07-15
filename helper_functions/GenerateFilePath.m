function filepath = GenerateFilePath()
    % Query subject initials and create a filepath for output data
    subInput = inputdlg2({'Please enter initials here:'}, 'Initials', 1, {'XXX'});
    if isempty(subInput)
        disp('No initials were provided.');
        return
    end

    initials = char(subInput); 
    todayString = datestr(datetime('now'), 'yy-mm-dd');
    nowString = datestr(datetime('now'), 'HHMM');
    
    filepath = convertCharsToStrings(['data/', todayString, '/', initials, '_', nowString, '.mat']);
    
    if ~isfolder(['data/', todayString])
        mkdir(['data/', todayString]);
    end
end