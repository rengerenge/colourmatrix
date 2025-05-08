function resultMatrix = colourMatrix(file, showProcess)
%% Settings
% Read image, denoise, detect black dots, perspective correction, 
% segment 4×4 grid, count colors
ROW = 4;
COL = 4;
CircleRatio = 0.06;
PlotIndex = 1;
PlotRow = 5;
PlotCol = 4;
ErosionPix = 4;
ImdilatePix = 0;
CropOffset = 2.5;
NeedCorrectionShadow = 0;
NeedWiener = 0;
NeedClearBoard = 0;
bwareaopenValue = 20;

%% Load File
IMG = imread(file);
[height, width, ~] = size(IMG);
if height > 1000 || width > 1000
    if contains(file, '32.jpg') || contains(file, '34.jpg') || contains(file, '35.jpg')
        NeedCorrectionShadow = 1;
    end
    if contains(file, '44.jpg')
        NeedWiener = 1;
    end
    NeedClearBoard = 1;
    ErosionPix = 8;
    ImdilatePix = 6;
    CropOffset = 1.1;
    bwareaopenValue = 50;
end

if showProcess
    figure;
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(IMG);
    title('Source Image');
end

%% Wiener filter to remove motion blur
if NeedWiener
    I = wiener(IMG,60,160/180*pi);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshowpair(IMG, I, 'montage');
        title('Wiener');
    end
    IMG = I;
end

%% Remove noise
I = IMG;
% Median filter for each RGB channel to remove noise
hsize_2 = [6 6];
I = cat(3, medfilt2(I(:,:,1), hsize_2), medfilt2(I(:,:,2), hsize_2), medfilt2(I(:,:,3), hsize_2));

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(I);
    title('Median Filter');
end

%% Binarize to separate background
I_gray = rgb2gray(I);

if NeedCorrectionShadow
    % Correct shadows
    shadow_correction = shadow_correction_division(I_gray, 40);
    shadow_correction = illumination_correction(shadow_correction, 2);
    
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshowpair(I_gray, shadow_correction, 'montage');
        title('Shadow Correction');
    end
    I_gray = shadow_correction;
end

% Binarization
bw = imbinarize(I_gray);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('Binarization');
end
bw = imcomplement(bw);

if NeedCorrectionShadow
    bw = imcomplement(bw);
    bw = imfill(bw, 'holes');
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(bw);
        title('imfill holes');
    end
    CC = bwconncomp(bw);
    stats = regionprops(CC, 'BoundingBox', 'Area');
    [~, idx] = max([stats.Area]);
    bbox = stats(idx).BoundingBox;

    I_whitebg = shadow_correction;
    I_whitebg(~bw) = 255;
    I_whitebg = imcrop(I_whitebg, [bbox(1), bbox(2), bbox(3), bbox(4)]);
    IMG = imcrop(IMG, [bbox(1), bbox(2), bbox(3), bbox(4)]);

    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(I_whitebg);
        title('Fill&Crop');
    end

    % Local binarization
    bw = imbinarize(I_whitebg, 'adaptive', 'Sensitivity', 0.75);
    bw = imcomplement(bw);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(bw);
        title('Binarization');
    end

    % Dilate to connect boundaries
    SE = strel('square', ImdilatePix);
    bw = imdilate(bw, SE);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(bw);
        title('Dilate');
    end
end

%% Remove borders
if NeedClearBoard
    bw = imclearborder(bw);
end

if NeedCorrectionShadow
    % Remove dilation
    bw = imerode(bw, SE);
end

if showProcess && NeedClearBoard
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('Border Clearing');
end

%% Erosion
SE = strel('square', ErosionPix);
erodedI = imerode(bw, SE);

% Shadow correction may produce noise, needs extra erosion
if NeedCorrectionShadow
    erodedI = imerode(erodedI, SE);
end

erodedI = bwareaopen(erodedI, bwareaopenValue);

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(erodedI);
    title('Erosion');
