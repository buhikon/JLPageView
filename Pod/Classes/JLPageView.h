//
//  JLPageView.h
//
//  Version 0.1.0
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#import <UIKit/UIKit.h>
#import "JLPageCell.h"

@class JLPageView;

@protocol JLPageViewDataSource

- (NSUInteger)numberOfItemsInPageView:(JLPageView *)pageView;

- (void)prepareCell:(JLPageCell *)reusingCell AtIndex:(NSInteger)index;
- (void)startLoadingCell:(JLPageCell *)reusingCell AtIndex:(NSInteger)index;

@end



@protocol JLPageViewDelegate

@optional
- (void)pageView:(JLPageView *)pageView didSelectCellAtIndex:(NSInteger)index;
- (void)pageView:(JLPageView *)pageView didChangeCurrentIndex:(NSInteger)index;

@end



@interface JLPageView : UIView

@property (nonatomic, weak) IBOutlet id<JLPageViewDataSource> dataSource;
@property (nonatomic, weak) IBOutlet id<JLPageViewDelegate> delegate;
@property (nonatomic, assign, getter = isWrapEnabled) IBInspectable BOOL wrapEnabled;

- (void)reloadPageView;
- (void)moveToIndex:(NSInteger)index;

@end
