function GenerateNavonLetters()
    fileID = fopen('navon_letters.txt');
    for ii = 1:26
        letters{ii} = '';
        for jj = 1:7
            letters{ii} = [letters{ii}, fgets(fileID)];
        end
        fgetl(fileID);
    end
    
    save("navon_letters.mat", 'letters')
    fclose(fileID);
end
