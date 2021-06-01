//
//  RecognizeDegree.m
//  TestTilt
//
//  Created by uchiyama_Macmini on 2019/05/23.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include <algorithm>
#include <opencv2/opencv.hpp>
#include <opencv2/core/base.hpp>
#import "RecognizeDegree.h"

@interface RecognizeDegree()
{
    cv::Mat _img;
    cv::Mat _img_tmp;
    cv::Size _makeSize;
}
@end

@implementation RecognizeDegree

cv::Point minPoint(std::vector<cv::Point> contours){
    // 原点に近い点を抽出
    cv::Point minDis;
    double mindist = 999999;
    for(int i = 0; i < contours.size(); i++){
        double minx = contours.at(i).x;
        double miny = contours.at(i).y;
        double d = sqrt(minx*minx+miny*miny);
        if(d < mindist){
            minDis = contours.at(i);
            mindist = d;
        }
    }
    return minDis;
}
cv::Point maxPoint(std::vector<cv::Point> contours){
    // 距離が遠いモノを抽出
    cv::Point maxDis;
    double maxdist = 0;
    for(int i = 0; i < contours.size(); i++){
        double maxx = contours.at(i).x;
        double maxy = contours.at(i).y;
        double d = sqrt(maxx*maxx+maxy*maxy);
        if(d > maxdist){
            maxDis = contours.at(i);
            maxdist = d;
        }
    }
    return maxDis;
}

- (void)openImage:(NSString*)path
{
    if (path) {
        _img = cv::imread(path.UTF8String, cv::IMREAD_GRAYSCALE);
    }
}

- (NSData*)saveImage:(NSString*)fileName
{
    _img_tmp.copyTo(_img);
    
    cv::Mat retImg(_makeSize, CV_8UC1, cv::Scalar::all(255));
    
    [self adjustImg];
    cv::pyrUp(_img_tmp, _img_tmp);
    cv::pyrUp(_img_tmp, _img_tmp);
    cv::threshold(_img_tmp, _img_tmp, 0, 255, cv::THRESH_OTSU);
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Point> normContour;
    cv::findContours(_img_tmp, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (int i = 0; i < contours.size(); i++) {
        for (int j = 0; j < contours.at(i).size(); j++) {
            normContour.push_back(contours.at(i).at(j));
        }
    }
    
    if (normContour.size() == 0)
    {
        //retImg.copyTo(_img_tmp);
        std::vector<uchar> buff;
        std::vector<int> param = std::vector<int>(2);

        cv::imencode(".tif", retImg, buff);
        
        NSData *result = [[NSData alloc] initWithBytes:buff.data() length:buff.size()];
        retImg.release();
        return result;
    }
    
    cv::Rect contentRect = cv::boundingRect(normContour);
    contentRect.x -= 2;
    contentRect.y -= 2;
    contentRect.width += 4;
    contentRect.height += 4;
    cv::Mat content(_img, contentRect);
    
    int pageNum = 0;
    double dx;
    NSArray *arfn = [fileName componentsSeparatedByString:@"_"];
    
    for (NSString* s in arfn) {
        NSString *seped = [s substringToIndex:4];
        NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:seped];
        
        if ([[NSCharacterSet decimalDigitCharacterSet] isSupersetOfSet:charSet]) {
            pageNum = [seped intValue];
            break;
        }
    }
    
    if ((pageNum % 2) == 0) {
        dx = (double)_makeSize.width - ((double)content.cols + _hanRL);
    }
    else {
        dx = _hanRL;
    }

    double dy = (double)_makeSize.height - ((double)content.rows + _hanB) ;
    cv::Mat mat = (cv::Mat_<double>(2,3)<<1.0, 0.0, dx, 0.0, 1.0, dy);
    
    cv::warpAffine(content, retImg, mat, _makeSize, cv::INTER_LINEAR, cv::BORDER_CONSTANT, cv::Scalar::all(255));
    cv::threshold(retImg, retImg, 0, 255, cv::THRESH_OTSU);
    cv::Mat bitImg;
    cv::bitwise_not(retImg, bitImg);
    contours.clear();
    std::vector<cv::Vec4i> hie;
    std::vector<std::vector<cv::Point>> minArea;
    cv::findContours(bitImg, contours, hie, cv::RETR_TREE, cv::CHAIN_APPROX_NONE);
    
    for(auto ct = contours.begin(); ct != contours.end(); ++ct) {
        double area = cv::contourArea(*ct);
        if (area < _dustArea) {
            minArea.push_back(*ct);
        }
    }

    std::vector<int> dustIndex;
    for(auto it = hie.begin(); it != hie.end(); ++it) {
        cv::Vec4i info = *it;
        //int next = info[0];
        //int prev = info[1];
        int first = info[2];
        int parent = info[3];
        
        if (parent == -1) {
            if (first == -1) continue;
            int child = first;
            while (true) {
                cv::Vec4i di = hie[child];
                dustIndex.push_back(child);
                if (di[0] != -1) {
                    child = di[0];
                }else{
                    break;
                }
            }
        }
    }
    
    std::vector<std::vector<cv::Point>> whitePoint;
    
    for(auto it = dustIndex.begin(); it != dustIndex.end(); ++it) {
        std::vector<cv::Point> theCont = contours.at(*it);
        if (cv::contourArea(theCont) < _dustArea) {
            whitePoint.push_back(theCont);
            minArea.erase(std::remove(minArea.begin(), minArea.end(), theCont));
        }
    }
    
    for(auto ct = minArea.begin(); ct != minArea.end(); ++ct) {
        std::vector<std::vector<cv::Point>> theArea;
        theArea.push_back(*ct);
        cv::drawContours(bitImg, theArea, 0, cv::Scalar::all(0), cv::FILLED);
    }
    
    for(auto it = whitePoint.begin(); it != whitePoint.end(); ++it) {
        std::vector<std::vector<cv::Point>> theArea;
        theArea.push_back(*it);
        cv::drawContours(bitImg, theArea, 0, cv::Scalar::all(255), cv::FILLED);
    }
    cv::bitwise_not(bitImg, retImg);
    
    /*cv::Mat edge,k;

    cv::Canny(bitImg, edge, 100, 255);
    k = cv::getGaussianKernel(5, -1);
    cv::filter2D(edge, edge, -1, k);
    cv::pyrUp(edge, edge);
    cv::pyrUp(edge, edge);
    cv::pyrDown(edge, edge);
    cv::pyrDown(edge, edge);
    cv::imwrite("/tmp/bitImg_b.tif", edge);
    cv::threshold(edge, edge, 100, 255, cv::THRESH_BINARY);
    cv::bitwise_or(edge, bitImg, bitImg);
    
    //    cv::pyrUp(bitImg, edge);
    cv::pyrUp(edge, edge);
    cv::imwrite("/tmp/bitImg.tif", bitImg);
    */

    std::vector<uchar> buff;
    std::vector<int> param = std::vector<int>(2);
    
    cv::imencode(".tif", retImg, buff);
    
    NSData *result = [[NSData alloc] initWithBytes:buff.data() length:buff.size()];
    retImg.release();
    return result;
    
}

