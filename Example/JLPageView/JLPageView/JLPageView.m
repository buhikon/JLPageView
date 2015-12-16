//
//  JLPageView.m
//
//  Version 0.2.0
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#import "JLPageView.h"

@interface JLPageView () <UIScrollViewDelegate>
{
    BOOL _isInitialized;
    NSUInteger _wrapMaxLimit;
}
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *cellPool;
@property (nonatomic, strong) NSNumber *currentPageIndex;
@property (nonatomic, strong) NSNumber *currentScreenIndex;
@property (nonatomic, strong) NSNumber *lastestLoadedIndex;

@end

@implementation JLPageView

static NSUInteger numberOfCachedViews = 6;
static NSUInteger defaultWrapMaxLimit = 100;

- (void)initialize {
    for (NSInteger i = 0; i < numberOfCachedViews; i++) {
        JLPageViewCell *cell = [[JLPageViewCell alloc] initWithFrame:CGRectZero];
        
        [self.scrollView addSubview:cell];
        [self.cellPool addObject:cell];
    }
    
    _wrapMaxLimit = defaultWrapMaxLimit;
    
    if (self.numberOfItems > 0) {
        while (_wrapMaxLimit % self.numberOfItems != 0)
            _wrapMaxLimit++;
    }
    
    NSInteger wrapSize = self.wrapEnabled ? _wrapMaxLimit : 0;
    NSInteger screenIndex = 0 + wrapSize;
    self.currentScreenIndex = @(screenIndex);
    
    
    UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pageTapped:)];
    self.gestureRecognizers = @[gr];
}

- (void)layoutSubviews {
    if (!_isInitialized) {
        _isInitialized = YES;
        [self initialize];
        [self startLoadingCell];
    }
    
    NSInteger numberOfItems = self.numberOfItems;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * numberOfItems + [self wrapContentBufferWidth] * 2.0,
                                             self.scrollView.frame.size.height);
    self.scrollView.scrollEnabled = (numberOfItems <= 1) ? NO : YES;
    
    [self updateCellsFrame];
    [self moveToIndex:self.currentPageIndex.integerValue];
    
    
    [super layoutSubviews];
}

#pragma mark - accessor

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        scrollView.backgroundColor = [UIColor clearColor];
        scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrollView.pagingEnabled = YES;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.showsVerticalScrollIndicator = NO;
        scrollView.delegate = self;
        scrollView.scrollsToTop = NO;
        {
            // to avoid view controller automatically add top 20px inset to scrollview.
            UIView *blankView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            blankView.backgroundColor = [UIColor clearColor];
            blankView.userInteractionEnabled = NO;
            [self addSubview:blankView];
        }
        [self addSubview:scrollView];
        
        _scrollView = scrollView;
    }
    
    return _scrollView;
}

- (NSMutableArray *)cellPool {
    if (!_cellPool) {
        _cellPool = [[NSMutableArray alloc] init];
    }
    
    return _cellPool;
}

- (void)setCurrentScreenIndex:(NSNumber *)currentScreenIndex {
    if (!_currentScreenIndex || _currentScreenIndex.integerValue != currentScreenIndex.integerValue) {
        _currentScreenIndex = currentScreenIndex;
        
        if (_currentScreenIndex) {
            [self updateCellsFrame];
            
            NSUInteger numberOfItems = self.numberOfItems;
            
            if (numberOfItems > 0) {
                NSInteger pageIndex = currentScreenIndex.integerValue % numberOfItems;
                self.currentPageIndex = @(pageIndex);
            }
        }
    }
}

- (void)setCurrentPageIndex:(NSNumber *)currentPageIndex {
    if (!_currentPageIndex || _currentPageIndex.integerValue != currentPageIndex.integerValue) {
        _currentPageIndex = currentPageIndex;
        
        if (_currentPageIndex) {
            [self prepareViews];
            
            if ([(id)self.delegate respondsToSelector:@selector(pageView:didChangeCurrentIndex:)]) {
                [self.delegate pageView:self didChangeCurrentIndex:currentPageIndex.integerValue];
            }
        }
    }
}