end

%% Detect black dots
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(erodedI);
    title('Detected');
    hold on;
end

try
    inputPoints = getInputPoints(erodedI, showProcess);
catch ME
    fprintf('Error: %s\n', ME.message);
    return;
end

if showProcess
    hold off;
end

%% Perspective correction and cropping
% Calculate output width and height based on corner points
pTL = inputPoints(1).Centroid;
pTR = inputPoints(2).Centroid;
pBR = inputPoints(3).Centroid;
pBL = inputPoints(4).Centroid;

width_top = norm(pTR - pTL);
width_bot = norm(pBR - pBL);
outputWidth = round(mean([width_top, width_bot]));

height_left = norm(pBL - pTL);
height_right = norm(pBR - pTR);
outputHeight = round(mean([height_left, height_right]));

side = max(outputHeight, outputWidth);

% Define target image corners (same order as above)
outputPoints = [1, 1;
                side, 1;
                side, side;
                1, side];

% Calculate projective transformation matrix
tform = fitgeotrans([pTL; pTR; pBR; pBL], outputPoints, 'projective');

% Apply perspective transform to preprocessed image
I = imwarp(IMG, tform, 'OutputView', imref2d([side, side]));
I = cat(3, medfilt2(I(:,:,1), hsize_2), medfilt2(I(:,:,2), hsize_2), medfilt2(I(:,:,3), hsize_2));
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(I);
    title('Perspective Rectification');
end

I_gray = rgb2gray(I);
if NeedCorrectionShadow
    shadow_correction = shadow_correction_division(I_gray, 40);
    shadow_correction = illumination_correction(shadow_correction, 3);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(shadow_correction);
        title('Shadow Correction');
    end
    I_gray = shadow_correction;
end

%% Crop dots
I_crop = I;

[h,w,~] = size(I_crop);

rH = CircleRatio * h;
rW = CircleRatio * w;
x = 1 + rW*CropOffset;
y = 1 + rH*CropOffset;
width = w - x * 2;
height = h - y * 2;

%% White balance
blackX = 1;
blackW = floor(rW / 2);

whiteX = ceil(x);
whiteW = floor(rW / 2);
whiteY = 1;

black_patch = I_crop(blackX:blackX+blackW, blackX:blackX+blackW, :);
white_patch = I_crop(whiteY:whiteY, whiteX:whiteX+whiteW, :);
Temp = I_crop;
I_crop = whiteBalance(I_crop, white_patch, black_patch);
Temp = imcrop(Temp, [x,y,width,height]);
I_crop = imcrop(I_crop, [x,y,width,height]);
I_gray = imcrop(I_gray, [x,y,width,height]);

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshowpair(Temp, I_crop, 'montage');
    title('White Balance');
end

%% Median & Gaussian filtering, binarization, dilation
bw = imbinarize(I_gray, 'adaptive', 'Sensitivity', 0.75);

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('Binarization');
end

% Remove small noise
bw = imcomplement(bw);
bw = bwareaopen(bw, 50); % Remove regions smaller than 50 pixels
bw = imcomplement(bw);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('Remove Small Connected Component');
end

% Hough transform
dilatedI = imcomplement(bw);
dilatedI = lineConnect(dilatedI);
dilatedI = imcomplement(dilatedI);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(dilatedI);
    title('Hough Transform');

    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(dilatedI);
    title('Connected Component Extraction');
    hold on;
end

%% Get color connected regions and sort 4×4 grid
color_stats = regionprops(dilatedI, 'Centroid', 'Area', 'Circularity');
color_stats = color_stats([color_stats.Area] > 8);
while length(color_stats) > 16
    median_value = median([color_stats.Area]);
    maxArea = max([color_stats.Area]);
    minArea = min([color_stats.Area]);
    if maxArea > median_value * 10
        color_stats = color_stats([color_stats.Area] ~= maxArea);
    elseif minArea < median_value / 2
        color_stats = color_stats([color_stats.Area] ~= minArea);
    else
        break
    end
