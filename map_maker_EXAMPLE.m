%this code reads in predictions that were made at multiple resolutions
%(including TILs) and reconstructs the maps based on the information in the
%file name from the patch that was fed into 5 different networks


srcl = '/data/MIP/'; %
addpath([srcl 'code/MATLAB/Path_Scripts/bfmatlab'])
mainDir = [srcl 'TCGABLCA/cohort_final']; %'V:\TCGABLCA'
csvLoc = [srcl 'TCGABLCA/predictions/csv'];

% csvs from validation set
mapLoc = [srcl 'TCGABLCA/predictions/maps/val_small/images'];
mapLoc2 = [srcl 'TCGABLCA/predictions/maps/val_small/matfiles'];
preds_5x = readtable([csvLoc filesep 'val_results_by_img_5x_40_noloss_06142019-1653.pkl_06252019-1852.csv'],'Delimiter',',');
preds_10x = readtable([csvLoc filesep 'val_results_by_img_10x_37_one5loss_06142019-1945.pkl_06252019-1845.csv'],'Delimiter',',');
preds_20x = readtable([csvLoc filesep 'val_results_by_img_20x_37_two5loss_06282019-0417.pkl_06282019-1344.csv'],'Delimiter',',');
preds_40x = readtable([csvLoc filesep 'val_results_by_img_40x_obs_2loss_07142019-0637.pkl_07162019-2352.csv'],'Delimiter',',');


%find unique patients in 5x, 10x, 20x, 40x - we read in TILs later
list_5x = table2cell(preds_5x); list_5x = list_5x(:,2:5);
list_10x = table2cell(preds_10x); list_10x = list_10x(:,2:5);
list_20x = table2cell(preds_20x); list_20x = list_20x(:,2:5);
list_40x = table2cell(preds_40x); list_40x = list_40x(:,2:5);

%5x
%example of 5x naming: 
% TCGA-GC-A3BM-01Z-00-DX1_roi1_box6-1164-6721_0.34_neg.jpeg
% the first 4 columns are: filename, prediction, probability negative, probability positive 
for i = 1:size(list_5x,1)
    filei = strsplit(list_5x{i,1},'_');
    list_5x{i,5} = filei{1};
    list_5x{i,6} = filei{2};
    list_5x{i,7} = filei{3};
    list_5x{i,8} = strrep(filei{5},'.jpeg','');
end
uniq_5x = unique(list_5x(:,5));

%10x
%example of 10x naming
% TCGA-GC-A3BM-01Z-00-DX1_roi1_box18-3490-5601_xbox2_0.19_neg.jpeg
% the first 4 columns are: filename, prediction, probability negative, probability positive 
for i = 1:size(list_10x,1)
    filei = strsplit(list_10x{i,1},'_');
    list_10x{i,5} = filei{1};
    list_10x{i,6} = filei{2};
    list_10x{i,7} = filei{3};
    list_10x{i,8} = filei{4};
end
uniq_10x = unique(list_10x(:,5));

%20x
%example of 20x naming
% 'TCGA-GC-A3BM-01Z-00-DX1_roi1_box4-1164-4481_xxbox8_0.07_neg.jpeg'
% the first 4 columns are: filename, prediction, probability negative, probability positive 
for i = 1:size(list_20x,1)
    filei = strsplit(list_20x{i,1},'_');
    list_20x{i,5} = filei{1};
    list_20x{i,6} = filei{2};
    list_20x{i,7} = filei{3};
    list_20x{i,8} = filei{4};
end
uniq_20x = unique(list_20x(:,5));

%40x
% example of 40x naming
% 'TCGA-GC-A3BM-01Z-00-DX1_roi1_box4-1164-4481_xxxbox44_0.36_neg.jpeg'
% the first 4 columns are: filename, prediction, probability negative, probability positive 
for i = 1:size(list_40x,1)
    filei = strsplit(list_40x{i,1},'_');
    list_40x{i,5} = filei{1};
    list_40x{i,6} = filei{2};
    list_40x{i,7} = filei{3};
    list_40x{i,8} = filei{4};
