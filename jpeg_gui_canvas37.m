function jpeg_gui_canvas37
% JPEG Compressor GUI in MATLAB with Huffman encoding/decoding and preview

outputDir = 'C:\Users\Nikhil Jindal\OneDrive\Desktop\FILES';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

img = [];
filePath = '';

hFig = figure('Name', 'JPEG Compressor', ...
    'Position', [100 100 600 650], ...
    'Resize', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Color', [0.9 0.9 0.9]);

uicontrol(hFig, 'Style', 'text', 'String', 'JPEG Compressor','Position', [200 580 200 30], 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Select Image','Position', [50 520 150 40], 'FontSize', 12, 'BackgroundColor', [0.3 0.6 0.3],'Callback', @selectImage);
hAx = axes('Parent', hFig, 'Units', 'pixels', 'Position', [100 250 400 250]);
axis(hAx, 'off');
hTxtStatus = uicontrol(hFig, 'Style', 'text', 'String', 'No image selected','Position', [100 220 400 20], 'ForegroundColor', [1 0 0],'HorizontalAlignment', 'center', 'FontSize', 12);
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Upsample + Compress','Position', [50 150 200 40], 'FontSize', 12, 'BackgroundColor', [0.3 0.6 0.9],'Callback', @(~, ~) compressImage('upsample'));
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Downsample + Compress','Position', [350 150 200 40], 'FontSize', 12, 'BackgroundColor', [0.9 0.6 0.3],'Callback', @(~, ~) compressImage('downsample'));
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Decompress and Show','Position', [175 100 250 40], 'FontSize', 12, 'BackgroundColor', [0.4 0.4 0.8],'Callback', @decompressImage);
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Exit','Position', [150 50 300 40], 'FontSize', 12, 'BackgroundColor', [0.7 0.3 0.3],'Callback', @(src, evt) close(hFig));
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Help', 'Position', [450 520 100 40], 'FontSize', 12, 'BackgroundColor', [0.6 0.6 0.6],'Callback', @showHelp);

    function selectImage(~, ~)
        [file, folder] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.DNG','Image Files'});
        if isequal(file, 0), return; end
        filePath = fullfile(folder, file);
        img = imread(filePath);
        I_disp = imresize(img, [250 NaN]);
        imshow(I_disp, 'Parent', hAx);
        hTxtStatus.String = 'Image selected';
    end

    function compressImage(mode)
        if isempty(img) || ~exist(filePath, 'file')
            errordlg('Please select a valid image first!', 'Error');
            return;
        end
        try
            hTxtStatus.String = 'Processing...';
            drawnow;

            I = img;
            [h, w, ~] = size(I);
            ycb = rgb2ycbcr(I);
            Y  = double(ycb(:,:,1));
            Cb = double(ycb(:,:,2));
            Cr = double(ycb(:,:,3));

            switch mode
                case 'downsample'
                    Cb = imresize(Cb, [floor(h/2), floor(w/2)], 'bilinear');
                    Cr = imresize(Cr, [floor(h/2), floor(w/2)], 'bilinear');
                case 'upsample'
                    Cb = imresize(Cb, [h*2, w*2], 'bilinear');
                    Cr = imresize(Cr, [h*2, w*2], 'bilinear');
            end

            % Apply DCT and Quantization
            QY = blockDCT(Y);
            QCb = blockDCT(Cb);
            QCr = blockDCT(Cr);

            % Encode the Y, Cb, and Cr channels
            symbols_Y = round(QY(:)); 
            symbols_Y = symbols_Y - min(symbols_Y(:)) + 1;

            symbols_Cb = round(QCb(:)); 
            symbols_Cb = symbols_Cb - min(symbols_Cb(:)) + 1;

            symbols_Cr = round(QCr(:)); 
            symbols_Cr = symbols_Cr - min(symbols_Cr(:)) + 1;

            % Get the unique symbols and their frequencies
            [unique_Y, ~, idx_Y] = unique(symbols_Y);
            [unique_Cb, ~, idx_Cb] = unique(symbols_Cb);
            [unique_Cr, ~, idx_Cr] = unique(symbols_Cr);

            % Calculate the frequency counts for each unique symbol
            freq_Y = accumarray(idx_Y, 1);
            freq_Cb = accumarray(idx_Cb, 1);
            freq_Cr = accumarray(idx_Cr, 1);

            % Normalize the frequencies to get probabilities
            prob_Y = freq_Y / sum(freq_Y);
            prob_Cb = freq_Cb / sum(freq_Cb);
            prob_Cr = freq_Cr / sum(freq_Cr);

            % Huffman Encoding for Y, Cb, and Cr
            dict_Y = huffmandict(unique_Y, prob_Y);
            dict_Cb = huffmandict(unique_Cb, prob_Cb);
            dict_Cr = huffmandict(unique_Cr, prob_Cr);

            huff_encoded_Y = huffmanenco(symbols_Y, dict_Y);
            huff_encoded_Cb = huffmanenco(symbols_Cb, dict_Cb);
            huff_encoded_Cr = huffmanenco(symbols_Cr, dict_Cr);

            [~, name, ~] = fileparts(filePath);
            save(fullfile(outputDir, [name '_' mode '.mat']), 'huff_encoded_Y', 'huff_encoded_Cb', 'huff_encoded_Cr', 'dict_Y', 'dict_Cb', 'dict_Cr', 'I');

            I_disp = imresize(I, [250 NaN]);
            imshow(I_disp, 'Parent', hAx);
            hTxtStatus.String = ['Compressed: ' mode];
            msgbox('Saved encoded data to .mat file', 'Success');
        catch ME
            errordlg(ME.message, 'Error');
        end
    end

    function decompressImage(hObject, eventdata)
        try
            hTxtStatus.String = 'Decompressing...';
            drawnow;

            [fileName, filePath] = uigetfile('*.mat', 'Select Compressed Data');
            if fileName == 0
                hTxtStatus.String = 'No file selected';
                return;
            end

            fullFilePath = fullfile(filePath, fileName);

            if exist(fullFilePath, 'file') ~= 2
                errordlg('File does not exist!', 'Error');
                return;
            end

            load(fullFilePath);  % Load the .mat file containing encoded data

            % Decode Huffman encoded data
            decoded_Y = huffmandeco(huff_encoded_Y, dict_Y);
            decoded_Cb = huffmandeco(huff_encoded_Cb, dict_Cb);
            decoded_Cr = huffmandeco(huff_encoded_Cr, dict_Cr);

            % Reshape the decoded data back to the original image size
            [h, w, ~] = size(I);  % Original image size
            Y_recon = reshape(decoded_Y, [h, w]);
            
            % For Cb and Cr, we need to reshape them based on their downsampling
            Cb_recon = reshape(decoded_Cb, [floor(h/2), floor(w/2)]);
            Cr_recon = reshape(decoded_Cr, [floor(h/2), floor(w/2)]);

            % Reconstruct the YCbCr image
            ycbcr_recon = cat(3, Y_recon, Cb_recon, Cr_recon);

            % Convert back to RGB
            I_recon = ycbcr2rgb(uint8(ycbcr_recon));

            % Display the decompressed image
            imshow(I_recon);
            hTxtStatus.String = 'Decompression Complete';
            msgbox('Decompression successful!', 'Success');
        catch ME
            errordlg(ME.message, 'Error');
        end
    end

    function Qmat = blockDCT(channel)
        Q = [16 11 10 16 24 40 51 61;
            12 12 14 19 26 58 60 55;
            14 13 16 24 40 57 69 56;
            14 17 22 29 51 87 80 62;
            18 22 37 56 68 109 103 77;
            24 35 55 64 81 104 113 92;
            49 64 78 87 103 121 120 101;
            72 92 95 98 112 100 103 99];
        [H, W] = size(channel);
        padH = mod(8-mod(H,8),8);
        padW = mod(8-mod(W,8),8);
        C = padarray(channel, [padH padW], 'replicate', 'post');
        [h2, w2] = size(C);
        Qmat = zeros(h2, w2);

        for i = 1:8:h2
            for j = 1:8:w2
                block = C(i:i+7, j:j+7);
                D = dct2(block);  % Apply DCT
                quantizedBlock = round(D ./ Q);  % Apply quantization
                zigzagBlock = zigzagScan(quantizedBlock);  % Apply zigzag scan
                Qmat(i:i+7,j:j+7) = reshape(zigzagBlock, [8,8]);  % Store in matrix
            end
        end
    end
    warning('off', 'MATLAB:assignedVariable');
    function zigzag = zigzagScan(block)
        % Preallocate the zigzag array (size 1x64 for an 8x8 block)
        zigzag = zeros(1, 64);

        % Zigzag indexing pattern for an 8x8 block
        zigzagIdx = [
            1, 2, 6, 7, 15, 16, 28, 29;
            3, 5, 8, 14, 17, 27, 30, 43;
            4, 9, 13, 18, 26, 31, 42, 44;
            10, 12, 19, 25, 32, 41, 45, 53;
            11, 20, 24, 33, 40, 46, 52, 54;
            21, 23, 34, 39, 47, 51, 55, 56;
            22, 35, 38, 48, 50, 57, 58, 59;
            36, 37, 49, 59, 60, 61, 62, 63
        ];

        % Extract values in zigzag order from the block
        zigzag = block(zigzagIdx);
    end

    function showHelp(~, ~)
        helpdlg('This GUI allows you to compress, decompress, and view JPEG images using Huffman encoding and DCT-based quantization.', 'Help');
    end

end
