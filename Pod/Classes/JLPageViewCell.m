//
//  JLPageViewCell.m
//
//  Version 0.3.0
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#import "JLPageViewCell.h"

@implementation JLPageViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.index = -1;
        self.clipsToBounds = YES;
    }
    
    return self;
}

@end
