//
//  JLPageViewCell.h
//
//  Version 0.2.0
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#import <UIKit/UIKit.h>

@interface JLPageViewCell : UIView

@property (assign, nonatomic) NSInteger index;
@property (strong, nonatomic) NSDictionary *userInfo;
@property (assign, nonatomic) BOOL visible;

@end
