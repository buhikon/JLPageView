//
//  JLPageView.h
//
//  Version 0.2.1
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#import <UIKit/UIKit.h>
#import "JLPageViewCell.h"

@class JLPageView;

@protocol JLPageViewDataSource

- (NSUInteger)numberOfItemsInPageView:(JLPageView *)pageView;

- (void)prepareCell:(JLPageViewCell *)reusingCell AtIndex:(NSInteger)index;
- (void)startLoadingCell:(JLPageViewCell *)reusingCell AtIndex:(NSInteger)index;

@end



@protocol JLPageViewDelegate

@optional
- (void)pageView:(JLPageView *)pageView didSelectCellAtIndex:(NSInteger)index;
- (void)pageView:(JLPageView *)pageView didChangeCurrentIndex:(NSInteger)index;
- (void)pageViewCellDidAppear:(JLPageViewCell *)pageViewCell;
- (void)pageViewCellDidDisappear:(JLPageViewCell *)pageViewCell;

// (UIScrollViewDelegate)
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;

@end



@interface JLPageView : UIView

@property (nonatomic, weak) IBOutlet id<JLPageViewDataSource> dataSource;
@property (nonatomic, weak) IBOutlet id<JLPageViewDelegate> delegate;
@property (nonatomic, assign, getter = isWrapEnabled) IBInspectable BOOL wrapEnabled;
@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) NSUInteger numberOfItems;

@property (nonatomic, assign) NSUInteger numberOfCachedViews;
@property (nonatomic, assign) NSUInteger defaultWrapMaxLimit;

- (void)reloadData;

- (void)moveToIndex:(NSInteger)index;
- (void)moveToIndex:(NSInteger)index animated:(BOOL)animated;
- (void)moveToNext;
- (void)moveToNextAnimated:(BOOL)animated;
- (void)moveToBefore;
- (void)moveToBeforeAnimated:(BOOL)animated;

@end