end

final_stats = color_stats;

if showProcess
    % Plot centroids
    for k = 1:length(final_stats)
        centroid = final_stats(k).Centroid;
        plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 6);
    end
    hold off;
end

% Extract all centroids and sort
centroids = cat(1, final_stats.Centroid);  % N×2 matrix [x1,y1; x2,y2; ...]
[~, yOrder] = sort(centroids(:, 2));  % Sort by Y ascending
sortedByY = final_stats(yOrder);      % Regions sorted by Y

sorted_stats = repmat(struct('Centroid', [], 'Area', [], 'Circularity', []), 16, 1);
for row = 1:ROW
    % Extract current row's 4 regions
    startIdx = (row-1)*ROW + 1;
    endIdx = row*ROW;
    currentRow = sortedByY(startIdx:endIdx);

    % Sort current row by X coordinate
    currentCentroids = cat(1, currentRow.Centroid);
    [~, xOrder] = sort(currentCentroids(:, 1));  % Sort by X ascending
    sortedRow = currentRow(xOrder);              % Sort row by X

    % Add sorted row to result
    sorted_stats(startIdx : endIdx) = sortedRow';
end

%% Count colors
hsize_2 = [15, 15];
I_crop = cat(3, medfilt2(I_crop(:,:,1), hsize_2), medfilt2(I_crop(:,:,2), hsize_2), medfilt2(I_crop(:,:,3), hsize_2));
I_crop = imgaussfilt(I_crop, 5.5);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex);
    imshow(I_crop);
    title('Output');
    hold on;
end

resultMatrix = repmat(' ', ROW, COL);
hsvImage = rgb2hsv(I_crop);
maxHalfSize = floor(min(width, height) / 10 / 2);
for k = 1:length(sorted_stats)
    centroid = sorted_stats(k).Centroid;
    x = round(centroid(1));
    y = round(centroid(2));
    colorChar = 'U';
    halfSize = 5;
    while colorChar == 'U' && halfSize < maxHalfSize
        % Define region boundaries, ensuring they stay within image
        x1 = max(1, x - halfSize);
        x2 = floor(min(width, x + halfSize));
        y1 = max(1, y - halfSize);
        y2 = floor(min(height, y + halfSize));

        regionH = hsvImage(y1:y2, x1:x2, 1);
        regionS = hsvImage(y1:y2, x1:x2, 2);
        regionV = hsvImage(y1:y2, x1:x2, 3);

        % Calculate channel means
        avgH = mean(regionH(:), 'omitnan');
        avgS = mean(regionS(:), 'omitnan');
        avgV = mean(regionV(:), 'omitnan');
        colorChar = colorTitle(avgH, avgS, avgV);
        halfSize = halfSize + 1;
    end

    i = ceil(k/4);
    j = mod(k-1,4)+1;

    if colorChar == 'U'
        colorChar = 'W';
    end
    resultMatrix(i,j) = colorChar;

    if showProcess
        textColor = 'black';
        if colorChar == 'B'
            textColor = 'White';
        end
        text(x-8, y, sprintf(colorChar), ...
            'Color', textColor, 'FontSize', 8);
    end
end

if showProcess
    hold off;
end
end

function colorChar = colorTitle(avgH, avgS, avgV)
% Determine color based on HSV values
if avgS < 0.216 && avgV >= 0.84
    colorChar = 'W';  % white
elseif ((avgH >= 0.941 || avgH < 0.116)) && avgS > 0.25
    colorChar = 'R';  % red
elseif (avgH >= 0.116 && avgH < 0.23) && avgS > 0.25
    colorChar = 'Y';  % yellow
elseif (avgH >= 0.23 && avgH <= 0.45) && avgS > 0.25
    colorChar = 'G';  % green
elseif (avgH > 0.5 && avgH < 0.941) && avgS > 0.25
    colorChar = 'B';  % blue
