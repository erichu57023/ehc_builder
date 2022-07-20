function GenerateNavonLetters()
% GENERATENAVONLETTERS Creates 9x7 Navon strings for each letter in the English alphabet, based on
% navon_letters.txt, and saves it in a file called navon_letters.mat.
    
    fileID = fopen('navon_letters.txt');
    for ii = 1:26
        letters{ii} = '';
        for jj = 1:7
            letters{ii} = [letters{ii}, fgets(fileID)];
        end
        fgetl(fileID);
    end
    
    save("helper_functions/navon_letters.mat", 'letters');
    fclose(fileID);
end
