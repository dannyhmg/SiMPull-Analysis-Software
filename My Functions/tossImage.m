%
% Eliminates an image from a SiMPull dataset and re-calculates summary
% tables. Used for getting rid of images with known artifacts (focus drift,
% poor passivation, etc.) 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [gridData, summary] = tossImage(varargin) % Typical arguments: matPath, matFile, selection (selection = number of image to be deleted)
    if nargin < 2
        [matFile matPath] = uigetfile('*.mat','Choose a .mat file with data from the spot counter');
    else
        matPath = varargin{1};
        matFile = varargin{2};
    end

    load([matPath filesep matFile]);
    if exist('gridData', 'var') ~= 1
        msgbox('This script requires SiMPull data from the spot counter.');
        return
    end

    imageNames = {gridData.imageName};
    
    if nargin < 3    
        [selection, ok] = listdlg('PromptString', 'Select Image to Remove',...
                                  'SelectionMode', 'single',...
                                  'ListSize', [300 300],...
                                  'ListString', imageNames);
        if ~ok
            return
        end
    else
        selection = varargin{3};
    end

    answer = questdlg(['Image ' imageNames(selection) ' will be removed from the analysis. Continue?']);

    if ~strcmp(answer, 'Yes')
        return
    end

    % Remove image from gridData
    index = true(size(gridData));
    index(selection) = false;
    gridData = gridData(index);

    % Recalculate summary statistics
    varToSave = {'nPositions', 'nChannels', 'gridData', 'channels', 'statsByColor', 'params'};
    nPositions = nPositions - 1;

    for a = 1:length(channels)
        color1 = channels{a};

        %Spot count data
        statsByColor.(['total' color1 'Spots']) = sum(cell2mat({gridData.([color1 'SpotCount'])}));
        statsByColor.(['avg' color1 'Spots']) = statsByColor.(['total' color1 'Spots']) / nPositions;

        %Colocalization data
        for b = 1:length(channels)
            color2 = channels{b};
            if isfield(statsByColor, ['pct' color1 'Coloc_w_' color2]);
                countedIndex = cellfun(@isnumeric, {gridData.([color1 color2 'ColocSpots'])});
                statsByColor.(['pct' color1 'Coloc_w_' color2]) = 100 * sum(cell2mat({gridData(countedIndex).([color1 color2 'ColocSpots'])})) / sum(cell2mat({gridData(countedIndex).([color1 'SpotCount'])}));
            end
        end

        %Photobleaching data
        if isfield(statsByColor, [color1 'TracesAnalyzed']);
            countedIndex = cellfun(@isnumeric, {gridData.([color1 'GoodSpotCount'])});
            statsByColor.([color1 'TracesAnalyzed']) = sum(cell2mat({gridData(countedIndex).([color1 'SpotCount'])}));
            statsByColor.([color1 'BadSpots']) = sum(cell2mat({gridData(countedIndex).([color1 'SpotCount'])})) - sum(cell2mat({gridData(countedIndex).([color1 'GoodSpotCount'])}));
            statsByColor.([color1 'StepHist']) = sum(cell2mat({gridData.([color1 'StepDist'])})');
        end
    end


    % Summary Table 
    slash = strfind(matPath,filesep);
    expName = matPath(slash(end-1)+1 : end-1);
    if ~isempty(strfind(matFile, 'filtered'))
        suffix = '_summary_filtered.mat';
    else
        suffix = '_summary.mat';
    end
        
    try 
        load([matPath filesep expName suffix]);
    catch
        msgbox('Could not load summary table file!');
        return
    end

    changeLines = find(cellfun(@(x) strncmp( x, matFile(1:end-4), length(matFile)-4 ), summary));
    [~, width] = size(summary);

    for y = changeLines'
        rowname = strsplit(summary{y,1});
        color1 = rowname{end};

        for x = 2:width

            %Spotcount column
            if strcmp(summary{1,x},'Spots per Image') 
                summary{y,x} = statsByColor.(['avg' color1 'Spots']);
            end

            %Colocalization columns        
            if ~isempty(strfind(summary{1,x}, '% Coloc'))
                colname = strsplit(summary{1,x});
                color2 = colname{end};
                if isfield(statsByColor, ['pct' color1 'Coloc_w_' color2])
                    summary{y,x} = statsByColor.(['pct' color1 'Coloc_w_' color2]);
                else
                    summary{y,x} = '-';
                end
            end

            %Traces Analyzed Column
            if strcmp(summary{1,x}, 'Traces Analyzed')
                if isfield(statsByColor, [color1 'TracesAnalyzed'])
                   summary{y,x} = statsByColor.([color1 'TracesAnalyzed']);
                else
                    summary{y,x} = '-';
                end
            end

            %Photobleaching columns
            if ~isempty(strfind(summary{1,x}, 'step'))
                num = str2num(summary{1,x}(3));
                if strcmp(summary{1,x}, '% 10 step')
                    num = 10;
                end
                if isfield(statsByColor, [color1 'StepHist'])
                    summary{y,x} = 100 * statsByColor.([color1 'StepHist'])(num) / statsByColor.([color1 'TracesAnalyzed']);
                else
                    summary{y,x} = '-';
                end
            end

            % Bad Spots column
            if strcmp(summary{1,x}, '% Rejected')
                if isfield(statsByColor, [color1 'BadSpots'])
                    summary{y,x} = 100 * statsByColor.([color1 'BadSpots']) / statsByColor.(['total' color1 'Spots']);
                else
                    summary{y,x} = '-';
                end
            end

        end
    end

    % Save data
    save([matPath filesep matFile], varToSave{:});

    %Save summary table 
    save([matPath filesep expName suffix],'summary');
    msgbox('Completed Successfully');
