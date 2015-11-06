//
//  JLPageView.m
//
//  Version 0.1.0
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#import "JLPageView.h"

@interface JLPageView () <UIScrollViewDelegate>
{
    BOOL _isInitialized;
}
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *cellPool;
@property (nonatomic, strong) NSNumber *currentPageIndex;
@property (nonatomic, strong) NSNumber *currentScreenIndex;

@end

@implementation JLPageView

static NSUInteger numberOfCachedViews = 4;
static NSUInteger wrapMaxLimit = 100;

- (void)initialize {

    for(NSInteger i=0; i<numberOfCachedViews; i++) {
        JLPageCell *cell = [[JLPageCell alloc] initWithFrame:CGRectZero];
        [self.scrollView addSubview:cell];
        [self.cellPool addObject:cell];
    }
    
    NSInteger wrapSize = self.wrapEnabled ? wrapMaxLimit : 0;
    NSInteger screenIndex = 0 + wrapSize;
    self.currentScreenIndex = @(screenIndex);
    
    
    UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pageTapped:)];
    self.gestureRecognizers = @[gr];
    
}

- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    if(!_isInitialized) {
        _isInitialized = YES;
        [self initialize];
        [self startLoadingCell];
    }
    
    NSInteger numberOfItems = [self.dataSource numberOfItemsInPageView:self];
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * numberOfItems + [self wrapContentBufferWidth] * 2.0,
                                             self.scrollView.frame.size.height);
    [self updateCellsFrame];
    [self moveToIndex:self.currentPageIndex.integerValue];

    
}

#pragma mark - accessor

- (UIScrollView *)scrollView {
    
    if(!_scrollView) {
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        scrollView.backgroundColor = [UIColor clearColor];
        scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrollView.pagingEnabled = YES;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.showsVerticalScrollIndicator = NO;
        scrollView.delegate = self;
        scrollView.scrollsToTop = NO;
        [self addSubview:scrollView];
        
        _scrollView = scrollView;
    }
    
    return _scrollView;
}

- (NSMutableArray *)cellPool
{
    if(!_cellPool) {
        _cellPool = [[NSMutableArray alloc] init];
    }
    return _cellPool;
}

- (void)setCurrentScreenIndex:(NSNumber *)currentScreenIndex {
    if(!_currentScreenIndex || _currentScreenIndex.integerValue != currentScreenIndex.integerValue) {
        _currentScreenIndex = currentScreenIndex;
        
        [self updateCellsFrame];
        
        NSUInteger numberOfItems = [self.dataSource numberOfItemsInPageView:self];
        NSInteger pageIndex = currentScreenIndex.integerValue % numberOfItems;
        self.currentPageIndex = @(pageIndex);
    }
    
}
- (void)setCurrentPageIndex:(NSNumber *)currentPageIndex {
    
    if(!_currentPageIndex || _currentPageIndex.integerValue != currentPageIndex.integerValue) {
        _currentPageIndex = currentPageIndex;
        
        [self prepareViews];
        
        [self.delegate pageView:self didChangeCurrentIndex:currentPageIndex.integerValue];
    }
}

#pragma mark - public methods

- (void)reloadPageView {
    for (JLPageCell *cell in self.cellPool) {
        cell.index = -1;
    }
    [self updateCellsFrame];
    [self prepareViews];
}
- (void)moveToIndex:(NSInteger)index {
    if([self isValidPageIndex:index]) {
        NSInteger wrapSize = self.wrapEnabled ? wrapMaxLimit : 0;
        NSInteger screenIndex = index + wrapSize;
        CGFloat xPos = [self xPosForScreenIndex:screenIndex];
        [self.scrollView setContentOffset:CGPointMake(xPos, 0) animated:NO];
        self.currentScreenIndex = @(screenIndex);
    }
}
- (void)moveToIndex:(NSInteger)index animated:(BOOL)animated {
    //  not supported
}

#pragma mark - private methods

- (JLPageCell *)cellForPageIndex:(NSInteger)pageIndex {
    NSNumber *arrayIndex = [self arrayIndexForPageIndex:pageIndex];
    if(arrayIndex)
        return self.cellPool[arrayIndex.integerValue];
    else
        return nil;
}
- (NSNumber *)arrayIndexForPageIndex:(NSInteger)pageIndex {
    if(pageIndex >= 0)
        return @(pageIndex % numberOfCachedViews);
    else {
        return nil;
    }
}
- (void)prepareViews {
    
    // current
    NSNumber *currentPageIndex = self.currentPageIndex;
    {
        JLPageCell *cell = [self cellForPageIndex:currentPageIndex.integerValue];
        if(cell.index != currentPageIndex.integerValue) {
            cell.index = currentPageIndex.integerValue;
            [self.dataSource prepareCell:cell AtIndex:currentPageIndex.integerValue];
        }
    }
    
    // next
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    if(nextPageIndex) {
        JLPageCell *cell = [self cellForPageIndex:nextPageIndex.integerValue];
        if(cell.index != nextPageIndex.integerValue) {
            cell.index = nextPageIndex.integerValue;
            [self.dataSource prepareCell:cell AtIndex:nextPageIndex.integerValue];
        }
    }
    
    // before
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    if(beforePageIndex) {
        JLPageCell *cell = [self cellForPageIndex:beforePageIndex.integerValue];
        if(cell.index != beforePageIndex.integerValue) {
            cell.index = beforePageIndex.integerValue;
            [self.dataSource prepareCell:cell AtIndex:beforePageIndex.integerValue];
        }
    }
}