- (void)adjustImg
{
    cv::threshold(_img_tmp, _img_tmp, 0, 255, cv::THRESH_OTSU);
    cv::morphologyEx(_img_tmp, _img_tmp, cv::MORPH_OPEN, cv::Mat(), cv::Point(-1,-1), 2);
    cv::bitwise_not(_img_tmp, _img_tmp);
    cv::pyrDown(_img_tmp, _img_tmp);
    cv::pyrDown(_img_tmp, _img_tmp);
    cv::threshold(_img_tmp, _img_tmp, 0, 255, cv::THRESH_OTSU);
}

- (void)cropImg:(double)top right:(double)right left:(double)left bottom:(double)bottom
{
    // 周囲2pxきりとり
    double cropAround = 2.0;
    double x = cropAround + left;
    double y = cropAround + top;
    double w = _img.cols - ((cropAround * 2) + (left + right));
    double h = _img.rows - ((cropAround * 2) + (top + bottom));
    cv::Rect crop(x, y, w, h);
    _makeSize = cv::Size(crop.width + 4, crop.height + 4);
    _img_tmp = cv::Mat(_img, crop);
}

- (void)_rotate:(double)d
{
    cv::Point2f center(_img_tmp.cols / 2, _img_tmp.rows / 2);
    cv::Mat rot = cv::getRotationMatrix2D(center, -1*d, 1.0);
    cv::warpAffine(_img, _img_tmp, rot, _makeSize, cv::INTER_CUBIC, cv::BORDER_CONSTANT, cv::Scalar::all(255));
}

- (void)rotate:(double)deg
{
    [self _rotate:deg];
}

