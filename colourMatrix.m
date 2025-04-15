function resultMatrix = colourMatrix(file, showProcess)
%% process_grid.m
% 读取图像、去噪、检测黑色圆点、透视校正、分割4×4方格、统计颜色
% clc; close all;
ROW = 4;
COL = 4;

% 在实拍图像中，腐蚀矩阵需要设置得大一点 推荐6
ErosionPix = 4;
CropOffset = 2.5;

%% STEP 1: 读取图像并预处理
% 请确保图片文件名正确
IMG = imread(file);
[height, width, ~] = size(IMG);
if height > 1000 || width > 1000
    ErosionPix = 6;
    CropOffset = 1.1;
end

if showProcess
    figure;
    subplot(3, 4, 1);
    imshow(IMG);
    title('原图像');
end

I = IMG;
% 创建高斯滤波器
% hsize = [10 10];
sigma = 1.5;
% 对图像进行高斯滤波
% I = imgaussfilt(I, sigma);

% 对RGB每个通道进行中值滤波去除噪点
hsize_2 = [6 6];
I = cat(3, medfilt2(I(:,:,1), hsize_2), medfilt2(I(:,:,2), hsize_2), medfilt2(I(:,:,3), hsize_2));

I_denoised = I;

if showProcess
    subplot(3, 4, 2);
    imshow(I_denoised);
    title('中值滤波');
end

% 转换为灰度图，并增强对比度以便后续二值化
I_gray = rgb2gray(IMG);
I_gray_adjusted = imadjust(I_gray);

% 二值化（采用自适应阈值，Sensitivity可以根据实际图像调节）
bw = imbinarize(I_gray_adjusted);

% se = strel('square', 3);
% bw = imopen(bw, se);
bw = bwareaopen(bw, 30);

bw_clean = imcomplement(bw);

% 定义结构元素（例如3x3矩形）
SE = strel('square', ErosionPix); 
% 腐蚀操作
erodedI = imerode(bw_clean, SE);
% erodedI = medfilt2(erodedI, [8, 8]);
% erodedI = imdilate(erodedI, strel('disk', 3));

erodedI = imclearborder(erodedI);

if showProcess
    subplot(3, 4, 3);
    imshow(erodedI);
    title('二值化+腐蚀');
end

%% STEP 2: 检测黑色圆点
% 显示原图 + 边界 + 质心
if showProcess
    subplot(3, 4, 4);
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

%% STEP 4: 透视校正裁剪
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

% 定义目标图像的四角，顺序同上
outputPoints = [1, 1; 
                outputWidth, 1; 
                outputWidth, outputHeight; 
                1, outputHeight];

% 计算项目变换矩阵
tform = fitgeotrans([pTL; pTR; pBR; pBL], outputPoints, 'projective');

% 对预处理后的图像进行透视变换
I = imwarp(IMG, tform, 'OutputView', imref2d([outputHeight, outputWidth]));
I = cat(3, medfilt2(I(:,:,1), hsize_2), medfilt2(I(:,:,2), hsize_2), medfilt2(I(:,:,3), hsize_2));

if showProcess
    subplot(3, 4, 5);
    imshow(I);
    title('透视矫正+高斯&中值滤波');
end

I_crop = I;

I_gray = rgb2gray(I_crop);
I_gray_adjusted = imadjust(I_gray);
erodedI = imbinarize(I_gray_adjusted,'adaptive', 'Sensitivity',1);
erodedI = bwareaopen(erodedI, 30);

SE = strel('disk', 3);
% erodedI = imopen(bw, SE);
erodedI = imcomplement(erodedI);
% SE = strel('square', 5);
erodedI = imerode(erodedI, SE);
% erodedI = imclearborder(erodedI);

if showProcess
    subplot(3, 4, 6);
    imshow(erodedI);
    title('二值化+腐蚀');
end

if showProcess
    subplot(3, 4, 7);
    imshow(erodedI);
    title('定位');
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

x = inputPoints(1).BoundingBox(1) + inputPoints(1).BoundingBox(3)*CropOffset;
y = inputPoints(1).BoundingBox(2) + inputPoints(1).BoundingBox(4)*CropOffset;
width = inputPoints(3).BoundingBox(1) - inputPoints(1).BoundingBox(3)*CropOffset - x;
height = inputPoints(3).BoundingBox(2) - inputPoints(2).BoundingBox(4)*CropOffset - y;

I_crop = imcrop(I_crop, [x,y,width,height]);

if showProcess
    imshow(I_crop);
    title('裁剪');
end

%% STEP 5: 获取彩色连通区域 对4×4方格排序
I_crop = imgaussfilt(I_crop, sigma);

if showProcess
    subplot(3, 4, 8);
    imshow(I_crop);
    title('高斯滤波');
end

I_gray = rgb2gray(I_crop);
I_gray_adjusted = imadjust(I_gray);
bw = imbinarize(I_gray_adjusted, 'adaptive', 'Sensitivity', 0.75);
bw = bwareaopen(bw, 30);

if showProcess
    subplot(3, 4, 9);
    imshow(bw);
    title('二值化');
end

% 膨胀操作
SE = strel('square', 6); 
dilatedI = imdilate(imcomplement(bw), SE);

SE = zeros(7, 7);
SE(4, :) = 1;  % 水平方向
SE(:, 4) = 1;  % 垂直方向
dilatedI = imdilate(dilatedI, SE);
dilatedI = imcomplement(dilatedI);

if showProcess
    subplot(3, 4, 10);
    imshow(dilatedI);
    title('膨胀');
    hold on;
end

color_stats = regionprops(dilatedI, 'Centroid', 'Area', 'Circularity');

while length(color_stats) > 16
    % 提取所有面积并计算合适的阈值
    allAreas = [color_stats.Area];
    maxArea = max(allAreas);
    areaThreshold = maxArea;  % 调整阈值以适应实际情况

    % 只保留面积较小的区域（小方格）
    validIndices = [color_stats.Area] < areaThreshold & [color_stats.Area] > 8;
    color_stats = color_stats(validIndices);
end

final_stats = color_stats;
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

% 绘制质心
for k = 1:length(sorted_stats)
    centroid = sorted_stats(k).Centroid;
    if showProcess
        plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 6);
    end
end

if showProcess
    hold off;
end

%% STEP 6: 统计颜色

if showProcess
    subplot(3, 4, 11);
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

    avgH = hsvImage(y, x, 1);
    avgS = hsvImage(y, x, 2);
    avgV = hsvImage(y, x, 3);

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
        text(x-8, y, sprintf(colorChar), ...
            'Color', 'Black', 'FontSize', 8);
    end
end

if showProcess
    hold off;
end

%% 输出结果
% disp('检测到的4×4颜色矩阵：');
% disp(resultMatrix);
end