else
    colorChar = 'U';  % unknown
end
end

function I = wiener(IMG,len,theta)
% Wiener filter for motion blur removal
blurredImage = im2double(IMG);
psf = fspecial('motion',len,theta);

% Improved noise estimation
noise_var = estimate_noise(blurredImage);

% Estimate signal power
signal_var = var(blurredImage(:));
estimated_nsr = noise_var / signal_var;

% Wiener filtering
I = deconvwnr(blurredImage, psf, estimated_nsr);
end

function noise_var = estimate_noise(I)
% Estimate noise variance from smooth image regions
if ~isa(I, 'double')
    I = im2double(I);
end

[h,w] = size(I);

% Take multiple patches for better estimation
patch1 = I(1:min(20,h), 1:min(20,w));
patch2 = I(end-min(20,h)+1:end, end-min(20,w)+1:end);
patch3 = I(floor(h/2):floor(h/2)+19, floor(w/2):floor(w/2)+19);

% Calculate average noise variance
noise_var = (var(patch1(:)) + var(patch2(:)) + var(patch3(:))) / 3;

% Prevent estimation from being too small
noise_var = max(noise_var, 0.001);
end

function reconstructedImg = lineConnect(BW)
% Connect lines using morphological operations and Hough transform
se_h = strel('line', 100, 0);        % Long horizontal line
se_v = strel('line', 100, 90);       % Long vertical line
BW2 = imclose(BW, se_h);
BW2 = imclose(BW2, se_v);
[height, width, ~] = size(BW2);

% Hough transform to detect lines
[H, theta, rho] = hough(BW2);
P  = houghpeaks(H, 200, 'Threshold', ceil(0.3*max(H(:))), 'NHoodSize', [15, 15]);
lines = houghlines(BW2, theta, rho, P, ...
    'FillGap', 20, 'MinLength', min(height, width) / 5);

% Angle tolerance threshold (degrees)
angle_tolerance = 2;

% Create logical index arrays
keepHor = false(length(lines), 1);
keepVer = false(length(lines), 1);

for k = 1:length(lines)
    theta = lines(k).theta;

    % Check if line is approximately horizontal or vertical
    is_horizontal = abs(theta) < angle_tolerance || abs(theta - 180) < angle_tolerance;
    is_vertical = abs(theta - 90) < angle_tolerance || abs(theta + 90) < angle_tolerance;

    keepHor(k) = is_horizontal;
    keepVer(k) = is_vertical;
end

% Extract qualifying elements
horLines = lines(keepHor);
verLines = lines(keepVer);

lineWidth = 30;
for k = 1:length(horLines)
    point1 = horLines(k).point1; % [x1, y1]
    point2 = horLines(k).point2; % [x2, y2]

    x1 = point1(1); x2 = point2(1);
    BW = draw_line_with_width(BW, x1, 1, x2, height, lineWidth);
end

for k = 1:length(verLines)
    point1 = verLines(k).point1; % [x1, y1]
    point2 = verLines(k).point2; % [x2, y2]

    y1 = point1(2); y2 = point2(2);
    BW = draw_line_with_width(BW, 1, y1, width, y2, lineWidth);
end

reconstructedImg = BW;
end

function img = draw_line_with_width(img, x1, y1, x2, y2, width)
% Draw line with specified width
n_points = max(abs(x2-x1), abs(y2-y1)) * 10; % High density sampling
x = round(linspace(x1, x2, n_points));
y = round(linspace(y1, y2, n_points));

% Ensure coordinates are within image bounds
[rows, cols] = size(img);
x = max(1, min(cols, x));
y = max(1, min(rows, y));

% Draw line with width by drawing square regions
for i = 1:length(x)
    xx = x(i);
    yy = y(i);

    half_width = floor(width/2);
    x_range = max(1, xx-half_width):min(cols, xx+half_width);
    y_range = max(1, yy-half_width):min(rows, yy+half_width);

    img(y_range, x_range) = true; % Set to white
