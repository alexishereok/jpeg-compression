function jpeg_compressor_gui1
% JPEG Compressor GUI in MATLAB
% Mimics Python/Tkinter app: select image, YCbCr split, chroma down/up, block DCT+quant, save as JPEG.

    %--- Config ---    
    outputDir = 'C:\Users\Nikhil Jindal\OneDrive\Desktop\FILES';
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    %--- State ---    
    img = [];
    filePath = '';
    quality = 75; % Default quality
    
    %--- Build GUI ---    
    hFig = figure('Name', 'JPEG Compressor', ...
                  'Position', [100 100 600 650], ...
                  'Resize', 'off', ...
                  'MenuBar', 'none', ...
                  'ToolBar', 'none', ...
                  'Color', [0.9 0.9 0.9]);

    % Title Text
    uicontrol(hFig, 'Style', 'text', 'String', 'JPEG Compressor','Position', [200 580 200 30], 'FontSize', 16,'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % Select Image button
    uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Select Image','Position', [50 520 150 40], 'FontSize', 12, 'BackgroundColor', [0.3 0.6 0.3],'Callback', @selectImage);

    % Axes for image preview
    hAx = axes('Parent', hFig, 'Units', 'pixels', 'Position', [100 250 400 250]);
    axis(hAx, 'off');

    % Status text
    hTxtStatus = uicontrol(hFig, 'Style', 'text', 'String', 'No image selected','Position', [100 220 400 20], 'ForegroundColor', [1 0 0],'HorizontalAlignment', 'center', 'FontSize', 12);

    % Compress buttons
    uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Upsample + Compress','Position', [50 150 200 40], 'FontSize', 12, 'BackgroundColor', [0.3 0.6 0.9],'Callback', @(~, ~) compressImage('upsample'));
    uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Downsample + Compress','Position', [350 150 200 40], 'FontSize', 12, 'BackgroundColor', [0.9 0.6 0.3],'Callback', @(~, ~) compressImage('downsample'));

    % Exit button
    uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Exit','Position', [150 60 300 40], 'FontSize', 12, 'BackgroundColor', [0.7 0.3 0.3],'Callback', @(src, evt) close(hFig));

    % Help button
    uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Help', ...
              'Position', [450 520 100 40], 'FontSize', 12, 'BackgroundColor', [0.6 0.6 0.6],'Callback', @showHelp);
    
    %--- Nested Functions ---
    function selectImage(~, ~)
        [file, folder] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.DNG','Image Files'});
        if isequal(file, 0), return; end
        filePath = fullfile(folder, file);
        if ~exist(filePath, 'file')
            errordlg(['File not found: ', filePath], 'File Error');
            return;
        end
        img = imread(filePath);
        % Display thumbnail
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
            drawnow; % Update the GUI

            I = img;
            [h, w, ~] = size(I);
            % Convert to YCbCr
            ycb = rgb2ycbcr(I);
            Y  = double(ycb(:,:,1));
            Cb = double(ycb(:,:,2));
            Cr = double(ycb(:,:,3));
            
            % Chroma resizing
            switch mode
                case 'downsample'
                    Cb = imresize(Cb, [floor(h/2) floor(w/2)], 'bilinear');
                    Cr = imresize(Cr, [floor(h/2) floor(w/2)], 'bilinear');
                    quality = 40; % Fixed quality for downsampling
                case 'upsample'
                    Cb = imresize(Cb, [h*2 w*2], 'bilinear');
                    Cr = imresize(Cr, [h*2 w*2], 'bilinear');
                    quality = 100; % Fixed quality for upsampling
            end

            % Block DCT + quantization
            QY  = blockDCT(Y);
            QCb = blockDCT(Cb);
            QCr = blockDCT(Cr);

            % Save JPEG
            [~, name, ~] = fileparts(filePath);
            outFile = fullfile(outputDir, sprintf('%s_%s.jpg', name, mode));
            imwrite(I, outFile, 'jpg', 'Quality', quality);
            
            % Update preview & status
            I_disp = imresize(I, [250 NaN]);
            imshow(I_disp, 'Parent', hAx);
            hTxtStatus.String = ['Compressed: ', mode];
            msgbox(['Saved at ', outFile], 'Compressed');
        catch ME
            errordlg(ME.message, 'Error');
        end
    end

    function Qmat = blockDCT(channel)
        % JPEG luminance quant matrix
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
        Qmat = zeros(h2,w2);
        for i = 1:8:h2
            for j = 1:8:w2
                block = C(i:i+7, j:j+7);
                D = dct2(block);
                Qmat(i:i+7,j:j+7) = round(D ./ Q);
            end
        end
    end

    function showHelp(~, ~)
        helpMsg = sprintf(['JPEG Compressor Help:\n', ...
                           '1. Select an image using the "Select Image" button.\n', ...
                           '2. Choose to upsample or downsample the image and compress it.\n', ...
                           '3. The compressed image will be saved in the specified output directory.\n', ...
                           '4. Click "Exit" to close the application.']);
        msgbox(helpMsg, 'Help');
    end
end
