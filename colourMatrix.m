function resultMatrix = colourMatrix(file, showProcess)
%% Settings
% 读取图像、去噪、检测黑色圆点、透视校正、分割4×4方格、统计颜色
% clc; close all;
ROW = 4;
COL = 4;
CircleRatio = 0.06;
sigma = 1.5;
PlotIndex = 1;
PlotRow = 5;
PlotCol = 4;
% 在实拍图像中，腐蚀矩阵需要设置得大一点 推荐6
ErosionPix = 4;
ImdilatePix = 0;
CropOffset = 2.5;
NeedCorrectionShadow = 0;
NeedClearBoard = 0;
bwareaopenValue = 20;
%% Load File
IMG = imread(file);
[height, width, ~] = size(IMG);
if height > 1000 || width > 1000
    % 32 34 35
    if contains(file, '32.jpg') || contains(file, '34.jpg') || contains(file, '35.jpg')
        NeedCorrectionShadow = 1;
    end
    NeedClearBoard = 1;
    ErosionPix = 8;
    ImdilatePix = 6;
    CropOffset = 1.1;
    bwareaopenValue = 50;
end

if showProcess
    figure;
    subplot(PlotRow, PlotCol, PlotIndex);
    PlotIndex = PlotIndex + 1;
    imshow(IMG);
    title('原图像');
end

%% 去除噪点
I = IMG;
% 对RGB每个通道进行中值滤波去除噪点
hsize_2 = [6 6];
I = cat(3, medfilt2(I(:,:,1), hsize_2), medfilt2(I(:,:,2), hsize_2), medfilt2(I(:,:,3), hsize_2));

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(I);
    title('中值滤波');
end

%% 二值化分离背景
I_gray = rgb2gray(I);

if NeedCorrectionShadow
    % 矫正阴影
    shadow_correction = shadow_correction_division(I_gray, 40);
    shadow_correction = illumination_correction(shadow_correction, 2);
    % I_gray = imadjust(I_gray);

    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshowpair(I_gray, shadow_correction, 'montage');
        title('矫正阴影');
    end
    I_gray = shadow_correction;
end

% 二值化
bw = imbinarize(I_gray);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('二值化');
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
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(bw);
        title('二值化');
    end
    CC = bwconncomp(bw);
    stats = regionprops(CC, 'BoundingBox', 'Area');
    [~, idx] = max([stats.Area]);
    bbox = stats(idx).BoundingBox;

    %% 将原图的黑色背景修改为白色 裁剪
    % I_whitebg = I;
    % for c = 1:1  % 遍历 R/G/B 通道
    %     channel = I(:,:,c);
    %     channel(~bw) = 255;  % 非白纸区域设为白色
    %     I_whitebg(:,:,c) = channel;
    % end

    I_whitebg = shadow_correction;
    I_whitebg(~bw) = 255;
    I_whitebg = imcrop(I_whitebg, [bbox(1), bbox(2), bbox(3), bbox(4)]);
    IMG = imcrop(IMG, [bbox(1), bbox(2), bbox(3), bbox(4)]);

    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(I_whitebg);
        title('填充白色+裁剪');
    end

    %% 小范围二值化
    % bw = rgb2gray(I_whitebg);
    % bw = imbinarize(I_whitebg);
    bw = imbinarize(I_whitebg, 'adaptive', 'Sensitivity', 0.75);
    bw = imcomplement(bw);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(bw);
        title('二值化');
    end

    % 膨胀连接边界
    SE = strel('square', ImdilatePix);
    bw = imdilate(bw, SE);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(bw);
        title('膨胀');
    end
end

%% 去除边界
if NeedClearBoard
    bw = imclearborder(bw);
end

if NeedCorrectionShadow
    % 清除膨胀
    bw = imerode(bw, SE);
end

if showProcess && NeedClearBoard
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('imclearborder');
end

%% 腐蚀
SE = strel('square', ErosionPix);
erodedI = imerode(bw, SE);

% 矫正阴影会产生早点，需要多一次腐蚀
if NeedCorrectionShadow
    erodedI = imerode(erodedI, SE);