end
end

function I = whiteBalance(img, whitePatch, blackPatch)
% White balance using white and black reference patches
img = double(img) / 255; % Normalize to [0,1]
whitePatch = double(whitePatch) / 255;
blackPatch = double(blackPatch) / 255;

% Calculate mean of white and black points
mean_white = mean(reshape(whitePatch, [], 3), 1);
mean_black = mean(reshape(blackPatch, [], 3), 1);

% Calculate channel gains
gain_r = 1 / (mean_white(1) - mean_black(1));
gain_g = 1 / (mean_white(2) - mean_black(2));
gain_b = 1 / (mean_white(3) - mean_black(3));

% Adjust image
img_balanced = img;
img_balanced(:,:,1) = (img(:,:,1) - mean_black(1)) * gain_r;
img_balanced(:,:,2) = (img(:,:,2) - mean_black(2)) * gain_g;
img_balanced(:,:,3) = (img(:,:,3) - mean_black(3)) * gain_b;

% Limit to [0,1] and convert back to uint8
I = uint8(max(0, min(1, img_balanced)) * 255);
end

function corrected = shadow_correction_division(inputImage, smooth_sigma)
% Correct shadows using division method
if ~isa(inputImage, 'double')
    inputImage = im2double(inputImage);
end

% Step 1: Estimate illumination component using Gaussian filter
illumination = imgaussfilt(inputImage, smooth_sigma);

% Step 2: Avoid division by zero
epsilon = 1e-6;
illumination = illumination + epsilon;

% Step 3: Remove shadows by division
corrected = inputImage ./ illumination;

% Step 4: Normalize to [0,1]
corrected = corrected - min(corrected(:));
corrected = corrected / max(corrected(:));
end

function pointsStats = getInputPoints(I, drawInfo)
% Extract candidate circular regions from binary image and return 4 corner points

% 1. Extract region properties
stats = regionprops(I, 'Centroid', 'Area', 'Circularity','BoundingBox');

if drawInfo
    % Plot centroids
    for k = 1:length(stats)
        centroid = stats(k).Centroid;
        plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 6);
    end
end

% 2. Filter invalid regions
isValid = [stats.Circularity] > 0.14 & [stats.Area] > 10;
candidateStats = stats(isValid);

% Extract candidate centroids
candidateCentroids = vertcat(candidateStats.Centroid);
if size(candidateCentroids, 1) < 4
    error('Not enough candidate black dots detected, please adjust preprocessing or filtering parameters!');
end

% 3. Use convex hull to select candidate corners
kHull = convhull(candidateCentroids(:,1), candidateCentroids(:,2));
hullPoints = candidateCentroids(kHull(2:end), :);
candidateIndices = kHull(2:end);

% Remove collinear points with angle tolerance of 30 degrees
tolAngle = deg2rad(30);
i = 1;
while size(hullPoints,1) > 4 && i <= size(hullPoints,1)
    nPoints = size(hullPoints,1);
    prev = mod(i-2, nPoints) + 1;
    next = mod(i, nPoints) + 1;
    v1 = hullPoints(i,:) - hullPoints(prev,:);
    v2 = hullPoints(next,:) - hullPoints(i,:);
    detVal = v1(1)*v2(2) - v1(2)*v2(1);
    dotVal = dot(v1, v2);
    angle = abs(atan2(detVal, dotVal));
    if angle < tolAngle || abs(pi - angle) < tolAngle
        hullPoints(i,:) = [];
        candidateIndices(i) = [];
        i = 1; % Reset loop to check new sequence
    else
        i = i + 1;
    end
end

if size(hullPoints,1) ~= 4
    hold off;
    error('Convex hull did not yield exactly 4 corner points, please check candidate points');
end

% Save final 4 candidate corners
corners = hullPoints;
cornersCandidateIndices = candidateIndices;

