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

fileToColorDict = containers.Map('KeyType', 'char', 'ValueType', 'any');

fileToColorDict('noise_1.png') = ['BYYB'; 'WRYG'; 'RYYB'; 'GYWR'];
fileToColorDict('noise_2.png') = ['YBRG'; 'GGWY'; 'GBBW'; 'RYBY'];
fileToColorDict('noise_3.png') = ['RRRY'; 'BBYW'; 'GBYB'; 'RBWW'];
fileToColorDict('noise_4.png') = ['YGYW'; 'RWWW'; 'RWGG'; 'RGBG'];
fileToColorDict('noise_5.png') = ['RYRY'; 'BGYY'; 'WYBG'; 'RYBY'];

fileToColorDict('org_1.png') = ['BYWY'; 'YWWR'; 'WYRR'; 'GWWR'];
fileToColorDict('org_2.png') = ['WGYG'; 'WRBW'; 'BBWW'; 'GYGW'];
fileToColorDict('org_3.png') = ['GRYG'; 'YBGG'; 'BRRW'; 'GYWY'];
fileToColorDict('org_4.png') = ['WWBY'; 'GGBR'; 'WWGY'; 'GWYR'];
fileToColorDict('org_5.png') = ['RYGY'; 'WGGG'; 'YWGR'; 'GGYW'];

fileToColorDict('proj1_1.png') = ['WYBW'; 'WWWW'; 'BGRB'; 'RBYR'];
fileToColorDict('proj1_2.png') = ['GRYB'; 'YGBY'; 'RGWY'; 'BYWW'];
fileToColorDict('proj1_3.png') = ['WRYB'; 'BGBW'; 'BBWB'; 'WBBY'];
fileToColorDict('proj1_4.png') = ['BRBG'; 'YRGR'; 'BRRR'; 'BYWR'];
fileToColorDict('proj1_5.png') = ['WRBB'; 'RRGY'; 'BBRB'; 'GWRG'];

fileToColorDict('proj2_1.png') = ['RRGY'; 'WBYB'; 'YYBW'; 'RGWG'];
fileToColorDict('proj2_2.png') = ['YBBG'; 'GYWB'; 'BGGB'; 'BYYR'];
fileToColorDict('proj2_3.png') = ['RBWY'; 'WYYY'; 'BGBG'; 'GWRW'];
fileToColorDict('proj2_4.png') = ['YRRR'; 'RYGY'; 'YGBY'; 'RWBY'];
fileToColorDict('proj2_5.png') = ['GRGW'; 'BBGW'; 'RWRY'; 'RYYW'];

fileToColorDict('proj_1.png') = ['WGYY'; 'WGYG'; 'BYYR'; 'YWBY'];
fileToColorDict('proj_2.png') = ['YYYY'; 'YWRY'; 'RGWB'; 'RWRG'];
fileToColorDict('proj_3.png') = ['WGWB'; 'YRRY'; 'GBGY'; 'BRYB'];
fileToColorDict('proj_4.png') = ['BRYY'; 'RGBG'; 'BYYB'; 'GGGY'];
fileToColorDict('proj_5.png') = ['YGYR'; 'YRWB'; 'BGBB'; 'GBGR'];

fileToColorDict('rot_1.png') = ['YRYY'; 'BWRY'; 'YWRW'; 'RWWG'];
fileToColorDict('rot_2.png') = ['GWYR'; 'WRBW'; 'BBGW'; 'GBBB'];
fileToColorDict('rot_3.png') = ['WYWR'; 'WYRR'; 'WGGR'; 'GRYG'];
fileToColorDict('rot_4.png') = ['WRWB'; 'WWRB'; 'GYYW'; 'RRGY'];
fileToColorDict('rot_5.png') = ['RRRR'; 'BGYY'; 'GYRG'; 'BBBW'];

fileToColorDict('IMAG0032.jpg') = ['YBBG'; 'RGYW'; 'BRGB'; 'GRRR'];
fileToColorDict('IMAG0033.jpg') = ['RRRY'; 'GGRG'; 'RYWB'; 'YYBY'];
fileToColorDict('IMAG0034.jpg') = ['GYRG'; 'YBRG'; 'YRYB'; 'WWYB'];
fileToColorDict('IMAG0035.jpg') = ['RYWB'; 'YWYY'; 'WGGW'; 'WYYB'];
fileToColorDict('IMAG0036.jpg') = ['BYBW'; 'BWYY'; 'WGRY'; 'WRYW'];

fileToColorDict('IMAG0037.jpg') = ['BYWB'; 'RRRB'; 'YYYR'; 'RBWG'];
fileToColorDict('IMAG0038.jpg') = ['RRRR'; 'BGYY'; 'GYRG'; 'BBBW'];
fileToColorDict('IMAG0041.jpg') = ['BBRY'; 'YRYB'; 'RGBY'; 'YYRY'];
fileToColorDict('IMAG0042.jpg') = ['RWGB'; 'WWBY'; 'BYGW'; 'WWRB'];
fileToColorDict('IMAG0044.jpg') = ['RWGB'; 'WWBY'; 'BYGW'; 'WWRB'];


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
        disp(filename);

        f = imread(filename);
        subplot(rows, cols, 2*i-1);
        imshow(f);
        title(filename, 'Interpreter', 'none');
        status = '';
        try
            matrix = colourMatrix(filename, 0);
            if isequal(fileToColorDict(filename), matrix)
                status = "pass";
                disp("pass");
            else
                status = "mistake";
                disp("mistake");
                disp(matrix);
            end

            disp(" ");
            
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
            title('Color Matrix [' + status +']');
        catch ME
            fprintf("Error：%s\n", ME.message);
        end
    end
end