- (void)updateCellsFrame {

    NSUInteger numberOfItems = [self.dataSource numberOfItemsInPageView:self];
    NSInteger pageIndex = self.currentScreenIndex.integerValue % numberOfItems;
    
    // current
    NSNumber *currentPageIndex = @(pageIndex);
    NSNumber *currentScreenIndex = self.currentScreenIndex;
    {
        
        JLPageCell *cell = [self cellForPageIndex:currentPageIndex.integerValue];
        cell.frame = [self frameForScreenIndex:currentScreenIndex.integerValue];
        [cell.superview bringSubviewToFront:cell];
    }
    
    // next
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    if(nextPageIndex) {
        NSNumber *nextScreenIndex = [self nextScreenIndex:currentScreenIndex];
        
        JLPageCell *cell = [self cellForPageIndex:nextPageIndex.integerValue];
        cell.frame = [self frameForScreenIndex:nextScreenIndex.integerValue];
        [cell.superview bringSubviewToFront:cell];
    }
    
    // before
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    if(beforePageIndex) {
        NSNumber *beforeScreenIndex = [self beforeScreenIndex:currentScreenIndex];
        
        JLPageCell *cell = [self cellForPageIndex:beforePageIndex.integerValue];
        cell.frame = [self frameForScreenIndex:beforeScreenIndex.integerValue];
        [cell.superview bringSubviewToFront:cell];
    }
    
}

- (BOOL)isValidPageIndex:(NSInteger)pageIndex {
    NSUInteger numberOfItems = [self.dataSource numberOfItemsInPageView:self];
    if(0 <= pageIndex && pageIndex < numberOfItems) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSNumber *)beforePageIndex:(NSNumber *)currentPageIndex {
    NSInteger beforePageIndex = currentPageIndex.integerValue - 1;
    if(beforePageIndex < 0) {
        if(self.wrapEnabled) {
            NSInteger numberOfItems = [self.dataSource numberOfItemsInPageView:self];
            return @(numberOfItems-1);
        }
        else {
            return nil;
        }
    }
    return @(beforePageIndex);
}
- (NSNumber *)nextPageIndex:(NSNumber *)currentPageIndex {
    NSInteger nextPageIndex = currentPageIndex.integerValue + 1;
    
    NSInteger numberOfItems = [self.dataSource numberOfItemsInPageView:self];
    if(nextPageIndex >= numberOfItems) {
        if(self.wrapEnabled) {
            return @(0);
        }
        else {
            return nil;
        }
    }
    return @(nextPageIndex);
}
- (NSNumber *)beforeScreenIndex:(NSNumber *)currentScreenIndex {
    return @(currentScreenIndex.integerValue - 1);
}
- (NSNumber *)nextScreenIndex:(NSNumber *)currentScreenIndex {
    return @(currentScreenIndex.integerValue + 1);
}
- (CGFloat)wrapContentBufferWidth {
    return self.wrapEnabled ? self.scrollView.frame.size.width * 1000 : 0;
}
- (CGFloat)xPosForScreenIndex:(NSInteger)screenIndex {
    return self.scrollView.frame.size.width * screenIndex;
}

- (CGRect)frameForScreenIndex:(NSInteger)screenIndex
{
    CGFloat xPos = [self xPosForScreenIndex:screenIndex];
    return CGRectMake(xPos,
                      0,
                      self.scrollView.frame.size.width,
                      self.scrollView.frame.size.height);
}

- (void)startLoadingCell {
    JLPageCell *cell = [self cellForPageIndex:self.currentPageIndex.integerValue];
    [self.dataSource startLoadingCell:cell AtIndex:self.currentPageIndex.integerValue];
}

#pragma mark - event

- (void)pageTapped:(UITapGestureRecognizer *)gr {
    [self.delegate pageView:self didSelectCellAtIndex:self.currentPageIndex.integerValue];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(scrollView.dragging) {
        NSInteger screenIndex = (scrollView.contentOffset.x + scrollView.frame.size.width * 0.5) / scrollView.frame.size.width;
        self.currentScreenIndex = @(screenIndex);
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self moveToIndex:self.currentPageIndex.integerValue];
    [self startLoadingCell];
}


@end
