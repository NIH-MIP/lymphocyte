% PLEASE NOTE THIS IS JUST A STARTER CODE - I HAVE NOT RUN IT -- ITS JUST
% AN EXAMPLE TO FOR HOW TO BUILD MAPS BACK FROM THE PREDICTIONS THAT ARE
% OUTPUT FROM PRED.PY AND FOLLOWS THE SAME CONVENTION AS PATCH_EXTRACT.PY

srcl = '/data/MIP/'; %
powerref = 20;
pullsize = 5000;
boxSz = 100;
addpath([srcl 'code/MATLAB/Path_Scripts/bfmatlab'])
mainDir = [srcl 'TCGABLCA/cohort_final']; %this is where data is
tilDIR = [srcl 'path']; %this is where your TIL output is
saveDir = '';

for casei = 1:size(slides_unique,1)
    disp(slides_unique{casei})
    tcga_id = slides_unique{casei}(1:12);
    
    %this function uses bioformats instead of openslide, which i have now
    %moved to for all my python coding
    % the package is bioformats for matlab (bfmatlab)
    svsfind = dir([mainDir filesep tcga_id filesep slides_unique{casei} '*.svs']);
    svs_file = svsfind(1).name;
    caseData = bfGetReader([mainDir filesep tcga_id filesep svs_file]);
    caseMeta = caseData.getMetadataStore();
    caseMag = round(caseMeta.getObjectiveNominalMagnification(0,0).doubleValue(),2);
    resizefactor = caseMag/powerref;
    
    width = eval(caseMeta.getPixelsSizeX(0));
    height = eval(caseMeta.getPixelsSizeY(0));
    
    num_subs_updown = int(floor(width/pullsize)) + 1;
    num_subs_leftright = int(floor(height/pullsize)) + 1;
    
     list_TIL = {};
     TILlist = dir([tilDir 'Pred_' tcga_id '*']); %this is location where all your TILs are
     for listi = 1:numel(TILlist)
         TIL = readtable([TILlist(listi).folder filesep TILlist(listi).name]) ;
         TIL = table2cell(TIL); 
         list_TIL = cat(1,list_TIL,TIL); 
         %clear TIL
     end
     
    for TILi = 1:size(list_TIL,1)
        filei = strsplit(list_TIL{TILi,1},'_');
        list_TIL{TILi,6} = filei{1}; %tcga ID
        list_TIL{TILi,7} = filei{2}; %batchID
        list_TIL{TILi,8} = strrep(filei{3},'.png',''); %subID
    end
     
    out_map_TIL = zeros(width/resizefactor,height/resizefactor);
    
    batch = 1;
    %note to self: double check if x and y are flipped from TCGA
    for x = 1:num_subs_leftright
        for y = 1:num_subs_updown
            batch_TIL = list_TIL(strcmpi(list_TIL(:,7),['batch' int2str(batch) '-' int2str((x-1)*pullsize) '-' int2str((y-1)*pullsize)]),:);
            x_fit = round(pullsize/(boxSz*resizefactor));
            y_fit = round(pullsize/(boxSz*resizefactor));
            patchnum = 1;
            for xi = 1:x_fit
                for yi = 1:y_fit
                    sub_patch = batch_TIL(strcmpi(list_TIL(:,7),['sub' int2str(patchnum)]),:);
                    if(~isempty(sub_patch))
                         out_map_TIL((x-1)*pullsize+(xi-1)*boxSz+1:(x-1)*pullsize+xi*boxSz,(y-1)*pullsize+(yi-1)*boxSz+1:(y-1)*pullsize+yi*boxSz) =   out_map_TIL((x-1)*pullsize+(xi-1)*boxSz+1:(x-1)*pullsize+xi*boxSz,(y-1)*pullsize+(yi-1)*boxSz+1:(y-1)*pullsize+yi*boxSz) + sub_patch{1,5};
                    end
                    patchnum = patchnum+1;
                end
            end
           batch = batch+1;
        end
    end
        
    imwrite(out_map_TIL,[saveDir filesep 'saveName.jpeg']);
    save([saveDir filesep 'saveName.jpeg'],'out_map_TIL');
end