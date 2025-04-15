function pointsStats = getInputPoints(I, drawInfo)
%GETPOINTSSTATS 从二值图像 erodedI 中提取候选圆形区域，并返回4个角点对应的统计信息
%
%   输入:
%       I - 经形态学处理后的二值图像
%
%   输出:
%       pointsStats - 1x4结构体数组，每个元素包含一个角点对应的统计信息，
%                     字段包括 'Centroid', 'Area', 'Circularity'
%
%   说明:
%       1. 通过 regionprops 提取所有候选区域信息。
%       2. 根据 'Circularity' 与 'Area' 筛选候选区域。
%       3. 若候选区域不足4个，则抛出错误；候选区域多于4个时利用凸包与共线性剔除方法，
%          保证最终只保留4个角点。
%       4. 根据角点的 y 坐标以及 x 坐标对四个角点排序，返回顺序为：上左、上右、下右、下左。

% 显示图像并绘制候选区域质心

% 1. 通过 regionprops 提取候选区域的统计信息
stats = regionprops(I, 'Centroid', 'Area', 'Circularity','BoundingBox');

if drawInfo
    % 绘制质心
    for k = 1:length(stats)
        centroid = stats(k).Centroid;
        plot(centroid(1), centroid(2), 'r+', 'MarkerSize', 6);
        % text(centroid(1), centroid(2), sprintf('A: %d C: %f', stats(k).Area, stats(k).Circularity), ...
        %     'Color', 'yellow', 'FontSize', 8);
    end
end

% 2. 过滤掉不合条件的候选区域
isValid = [stats.Circularity] > 0.14 & [stats.Area] > 10;
candidateStats = stats(isValid);

% 提取候选区域的质心
candidateCentroids = vertcat(candidateStats.Centroid);
if size(candidateCentroids, 1) < 4
    error('检测到的候选黑点数量不足，请调整预处理或过滤参数！');
end

% 3. 利用凸包选取候选角点
kHull = convhull(candidateCentroids(:,1), candidateCentroids(:,2));
% 首尾重复，去除重复元素，保留后续候选点的索引
hullPoints = candidateCentroids(kHull(2:end), :);
candidateIndices = kHull(2:end);

% 剔除共线点，设置角度容差8度
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
        % fprintf('点 %d 夹角 %.2f 度，近似共线，将剔除\n', i, rad2deg(angle));
        hullPoints(i,:) = [];
        candidateIndices(i) = [];
        i = 1; % 重置循环检查新的序列
    else
        % fprintf('点 %d 的夹角为 %.2f 度\n', i, rad2deg(angle));
        i = i + 1;
    end
end

if size(hullPoints,1) ~= 4
    hold off;
    error('Convex hull 未能得到恰好4个角点，请检查候选点');
end

% 保存最终获得的4个候选角点及其在 candidateStats 中对应的索引
corners = hullPoints;
cornersCandidateIndices = candidateIndices;

% 4. 对角点进行排序：先按 y 坐标（越小越靠上），再对同一水平线的点按 x 坐标区分左右
[~, idxSortedByY] = sort(corners(:,2));
sortedCorners = corners(idxSortedByY, :);
sortedCandidateIndices = cornersCandidateIndices(idxSortedByY);

% 上部为较上面的两个点，下部为较下的两个点
topTwo = sortedCorners(1:2, :);
bottomTwo = sortedCorners(3:4, :);
topTwoIndices = sortedCandidateIndices(1:2);
bottomTwoIndices = sortedCandidateIndices(3:4);

% 上部两个点中，x较小者为左上；下部两个点中，x较小者为左下
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

% 5. 按顺序排列角点对应的统计信息：
% 顺序为：上左（pTL）、上右（pTR）、下右（pBR）、下左（pBL）
pointsStats(1) = candidateStats(pTL_idx);
pointsStats(2) = candidateStats(pTR_idx);
pointsStats(3) = candidateStats(pBR_idx);
pointsStats(4) = candidateStats(pBL_idx);

if drawInfo
    plot([pointsStats(1).Centroid(1), pointsStats(2).Centroid(1), pointsStats(3).Centroid(1), pointsStats(4).Centroid(1), pointsStats(1).Centroid(1)], [pointsStats(1).Centroid(2), pointsStats(2).Centroid(2), pointsStats(3).Centroid(2), pointsStats(4).Centroid(2), pointsStats(1).Centroid(2)], 'g-', 'LineWidth', 2);
end
end
