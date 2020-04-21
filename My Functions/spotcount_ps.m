% Detects spots in a single, 1-channel image. 

% Background subtraction and spot detection are done using a probabilistic 
% segmentation algorithm coded by Jacques Boisvert, Jonas Dorn and Paul
% Maddox.

% Intensity traces are calculated from the unfiltered time series by summing
% pixel intensities in a 5x5 spot centered on each peak pixel and subtracting 
% local background. 

function outStruct = spotcount_ps(channel, rawImage, avgImage, params, outStruct)                   
    [ymax, xmax, tmax] = size(rawImage);

    % Spot detection with probabilistic segmentation
    [coordinates,~,~] = psDetectSpots(avgImage,[25 25],params.psfSize,'fpExp',params.fpExp,'poissonNoise',params.poissonNoise);
    if isempty(coordinates)  %Protects against crashing when no spots are found
        peakLocations = [];
    else
        peakLocations = coordinates(:,2);
        peakLocations(:,2) = coordinates(:,1);
    end
    
    %Throw out peaks that are too close to the edge
    [nPeaks, ~] = size(peakLocations);
    for c = nPeaks:-1:1
        if (min(peakLocations(c,:))<6 || peakLocations(c,1)>xmax-5 || peakLocations(c,2)>ymax-5)
            peakLocations(c,:) = [];
        end
    end
    [nPeaks, ~] = size(peakLocations);

    %Saves the results
    existingSpots = 0;
    if isfield(outStruct, [channel 'SpotData']) && nPeaks > 0
        
        % If our data structure already has some spots, add the new ones to the end of the list
        existingSpots = length(outStruct.([channel 'SpotData']));
        peakCell = mat2cell(peakLocations,ones(nPeaks,1));
        % I couldn't figure out how to do this assignment on one line
        temp = struct('spotLocation',peakCell);
        [ outStruct( existingSpots+1 : existingSpots+nPeaks).spotLocation ] = temp.spotLocation;
        outStruct.([channel 'SpotCount']) = existingSpots + nPeaks;
    
    else
        
        %Otherwise, make new fields to hold the data. 
        if nPeaks == 0
        outStruct.([channel 'SpotData']) = struct('spotLocation',[0,0],...
                                                  'intensityTrace',zeros(1,tmax));
        else
            peakCell = mat2cell(peakLocations,ones(nPeaks,1));
            outStruct.([channel 'SpotData']) = struct('spotLocation',peakCell);
        end
        outStruct.([channel 'SpotCount']) = nPeaks;
    end

    %Get a box containing each spot and measure the intensity.
    %Subtract local background by measuring a larger box (Ted's method).
    
    %Determine the Wavelength
    if (strcmp(channel, 'Blue'))
        lambda = 480;
    elseif (strcmp(channel, 'Green'))
        lambda = 525;
    elseif (strcmp(channel, 'Red'))
        lambda = 600;
    elseif (strcmp(channel, 'FarRed'))
        lambda = 655;
    else
        error('Unexpected channel information given');
    end
    
    %Based on the wavelength and the pixel size, calculate the size of box to use
    PSFrad = lambda / (2*1.49); %Assumes we're using a 1.49 NA TIRF objective
    smBoxRad = ceil(PSFrad/params.pixelSize); %This will result in a 5x5 box for large-pixel cameras (EMCCD) and a 7x7 box for small-pixel cameras (sCMOS)
    smBoxArea = (2*smBoxRad + 1)^2; 
    lgBoxRad = smBoxRad + 2;
    lgBoxArea = (2*lgBoxRad + 1)^2;
    areaDiff =  lgBoxArea - smBoxArea; 
    
    %Calculate the background and perform the subtraction
    if nPeaks > 0 
        for e = existingSpots+1 : existingSpots+nPeaks   %existingSpots = 0 if this is a fresh analysis
            xcoord = peakLocations(e,1);
            ycoord = peakLocations(e,2);   
            spotMat = rawImage(ycoord-smBoxRad:ycoord+smBoxRad,xcoord-smBoxRad:xcoord+smBoxRad,:);
            traceSmall = squeeze(sum(sum(spotMat,1),2));
            BGMat = rawImage(ycoord-lgBoxRad:ycoord+lgBoxRad,xcoord-lgBoxRad:xcoord+lgBoxRad,:);
            traceLarge = squeeze(sum(sum(BGMat,1),2));
            traceAvgBG = (traceLarge - traceSmall)/areaDiff;
            traceSmallMBG = traceSmall-traceAvgBG*smBoxArea;
            outStruct.([channel 'SpotData'])(e).intensityTrace = transpose(traceSmallMBG);
        end
    end
    return;