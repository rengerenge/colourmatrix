clc; close all;

files = [
    "noise_1.png";"noise_2.png";"noise_3.png";"noise_4.png";"noise_5.png";
    "org_1.png";"org_2.png";"org_3.png";"org_4.png";"org_5.png";
    "proj1_1.png";"proj1_2.png";"proj1_3.png";"proj1_4.png";"proj1_5.png";
    "proj2_1.png";"proj2_2.png";"proj2_3.png";"proj2_4.png";"proj2_5.png";
    "proj_1.png";"proj_2.png";"proj_3.png";"proj_4.png";"proj_5.png";
    "rot_1.png";"rot_2.png";"rot_3.png";"rot_4.png";"rot_5.png";
    "IMAG0032.jpg";"IMAG0033.jpg";"IMAG0034.jpg";"IMAG0035.jpg";"IMAG0036.jpg";
    "IMAG0037.jpg";"IMAG0038.jpg";"IMAG0041.jpg";"IMAG0042.jpg";"IMAG0044.jpg"
];

numFiles = size(files, 1);
row = floor(numFiles/2);

rows = 5; cols = 2;  % 每页 5x2 子图
total_plots = numFiles*2;    % 总子图数
total_page = ceil(total_plots/(rows*cols));
for page = 1:total_page
    figure;
    for i = 1:rows*cols/2
        idx = (page-1)*rows*cols/2 + i;
        if idx > total_plots, break; end

        filename = strtrim(files(idx, :));
        disp(["handle: " filename]);

        f = imread(filename);
        subplot(rows, cols, 2*i-1);
        imshow(f);
        title(filename, 'Interpreter', 'none');

        try
            matrix = colourMatrix(filename, 0);
            disp("检测到的4×4颜色矩阵：");
            disp(matrix);

            [mRows, mCols] = size(matrix);
            subplot(rows, cols, 2*i);
            axis([0 mCols+1 0 mRows+1]);
            axis off;
            hold on;

            for x = 1:mRows
                for y = 1:mCols
                    currentChar = matrix(x, y);
                    text(y, mRows + 1 - x, sprintf('%c', currentChar), ...
                        'Color', 'black', 'FontSize', 7);
                end
            end
            hold off;
            title('Color Matrix');
        catch ME
            fprintf("发生错误：%s\n", ME.message);
        end
    end
end


% for i = 1:numFiles
%     filename = strtrim(files(i, :));
%     disp(["handle: " filename]);
%     try
%         matrix = fcolor(filename, 1);
%         disp("检测到的4×4颜色矩阵：");
%         disp(matrix);
%     catch ME
%         fprintf("发生错误：%s\n", ME.message);
%     end
%     % input('按下回车继续处理下一个文件...','s');
%     % pause(3);
% end