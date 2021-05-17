%% Checkerboard: transformation between cameras
%With each camera, take image of checkerboard placed in the relevant image plane
%Call these images im1 and im2.

%Directory with the two(or more) images
image_dir = 'CheckerImages/';

%Directory where to save transformation
save_dir = 'Transformations/';

%Name of file you want to save
customname = 'tform';

direc_im = dir([image_dir, '*.bmp']); %Adjust as needed

%Import images
im1 = imread( [image_dir '/' direc_im(1).name] );
im2 = imread( [image_dir '/' direc_im(2).name] );

%Prepare for detection of checkerboard crosses
checkers_n = []; checkers_p = [];

%Pre-processing: adjust as needed for your images
check_im1 = single(medfilt2(im1,[3,3]))*10;
check_im1 = imbinarize(check_im1,1);
%While loop in case checkerboard has many separate patterns (if, for instance,
%  you print out multiple checker patterns and tape them on a board)
while 1
    [checkers,boardSize] = detectCheckerboardPoints(check_im1);
    %If no more checkerboard patterns detected, leave
    if isempty(checkers)
        break
    end
    checkers_n = [checkers_n;checkers];
    %If checkerboard pattern was detected, "black out" image in this region
    minx = min(checkers(:,1));
    maxx = max(checkers(:,1));
    miny = min(checkers(:,2));
    maxy = max(checkers(:,2));
    check_im1(floor(miny):ceil(maxy), floor(minx):ceil(maxx)) = 0;
end

%Same as above, now for im2
check_im2 = single(medfilt2(im2,[3,3]))*10;
check_im2 = imbinarize(check_im2, 0.8);
while 1
    %Settings of detectCheckerboardPoints will depend on your specific images
    checkers = detectCheckerboardPoints(check_im2, 'MinCornerMetric',0.1);
    if isempty(checkers)
        break
    end
    checkers_p = [checkers_p; checkers];
    minx = min(checkers(:,1));
    maxx = max(checkers(:,1));
    miny = min(checkers(:,2));
    maxy = max(checkers(:,2));
    check_im2(floor(miny):ceil(maxy), floor(minx):ceil(maxx)) = 0;
end

%Optional: Plot image and look at locations of points for both images
figure;imshow(im1*10)
viscircles(checkers_n,5*ones(size(checkers_n,1),1),'color','r');
viscircles(checkers_p,5*ones(size(checkers_p,1),1),'color','b');drawnow

%Match pairs through cost minimization (other algorithms could work as well
dist_pair = zeros(size(checkers_p,1),size(checkers_n,1));
for i = 1:size(checkers_p,1)
    dist_pair(i,:) = sqrt((checkers_p(i,1)-checkers_n(:,1)).^2+(checkers_p(i,2)-checkers_n(:,2)).^2);
end
dist_thresh = 10; %threshold depends on average separation between matching points
[hungarian_min,uR,~] = matchpairs(dist_pair,dist_thresh);

%Organize checkers_n and _p to input into cp2tform
tracks_n = checkers_n ( hungarian_min(:,2),: );
tracks_p = checkers_p ( hungarian_min(:,1),: );

%Optional: Draw matched pairs with same colors (I use brewermap :
%   Stephen Cobeldick (2021). ColorBrewer: Attractive and Distinctive Colormaps
%       (https://github.com/DrosteEffect/BrewerMap), GitHub. Retrieved May 17, 2021. )
figure;imshow(0.5*ones(size(im1))); hold on
colors = brewermap(size(tracks_p,1),'Paired');
for i=1:size(tracks_p,1)
    plot(tracks_p(i,1),tracks_p(i,2), 'o','color',colors(i,:));
    plot(tracks_n(i,1),tracks_n(i,2) , 'o','color',colors(i,:));
    plot([tracks_n(i,1),tracks_p(i,1)],[tracks_n(i,2),tracks_p(i,2)],'k-')
end

%Compute polynomial transform between points
tform = cp2tform(tracks_p,tracks_n,'polynomial'); %Map 2 to 1. (inv: 1 to 2)
tformreverse= cp2tform(tracks_n,tracks_p,'polynomial'); %Map 1 to 2. (inv: 2 to 1)

%  the polynomial transform is only given as an inverse tranformation,
%  which cannot be inverted for forward, so we apply the inverse
%  transformation to take the "fixed" points (checkers_n) and move back to
%  the "moving" points (checkers_p). Which cam you transform to the other
%  is up to you.

checkers_tform = tforminv(tform,tracks_n(:,1),tracks_n(:,2));

%Optional: Plot distance between points after tform to check on error
dist = sqrt((checkers_tform(:,1)-tracks_p(:,1)).^2+(checkers_tform(:,2)-tracks_p(:,2)).^2);
figure(100);plot(dist);ylabel('pixels');title(num2str(framenum,'%05d'));drawnow
avgerr(imindex) = max(dist);

%HOW TO USE tformimage: ***************************************************
%    reference = imref2d(size(n_image));
%    testtrans =imwarp(p_image,tformimage,'OutputView',reference);
tformimage = fitgeotrans(tracks_p,tracks_n,'polynomial',3);
reference = imref2d(size(im1));
testtrans = imwarp(im2,tformimage,'OutputView',reference);

%Optional: Show images together after tform
figure;imshowpair(im1*5,testtrans*5,'diff');

save([save_dir customname '.mat'],'tform','tformreverse','tformimage')

