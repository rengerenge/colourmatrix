% illumination_correction.m
% MATLAB script demonstrating illumination correction methods:
% 1. CLAHE (Contrast-Limited Adaptive Histogram Equalization)
% 2. Homomorphic Filtering
% 3. Multiscale Retinex (MSR)
function result = illumination_correction(I,type)
if size(I,3) == 3
    Igray = rgb2gray(I);
else
    Igray = I;
end
% subplot(2,2,1); imshow(Igray); title('Original');

if type == 1
j = clahe(Igray);
% subplot(2,2,2); imshow(j); title('CLAHE');
elseif type == 2
j = homomorphic(Igray);
% subplot(2,2,3); imshow(j); title('Homomorphic Filter');
else
% Apply MSR with typical scales
scales = [15, 80, 250];
j = msr(Igray, scales);
% subplot(2,2,4); imshow(j); title('Multiscale Retinex');
end

result = j;
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 1. CLAHE
function J = clahe(Igray)
% ClipLimit controls contrast enhancement (default 0.01-0.03)
J = adapthisteq(Igray, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
end

%% 2. Homomorphic Filtering
function J = homomorphic(Igray)
Igray = mat2gray(Igray);
Ilog = log1p(Igray);
% Fourier transform
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
% Exponentiate and normalize (use exp(x)-1 instead of expm1)
J = mat2gray(exp(Ihomo) - 1);
end

%% 3. Multiscale Retinex (MSR)
function J = msr(Iin, scales)
%% Multiscale Retinex core function
Iin = mat2gray(Iin);
[M, N] = size(Iin);
J = zeros(M, N);
for sigma = scales
    % Gaussian surround function
    kernelSize = 2 * ceil(3 * sigma) + 1;
    G = fspecial('gaussian', kernelSize, sigma);
    % Convolution
    F = imfilter(Iin, G, 'replicate');
    % Retinex calculation (use log(1+x))
    J = J + (log1p(Iin) - log1p(F));
end
J = J / numel(scales);
J = mat2gray(J);
end

%% 使用高斯滤波矫正背景光照
function I_corrected = shadow_correction(I, method)
% I: 输入图像（灰度或RGB）
% method: 'division' 或 'multiplication'

if size(I, 3) == 3
    I = rgb2gray(I); % 转换为灰度图
end

I = double(I);
I = I / max(I(:));  % 归一化到 [0,1]

% 使用高斯滤波估计光照分布
R = imgaussfilt(I, 30);  % 半径越大越平滑（可调）

switch lower(method)
    case 'division'
        I_corrected = I ./ (R + eps);  % 避免除以0
        I_corrected = mat2gray(I_corrected);  % 归一化
    case 'multiplication'
        C = mean(R(:));
        I_corrected = I .* (C ./ (R + eps));
        I_corrected = mat2gray(I_corrected);  % 归一化
    otherwise
        error('Unknown method: use "division" or "multiplication"');
end
end