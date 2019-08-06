%dependencies: bfmatlab


dirlist = dir('\path\to\HE_slides\**\*.czi');
predDir = '\path\to\predictions';
mapDir = '\path\to\save\maps';
refratio = 8;

for hei = 1:numel(dirlist) 
    filename = [dirlist(hei).folder filesep dirlist(hei).name];
    fileid = strrep(dirlist(hei).name,'.czi','');
    disp(['processing: ' fileid])
    caseData = bfGetReader(filename);
    caseMeta = caseData.getMetadataStore();
    MMP = caseMeta.getPixelsPhysicalSizeX(0).value.floatValue;
    resizeratio = 1/((10/MMP)/20);
    bigSize = [eval(caseMeta.getPixelsSizeY(0)) eval(caseMeta.getPixelsSizeX(0))];
    bigSize = double(int32(bigSize.*resizeratio));
    imgsize = ceil(bigSize./100);
    
    list_TIL = [];
    TILlist = dir([predDir filesep 'Pred_' fileid '*']);
    for listi = 1:numel(TILlist)
        TIL = readtable([TILlist(listi).folder filesep TILlist(listi).name],'Delimiter',' ');
        TIL = table2cell(TIL);
        if(numel(TIL)>0)
            list_TIL = cat(1,list_TIL,TIL); 
        end
    end
    TILmap = zeros(imgsize);
    for TILi = 1:size(list_TIL,1)
        filei = strsplit(list_TIL{TILi,1},'_');
        xi = ceil(str2num(filei{7})/100);
        yi = ceil(str2num(strrep(filei{8},'.jpeg',''))/100);
        TILmap(xi,yi) = list_TIL{TILi,5};
    end
    
    TILmask = zeros(imgsize);
    TILmask(find(TILmap>0))=1;
    
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
    I1(find(I1==0)) = 255;
    I2(find(I2==0)) = 255;
    I3(find(I3==0)) = 255;
    lvl_img(:,:,1) = imresize(I1,imgsize);
    lvl_img(:,:,2) = imresize(I2,imgsize);
    lvl_img(:,:,3) = imresize(I3,imgsize);
    out_img = lvl_img;
    clear lvl_img
    out_img = imresize(out_img,imgsize);
    
    out_color = zeros(size(out_img));
    out_color(:,:,1) = 255.*TILmap;
    out_color(:,:,3) = 255.*TILmask;
    out_color = uint8(out_color);
    
    imwrite(TILmap,[mapDir filesep 'images' filesep fileid '_TILprob.png'])
    %imwrite(TILmask,[mapDir filesep 'images' filesep fileid '_TILmask.png'])
    imwrite(out_color,[mapDir filesep 'images' filesep fileid '_TILmap.png'])
    imwrite(out_img,[mapDir filesep 'images' filesep fileid '.png'])
    save([mapDir filesep 'matfiles' filesep fileid '_TILmap.mat'],'TILmap')
    save([mapDir filesep 'matfiles' filesep fileid '_TILmask.mat'],'TILmask')
    save([mapDir filesep 'matfiles' filesep fileid '.mat'],'out_img')
    clear TILmask TILmap out_img out_color
end



