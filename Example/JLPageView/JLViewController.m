//
//  JLViewController.m
//  JLPageView
//
//  Created by Joey L. on 11/06/2015.
//  Copyright (c) 2015 Joey L.. All rights reserved.
//

#import "JLViewController.h"
#import <JLPageView/JLPageView.h>

@interface JLViewController ()
@property (weak, nonatomic) IBOutlet UILabel *label;
@end

@implementation JLViewController

#define JLViewControllerLog 0

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - JLPageViewDelegate

- (NSUInteger)numberOfItemsInPageView:(JLPageView *)pageView {
    return 5;
}

- (void)prepareCell:(JLPageViewCell *)reusingCell AtIndex:(NSInteger)index {
#if JLViewControllerLog
    NSLog(@"[prepare] %ld", (long)index);
#endif
    NSInteger tag = 1000;
    UILabel *label = [reusingCell viewWithTag:tag];
    
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, reusingCell.frame.size.width, reusingCell.frame.size.height)];
        label.textAlignment = NSTextAlignmentCenter;
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        label.tag = tag;
        [reusingCell addSubview:label];
    }
    
    label.text = [NSString stringWithFormat:@"index : %ld", (long)index];
    
    reusingCell.backgroundColor = [UIColor colorWithRed:1.000 green:1.000 blue:0.707 alpha:1.000];
    
//    NSLog(@"[prepare]<%ld> %ld", (long)reusingCell, (long)index);
}

- (void)startLoadingCell:(JLPageViewCell *)reusingCell AtIndex:(NSInteger)index {
#if JLViewControllerLog
    NSLog(@"[load] %ld", (long)index);
#endif
    reusingCell.backgroundColor = [UIColor yellowColor];
}

#pragma mark - JLPageViewDataSource

- (void)pageView:(JLPageView *)pageView didSelectCellAtIndex:(NSInteger)index {
#if JLViewControllerLog
    NSLog(@"[select] %ld", (long)index);
#endif
}

- (void)pageView:(JLPageView *)pageView didChangeCurrentIndex:(NSInteger)index {
    self.label.text = [NSString stringWithFormat:@"%ld page", (long)index];
}

- (void)pageViewCellDidAppear:(JLPageViewCell *)pageViewCell {
#if JLViewControllerLog
    NSLog(@"[appear] %ld", (long)pageViewCell.index);
#endif
}

- (void)pageViewCellDidDisappear:(JLPageViewCell *)pageViewCell {
#if JLViewControllerLog
    NSLog(@"[disappear] %ld", (long)pageViewCell.index);
#endif
}

@end