end
uniq_40x = unique(list_40x(:,5));

uniq_all = uniq_40x;
slides_unique = unique(uniq_all);
slides_unique = setdiff(slides_unique,{'TCGA-BT-A2LA-01Z-00-DX1'});


%now we start reading in each case
for casei = 1:size(slides_unique,1)
    disp(slides_unique{casei})
    tcga_id = slides_unique{casei}(1:12);
    
    %this function uses bioformats instead of openslide, which i have now
    %moved to for all my python coding
    svsfind = dir([mainDir filesep tcga_id filesep slides_unique{casei} '*.svs']);
    svs_file = svsfind(1).name;
    caseData = bfGetReader([mainDir filesep tcga_id filesep svs_file]);
    caseMeta = caseData.getMetadataStore();
    caseMag = round(caseMeta.getObjectiveNominalMagnification(0,0).doubleValue(),2);
    
    %this is if you have voi data
    voifind = dir([mainDir filesep tcga_id filesep 'voi' filesep strrep(svs_file,'.svs','') '*_points.mat']);
    roidata = load([voifind(1).folder filesep voifind(1).name]);

    %depending on which magnification working at
    if(caseMag == 40)
        refratio = 4;
    elseif(caseMag == 20)
        refratio = 1;
    end
    
    lvls = zeros(caseMeta.getImageCount,3);
    for k = 1:caseMeta.getImageCount
        lvls(k,1) = eval(caseMeta.getPixelsSizeX(k-1)); 
        lvls(k,2) = eval(caseMeta.getPixelsSizeY(k-1)); 
        lvls(k,3) = lvls(1,1)/lvls(k,1); %mag difference from 40x
    end

    %find mag levels within file structure
    lvls_mag = lvls(:,3)';
    lvls_mag = round(lvls_mag(mod(log(round(lvls_mag))/log(2),1)==0));
    start_lvl = find(round(lvls(:,3)) == refratio);

    imgsize_orig = [lvls(start_lvl,2) lvls(start_lvl,1)];
    %we set our final image size to be such that each TIL = 1 pixel
    imgsize = ceil(imgsize_orig.*0.02);

    %pre-allocate all image masks
    count_map_5x = zeros(imgsize);
    count_map_10x = zeros(imgsize);
    count_map_20x = zeros(imgsize);
    count_map_40x = zeros(imgsize);
    count_map_TIL = zeros(imgsize);
    out_map_5x = zeros(imgsize);
    out_map_10x = zeros(imgsize);
    out_map_20x = zeros(imgsize);
    out_map_40x = zeros(imgsize);
    out_map_TIL = zeros(imgsize);
    all_mask = zeros(imgsize);
    
    slide_Data_5x = list_5x(strcmpi(list_5x(:,5),slides_unique{casei}),:);
    slide_Data_10x = list_10x(strcmpi(list_10x(:,5),slides_unique{casei}),:);
    slide_Data_20x = list_20x(strcmpi(list_20x(:,5),slides_unique{casei}),:);
    slide_Data_40x = list_40x(strcmpi(list_40x(:,5),slides_unique{casei}),:);
    
    %find unique rois
     slide_rois = unique(slide_Data_5x(:,6));

     %now read in TILs
     list_TIL = {};
     TILlist = dir(['/data/MIP/TCGABLCA/TIL/heat_map/Pred_' tcga_id '*']);
     for listi = 1:numel(TILlist)
         TIL = readtable([TILlist(listi).folder filesep TILlist(listi).name]) ;
         TIL = table2cell(TIL); 
         list_TIL = cat(1,list_TIL,TIL); 
         %clear TIL
     end
     
    %example TIL naming
    % TCGA-XF-AAML-01Z-00-DX1_roi1_box70-6001-4878_til-41_0.10_neg.jpeg
    %first colum is filename, 5th column is prediction
    for TILi = 1:size(list_TIL,1)
        filei = strsplit(list_TIL{TILi,1},'_');
        list_TIL{TILi,6} = filei{1};
        list_TIL{TILi,7} = filei{2};
        list_TIL{TILi,8} = filei{3};
        list_TIL{TILi,9} = str2num(strrep(filei{4},'til-',''));
    end
    
    %parse over ROIS
    for roi_i = 1:size(slide_rois,1)
        %this just string matches to find the ROI data from this patient
        %within all of the different prediction tables
        roi_5x = slide_Data_5x(strcmpi(slide_Data_5x(:,6),slide_rois{roi_i}),:);
        roi_10x = slide_Data_10x(strcmpi(slide_Data_10x(:,6),slide_rois{roi_i}),:);
        roi_20x = slide_Data_20x(strcmpi(slide_Data_20x(:,6),slide_rois{roi_i}),:);
        roi_40x = slide_Data_40x(strcmpi(slide_Data_40x(:,6),slide_rois{roi_i}),:);
        roi_TIL = list_TIL(strcmpi(list_TIL(:,7),slide_rois{roi_i}),:);

        %this finds the roi data and makes mask from points
        jroi = roidata.roi_final{1,roi_i};
        jroi = jroi./refratio;
        jmask = poly2mask(jroi(:,1),jroi(:,2),imgsize_orig(1),imgsize_orig(2));
        jinds = find(jmask>0);
        roi_mask = zeros(imgsize_orig);
        roi_mask(jinds) = 1;
        roi_mask = imresize(roi_mask,0.02,'method','nearest');
        all_mask = all_mask + roi_mask;
    
        %each of the boxes are determined by 5x level so we start there
        for box_i = 1:size(roi_5x,1)
            box_label = roi_5x{box_i,7};
            boxparts = strsplit(box_label,'-');
            box_dims = round([str2num(boxparts{2}) str2num(boxparts{3})].*0.02);
            box_10x = roi_10x(strcmpi(roi_10x(:,7),roi_5x{box_i,7}),:);
            box_20x = roi_20x(strcmpi(roi_20x(:,7),roi_5x{box_i,7}),:);
            box_40x = roi_40x(strcmpi(roi_40x(:,7),roi_5x{box_i,7}),:);
            box_TIL = roi_TIL(strcmpi(roi_TIL(:,8),roi_5x{box_i,7}),:);
            
            %5x box
            boxSz = 1200*0.02;
            out_map_5x(box_dims(1)+1:box_dims(1)+boxSz,box_dims(2)+1:box_dims(2)+boxSz) = out_map_5x(box_dims(1)+1:box_dims(1)+boxSz,box_dims(2)+1:box_dims(2)+boxSz) + roi_5x{box_i,4};
            count_map_5x(box_dims(1)+1:box_dims(1)+boxSz,box_dims(2)+1:box_dims(2)+boxSz) = count_map_5x(box_dims(1)+1:box_dims(1)+boxSz,box_dims(2)+1:box_dims(2)+boxSz) + 1;
            
            %10x
            bxSz = 600*0.02;
            counter10 = 1;
            for i = 1:2
                for j = 1:2
                    lilbox = box_10x(strcmpi(box_10x(:,8),['xbox' int2str(counter10)]),:);
                    if(~isempty(lilbox))
                        out_map_10x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) = out_map_10x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) + lilbox{1,4};
                        count_map_10x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) = count_map_10x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) + 1;
                    end
                    counter10 = counter10 + 1;
                end
            end
            
            %20x
            bxSz = 300*0.02;
            counter20 = 1;
            counter40 = 1;
            tilcounter = 1;
            for i = 1:4
                for j = 1:4
                    lilbox = box_20x(strcmpi(box_20x(:,8),['xxbox' int2str(counter20)]),:);
                    lilTIL = box_TIL(strcmpi(box_TIL(:,9),['xxbox' int2str(counter20)]),:);
                    if(~isempty(lilbox))
                        out_map_20x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) = out_map_20x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) + lilbox{1,4};
                        count_map_20x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) = count_map_20x(box_dims(1)+(i-1)*bxSz+1:box_dims(1)+i*bxSz,box_dims(2)+(j-1)*bxSz+1:box_dims(2)+j*bxSz) + 1;
                    end
                    dims_20 = [box_dims(1)+(i-1)*bxSz box_dims(2)+(j-1)*bxSz];
                    counter20 = counter20 + 1;

                    %40x were set within 20x boxes
                    fSize = 150*0.02;   
                    for x20 = 1:2
                        for y20 = 1:2
                            fbox = box_40x(strcmpi(box_40x(:,8),['xxxbox' int2str(counter40)]),:);
                            if(~isempty(fbox))
                                 out_map_40x(dims_20(1)+(x20-1)*fSize+1:dims_20(1)+x20*fSize,dims_20(2)+(y20-1)*fSize+1:dims_20(2)+y20*fSize)   =   out_map_40x(dims_20(1)+(x20-1)*fSize+1:dims_20(1)+x20*fSize,dims_20(2)+(y20-1)*fSize+1:dims_20(2)+y20*fSize) + fbox{1,4};
                                 count_map_40x(dims_20(1)+(x20-1)*fSize+1:dims_20(1)+x20*fSize,dims_20(2)+(y20-1)*fSize+1:dims_20(2)+y20*fSize) = count_map_40x(dims_20(1)+(x20-1)*fSize+1:dims_20(1)+x20*fSize,dims_20(2)+(y20-1)*fSize+1:dims_20(2)+y20*fSize) + 1;
                            end
                            counter40 = counter40 +1;
                        end
                    end
                    
                    %TILs were also set within 40x boxes
                    tbxSz = 100*0.02;
                    for tilli = 1:3
                        for tillj = 1:3
                            big_dims = [dims_20(1)+(tillj-1)*tbxSz dims_20(2)+(tilli-1)*tbxSz];
                            smSz = tbxSz/2;
                            for smx = 1:2
                                for smy = 1:2
                                    tilobj = box_TIL(find(cell2mat(box_TIL(:,9))==tilcounter),:);
                                    if(~isempty(tilobj))
                                        out_map_TIL(big_dims(1)+(smx-1)*smSz+1:big_dims(1)+smx*smSz,big_dims(2)+(smy-1)*smSz+1:big_dims(2)+smy*smSz) =   out_map_TIL(big_dims(1)+(smx-1)*smSz+1:big_dims(1)+smx*smSz,big_dims(2)+(smy-1)*smSz+1:big_dims(2)+smy*smSz) + tilobj{1,5};
                                        count_map_TIL(big_dims(1)+(smx-1)*smSz+1:big_dims(1)+smx*smSz,big_dims(2)+(smy-1)*smSz+1:big_dims(2)+smy*smSz) = count_map_TIL(big_dims(1)+(smx-1)*smSz+1:big_dims(1)+smx*smSz,big_dims(2)+(smy-1)*smSz+1:big_dims(2)+smy*smSz) + 1;
                                    end
                                    tilcounter = tilcounter+1;
                                end
                            end

                        end
                    end    
                end
            end
            
        end
    end

    
    %final masks
    indsmask = find(all_mask>1);
    all_mask(indsmask)=1;
    inds5 = find(count_map_5x > 0);
    out_map_5x(inds5) = out_map_5x(inds5)./count_map_5x(inds5);
    out_map_5x = out_map_5x.*all_mask;
    inds10 = find(count_map_10x > 0);
    out_map_10x(inds10) = out_map_10x(inds10)./count_map_10x(inds10);
    out_map_10x = out_map_10x.*all_mask;
    inds20 = find(count_map_20x > 0);
    out_map_20x(inds20) = out_map_20x(inds20)./count_map_20x(inds20);
    out_map_20x = out_map_20x.*all_mask;
    inds40 = find(count_map_40x > 0);
    out_map_40x(inds40) = out_map_40x(inds40)./count_map_40x(inds40);
    out_map_40x = out_map_40x.*all_mask;
    indsTIL = find(count_map_TIL > 0);
    out_map_TIL(indsTIL) = out_map_TIL(indsTIL)./count_map_TIL(indsTIL);
    
    
    mapped_image = (out_map_5x + out_map_10x + out_map_20x + out_map_40x)./4;
    prod_image = out_map_5x.*out_map_10x.*out_map_20x.*out_map_40x;

    % Create indexed image, explicitly using 256 colors
    imInd=gray2ind(mapped_image,255);
    imInd2=gray2ind(prod_image,255);
    % Convert indexed image to RGB using 256-colors jet map
    jetRGB=ind2rgb(imInd,jet(255));
    pRGB=ind2rgb(imInd2,jet(255));
    patient_outcome = slide_Data_5x{1,8};
