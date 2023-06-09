clear,close,clc;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Origin=imread('');                  %读取图像
sensitivity = 0.55;                 %敏感度
Eccentricity = [0.985,1];           %偏心率
character = 30;                     %条形码条数，如果出现了条形码上下的数字，请调小该参数
radius = 30;                        %形态学结构元素，圆形半径
hsize = [3,3];                      %均值滤波器的大小
erodetimes = 4;                     %腐蚀次数
dilatetimes = 6;                    %膨胀次数
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
GrayOrigin=rgb2gray(Origin); %将彩色图变成灰色图
%Robert算子锐化图像
[m,n]=size(GrayOrigin);
Sharped=double(GrayOrigin);
for i=1:m-1
    for j=1:n-1
        Sharped(i,j)=GrayOrigin(i+1,j)-GrayOrigin(i,j+1);
    end
end

Sharped = Sharped + double(GrayOrigin);
Sharped = uint8(Sharped);% 锐化完毕

Background =adaptthresh(Sharped, sensitivity);
TwoValued = imbinarize(Sharped,Background);
TwoValued = ~TwoValued;

% figure,imshowpair(Origin,TwoValued, 'montage');title('分区域自适应二值化完成');

lines = bwpropfilt(TwoValued,'Eccentricity',Eccentricity);%通过偏心率初步过滤出'线条'

MAL = regionprops(lines,'MajorAxisLength');%获得“线条”的主轴长度的struct
MAL = cell2mat(struct2cell(MAL));

%figure,histogram(MAL);

[N1,edges1] = histcounts(MAL,uint8(max(MAL)/10));%对不同'线条u的长度进行计数
MaxAxisLengthcoordinate = size(N1,2);
count1 = 0;
for i = MaxAxisLengthcoordinate:-1:0
    count1 = count1+N1(1,i);
    if count1 >= character   %通过条形码'线条”的条数进行第一次过滤
        break;
    end
end

AxisMin = edges1(1,i);
AxisMax = edges1(1,MaxAxisLengthcoordinate+1);

Mapofsuitablelength = (MAL >= AxisMin) & (MAL <= AxisMax);
mappedlength = MAL(Mapofsuitablelength);

suitablerange = rmoutliers(mappedlength,'mean');   %通过去除离群值进行主轴长度的第二次过滤

Axisfiltered= bwpropfilt(TwoValued,'MajorAxisLength',[min(suitablerange),max(suitablerange)]);%主轴长度

% figure;imshow(Axisfiltered);title('主轴数量，长度过滤完毕');

%{
    对于大部分图片比如sensitivity=0.55,characteristic=46时的ENbook和
    sensitivity=0.55,characteristic=30时的CNbook,
    在sensitivity和characteristic设置基本合适时,
    至此已经可以达到最后一步的效果.
%}

Ortion = regionprops(Axisfiltered,'Orientation');
Ortion = cell2mat(struct2cell(Ortion));
% figure;histogram(Ortion);

% [N2,edges2] = histcounts(Ortion);%对不同'线条'的角度进行计数

suitableOrtion = rmoutliers(Ortion,'gesd');     %通过去除主轴方向的离群值经行第三次过滤

Degreefiltered= bwpropfilt(Axisfiltered,'Orientation',[min(suitableOrtion),max(suitableOrtion)]);%主轴长度

% figure;imshow(Degreefiltered);title('主轴数量，长度，方向过滤完毕');

%{
    对于一部分书背上条形图案较多的书籍，还是无能为力
%}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Degreefiltered = (uint8(Degreefiltered)*255);

% figure;imshow(Degreefiltered)

imageGuussian = imgaussfilt(Degreefiltered,4);% 高斯消噪
[imageSobelX,imageSobelY] = imgradientxy(imageGuussian);% 求梯度
imageSobelXY = imageSobelX + imageSobelY;

mat = fspecial('average',hsize);
imageSobelOut = imfilter(imageSobelXY,mat);%均值滤波
% imshow(imageSobelOut);

imageSobelOut =gpuArray(logical(imageSobelOut));%gpu运算

SE = strel('disk',radius);
imageSobleOutThreshold = imclose(imageSobelOut,SE);%闭运算

for i = 1 : erodetimes
    imageSobleOutThreshold = imerode(imageSobleOutThreshold,SE);%腐蚀
end

for i = 1 : dilatetimes
    imageSobleOutThreshold = imdilate(imageSobleOutThreshold,SE);%膨胀
end

imageSobleOutThreshold = gather(imageSobleOutThreshold);
imageSobleOutThreshold = immultiply(imageSobleOutThreshold,Degreefiltered);%掩膜

figure;imshowpair(Origin,imageSobleOutThreshold,'montage');