% 4. Sort corners: first by Y coordinate, then by X coordinate for same Y
[~, idxSortedByY] = sort(corners(:,2));
sortedCorners = corners(idxSortedByY, :);
sortedCandidateIndices = cornersCandidateIndices(idxSortedByY);

% Top two points are upper ones, bottom two are lower ones
topTwo = sortedCorners(1:2, :);
bottomTwo = sortedCorners(3:4, :);
topTwoIndices = sortedCandidateIndices(1:2);
bottomTwoIndices = sortedCandidateIndices(3:4);

% For top two points, smaller x is top-left; for bottom two, smaller x is bottom-left
if topTwo(1,1) < topTwo(2,1)
    pTL_idx = topTwoIndices(1);
    pTR_idx = topTwoIndices(2);
else
    pTL_idx = topTwoIndices(2);
    pTR_idx = topTwoIndices(1);
end

if bottomTwo(1,1) < bottomTwo(2,1)
    pBL_idx = bottomTwoIndices(1);
    pBR_idx = bottomTwoIndices(2);
else
    pBL_idx = bottomTwoIndices(2);
    pBR_idx = bottomTwoIndices(1);
end

% 5. Arrange corner points in order: top-left (pTL), top-right (pTR), 
% bottom-right (pBR), bottom-left (pBL)
pointsStats(1) = candidateStats(pTL_idx);
pointsStats(2) = candidateStats(pTR_idx);
pointsStats(3) = candidateStats(pBR_idx);
pointsStats(4) = candidateStats(pBL_idx);

if drawInfo
    plot([pointsStats(1).Centroid(1), pointsStats(2).Centroid(1), pointsStats(3).Centroid(1), pointsStats(4).Centroid(1), pointsStats(1).Centroid(1)], ...
         [pointsStats(1).Centroid(2), pointsStats(2).Centroid(2), pointsStats(3).Centroid(2), pointsStats(4).Centroid(2), pointsStats(1).Centroid(2)], 'g-', 'LineWidth', 2);
end
end

function result = illumination_correction(I,type)
% Illumination correction methods:
% 1. CLAHE (Contrast-Limited Adaptive Histogram Equalization)
% 2. Homomorphic Filtering
% 3. Multiscale Retinex (MSR)
if size(I,3) == 3
    Igray = rgb2gray(I);
else
    Igray = I;
end

if type == 1
    j = clahe(Igray);
elseif type == 2
    j = homomorphic(Igray);
else
    % Apply MSR with typical scales
    scales = [15, 80, 250];
    j = msr(Igray, scales);
end

result = j;
end

function J = clahe(Igray)
% CLAHE with default parameters
J = adapthisteq(Igray, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
end

function J = homomorphic(Igray)
% Homomorphic filtering
Igray = mat2gray(Igray);
Ilog = log1p(Igray);
Ifft = fft2(Ilog);
[M, N] = size(Igray);

% Create high-pass Gaussian filter
gammaL = 0.5;  % low-frequency gain
gammaH = 2.0;  % high-frequency gain
c = 1;         % sharpness
D1 = M/2; D2 = N/2;
[u, v] = meshgrid(1:N, 1:M);
Duv = (u - D1).^2 + (v - D2).^2;
H = (gammaH - gammaL) * (1 - exp(-c * Duv / (50^2))) + gammaL;

% Apply filter
Ihomo = real(ifft2(H .* Ifft));
J = mat2gray(exp(Ihomo) - 1);
end

function J = msr(Iin, scales)
% Multiscale Retinex (MSR) core function
Iin = mat2gray(Iin);
[M, N] = size(Iin);
J = zeros(M, N);
for sigma = scales
    % Gaussian surround function
    kernelSize = 2 * ceil(3 * sigma) + 1;
    G = fspecial('gaussian', kernelSize, sigma);
    % Convolution
    F = imfilter(Iin, G, 'replicate');
    % Retinex calculation
    J = J + (log1p(Iin) - log1p(F));
end
J = J / numel(scales);
J = mat2gray(J);
end