- (NSInteger)index {
    return self.currentPageIndex.integerValue;
}

- (NSUInteger)numberOfItems {
    return [self.dataSource numberOfItemsInPageView:self];
}

#pragma mark - public methods

- (void)reloadData {
    if (!_isInitialized) return;
    
    for (JLPageViewCell *cell in self.cellPool) {
        cell.index = -1;
    }
    
    [self updateCellsFrame];
    [self prepareViews];
}

- (void)moveToIndex:(NSInteger)index {
    [self moveToIndex:index animated:NO];
}

- (void)moveToIndex:(NSInteger)index animated:(BOOL)animated {
    if (!_isInitialized) return;
    
    if ([self isValidPageIndex:index]) {
        NSInteger wrapSize = self.wrapEnabled ? _wrapMaxLimit : 0;
        NSInteger screenIndex = index + wrapSize;
        [self moveToScreenIndex:screenIndex animated:animated];
    }
}

- (void)moveToNext {
    [self moveToNextAnimated:NO];
}

- (void)moveToNextAnimated:(BOOL)animated {
    if (!_isInitialized) return;
    
    NSNumber *nextScreenIndex = [self nextScreenIndex:self.currentScreenIndex];
    
    if (nextScreenIndex) {
        [self moveToScreenIndex:nextScreenIndex.integerValue animated:animated];
    }
}

- (void)moveToBefore {
    [self moveToBeforeAnimated:NO];
}

- (void)moveToBeforeAnimated:(BOOL)animated {
    if (!_isInitialized) return;
    
    NSNumber *beforeScreenIndex = [self beforeScreenIndex:self.currentScreenIndex];
    
    if (beforeScreenIndex) {
        [self moveToScreenIndex:beforeScreenIndex.integerValue animated:animated];
    }
}

#pragma mark - private methods

- (void)moveToScreenIndex:(NSInteger)screenIndex animated:(BOOL)animated {
    if (!_isInitialized) return;
    
    CGFloat xPos = [self xPosForScreenIndex:screenIndex];
    [self.scrollView setContentOffset:CGPointMake(xPos, 0) animated:animated];
    self.currentScreenIndex = @(screenIndex);
    
    if (!animated) {
        [self startLoadingCell];
    }
    
    [self checkCellsVisibility];
}

- (JLPageViewCell *)cellForScreenIndex:(NSInteger)screenIndex {
    NSNumber *arrayIndex = [self arrayIndexForScreenIndex:screenIndex];
    
    if (arrayIndex) return self.cellPool[arrayIndex.integerValue];
    else return nil;
}

- (NSNumber *)arrayIndexForScreenIndex:(NSInteger)screenIndex {
    if (screenIndex >= 0) return @(screenIndex % numberOfCachedViews);
    else {
        return nil;
    }
}

- (void)prepareViews {
    // current
    NSNumber *currentPageIndex = self.currentPageIndex;
    NSNumber *currentScreenIndex = self.currentScreenIndex;
    {
        JLPageViewCell *cell = [self cellForScreenIndex:currentScreenIndex.integerValue];
        
        if (cell.index != currentPageIndex.integerValue) {
            cell.index = currentPageIndex.integerValue;
            [self.dataSource prepareCell:cell AtIndex:currentPageIndex.integerValue];
        }
    }
    
    // next
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    
    if (nextPageIndex) {
        NSNumber *nextScreenIndex = [self nextScreenIndex:currentScreenIndex];
        
        if (nextScreenIndex) {
            JLPageViewCell *cell = [self cellForScreenIndex:nextScreenIndex.integerValue];
            
            if (cell.index != nextPageIndex.integerValue) {
                cell.index = nextPageIndex.integerValue;
                [self.dataSource prepareCell:cell AtIndex:nextPageIndex.integerValue];
            }
        }
    }
    
    // before
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    
    if (beforePageIndex) {
        NSNumber *beforeScreenIndex = [self beforeScreenIndex:currentScreenIndex];
        
        if (beforeScreenIndex) {
            JLPageViewCell *cell = [self cellForScreenIndex:beforeScreenIndex.integerValue];
            
            if (cell.index != beforePageIndex.integerValue) {
                cell.index = beforePageIndex.integerValue;
                [self.dataSource prepareCell:cell AtIndex:beforePageIndex.integerValue];
            }
        }
    }
}

