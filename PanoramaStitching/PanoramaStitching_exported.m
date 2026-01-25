classdef PanoramaStitching_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        AddImageButton                 matlab.ui.control.Button
        RemoveImageButton              matlab.ui.control.Button
        PanoramaImageStitcherLabel     matlab.ui.control.Label
        ThumbnailPanel                 matlab.ui.container.Panel
        UseSimilarityOrderingCheckBox  matlab.ui.control.CheckBox
        StitchButton                   matlab.ui.control.Button
        LoadImagesButton               matlab.ui.control.Button
        UIAxes2                        matlab.ui.control.UIAxes
        UIAxes                         matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        ImagesOriginal cell = {}
        stitchedImage
        ThumbnailAxes
        SelectedIndex double = 0            % Index of the selected image
        ThumbnailImages = [];
    end
    

    methods (Access = private)

    function resultImage = image_stitching(app , imagesOriginal)
    numImages = length(imagesOriginal);

        if numImages == 1
            resultImage = imagesOriginal{1};
            return;
        end
    
    imagesGrayScale = cell(1,numImages);
    for i=1:numImages
        imagesGrayScale{i} = rgb2gray(im2single(imagesOriginal{i}));
    end
    
    f = cell(1,numImages);
    d = cell(1,numImages);
    for j=1:numImages 
       [f{j}, d{j}] = vl_sift(imagesGrayScale{j});
    end
    
       if numImages == 2
          [X1,X2,matches] = matchImages(f{1}, d{1}, f{2}, d{2});
           H = ransac(X1, X2, matches);
           resultImage = homographyStitchPair(H, imagesOriginal{1}, imagesOriginal{2});
           return;
       end
    
    midImageIndex = ceil(numImages/2);
    rotationIndices = floor(numImages/2);
    
    if mod(numImages,2)==0
        imgIndex1 = midImageIndex-1; 
        imgIndex2 = midImageIndex;
    else
        imgIndex1 = midImageIndex; 
        imgIndex2 = midImageIndex+1;
    end

    [X1,X2,matches] = matchImages(f{imgIndex1},d{imgIndex1},f{imgIndex2},d{imgIndex2});
    H = ransac(X1,X2,matches);
    resultImage = homographyStitchPair(H,imagesOriginal{imgIndex1},imagesOriginal{imgIndex2});
    grayStitchedFeatureBase = rgb2gray(im2single(resultImage));
    
    if mod(numImages,2)==0
        indicesToIgnore = -1;
    else
        indicesToIgnore = 1;
    end
    
    for j=1:rotationIndices
       for k = [-1,1]
           imageIndex = midImageIndex + (j*k);
           if imageIndex >= 1 && imageIndex <= numImages && (j*k) ~= indicesToIgnore
               [fG,dG] = vl_sift(grayStitchedFeatureBase);
               [X1,X2,matches] = matchImages(fG,dG,f{imageIndex},d{imageIndex});
               H = ransac(X1,X2,matches);
               resultImage = homographyStitchPair(H,resultImage,imagesOriginal{imageIndex});
               grayStitchedFeatureBase = rgb2gray(im2single(resultImage));
           end
       end
    end
    
    %figure; 
    %imshow(resultImage);

    function [X1,X2,matches] = matchImages(f1,d1,f2,d2)
        [matches, ~] = vl_ubcmatch(d1,d2);
        X1 = f1(1:2,matches(1,:)); X1(3,:) = 1;
        X2 = f2(1:2,matches(2,:)); X2(3,:) = 1;
    end

    function H = ransac(X1,X2,matches)
        clear H score ok;
        numMatches = size(matches,2);
        rng(300); 

        for t = 1:500
            subset = vl_colsubset(1:numMatches, 4);
            A = [];
            for i = subset
                A = cat(1, A, kron(X1(:,i)', vl_hat(X2(:,i))));
            end
            [~,~,V] = svd(A);
            H{t} = reshape(V(:,9),3,3);
            X2_ = H{t} * X1;
            du = X2_(1,:)./X2_(3,:) - X2(1,:)./X2(3,:);
            dv = X2_(2,:)./X2_(3,:) - X2(2,:)./X2(3,:);
            ok{t} = (du.*du + dv.*dv) < 4*4;
            score(t) = sum(ok{t});
        end
        [~, best] = max(score);

       if size(matches,2) < 4
        uialert(app.UIFigure, 'Not enough matching points between selected images.');
        return;
      end


        H = H{best};
    end

    
        function mosaic = homographyStitchPair(H,im1,im2)
        box2 = [1 size(im2,2) size(im2,2) 1;
                1 1 size(im2,1) size(im2,1);
                1 1 1 1];
        box2_ = inv(H) * box2;
        box2_(1,:) = box2_(1,:) ./ box2_(3,:);
        box2_(2,:) = box2_(2,:) ./ box2_(3,:);
        ur = min([1 box2_(1,:)]) : max([size(im1,2) box2_(1,:)]);
        vr = min([1 box2_(2,:)]) : max([size(im1,1) box2_(2,:)]);
        [u,v] = meshgrid(ur,vr);
        im1_ = vl_imwbackward(im2double(im1),u,v);
        z_ = H(3,1)*u + H(3,2)*v + H(3,3);
        u_ = (H(1,1)*u + H(1,2)*v + H(1,3)) ./ z_;
        v_ = (H(2,1)*u + H(2,2)*v + H(2,3)) ./ z_;
        im2_ = vl_imwbackward(im2double(im2),u_,v_);
        mass = ~isnan(im1_) + ~isnan(im2_);
        im1_(isnan(im1_)) = 0;
        im2_(isnan(im2_)) = 0;
        mosaic = (im1_ + im2_) ./ mass;
    end
    

end            
        
function order = estimateImageOrder(app, images)
    numImages = length(images);
    scores = zeros(numImages);

    for i = 1:numImages
        gray1 = rgb2gray(im2single(images{i}));
        [f1, d1] = vl_sift(gray1);
        for j = i+1:numImages
            gray2 = rgb2gray(im2single(images{j}));
            [f2, d2] = vl_sift(gray2);
            [matches, ~] = vl_ubcmatch(d1, d2);
            scores(i,j) = size(matches,2);
            scores(j,i) = size(matches,2);  
        end
    end

    totalMatches = sum(scores,2);
    [~, startIdx] = max(totalMatches);
    
    visited = false(1,numImages);
    order = startIdx;
    visited(startIdx) = true;

    for k = 2:numImages
        last = order(end);
        scores(:,last) = -inf; 
        [~, next] = max(scores(last,:));
        order(end+1) = next;
        visited(next) = true;
    end            
        end
        
        function selectThumbnail(app, index, imageObj)
           app.SelectedIndex = index;

            % Clear old borders
            delete(findall(app.ThumbnailPanel, 'Tag', 'BorderRect'));
        
            % Draw new border
            pos = imageObj.Position;
            rectangle(app.ThumbnailPanel, 'Position', pos + [-2, -2, 4, 4], ...
                'EdgeColor', 'red', 'LineWidth', 15, 'Tag', 'BorderRect');
                  
        end
        
        function updateMontage(app)
           
            if isempty(app.ImagesOriginal)
                cla(app.UIAxes);
            else
                montage(app.ImagesOriginal, 'Parent', app.UIAxes);
            end
            
        end

        
        function updateThumbnails(app)
            delete(findall(app.ThumbnailPanel, 'Type', 'uiimage'));
            delete(findall(app.ThumbnailPanel, 'Type', 'rectangle'));
        
            numImages = length(app.ImagesOriginal);
            app.ThumbnailImages = gobjects(1, numImages);
      
               
            for i = 1:numImages
                thumb = uiimage(app.ThumbnailPanel);
                thumb.ImageSource = app.ImagesOriginal{i};
                thumb.Position = [10 + mod(i-1, 4)*90, 250 - floor((i-1)/4)*90, 80, 80];
                thumb.ImageClickedFcn = @(src, event) selectThumbnail(app, i, src);
                app.ThumbnailImages(i) = thumb;
            end
            
        end
       
      end
                  

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadImagesButton
        function LoadImagesButtonPushed(app, event)
             [filenames, pathname] = uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.gif', 'All Image Files'; '*.*', 'All Files'}, ...
                'Select Images', 'MultiSelect', 'on');
        
            if isequal(filenames, 0)
                return;
            end
        
            if ischar(filenames)
                filenames = {filenames}; % Wrap in cell if only one file
            end
        
            % Clear previous data
            app.ImagesOriginal = cell(1, numel(filenames));
            delete(findall(app.ThumbnailPanel, 'Type', 'uiimage'));
            delete(findall(app.ThumbnailPanel, 'Type', 'rectangle'));
            app.ThumbnailImages = gobjects(1, length(filenames));
            app.SelectedIndex = 0;
        

            % Read, convert and scale images
            for i = 1:numel(filenames)
                fullPath = fullfile(pathname, filenames{i});
                img = imread(fullPath);
        
                % Normalize datatype
                if ~isa(img, 'uint8')
                    img = im2uint8(img);
                end
        
                % Convert grayscale to RGB
                if ndims(img) == 2 || (ndims(img) == 3 && size(img, 3) == 1)
                    img = cat(3, img, img, img);  % Convert grayscale to RGB
                end

                % Resize if needed
                scale = max(size(img, 1), size(img, 2));
                if scale > 400
                    img = imresize(img, 400 / scale);
                end
        
                app.ImagesOriginal{i} = img;
            end
        
            % Refresh GUI
            updateMontage(app);
            updateThumbnails(app);
        end

        % Button pushed function: StitchButton
        function StitchButtonPushed(app, event)
            if isempty(app.ImagesOriginal)
                uialert(app.UIFigure, 'Please load images first.', 'No Images Loaded');
                return;
            end
            
            app.UIFigure.Pointer = 'watch'; % denote loading for user clarity
            cla(app.UIAxes2);  %Clear the stitched image axes
            drawnow;

            if app.UseSimilarityOrderingCheckBox.Value == 1
                order = app.estimateImageOrder(app.ImagesOriginal);
                orderedImages = app.ImagesOriginal(order);
                app.stitchedImage = app.image_stitching(orderedImages);
               imshow(app.stitchedImage, 'Parent', app.UIAxes2);
            else
        
           try
                app.stitchedImage = app.image_stitching(app.ImagesOriginal);
                imshow(app.stitchedImage, 'Parent', app.UIAxes2);
            catch ME
                uialert(app.UIFigure, ME.message, 'Stitching Failed');
           end
            end
                      
           app.UIFigure.Pointer = 'arrow'; % stop loading
           drawnow;
        end

        % Button pushed function: RemoveImageButton
        function RemoveImageButtonPushed(app, event)
           idx = app.SelectedIndex;

            if idx < 1 || idx > length(app.ImagesOriginal)
                uialert(app.UIFigure, 'Please select an image to remove.', 'No Selection');
                return;
            end
        
            % Remove the selected image and thumbnail
            app.ImagesOriginal(idx) = [];
            app.ThumbnailImages(idx) = [];
        
            % Reset selection and clear border
            app.SelectedIndex = 0;
            delete(findall(app.ThumbnailPanel, 'Tag', 'BorderRect'));
        
            % Refresh thumbnails and montage
            updateThumbnails(app);
            updateMontage(app);
        end

        % Button pushed function: AddImageButton
        function AddImageButtonPushed(app, event)
        
            [filename, pathname] = uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.gif', 'All Image Files'; '*.*', 'All Files'}, ...
                'Select an Image to Add');
        
            if isequal(filename, 0)
                return;
            end
        
            img = imread(fullfile(pathname, filename));
        
            % Normalize datatype
            if ~isa(img, 'uint8')
                img = im2uint8(img);
            end
        
            % Convert grayscale to RGB
            if ndims(img) == 2 || (ndims(img, 3) == 1)
                img = cat(3, img, img, img);
            end
        
            % Resize if too large
            scale = max(size(img, 1), size(img, 2));
            if scale > 400
                img = imresize(img, 400 / scale);
            end
        
            % Add image to the list
            app.ImagesOriginal{end + 1} = img;
        
            % Refresh GUI
            updateMontage(app);
            updateThumbnails(app);

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [1 1 1];
            app.UIFigure.Position = [100 100 817 503];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.LineWidth = 0.1;
            app.UIAxes.Box = 'on';
            app.UIAxes.Position = [32 219 357 235];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.UIFigure);
            app.UIAxes2.XTick = [];
            app.UIAxes2.YTick = [];
            app.UIAxes2.LineWidth = 0.1;
            app.UIAxes2.Box = 'on';
            app.UIAxes2.Position = [402 219 359 234];

            % Create LoadImagesButton
            app.LoadImagesButton = uibutton(app.UIFigure, 'push');
            app.LoadImagesButton.ButtonPushedFcn = createCallbackFcn(app, @LoadImagesButtonPushed, true);
            app.LoadImagesButton.FontWeight = 'bold';
            app.LoadImagesButton.Position = [142 195 122 24];
            app.LoadImagesButton.Text = 'Load Images';

            % Create StitchButton
            app.StitchButton = uibutton(app.UIFigure, 'push');
            app.StitchButton.ButtonPushedFcn = createCallbackFcn(app, @StitchButtonPushed, true);
            app.StitchButton.FontWeight = 'bold';
            app.StitchButton.Position = [614 195 122 24];
            app.StitchButton.Text = 'Stitch';

            % Create UseSimilarityOrderingCheckBox
            app.UseSimilarityOrderingCheckBox = uicheckbox(app.UIFigure);
            app.UseSimilarityOrderingCheckBox.Text = 'Use Similarity Ordering';
            app.UseSimilarityOrderingCheckBox.Position = [448 197 145 22];

            % Create ThumbnailPanel
            app.ThumbnailPanel = uipanel(app.UIFigure);
            app.ThumbnailPanel.Title = 'ThumbnailPanel';
            app.ThumbnailPanel.FontWeight = 'bold';
            app.ThumbnailPanel.Scrollable = 'on';
            app.ThumbnailPanel.Position = [189 46 466 138];

            % Create PanoramaImageStitcherLabel
            app.PanoramaImageStitcherLabel = uilabel(app.UIFigure);
            app.PanoramaImageStitcherLabel.HorizontalAlignment = 'center';
            app.PanoramaImageStitcherLabel.FontName = 'Baskerville Old Face';
            app.PanoramaImageStitcherLabel.FontSize = 26;
            app.PanoramaImageStitcherLabel.FontWeight = 'bold';
            app.PanoramaImageStitcherLabel.Position = [264 461 296 35];
            app.PanoramaImageStitcherLabel.Text = 'Panorama Image Stitcher';

            % Create RemoveImageButton
            app.RemoveImageButton = uibutton(app.UIFigure, 'push');
            app.RemoveImageButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveImageButtonPushed, true);
            app.RemoveImageButton.VerticalAlignment = 'top';
            app.RemoveImageButton.FontWeight = 'bold';
            app.RemoveImageButton.FontColor = [0.6353 0.0784 0.1843];
            app.RemoveImageButton.Position = [304 14 86 21];
            app.RemoveImageButton.Text = 'Remove';

            % Create AddImageButton
            app.AddImageButton = uibutton(app.UIFigure, 'push');
            app.AddImageButton.ButtonPushedFcn = createCallbackFcn(app, @AddImageButtonPushed, true);
            app.AddImageButton.FontWeight = 'bold';
            app.AddImageButton.FontColor = [0 0.4471 0.7412];
            app.AddImageButton.Position = [418 13 100 22];
            app.AddImageButton.Text = 'Add Image';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = PanoramaStitching_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end