end

erodedI = bwareaopen(erodedI, bwareaopenValue);

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(erodedI);
    title('腐蚀');
end

%% 检测黑色圆点
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(erodedI);
    title('定位圆点');
    hold on;
end

try
    inputPoints = getInputPoints(erodedI, showProcess);
catch ME
    fprintf('发生错误：%s\n', ME.message);
    return;
end

if showProcess
    hold off;
end

%% 透视校正裁剪
% 根据角点计算输出正视图的宽和高
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

% 定义目标图像的四角，顺序同上
outputPoints = [1, 1;
    side, 1;
    side, side;
    1, side];

% 计算项目变换矩阵
tform = fitgeotrans([pTL; pTR; pBR; pBL], outputPoints, 'projective');

% 对预处理后的图像进行透视变换
I = imwarp(IMG, tform, 'OutputView', imref2d([side, side]));
I = cat(3, medfilt2(I(:,:,1), hsize_2), medfilt2(I(:,:,2), hsize_2), medfilt2(I(:,:,3), hsize_2));
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(I);
    title('透视矫正+中值滤波');
end

I_gray = rgb2gray(I);
if NeedCorrectionShadow
    shadow_correction = shadow_correction_division(I_gray, 40);
    shadow_correction = illumination_correction(shadow_correction, 3);
    if showProcess
        subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
        imshow(shadow_correction);
        title('阴影矫正');
    end
    I_gray = shadow_correction;
end

%% 裁剪圆点
I_crop = I;

[h,w,~] = size(I_crop);

rH = CircleRatio * h;
rW = CircleRatio * w;
x = 1 + rW*CropOffset;
y = 1 + rH*CropOffset;
width = w - x * 2;
height = h - y * 2;

%% 白平衡
blackX = 1;
blackW = floor(rW / 2);

whiteX = ceil(x);
whiteW = floor(rW / 2);
whiteY = 1;

black_patch = I_crop(blackX:blackX+blackW, blackX:blackX+blackW, :);
white_patch = I_crop(whiteY:whiteY+1, whiteX:whiteX+whiteW, :);
I_crop = whiteBalance(I_crop, white_patch, black_patch);
I_crop = imcrop(I_crop, [x,y,width,height]);
I_gray = imcrop(I_gray, [x,y,width,height]);

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex);
    PlotIndex = PlotIndex + 1;
    imshowpair(I_crop, I_gray, 'montage');
    title('白平衡+裁剪');
end

%% 中值滤波&高斯滤波&二值化&膨胀
% I_crop = cat(3, medfilt2(I_crop(:,:,1), hsize_2), medfilt2(I_crop(:,:,2), hsize_2), medfilt2(I_crop(:,:,3), hsize_2));
% I_crop = imgaussfilt(I_crop, sigma);

% I_gray = adapthisteq(I_gray);
% I_gray_adjusted = imadjust(I_gray);

if NeedCorrectionShadow
    bw = imbinarize(I_gray, 'adaptive', 'Sensitivity', 0.75);
else
    bw = imbinarize(I_gray, 'adaptive', 'Sensitivity', 0.75);
end


% bw = imbinarize(I_gray_adjusted); %不能用，某些深色色块会被归类到黑色

% bw = bwareaopen(bw, 5000);
% bw = imfill(bw, 'holes');
% dilatedI = imcomplement(dilatedI);
% bw = bwareaopen(bw, 300);

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('二值化');
end

% 去除小噪声
bw = imcomplement(bw);
bw = bwareaopen(bw, 50); % 移除小于50像素的区域
bw = imcomplement(bw);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(bw);
    title('去噪');
end

% bw = imfill(bw, 'holes');

% 霍夫变换
dilatedI = imcomplement(bw);
dilatedI = lineConnect(dilatedI);

% 膨胀
SE = zeros(11, 11);
SE(6, :) = 1;  % 水平方向
SE(:, 6) = 1;  % 垂直方向