- (void)updateCellsFrame {
    NSUInteger numberOfItems = self.numberOfItems;
    
    if (numberOfItems == 0) return;
    
    NSInteger pageIndex = self.currentScreenIndex.integerValue % numberOfItems;
    
    // current
    NSNumber *currentPageIndex = @(pageIndex);
    NSNumber *currentScreenIndex = self.currentScreenIndex;
    {
        JLPageViewCell *cell = [self cellForScreenIndex:currentScreenIndex.integerValue];
        cell.frame = [self frameForScreenIndex:currentScreenIndex.integerValue];
        [cell.superview bringSubviewToFront:cell];
    }
    
    // next
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    
    if (nextPageIndex) {
        NSNumber *nextScreenIndex = [self nextScreenIndex:currentScreenIndex];
        
        if (nextScreenIndex) {
            JLPageViewCell *cell = [self cellForScreenIndex:nextScreenIndex.integerValue];
            cell.frame = [self frameForScreenIndex:nextScreenIndex.integerValue];
            [cell.superview bringSubviewToFront:cell];
        }
    }
    
    // before
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    
    if (beforePageIndex) {
        NSNumber *beforeScreenIndex = [self beforeScreenIndex:currentScreenIndex];
        
        if (beforeScreenIndex) {
            JLPageViewCell *cell = [self cellForScreenIndex:beforeScreenIndex.integerValue];
            cell.frame = [self frameForScreenIndex:beforeScreenIndex.integerValue];
            [cell.superview bringSubviewToFront:cell];
        }
    }
}

- (void)shiftToCurrentIndex {
    NSInteger wrapSize = self.wrapEnabled ? _wrapMaxLimit : 0;
    
    NSNumber *currentPageIndex = self.currentPageIndex;
    NSNumber *currentScreenIndex = self.currentScreenIndex;
    NSNumber *currentExpectedScreenIndex = @(currentPageIndex.integerValue + wrapSize);
    
    if (currentScreenIndex) {
        JLPageViewCell *cell = [self cellForScreenIndex:currentScreenIndex.integerValue];
        
        if (cell) {
            NSNumber *arrayIndex = [self arrayIndexForScreenIndex:currentScreenIndex.integerValue];
            NSNumber *expectedArrayIndex = [self arrayIndexForScreenIndex:currentExpectedScreenIndex.integerValue];
            
            if (arrayIndex && expectedArrayIndex) {
                if (arrayIndex.integerValue != expectedArrayIndex.integerValue) {
                    [self.cellPool exchangeObjectAtIndex:arrayIndex.integerValue withObjectAtIndex:expectedArrayIndex.integerValue];
                }
            }
        }
    }
    
    // next
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    
    if (nextPageIndex) {
        NSNumber *nextScreenIndex = [self nextScreenIndex:currentScreenIndex];
        NSNumber *nextExpectedScreenIndex = @(nextPageIndex.integerValue + wrapSize);
        
        if (nextScreenIndex) {
            JLPageViewCell *cell = [self cellForScreenIndex:nextScreenIndex.integerValue];
            
            if (cell) {
                NSNumber *arrayIndex = [self arrayIndexForScreenIndex:nextScreenIndex.integerValue];
                NSNumber *expectedArrayIndex = [self arrayIndexForScreenIndex:nextExpectedScreenIndex.integerValue];
                
                if (arrayIndex && expectedArrayIndex) {
                    if (arrayIndex.integerValue != expectedArrayIndex.integerValue) {
                        [self.cellPool exchangeObjectAtIndex:arrayIndex.integerValue withObjectAtIndex:expectedArrayIndex.integerValue];
                    }
                }
            }
        }
    }
    
    // before
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    
    if (beforePageIndex) {
        NSNumber *beforeScreenIndex = [self beforeScreenIndex:currentScreenIndex];
        NSNumber *beforeExpectedScreenIndex = @(beforePageIndex.integerValue + wrapSize);
        
        if (beforeScreenIndex) {
            JLPageViewCell *cell = [self cellForScreenIndex:beforeScreenIndex.integerValue];
            
            if (cell) {
                NSNumber *arrayIndex = [self arrayIndexForScreenIndex:beforeScreenIndex.integerValue];
                NSNumber *expectedArrayIndex = [self arrayIndexForScreenIndex:beforeExpectedScreenIndex.integerValue];
                
                if (arrayIndex && expectedArrayIndex) {
                    if (arrayIndex.integerValue != expectedArrayIndex.integerValue) {
                        [self.cellPool exchangeObjectAtIndex:arrayIndex.integerValue withObjectAtIndex:expectedArrayIndex.integerValue];
                    }
                }
            }
        }
    }
    
    [self moveToIndex:self.currentPageIndex.integerValue];
}

