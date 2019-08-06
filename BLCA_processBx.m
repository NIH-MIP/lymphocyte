%dependencies: bfmatlab

dirlist = dir('S:\bladder_NIH\Apolo\HE_slides\**\*.czi');
refratio = 8;
imgSize = 5000;
patchSize = 100;
saveDir = 'V:\NIH_BLCA_TIL\patches';
    
for hei = 11:numel(dirlist) 
    filename = [dirlist(hei).folder filesep dirlist(hei).name];
    fileid = strrep(dirlist(hei).name,'.czi','');
    disp(['processing: ' fileid])
    if(~exist([saveDir filesep fileid]))
        mkdir([saveDir filesep fileid])
    end
    caseData = bfGetReader(filename);
    caseMeta = caseData.getMetadataStore();
    lvls = zeros(caseMeta.getImageCount,3);
    for k = 1:caseMeta.getImageCount
        %i=1 is the reference level
        lvls(k,1) = eval(caseMeta.getPixelsSizeX(k-1));
        lvls(k,2) = eval(caseMeta.getPixelsSizeY(k-1));
        lvls(k,3) = round(lvls(1,1)/lvls(k,1)); %mag difference from 40x
    end
    bigSize = [lvls(1,2) lvls(1,1)];
    refind = find(lvls(:,3)==refratio);
    caseData.setSeries(refind-1);
    I1 = bfGetPlane(caseData,1);
    I2 = bfGetPlane(caseData,2);
    I3 = bfGetPlane(caseData,3);
    lvl_img(:,:,1) = I1;
    lvl_img(:,:,2) = I2;
    lvl_img(:,:,3) = I3;
    bwimg = rgb2gray(lvl_img);
    clear lvl_img

    bwfind = find(bwimg>0 & bwimg<200);
    mask = zeros(size(bwimg));
    mask(bwfind)=1;
    mask = imfill(mask,'holes');

    %find number we can fill space
    MMP = caseMeta.getPixelsPhysicalSizeX(0).value.floatValue;
    
    physSize = double(int32(((10/MMP)*imgSize)/20));
    resizeratio = imgSize/physSize;
    num_subs_updown = floor(bigSize(1)/physSize)+1;
    num_subs_leftright = floor(bigSize(2)/physSize)+1;

    batch = 1;

    for iud = 1:num_subs_updown
        for ilr = 1:num_subs_leftright
            if (iud ~= num_subs_updown && ilr ~= num_subs_leftright)        
                mask_crop = mask(round(physSize/refratio)*(iud-1)+1:round(physSize/refratio)*iud,round(physSize/refratio)*(ilr-1)+1:round(physSize/refratio)*ilr);
                mask_resize = imresize(mask_crop,[physSize physSize]);
                pullSize = [physSize physSize];
            else
                crop_end = [];
                if(iud == num_subs_updown)
                    crop_end(1) = size(mask,1);
                else
                    crop_end(1) = (physSize/refratio)*iud;
                end
                if(ilr == num_subs_leftright)
                    crop_end(2) = size(mask,2);
                else
                    crop_end(2) = (physSize/refratio)*ilr;
                end
                mask_crop = mask((physSize/refratio)*(iud-1)+1:crop_end(1),(physSize/refratio)*(ilr-1)+1:crop_end(2));
                mask_resize = imresize(mask_crop,8);
                pullSize = [size(mask_resize,1) size(mask_resize,2)];
            end

            %if mask has tissue within it
            if((numel(find(mask_crop>0))>0))
                disp(['      ... starting batch ' int2str(batch)])
                if(~exist([saveDir filesep fileid filesep int2str(batch)]))
                    mkdir([saveDir filesep fileid filesep int2str(batch)])
                end
                caseData.setSeries(0);
                I1 = bfGetPlane(caseData,1,physSize*(ilr-1)+1,physSize*(iud-1)+1,pullSize(2),pullSize(1));
                I2 = bfGetPlane(caseData,2,physSize*(ilr-1)+1,physSize*(iud-1)+1,pullSize(2),pullSize(1));
                I3 = bfGetPlane(caseData,3,physSize*(ilr-1)+1,physSize*(iud-1)+1,pullSize(2),pullSize(1));
                batch_img(:,:,1) = I1;
                batch_img(:,:,2) = I2;
                batch_img(:,:,3) = I3;
                
                batch_img = imresize(batch_img,resizeratio);
                mask_resize = imresize(mask_resize,resizeratio,'Nearest');
                
                 num_sm_updown = floor(size(batch_img,1)/patchSize);
                 num_sm_leftright = floor(size(batch_img,2)/patchSize);

                for smud = 1:num_sm_updown
                    for smlr = 1:num_sm_leftright
                        crop_sm = mask_resize(patchSize*(smud-1)+1:patchSize*smud,patchSize*(smlr-1)+1:patchSize*smlr);
                        if((numel(find(crop_sm>0))>0))
                            img_crop = batch_img(patchSize*(smud-1)+1:patchSize*smud,patchSize*(smlr-1)+1:patchSize*smlr,:);
                             ud_ind = imgSize*(iud-1)+patchSize*(smud-1)+1;
                             lr_ind = imgSize*(ilr-1)+patchSize*(smlr-1)+1;
                            imwrite(img_crop,[saveDir filesep fileid filesep int2str(batch) filesep fileid '_' int2str(ud_ind) '_' int2str(lr_ind) '.jpeg']);
                            clear img_crop ud_ind lr_ind
                        end
                        clear crop_sm
                    end
                end
                batch = batch + 1;
            end
            %then send to patch_by_batch
            clear batch_img mask_resize mask_crop
        end
    end
end