- (double)getDegree
{
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Point> normContour;
    std::vector<cv::Point> normContour_l;
    std::vector<cv::Point> normContour_r;
    std::vector<cv::Point> normContour_c;
    std::vector<cv::Point> negY;
    std::vector<cv::Point> posY;
    std::vector<cv::Point> negY_l;
    std::vector<cv::Point> posY_l;
    std::vector<cv::Point> negY_r;
    std::vector<cv::Point> posY_r;
    
    cv::Mat degImg;
    _img_tmp.copyTo(_img);
    
    [self adjustImg];
    
    _img_tmp.copyTo(degImg);
    _img.copyTo(_img_tmp);
    cv::findContours(degImg, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (int i = 0; i < contours.size(); i++) {
        for (int j = 0; j < contours.at(i).size(); j++) {
            normContour.push_back(contours.at(i).at(j));
        }
    }

    if (normContour.size() == 0) return 0;
    cv::Rect contentRect = cv::boundingRect(normContour);
    
    int cropBarHeight = 35;
    contentRect.y += cropBarHeight;
    contentRect.height -= cropBarHeight;
    contentRect.height -= cropBarHeight;
    
    cv::Mat allImg(degImg, contentRect);
    
    contours.clear();
    normContour.clear();
    
    //cv::imwrite("/tmp/allImg.tif", allImg);
    cv::findContours(allImg, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (int i = 0; i < contours.size(); i++) {
        for (int j = 0; j < contours.at(i).size(); j++) {
            normContour.push_back(contours.at(i).at(j));
        }
    }
    
    if (normContour.size() == 0) return 0;
    
    std::sort(normContour.begin(), normContour.end(), [](const cv::Point& p1,const cv::Point& p2){
        return p1.y > p2.y;
    });
    
    int mostX = 9999;
    int gappx = 15;
    
    for (int i = 0; i < allImg.rows; i++) {
        std::vector<cv::Point> theCont;
        for (int j = 0; j < normContour.size(); j++) {
            if (normContour.at(j).y == i) {
                theCont.push_back(normContour.at(j));
            }
        }
        if (theCont.size() != 0) {
            std::sort(theCont.begin(), theCont.end(), [](const cv::Point& p1,const cv::Point& p2){
                return p1.x < p2.x;
            });

            if (mostX >= theCont[0].x) {
                mostX = theCont[0].x;
                posY.push_back(theCont[0]);
            }
            else if (mostX < theCont[0].x){
                negY.push_back(theCont[0]);
            }
        }
    }

    for (int i = 0; i < posY.size(); i++) {
        int theX = posY.at(i).x;
        if (theX < mostX + gappx && theX > mostX - gappx) {
            normContour_l.push_back(posY.at(i));
            posY_l.push_back(posY.at(i));
        }
    }
    for (int i = 0; i < negY.size(); i++) {
        int theX = negY.at(i).x;
        if (theX < mostX + gappx && theX > mostX - gappx) {
            normContour_l.push_back(negY.at(i));
            negY_l.push_back(negY.at(i));
        }
    }
    
    negY.clear();
    posY.clear();
    
    mostX = 0;
    
    for (int i = 0; i < allImg.rows; i++) {
        std::vector<cv::Point> theCont;
        for (int j = 0; j < normContour.size(); j++) {
            if (normContour.at(j).y == i) {
                theCont.push_back(normContour.at(j));
            }
        }
        if (theCont.size() != 0) {
            std::sort(theCont.begin(), theCont.end(), [](const cv::Point& p1,const cv::Point& p2){
                return p1.x > p2.x;
            });
            
            if (mostX <= theCont[0].x) {
                mostX = theCont[0].x;
                negY.push_back(theCont[0]);
            }
            else if (mostX > theCont[0].x){
                posY.push_back(theCont[0]);
            }
        }
    }
    
    for (int i = 0; i < posY.size(); i++) {
        int theX = posY.at(i).x;
        if (theX < mostX + gappx && theX > mostX - gappx) {
            normContour_r.push_back(posY.at(i));
            posY_r.push_back(posY.at(i));
        }
    }
    for (int i = 0; i < negY.size(); i++) {
        int theX = negY.at(i).x;
        if (theX < mostX + gappx && theX > mostX - gappx) {
            normContour_r.push_back(negY.at(i));
            negY_r. push_back(negY.at(i));
        }
    }
    
    
    cv::Mat status, labelImg;
    cv::Mat centroids;
    std::map<int, cv::Mat> nLabImgs;
    std::map<int, cv::Mat> nLabImgs_l;
    std::map<int, cv::Mat> nLabImgs_r;
    
    int nLab = cv::connectedComponentsWithStats(allImg, labelImg, status, centroids, 8, CV_32S);
    
    for(int i = 1; i < nLab; ++i){
        int *param = status.ptr<int>(i);
        cv::Mat img(allImg.size(), CV_8UC1, cv::Scalar::all(0));
        nLabImgs.insert(std::pair<int, cv::Mat>(i,img));
    }
    
    for (int i = 0; i < labelImg.rows; ++i) {
        int *lb = labelImg.ptr<int>(i);
        for (int j = 0; j < labelImg.cols; ++j) {
            int theLabel = lb[j];
            auto iter = nLabImgs.find(theLabel);
            if (iter != std::end(nLabImgs)) {
                uchar *pix = iter->second.ptr<uchar>(i);
                pix[j] = 255;
            }
        }
    }
    
    for(auto it = nLabImgs.begin(); it != nLabImgs.end(); ++it){
        bool isFound = false;
        cv::findContours(it->second, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        for (int i = 0; i < contours.size(); i++) {
            for (int j = 0; j < contours.at(i).size(); j++) {
                for (int k = 0; k < normContour_l.size(); k++) {
                    if(contours.at(i).at(j) == normContour_l.at(k)) {
                        nLabImgs_l.insert(std::pair<int, cv::Mat>(it->first,it->second));
                        isFound = true;
                        break;
                    }
                }
                if (isFound) break;
            }
            if (isFound) break;
        }
    }
    for(auto it = nLabImgs.begin(); it != nLabImgs.end(); ++it){
        bool isFound = false;
        cv::findContours(it->second, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        for (int i = 0; i < contours.size(); i++) {
            for (int j = 0; j < contours.at(i).size(); j++) {
                for (int k = 0; k < normContour_r.size(); k++) {
                    if(contours.at(i).at(j) == normContour_r.at(k)) {
                        nLabImgs_r.insert(std::pair<int, cv::Mat>(it->first,it->second));
                        isFound = true;
                        break;
                    }
                }
                if (isFound) break;
            }
            if (isFound) break;
        }
    }
    cv::Mat rImg(allImg.size(), CV_8UC1, cv::Scalar::all(0));
    cv::Mat lImg(allImg.size(), CV_8UC1, cv::Scalar::all(0));
    for (auto it = nLabImgs_r.begin(); it != nLabImgs_r.end(); ++it){
        rImg += it->second;
    }
    for (auto it = nLabImgs_l.begin(); it != nLabImgs_l.end(); ++it){
        lImg += it->second;
    }
    
    contours.clear();
    normContour.clear();
    
    cv::findContours(lImg, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (int i = 0; i < contours.size(); i++) {
        for (int j = 0; j < contours.at(i).size(); j++) {
            normContour.push_back(contours.at(i).at(j));
        }
    }
    cv::RotatedRect rc_L = cv::minAreaRect(normContour);
    
    contours.clear();
    normContour.clear();
    
    cv::findContours(rImg, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (int i = 0; i < contours.size(); i++) {
        for (int j = 0; j < contours.at(i).size(); j++) {
            normContour.push_back(contours.at(i).at(j));
        }
    }
    cv::RotatedRect rc_R = cv::minAreaRect(normContour);
    
    cv::cvtColor(lImg, lImg, cv::COLOR_GRAY2BGR);
    cv::cvtColor(rImg, rImg, cv::COLOR_GRAY2BGR);
    
    cv::Point2f verticesR[4];
    cv::Point2f verticesL[4];
    rc_R.points(verticesR);
    rc_L.points(verticesL);
    
    for (int j = 0; j < 4; j++)
        cv::line(rImg, verticesR[j], verticesR[(j+1)%4], cv::Scalar(0,0,255));
    for (int j = 0; j < 4; j++)
        cv::line(lImg, verticesL[j], verticesL[(j+1)%4], cv::Scalar(0,0,255));
    
    //cv::imwrite("/tmp/_img_tmp_L.tif", lImg);
    //cv::imwrite("/tmp/_img_tmp_R.tif", rImg);
    
    
    if (rc_L.angle == -90) rc_L.angle = 0;
    if (rc_R.angle == -90) rc_R.angle = 0;
    
    double rcRLen = (rc_R.size.width > rc_R.size.height)? rc_R.size.width:rc_R.size.height;
    double rcLLen = (rc_L.size.width > rc_L.size.height)? rc_L.size.width:rc_L.size.height;
    
    cv::RotatedRect largerRect = (rcLLen < rcRLen)? rc_R : rc_L;
    
    //bool isTurnRight = (abs(largerRect.angle) > 45)? false : true;
    
    if (largerRect.size.width < largerRect.size.height) {
        largerRect.angle -= 90;
    }
    
    if (largerRect.angle < -45) {
        largerRect.angle = -1 * (90 + largerRect.angle);
    }
    else {
        largerRect.angle = -1 * largerRect.angle;
    }
    
    //if (isTurnRight) largerRect.angle * -1;
    
    //cv::imwrite("/tmp/_img_tmp.tif", degImg);
    return largerRect.angle;
}

@end