- (BOOL)isValidPageIndex:(NSInteger)pageIndex {
    NSUInteger numberOfItems = self.numberOfItems;
    
    if (0 <= pageIndex && pageIndex < numberOfItems) {
        return YES;
    } else {
        return NO;
    }
}

- (NSNumber *)beforePageIndex:(NSNumber *)currentPageIndex {
    NSInteger beforePageIndex = currentPageIndex.integerValue - 1;
    
    if (beforePageIndex < 0) {
        if (self.wrapEnabled) {
            NSInteger numberOfItems = self.numberOfItems;
            return @(numberOfItems - 1);
        } else {
            return nil;
        }
    }
    
    return @(beforePageIndex);
}

- (NSNumber *)nextPageIndex:(NSNumber *)currentPageIndex {
    NSInteger nextPageIndex = currentPageIndex.integerValue + 1;
    
    NSInteger numberOfItems = self.numberOfItems;
    
    if (nextPageIndex >= numberOfItems) {
        if (self.wrapEnabled) {
            return @(0);
        } else {
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

- (CGRect)frameForScreenIndex:(NSInteger)screenIndex {
    CGFloat xPos = [self xPosForScreenIndex:screenIndex];
    
    return CGRectMake(xPos,
                      0,
                      self.scrollView.frame.size.width,
                      self.scrollView.frame.size.height);
}

- (void)startLoadingCell {
    if (!self.lastestLoadedIndex || self.lastestLoadedIndex.integerValue != self.currentPageIndex.integerValue) {
        self.lastestLoadedIndex = self.currentPageIndex;
        
        JLPageViewCell *cell = [self cellForScreenIndex:self.currentScreenIndex.integerValue];
        [self.dataSource startLoadingCell:cell AtIndex:self.currentPageIndex.integerValue];
    }
}

- (void)checkCellsVisibility {
    NSUInteger numberOfItems = self.numberOfItems;
    
    if (numberOfItems == 0) return;
    
    NSInteger pageIndex = self.currentScreenIndex.integerValue % numberOfItems;
    
    // current
    NSNumber *currentPageIndex = @(pageIndex);
    NSNumber *currentScreenIndex = self.currentScreenIndex;
    JLPageViewCell *currentCell = [self cellForScreenIndex:currentScreenIndex.integerValue];
    // next
    JLPageViewCell *nextCell = nil;
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    
    if (nextPageIndex) {
        NSNumber *nextScreenIndex = [self nextScreenIndex:currentScreenIndex];
        
        if (nextScreenIndex) {
            nextCell = [self cellForScreenIndex:nextScreenIndex.integerValue];
        }
    }
    
    // before
    JLPageViewCell *beforeCell = nil;
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    
    if (beforePageIndex) {
        NSNumber *beforeScreenIndex = [self beforeScreenIndex:currentScreenIndex];
        
        if (beforeScreenIndex) {
            beforeCell = [self cellForScreenIndex:beforeScreenIndex.integerValue];
        }
    }
    
    for (JLPageViewCell *cell in self.cellPool) {
        if (cell == currentCell || cell == nextCell || cell == beforeCell) {
            continue;
        }
        
        if (cell.visible) {
            cell.visible = NO;
            
            if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidDisappear:)]) {
                [self.delegate pageViewCellDidDisappear:cell];
            }
        }
    }
    
    if (currentCell) {
        BOOL visible = NO;
        
        if (self.scrollView.contentOffset.x - self.scrollView.frame.size.width < currentCell.frame.origin.x &&
            currentCell.frame.origin.x < self.scrollView.contentOffset.x + self.scrollView.frame.size.width) {
            visible = YES;
        }
        
        if (currentCell.visible != visible) {
            currentCell.visible = visible;
            
            if (visible) {
                if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidAppear:)]) {
                    [self.delegate pageViewCellDidAppear:currentCell];
                }
            } else {
                if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidDisappear:)]) {
                    [self.delegate pageViewCellDidDisappear:currentCell];
                }
            }
        }
    }
    
    if (nextCell) {
        BOOL visible = NO;
        
        if (self.scrollView.contentOffset.x - self.scrollView.frame.size.width < nextCell.frame.origin.x &&
            nextCell.frame.origin.x < self.scrollView.contentOffset.x + self.scrollView.frame.size.width) {
            visible = YES;
        }
        
        if (nextCell.visible != visible) {
            nextCell.visible = visible;
            
            if (visible) {
                if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidAppear:)]) {
                    [self.delegate pageViewCellDidAppear:nextCell];
                }
            } else {
                if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidDisappear:)]) {
                    [self.delegate pageViewCellDidDisappear:nextCell];
                }
            }
        }
    }
    
    if (beforeCell) {
        BOOL visible = NO;
        
        if (self.scrollView.contentOffset.x - self.scrollView.frame.size.width < beforeCell.frame.origin.x &&
            beforeCell.frame.origin.x < self.scrollView.contentOffset.x + self.scrollView.frame.size.width) {
            visible = YES;
        }
        
        if (beforeCell.visible != visible) {
            beforeCell.visible = visible;
            
            if (visible) {
                if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidAppear:)]) {
                    [self.delegate pageViewCellDidAppear:beforeCell];
                }
            } else {
                if ([(id)self.delegate respondsToSelector:@selector(pageViewCellDidDisappear:)]) {
                    [self.delegate pageViewCellDidDisappear:beforeCell];
                }
            }
        }
    }
}

#pragma mark - event

- (void)pageTapped:(UITapGestureRecognizer *)gr {
    if ([(id)self.delegate respondsToSelector:@selector(pageView:didSelectCellAtIndex:)]) {
        [self.delegate pageView:self didSelectCellAtIndex:self.currentPageIndex.integerValue];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.delegate scrollViewDidScroll:scrollView];
    }
    
    if (scrollView.dragging) {
        NSInteger screenIndex = (scrollView.contentOffset.x + scrollView.frame.size.width * 0.5) / scrollView.frame.size.width;
        self.currentScreenIndex = @(screenIndex);
    }
    
    [self checkCellsVisibility];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.delegate scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [self.delegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.delegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {
        [self.delegate scrollViewWillBeginDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [self.delegate scrollViewDidEndDecelerating:scrollView];
    }
    
    [self shiftToCurrentIndex];
    [self startLoadingCell];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.delegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

@end
