//
//  RecognizeDegree.h
//  TestTilt
//
//  Created by uchiyama_Macmini on 2019/05/23.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RecognizeDegree : NSObject
@property (assign) double hanRL;
@property (assign) double hanB;
@property (assign) double dustArea;
@property (assign) double beforeDegree;
- (void)openImage:(NSString*)path;
- (NSData*)saveImage:(NSString*)fileName;
- (void)cropImg:(double)top right:(double)right left:(double)left bottom:(double)bottom;
- (double)getDegree;
- (void)rotate:(double)deg;
@end
