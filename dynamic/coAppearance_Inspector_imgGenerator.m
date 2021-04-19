% Generate difference and average images for bait and prey channels for data visualization using coAppearance_inspector_App

%% Get data file from user
files = uipickfiles('Prompt','Select directories that need difference and average images for the prey and bait channel saved.','Type',{'Directory'});
for f=1:length(files)
    matFile = uipickfiles_subs.filtered_dir([files{f} filesep '*.mat'],'',false,@(x,c)uipickfiles_subs.file_sort(x,[1 0 0],c));
    sampleName = arrayfun(@(x) [x.folder filesep x.name], matFile, 'UniformOutput', false);
    [~,sampleLabel,~] = fileparts(sampleName{1}); message = msgbox(['Working on ' sampleLabel]);
    load([sampleName{1}]);
    
    %%Check for necessary parameters, get from dialog box if missing
    if ~isfield(params, 'BaitPos')
        [Answer,Cancelled] = dynamicChannelInfoDlg_short;
        if Cancelled
            return
        else
            v2struct(Answer);
            params.LeftChannel = LeftChannel;
            params.RightChannel = RightChannel;
            params.BaitPos = BaitPos;
        end
    end
    if ~isfield(params,'BaitChannel')
        params.BaitChannel = params.([params.BaitPos 'Channel']);
        if strcmp(params.BaitPos,'Right')
            params.PreyChannel = params.LeftChannel;
        else
            params.PreyChannel = params.RightChannel;
        end
    end
    baitChannel = params.BaitChannel;
    preyChannel = params.PreyChannel;

%% Save average and difference images for the bait and prey channels 
    % Check if any windowed average and difference images exist before continuing
    if ~exist([files{f} filesep sampleLabel '_baitAvg.tif'], 'file')
        warning('off','all');
        % Locate images
        images = uipickfiles_subs.filtered_dir([files{f} filesep '*.tif'],'',false,@(x,c)uipickfiles_subs.file_sort(x,[1 0 0],c)); % See comments in uipickfiles_subs for syntax here
        imgFile = arrayfun(@(x) [x.folder filesep x.name], images, 'UniformOutput', false);
        %Load images
        if length(imgFile) > 1 %if the directory contains multiple files
            nFiles = length(imgFile);
            stackOfStacks = cell(nFiles,1);
            for a = 1:nFiles
                stackOfStacks{a} = TIFFStack(imgFile{a});
            end
            index = ~cellfun(@isempty,stackOfStacks);
            stackOfStacks = stackOfStacks(index);
            if length(stackOfStacks) == 1
                stackObj = stackOfStacks{1};
            else
                stackObj = TensorStack(3, stackOfStacks{:});
            end
        else
            % If there's just a single TIFF file, it's simpler
            stackObj = TIFFStack(imgFile{1});
        end
        % Calculate windowed average and difference images
        baitAvg = windowMean(stackObj,dynData.window,params.BaitPos);
        baitDiff = diff(baitAvg,1,3);
        
        preyAvg = windowMean(stackObj,dynData.window,params.preyPos); 
        preyDiff = diff(preyAvg,1,3);
        
        % Save images
        [~,~,ndiffs] = size(baitDiff);
        for w=1:ndiffs
            imwrite(uint16(baitDiff(:,:,w)),[expDir filesep imgName '_baitDiff.tif'],'tif','WriteMode','append','Compression','none');
            imwrite(uint16(preyDiff(:,:,w)),[expDir filesep imgName '_preyDiff.tif'],'tif','WriteMode','append','Compression','none');
        end
        for w=1:ndiffs+1
            imwrite(uint16(baitAvg(:,:,w)),[expDir filesep imgName '_baitAvg.tif'],'tif','WriteMode','append','Compression','none');
            imwrite(uint16(preyAvg(:,:,w)),[expDir filesep imgName '_preyAvg.tif'],'tif','WriteMode','append','Compression','none');
        end
    end
    close (message);
end
   