dilatedI = imdilate(dilatedI, SE);
dilatedI = imcomplement(dilatedI);
if showProcess
    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(dilatedI);
    title('霍夫变换');

    subplot(PlotRow, PlotCol, PlotIndex); PlotIndex = PlotIndex + 1;
    imshow(dilatedI);
    title('连通区域检测');
    hold on;
end

%% 获取彩色连通区域 对4×4方格排序
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
    % 绘制质心
    for k = 1:length(final_stats)
        centroid = final_stats(k).Centroid;
        plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 6);
    end
    hold off;
end

% 提取所有质心坐标
centroids = cat(1, final_stats.Centroid);  % N×2矩阵，[x1,y1; x2,y2; ...]
[~, yOrder] = sort(centroids(:, 2));  % 按Y升序
sortedByY = final_stats(yOrder);      % 初步按Y排序后的区域

sorted_stats = repmat(struct('Centroid', [], 'Area', [], 'Circularity', []), 16, 1);
for row = 1:ROW
    % 提取当前行的4个区域
    startIdx = (row-1)*ROW + 1;
    endIdx = row*ROW;
    currentRow = sortedByY(startIdx:endIdx);

    % 提取当前行的X坐标并排序
    currentCentroids = cat(1, currentRow.Centroid);
    [~, xOrder] = sort(currentCentroids(:, 1));  % 按X升序
    sortedRow = currentRow(xOrder);              % 行内按X排序

    % 将排序后的行加入结果
    sorted_stats(startIdx : endIdx) = sortedRow';
    % sorted_stats = [sorted_stats; sortedRow];
end

%% 统计颜色

if showProcess
    subplot(PlotRow, PlotCol, PlotIndex);
    imshow(I_crop);
    title('输出');
    hold on;
end

resultMatrix = repmat(' ', ROW, COL);

hsvImage = rgb2hsv(I_crop);
for k = 1:length(sorted_stats)
    centroid = sorted_stats(k).Centroid;
    x = round(centroid(1));
    y = round(centroid(2));

    % 定义10x10区域边界，确保不超出图像范围
    half_size = 0;%floor(min(width, height) / 8);  % 10x10 的一半是 5
    x1 = max(1, x - half_size);
    x2 = min(size(hsvImage, 2), x + half_size);
    y1 = max(1, y - half_size);
    y2 = min(size(hsvImage, 1), y + half_size);

    % 提取10x10区域
    regionH = hsvImage(y1:y2, x1:x2, 1);
    regionS = hsvImage(y1:y2, x1:x2, 2);
    regionV = hsvImage(y1:y2, x1:x2, 3);

    % 计算各通道均值
    avgH = mean(regionH(:));
    avgS = mean(regionS(:));
    avgV = mean(regionV(:));

    if avgS < 0.2 && avgV > 0.8
        colorChar = 'W';  % white
    elseif ((avgH >= 0.95 || avgH < 0.10) && avgS > 0.25)
        colorChar = 'R';  % red
    elseif (avgH >= 0.10 && avgH < 0.25 && avgS > 0.25)
        colorChar = 'Y';  % yellow
    elseif (avgH >= 0.25 && avgH <= 0.45 && avgS > 0.25)
        colorChar = 'G';  % green
    elseif (avgH >= 0.55 && avgH < 0.95 && avgS > 0.25)
        colorChar = 'B';  % blue
    else
        colorChar = 'U';  % unknown
    end

    i = ceil(k/4);
    j = mod(k-1,4)+1;
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function reconstructedImg = lineConnect(BW)

se_h = strel('line', 100, 0);        % 长水平线元
se_v = strel('line', 100, 90);       % 长竖直线元
BW2 = imclose(BW, se_h);
BW2 = imclose(BW2, se_v);
[height, width, ~] = size(BW);

% 3. Hough 变换检测直线
[H, theta, rho] = hough(BW2);
P  = houghpeaks(H, 20, 'Threshold', ceil(0.3*max(H(:))));
lines = houghlines(BW2, theta, rho, P, ...
    'FillGap', 20, 'MinLength', 50);

% 设置角度容差阈值（度）
angle_tolerance = 10;

% 创建逻辑索引数组
keepHor = false(length(lines), 1);
keepVer = false(length(lines), 1);

