//
//  JLPageView.m
//
//  Version 0.3.0
//
//  Created by Joey L. on 10/5/15.
//  Copyright 2015 Joey L. All rights reserved.
//
//  https://github.com/buhikon/JLPageView
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#define JLPageViewLog 0

#import "JLPageView.h"

@interface JLPageView () <UIScrollViewDelegate>
{
    BOOL _isInitialized;
    NSUInteger _wrapMaxLimit;
    BOOL _currentPageDidChanged;
}
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *currentCells;
@property (nonatomic, strong) NSMutableArray *cellPool;
@property (nonatomic, strong) NSNumber *currentPageIndex;
@property (nonatomic, strong) NSNumber *currentScreenIndex;
@property (nonatomic, strong) NSNumber *lastestLoadedIndex;

@end

@implementation JLPageView

static NSUInteger defaultWrapMaxLimit = 100;
static NSUInteger defaultCacheRange = 2;

- (void)initialize {
    
    if(self.defaultWrapMaxLimit == 0) {
        self.defaultWrapMaxLimit = defaultWrapMaxLimit;
    }
    if(self.cacheRange == 0) {
        self.cacheRange = defaultCacheRange;
    }
    
    for (NSInteger i = 0; i < self.cacheRange * 2 + 1; i++) {
        JLPageViewCell *cell = [self createPageViewCell];
        [self queueCellToPool:cell];
    }
    
    _wrapMaxLimit = self.defaultWrapMaxLimit;
    
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
- (NSMutableArray *)currentCells
{
    if(!_currentCells) {
        _currentCells = [[NSMutableArray alloc] init];
    }
    return _currentCells;
}
- (NSMutableArray *)cellPool
{
    if(!_cellPool) {
        _cellPool = [[NSMutableArray alloc] init];
    }
    return _cellPool;
}

- (void)setCurrentScreenIndex:(NSNumber *)currentScreenIndex {
    
#if JLPageViewLog
    NSLog(@"[set currentScreenIndex] %@", currentScreenIndex);
#endif
    
    if (!_currentScreenIndex || _currentScreenIndex.integerValue != currentScreenIndex.integerValue) {
        _currentScreenIndex = currentScreenIndex;
        
        if (_currentScreenIndex) {
            //[self updateCellsFrame];
            
            NSNumber *pageIndex = [self pageIndexForScreenIndex:currentScreenIndex.integerValue];
            if(pageIndex) {
                self.currentPageIndex = pageIndex;
            }
        }
    }
}

- (void)setCurrentPageIndex:(NSNumber *)currentPageIndex {
    
#if JLPageViewLog
    NSLog(@"[set currentPageIndex] %@", currentPageIndex);
#endif
    
    if(!_currentPageIndex || _currentPageIndex.integerValue != currentPageIndex.integerValue) {
        _currentPageIndex = currentPageIndex;
        _currentPageDidChanged = YES;
        
        if (_currentPageIndex) {
            [self prepareViews];
            [self updateCellsFrame];
            [self dequeueCellsFromCurrentArrayIfNecessary];
            
            if ([(id)self.delegate respondsToSelector:@selector(pageView:didChangeCurrentIndex:)]) {
                [self.delegate pageView:self didChangeCurrentIndex:currentPageIndex.integerValue];
            }
        }
    }
    else {
        [self updateCellsFrame];
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
    
    for (JLPageViewCell *cell in self.currentCells) {
        cell.index = -1;
    }
    
    [self updateCellsFrame];
    [self prepareViews];
}

#pragma mark (move)

- (void)moveToIndex:(NSInteger)index {
    [self moveToIndex:index animated:NO];
}

- (void)moveToIndex:(NSInteger)index animated:(BOOL)animated {
    if (!_isInitialized) return;
    
    NSNumber *screenIndex = [self screenIndexForPageIndex:index];
    if(screenIndex) {
        [self moveToScreenIndex:screenIndex.integerValue animated:animated];
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

- (void)prepareViews {
    
    NSNumber *currentPageIndex = self.currentPageIndex;
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    
    if(currentPageIndex) {
        NSInteger pageIndex = currentPageIndex.integerValue;
        JLPageViewCell *cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        if(!cell) {
            cell = [self dequeueCellFromPoolForPageIndex:pageIndex];
            cell.index = pageIndex;
            [self.dataSource prepareCell:cell AtIndex:pageIndex];
            [self queueCellToCurrentArray:cell];
        }
    }
    if(nextPageIndex) {
        NSInteger pageIndex = nextPageIndex.integerValue;
        JLPageViewCell *cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        if(!cell) {
            cell = [self dequeueCellFromPoolForPageIndex:pageIndex];
            cell.index = pageIndex;
            [self.dataSource prepareCell:cell AtIndex:pageIndex];
            [self queueCellToCurrentArray:cell];
        }
    }
    if(beforePageIndex) {
        NSInteger pageIndex = beforePageIndex.integerValue;
        JLPageViewCell *cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        if(!cell) {
            cell = [self dequeueCellFromPoolForPageIndex:pageIndex];
            cell.index = pageIndex;
            [self.dataSource prepareCell:cell AtIndex:pageIndex];
            [self queueCellToCurrentArray:cell];
        }
    }
}

- (void)updateCellsFrame {
    NSUInteger numberOfItems = self.numberOfItems;
    
    if (numberOfItems == 0) return;
    
#if JLPageViewLog
    NSLog(@"[updateCellsFrame] ---- contentOffset : %@ ----", NSStringFromCGPoint(self.scrollView.contentOffset));
#endif
    NSNumber *currentPageIndex = [self pageIndexForScreenIndex:self.currentScreenIndex.integerValue];
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    NSNumber *currentScreenIndex = self.currentScreenIndex;
    NSNumber *nextScreenIndex = [self nextScreenIndex:currentScreenIndex];
    NSNumber *beforeScreenIndex = [self beforeScreenIndex:currentScreenIndex];
    
    JLPageViewCell *cell = nil;
    
    if(currentPageIndex && currentScreenIndex) {
        NSInteger pageIndex = currentPageIndex.integerValue;
        NSInteger screenIndex = currentScreenIndex.integerValue;
        cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        cell.frame = [self frameForScreenIndex:screenIndex];
        [cell.superview bringSubviewToFront:cell];
#if JLPageViewLog
        NSLog(@"   <%lx>current(%@,%@) : %@", (long)cell, currentPageIndex, currentScreenIndex, NSStringFromCGRect(cell.frame));
#endif
    }
    if(nextPageIndex && nextScreenIndex) {
        NSInteger pageIndex = nextPageIndex.integerValue;
        NSInteger screenIndex = nextScreenIndex.integerValue;
        cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        if(!cell) {
            NSLog(@"null");
        }
        cell.frame = [self frameForScreenIndex:screenIndex];
        [cell.superview bringSubviewToFront:cell];
#if JLPageViewLog
            NSLog(@"   <%lx>next(%@,%@) : %@", (long)cell, nextPageIndex, nextScreenIndex, NSStringFromCGRect(cell.frame));
#endif
    }
    if(beforePageIndex && beforeScreenIndex) {
        NSInteger pageIndex = beforePageIndex.integerValue;
        NSInteger screenIndex = beforeScreenIndex.integerValue;
        cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        cell.frame = [self frameForScreenIndex:screenIndex];
        [cell.superview bringSubviewToFront:cell];
#if JLPageViewLog
            NSLog(@"   <%lx>before(%@,%@) : %@", (long)cell, beforePageIndex, beforeScreenIndex, NSStringFromCGRect(cell.frame));
#endif
    }
}

- (void)startLoadingCell {
    if(_currentPageDidChanged) {
        _currentPageDidChanged = NO;
    
        NSInteger pageIndex = self.currentPageIndex.integerValue;
        JLPageViewCell *cell = [self cellInCurrentArrayForPageIndex:pageIndex];
        [self.dataSource startLoadingCell:cell AtIndex:pageIndex];
    }
}

- (void)checkCellsVisibility {
    NSUInteger numberOfItems = self.numberOfItems;
    
    if (numberOfItems == 0) return;
    
//#if JLPageViewLog
//    NSLog(@"[check visibility] ---- contentOffset : %@ ----", NSStringFromCGPoint(self.scrollView.contentOffset));
//#endif
    
    NSNumber *currentPageIndex = [self pageIndexForScreenIndex:self.currentScreenIndex.integerValue];
    NSNumber *nextPageIndex = [self nextPageIndex:currentPageIndex];
    NSNumber *beforePageIndex = [self beforePageIndex:currentPageIndex];
    
    JLPageViewCell *currentCell = nil;
    JLPageViewCell *nextCell = nil;
    JLPageViewCell *beforeCell = nil;
    
    if(currentPageIndex) {
        NSInteger pageIndex = currentPageIndex.integerValue;
        currentCell = [self cellInCurrentArrayForPageIndex:pageIndex];
    }
    if(nextPageIndex) {
        NSInteger pageIndex = nextPageIndex.integerValue;
        nextCell = [self cellInCurrentArrayForPageIndex:pageIndex];
    }
    if(beforePageIndex) {
        NSInteger pageIndex = beforePageIndex.integerValue;
        beforeCell = [self cellInCurrentArrayForPageIndex:pageIndex];
    }
    
    
//#if JLPageViewLog
//    NSLog(@"   <%lx>current(%@) : %@", (long)currentCell, currentPageIndex, NSStringFromCGRect(currentCell.frame));
//    NSLog(@"   <%lx>next(%@) : %@", (long)nextCell, nextPageIndex, NSStringFromCGRect(nextCell.frame));
//    NSLog(@"   <%lx>before(%@) : %@", (long)beforeCell, beforePageIndex, NSStringFromCGRect(beforeCell.frame));
//#endif
    
    for (JLPageViewCell *cell in self.currentCells) {
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

- (BOOL)isValidPageIndex:(NSInteger)pageIndex {
    NSUInteger numberOfItems = self.numberOfItems;
    
    if (0 <= pageIndex && pageIndex < numberOfItems) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark -

- (NSNumber *)pageIndexForScreenIndex:(NSInteger)screenIndex {
    if(self.numberOfItems > 0) {
        NSInteger wrapSize = self.wrapEnabled ? _wrapMaxLimit : 0;
        NSInteger pageIndex = (screenIndex - wrapSize + self.numberOfItems) % self.numberOfItems;
        return @(pageIndex);
    }
    return nil;
}
- (NSNumber *)screenIndexForPageIndex:(NSInteger)pageIndex {
    if ([self isValidPageIndex:pageIndex]) {
        NSInteger wrapSize = self.wrapEnabled ? _wrapMaxLimit : 0;
        NSInteger screenIndex = pageIndex + wrapSize;
        return @(screenIndex);
    }
    return nil;
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
    if(currentScreenIndex) {
        return @(currentScreenIndex.integerValue - 1);
    }
    return nil;
}

- (NSNumber *)nextScreenIndex:(NSNumber *)currentScreenIndex {
    if(currentScreenIndex) {
        return @(currentScreenIndex.integerValue + 1);
    }
    return nil;
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

- (JLPageViewCell *)createPageViewCell {
    JLPageViewCell *cell = [[JLPageViewCell alloc] initWithFrame:CGRectZero];
    return cell;
}

#pragma mark (queue / dequeue)

- (JLPageViewCell *)dequeueCellFromPoolForPageIndex:(NSInteger)pageIndex {
    
#if JLPageViewLog
    NSLog(@"[dequeue - pool] pageIndex : %ld", (long)pageIndex);
#endif
    
    JLPageViewCell *result = nil;
    
    // looking for a cell which has same index
    for (NSInteger i=0; i<self.cellPool.count; i++) {
        JLPageViewCell *cell = self.cellPool[i];
        if(cell.index == pageIndex) {
            result = cell;
            [self.cellPool removeObjectAtIndex:i];
#if JLPageViewLog
            NSLog(@"   found cell at pool for pageIndex : %ld", (long)pageIndex);
#endif
            break;
        }
    }
    
    // looking for any cells
    if(!result) {
        if(self.cellPool.count == 0) {
            // create and add a cell into the pool if empty.
            JLPageViewCell *cell = [self createPageViewCell];
            [self.cellPool addObject:cell];
#if JLPageViewLog
            NSLog(@"   create a new cell and add it into pool, because it is empty.");
#endif
        }
        result = self.cellPool[0];
        [self.cellPool removeObjectAtIndex:0];
#if JLPageViewLog
        NSLog(@"   first cell");
#endif
    }
    
    return result;
}
- (void)queueCellToCurrentArray:(JLPageViewCell *)cell {
#if JLPageViewLog
    NSLog(@"[queue - current array] pageIndex : %ld", (long)cell.index);
#endif
    [self.scrollView addSubview:cell];
    [self.currentCells addObject:cell];
}
- (JLPageViewCell *)dequeueCellFromCurrentArrayForPageIndex:(NSInteger)pageIndex {
#if JLPageViewLog
    NSLog(@"[dequeue - current array] pageIndex : %ld", (long)pageIndex);
#endif
    JLPageViewCell *cell = [self cellInCurrentArrayForPageIndex:pageIndex];
    if(cell) {
        [self.currentCells removeObject:cell];
        [cell removeFromSuperview];
    }
    return cell;
}
- (void)queueCellToPool:(JLPageViewCell *)cell {
#if JLPageViewLog
    NSLog(@"[queue - pool] pageIndex : %ld", (long)cell.index);
#endif
    [self.cellPool addObject:cell];
}
- (JLPageViewCell *)cellInCurrentArrayForPageIndex:(NSInteger)pageIndex {
#if JLPageViewLog
    NSMutableString *s = [NSMutableString string];
    for (JLPageViewCell *cell in self.currentCells) {
        [s appendFormat:@"%ld ", (long)cell.index];
    }
    NSLog(@"looking for cell (%ld) in [%@]", (long)pageIndex, s);
#endif
    for (JLPageViewCell *cell in self.currentCells) {
        if(cell.index == pageIndex) {
            return cell;
        }
    }
    return nil;
}
/**
 *  check cells in the current array, and if cells are found which is out of cache range, then dequeue from the current array.
 */
- (void)dequeueCellsFromCurrentArrayIfNecessary {
    NSInteger pageIndex = self.currentPageIndex.integerValue;
    JLPageViewCell *currentCell = [self cellInCurrentArrayForPageIndex:pageIndex];
    
    for(NSInteger i=self.currentCells.count-1; i>=0; i--) {
        JLPageViewCell *cell = self.currentCells[i];
        if(ABS(cell.frame.origin.x - currentCell.frame.origin.x) > self.cacheRange * self.scrollView.frame.size.width) {
            [self dequeueCellFromCurrentArrayForPageIndex:cell.index];
            [self queueCellToPool:cell];
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
    
    [self moveToIndex:self.currentPageIndex.integerValue];
    [self startLoadingCell];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if ([(id)self.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.delegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

@end