%   
    redchan = uint8(255.*out_map_TIL);
    grchan = uint8(255.*mapped_image);
    grchan2 = uint8(255.*prod_image);
    blchan = uint8(255.*all_mask);
    newcrazy = cat(3,redchan,grchan,blchan);
    newcrazy2 = cat(3,redchan,grchan2,blchan);
    
    %write to jpeg
    imwrite(out_map_5x,[mapLoc filesep slides_unique{casei}  '_5x_prob_' patient_outcome '.jpeg']);
    imwrite(out_map_10x,[mapLoc filesep slides_unique{casei} '_10x_prob_' patient_outcome '.jpeg']);
    imwrite(out_map_20x,[mapLoc filesep slides_unique{casei} '_20x_prob_' patient_outcome '.jpeg']);
    imwrite(out_map_40x,[mapLoc filesep slides_unique{casei} '_40x_prob_' patient_outcome '.jpeg']);
    imwrite(out_map_TIL,[mapLoc filesep slides_unique{casei} '_TIL_prob_' patient_outcome '.jpeg']);
    imwrite(mapped_image,[mapLoc filesep slides_unique{casei} '_sum_prob_' patient_outcome '.jpeg']);
    imwrite(prod_image,[mapLoc filesep slides_unique{casei} '_prod_prob_' patient_outcome '.jpeg']);
    imwrite(newcrazy,[mapLoc filesep slides_unique{casei} '_overlay_' patient_outcome '.jpeg']);
    imwrite(newcrazy2,[mapLoc filesep slides_unique{casei} '_overlay2_' patient_outcome '.jpeg']);
    %keep as mat file
    save([mapLoc2 filesep slides_unique{casei}  '_5x_prob_' patient_outcome '.mat'],'out_map_5x');
    save([mapLoc2 filesep slides_unique{casei} '_10x_prob_' patient_outcome '.mat'],'out_map_10x');
    save([mapLoc2 filesep slides_unique{casei} '_20x_prob_' patient_outcome '.mat'],'out_map_20x');
    save([mapLoc2 filesep slides_unique{casei} '_40x_prob_' patient_outcome '.mat'],'out_map_40x');
    save([mapLoc2 filesep slides_unique{casei} '_TIL_prob_' patient_outcome '.mat'],'out_map_TIL');
    save([mapLoc2 filesep slides_unique{casei} '_sum_prob_' patient_outcome '.mat'],'mapped_image');
    save([mapLoc2 filesep slides_unique{casei} '_prod_prob_' patient_outcome '.mat'],'prod_image');
    save([mapLoc2 filesep slides_unique{casei} '_overlay_' patient_outcome '.mat'],'newcrazy');
    save([mapLoc2 filesep slides_unique{casei} '_overlay2_' patient_outcome '.mat'],'newcrazy2');
    
    imwrite(jetRGB,[mapLoc filesep slides_unique{casei} '_color_prob_' patient_outcome '.jpeg']);
    imwrite(pRGB,[mapLoc filesep slides_unique{casei} '_color_prod_' patient_outcome '.jpeg']);
    copyfile([mainDir filesep tcga_id filesep 'voi' filesep strrep(svs_file,'.svs','.png')],[mapLoc filesep slides_unique{casei} '_HE_' patient_outcome '.png'])
end