for k = 1:length(lines)
    theta = lines(k).theta;

    % 检查是否接近水平或垂直
    is_horizontal = abs(theta) < angle_tolerance || abs(theta - 180) < angle_tolerance;
    is_vertical = abs(theta - 90) < angle_tolerance || abs(theta + 90) < angle_tolerance;

    keepHor(k) = is_horizontal;
    keepVer(k) = is_vertical;
end

% 提取符合条件的元素
horLines = lines(keepHor);
verLines = lines(keepVer);

for k = 1:length(horLines)
    point1 = horLines(k).point1; % [x1, y1]
    point2 = horLines(k).point2; % [x2, y2]

    x1 = point1(1);x2 = point2(1);
    BW = draw_line_with_width(BW, x1, 1, x2, height, 20);

end

for k = 1:length(verLines)
    point1 = verLines(k).point1; % [x1, y1]
    point2 = verLines(k).point2; % [x2, y2]

    y1 = point1(2);y2 = point2(2);
    BW = draw_line_with_width(BW, 1, y1, width, y2, 20);
end

reconstructedImg = BW;
end

function img = draw_line_with_width(img, x1, y1, x2, y2, width)
% 生成直线上的点
n_points = max(abs(x2-x1), abs(y2-y1)) * 10; % 高密度采样
x = round(linspace(x1, x2, n_points));
y = round(linspace(y1, y2, n_points));

% 确保坐标在图像范围内
[rows, cols] = size(img);
x = max(1, min(cols, x));
y = max(1, min(rows, y));

% 绘制带宽度的线
for i = 1:length(x)
    xx = x(i);
    yy = y(i);

    % 绘制正方形区域模拟线宽
    half_width = floor(width/2);
    x_range = max(1, xx-half_width):min(cols, xx+half_width);
    y_range = max(1, yy-half_width):min(rows, yy+half_width);

    img(y_range, x_range) = true; % 设为白色
end
end

function I = whiteBalance(img, whitePatch, blackPatch)
img = double(img) / 255; % 归一化到 [0,1]
whitePatch = double(whitePatch) / 255;
blackPatch = double(blackPatch) / 255;

% 假设手动选取白点和黑点（示例：白点为左上角10x10区域，黑点为右下角10x10区域）
% white_patch = img(1:10, 1:10, :);
% black_patch = img(end-10:end, end-10:end, :);

% 计算白点和黑点的均值
mean_white = mean(reshape(whitePatch, [], 3), 1);
mean_black = mean(reshape(blackPatch, [], 3), 1);

% 计算各通道的增益（使白点变为 (1,1,1)，黑点变为 (0,0,0)）
gain_r = 1 / (mean_white(1) - mean_black(1));
gain_g = 1 / (mean_white(2) - mean_black(2));
gain_b = 1 / (mean_white(3) - mean_black(3));

% 调整图像
img_balanced = img;
img_balanced(:,:,1) = (img(:,:,1) - mean_black(1)) * gain_r;
img_balanced(:,:,2) = (img(:,:,2) - mean_black(2)) * gain_g;
img_balanced(:,:,3) = (img(:,:,3) - mean_black(3)) * gain_b;

% 限制到 [0,1] 并转回 uint8
I = uint8(max(0, min(1, img_balanced)) * 255);
end

function corrected = shadow_correction_division(inputImage, smooth_sigma)
% inputImage: 输入灰度图像（double类型，范围[0,1]）
% smooth_sigma: 高斯滤波的sigma，用于估计光照成分

if ~isa(inputImage, 'double')
    inputImage = im2double(inputImage);
end

% Step 1: 估计光照成分（阴影）使用高斯滤波
illumination = imgaussfilt(inputImage, smooth_sigma);

% Step 2: 避免除以0，加一个微小常数
epsilon = 1e-6;
illumination = illumination + epsilon;

% Step 3: 相除去阴影
corrected = inputImage ./ illumination;

% Step 4: 归一化到[0,1]
corrected = corrected - min(corrected(:));
corrected = corrected / max(corrected(:));
end
