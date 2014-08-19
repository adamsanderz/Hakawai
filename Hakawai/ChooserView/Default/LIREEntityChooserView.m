//
//  LIREEntityChooserView.m
//  LIEditorLibrary
//
//  Created by Ethan Goldblum on 11/10/13.
//  Copyright (c) 2013 LinkedIn. All rights reserved.
//

#import "LIREEntityChooserView.h"
#import "LIREChooserBorderView.h"
#import "LIREChooserArrowView.h"
#import "LIREChooserShadowView.h"

#define LINE_WIDTH 1

@interface LIREEntityChooserView ()

@property (nonatomic) CGFloat pointerXPercent;

@property (nonatomic, strong, readwrite) UITableView *tableView;
@property (nonatomic, strong) UIView *tableViewContainer;
@property (nonatomic, strong) LIREChooserBorderView *borderView;
@property (nonatomic, strong) LIREChooserArrowView *arrowView;
//@property (nonatomic, strong) LIREChooserShadowView *shadowView;

@property (nonatomic, readonly) CGFloat boundaryViewHeight;
@property (nonatomic, readonly) CGFloat shadowViewHeight;

@property (nonatomic, strong) UIView *tableViewBufferView;

// Constraints (descriptions in terms of arrow-pointing-up mode)
/// The constraint describing the height of the chooser view
@property (nonatomic, strong) NSLayoutConstraint *chooserHeightConstraint;
/// The constraint describing the width of the chooser view
@property (nonatomic, strong) NSLayoutConstraint *chooserWidthConstraint;
/// The constraint fixing the top of the border subview to the top of the chooser view
@property (nonatomic, strong) NSLayoutConstraint *borderToContainerVerticalConstraint;
/// The constraint fixing the top of the arrow subview to the top of the chooser view
@property (nonatomic, strong) NSLayoutConstraint *arrowToContainerVerticalConstraint;
/// The constraint fixing the left of the arrow subview to the left of the chooser view
@property (nonatomic, strong) NSLayoutConstraint *arrowToContainerHorizontalConstraint;

@end

@implementation LIREEntityChooserView

+ (instancetype)chooserViewWithFrame:(CGRect)frame
                            delegate:(id<UITableViewDelegate>)delegate
                          dataSource:(id<UITableViewDataSource>)dataSource {
    if (!delegate) return nil;
    LIREEntityChooserView *chooserView = [[[self class] alloc] initWithFrame:frame];
    [chooserView initialSetupForFrame:frame];
    chooserView.tableView.delegate = delegate;
    chooserView.tableView.dataSource = dataSource;
    return chooserView;
}

- (void)setArrowPosition:(CGFloat)position {
    self.borderView.pointerXPercent = fabs(position/self.bounds.size.width);
    [self updateSubviewsForMode:self.borderMode];
}


#pragma mark - Protocol

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)resetScrollPositionAndHide {
    [self.tableView setContentOffset:CGPointMake(0, 0) animated:NO];
    self.hidden = YES;
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (UIColor *)chooserBackgroundColor {
    return self.tableView.backgroundColor;
}

- (void)setChooserBackgroundColor:(UIColor *)chooserBackgroundColor {
    self.tableView.backgroundColor = chooserBackgroundColor;
}

- (void)moveInsertionPointMarkerToXPosition:(CGFloat)position {
    position += self.arrowView.bounds.size.width/2.0;
    [self setArrowPosition:position];
}

- (UIEdgeInsets)dataViewContentInset {
    return self.tableView.contentInset;
}

- (void)setDataViewContentInset:(UIEdgeInsets)dataViewContentInset {
    self.tableView.contentInset = dataViewContentInset;
}

- (UIEdgeInsets)dataViewScrollIndicatorInsets {
    return self.tableView.scrollIndicatorInsets;
}

- (void)setDataViewScrollIndicatorInsets:(UIEdgeInsets)dataViewScrollIndicatorInsets {
    self.tableView.scrollIndicatorInsets = dataViewScrollIndicatorInsets;
}


#pragma mark - Private

- (void)initialSetupForFrame:(CGRect)frame {
    [self setupTableView];

    self.backgroundColor = [UIColor clearColor];
    self.chooserWidthConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"[c(==W)]" options:0
                                                                          metrics:@{@"W": @(frame.size.width)}
                                                                            views:@{@"c": self}][0];
    self.chooserHeightConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[c(==H)]" options:0
                                                                           metrics:@{@"H": @(frame.size.height)}
                                                                             views:@{@"c": self}][0];
    [self addConstraints:@[self.chooserWidthConstraint, self.chooserHeightConstraint]];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self updateSubviewConstraintsForMode:LIREChooserBorderModeNone];
    self.borderMode = LIREChooserBorderModeNone;
}

- (CALayer *)maskLayerForMode:(LIREChooserBorderMode)mode {
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.frame = self.bounds;
    layer.backgroundColor = [[UIColor clearColor] CGColor];
    CGMutablePathRef path = CGPathCreateMutable();
    CGSize size = self.bounds.size;

    switch (mode) {
        case LIREChooserBorderModeNone:
            // No border chooser view does not need any masking
            CGPathRelease(path);
            return nil;
        case LIREChooserBorderModeTop: {
            // Start at upper left
            CGFloat topY = self.boundaryViewHeight - self.borderView.strokeThickness;
            CGPathMoveToPoint(path, NULL, 0, topY);
            // Move to upper right
            if (self.insertionPointMarkerEnabled) {
                CGFloat tipY = topY + self.borderView.arrowTipYOffset;
                CGPathAddLineToPoint(path, NULL, self.borderView.arrowLeftX, topY);
                CGPathAddLineToPoint(path, NULL, self.borderView.arrowMiddleX, tipY);
                CGPathAddLineToPoint(path, NULL, self.borderView.arrowRightX, topY);
            }
            CGPathAddLineToPoint(path, NULL, size.width, topY);
            // Move to bottom right
            CGPathAddLineToPoint(path, NULL, size.width, size.height);
            // Move to bottom left
            CGPathAddLineToPoint(path, NULL, 0, size.height);
            // Close path
            CGPathCloseSubpath(path);
            break;
        }
        case LIREChooserBorderModeBottom: {
            CGFloat bottomY = size.height - self.boundaryViewHeight + self.borderView.strokeThickness;
            // Start at bottom left
            CGPathMoveToPoint(path, NULL, 0, bottomY);
            // Move to bottom right
            if (self.insertionPointMarkerEnabled) {
                CGPathAddLineToPoint(path, NULL, self.borderView.arrowLeftX, bottomY);
                CGPathAddLineToPoint(path, NULL, self.borderView.arrowMiddleX, bottomY + self.borderView.arrowTipYOffset);
                CGPathAddLineToPoint(path, NULL, self.borderView.arrowRightX, bottomY);
            }
            CGPathAddLineToPoint(path, NULL, size.width, bottomY);
            // Move to upper right
            CGPathAddLineToPoint(path, NULL, size.width, 0);
            // Move to upper left
            CGPathAddLineToPoint(path, NULL, 0, 0);
            // Close path
            CGPathCloseSubpath(path);
            break;
        }
    }
    layer.path = path;
    CGPathRelease(path);
    return layer;
}

- (void)updateSubviewConstraintsForMode:(LIREChooserBorderMode)mode {
    NSDictionary *viewsDictionary = @{@"av": self.arrowView,
                                      @"bv": self.borderView};
    NSDictionary *metricsDictionary = @{@"AY": @(self.boundaryViewHeight - self.arrowView.bounds.size.height)};

    [self removeConstraint:self.arrowToContainerVerticalConstraint];
    [self removeConstraint:self.borderToContainerVerticalConstraint];
    switch (mode) {
        case LIREChooserBorderModeNone:
            self.arrowToContainerVerticalConstraint = nil;
            self.borderToContainerVerticalConstraint = nil;
            break;
        case LIREChooserBorderModeTop: {
            // Update border view constraints
            self.borderToContainerVerticalConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bv]"
                                                                                                  options:0
                                                                                                  metrics:metricsDictionary
                                                                                                    views:viewsDictionary][0];
            // Update arrow view constraints
            self.arrowToContainerVerticalConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-AY-[av]"
                                                                                              options:0
                                                                                              metrics:metricsDictionary
                                                                                                views:viewsDictionary][0];
            break;
        }
        case LIREChooserBorderModeBottom: {
            // Update border view constraints
            self.borderToContainerVerticalConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[bv]|"
                                                                                               options:0
                                                                                               metrics:metricsDictionary
                                                                                                 views:viewsDictionary][0];
            // Update arrow view constraints
            self.arrowToContainerVerticalConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[av]-AY-|"
                                                                                              options:0
                                                                                              metrics:metricsDictionary
                                                                                                views:viewsDictionary][0];
            break;
        }
    }

    NSMutableArray *constraintBuffer = [NSMutableArray array];
    if (self.arrowToContainerVerticalConstraint && self.insertionPointMarkerEnabled) {
        [constraintBuffer addObject:self.arrowToContainerVerticalConstraint];
    }
    if (self.borderToContainerVerticalConstraint) {
        [constraintBuffer addObject:self.borderToContainerVerticalConstraint];
    }
    [self addConstraints:constraintBuffer];
    [self updateConstraints];
}

- (void)updateSubviewsForMode:(LIREChooserBorderMode)mode {
    switch (mode) {
        case LIREChooserBorderModeNone:
            self.tableView.tableHeaderView = nil;
            self.tableView.tableFooterView = nil;
            self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;

            self.borderView.hidden = YES;
            self.arrowView.hidden = YES;
            break;
        case LIREChooserBorderModeTop:
            self.tableView.tableHeaderView = self.tableViewBufferView;
            self.tableView.tableFooterView = nil;
            self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(self.boundaryViewHeight, 0, 0, 0);

            self.borderView.borderOnTop = YES;
            self.arrowView.pointingUp = YES;
            self.borderView.hidden = NO;
            self.arrowView.hidden = !self.insertionPointMarkerEnabled;
            break;
        case LIREChooserBorderModeBottom:
            self.tableView.tableHeaderView = nil;
            self.tableView.tableFooterView = self.tableViewBufferView;
            self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, self.boundaryViewHeight, 0);

            self.borderView.borderOnTop = NO;
            self.arrowView.pointingUp = NO;
            self.borderView.hidden = NO;
            self.arrowView.hidden = !self.insertionPointMarkerEnabled;
            break;
    }
    [self updateSubviewConstraintsForMode:mode];
    self.tableViewContainer.layer.mask = [self maskLayerForMode:mode];
}


#pragma mark - Delegate

- (CGSize)sizeForArrowView {
    return self.arrowView.bounds.size;
}

- (void)moveArrowViewToPositionRelativeToBorderView:(CGPoint)position {
    // Unfortunately, refactoring means that position.y is ignored.
    self.arrowToContainerHorizontalConstraint.constant = position.x;
    [self updateConstraints];
}


#pragma mark - Subview Instantiation

- (void)setupTableView {
    NSAssert(!self.tableView, @"Logic error: cannot call setupTableView after initial creation.");

    // Build the table view
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.translatesAutoresizingMaskIntoConstraints = NO;

    // Create a container view
    UIView *containerView = [[UIView alloc] initWithFrame:self.bounds];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.backgroundColor = [UIColor clearColor];

    // Set up the constraints for the table view AFTER the table view has been added to the superview
    [containerView addSubview:tableView];
    [self setupConstraintsForTableView:tableView];

    // Set up the constraints for the container AFTER the container has been added to the superview
    [self addSubview:containerView];
    [self setupConstraintsForTableViewContainer:containerView];

    // Set the property
    self.tableViewContainer = containerView;
    self.tableView = tableView;
}

- (void)setupConstraintsForTableView:(UITableView *)tableView {
    // Table view should adhere strongly to its container view.
    NSDictionary *views = @{@"tv": tableView};
    NSMutableArray *constraints = [[NSLayoutConstraint constraintsWithVisualFormat:@"|[tv]|"
                                                                           options:0
                                                                           metrics:nil
                                                                             views:views] mutableCopy];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views]];
    [tableView.superview addConstraints:constraints];
}

- (void)setupConstraintsForTableViewContainer:(UIView *)container {
    NSDictionary *views = @{@"c": container};
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[c]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[c]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
}

- (void)setupBorderView:(LIREChooserBorderView *)borderView {
    [self addSubview:borderView];

    // Create constraints
    NSDictionary *views = @{@"bv": borderView};
    NSDictionary *metrics = @{@"BVH": @(self.boundaryViewHeight)};
    NSMutableArray *constraints = [NSMutableArray array];
    // Full width
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[bv]-0-|"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];
    // Height
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[bv(==BVH)]"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];
    [self addConstraints:constraints];

    // Other setup
    borderView.delegate = self;
    borderView.arrowVisible = YES;
    borderView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void)setupArrowView:(LIREChooserArrowView *)arrowView {
    arrowView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:arrowView];

    // Create constraints
    NSDictionary *views = @{@"av": arrowView};
    NSDictionary *metrics = @{@"W": @(arrowView.bounds.size.width),
                              @"H": @(arrowView.bounds.size.height)};
    NSMutableArray *constraints = [NSMutableArray array];
    // Width and height
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[av(==W)]"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[av(==H)]"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];
    [arrowView addConstraints:constraints];

    // Left edge constraint
    NSLayoutConstraint *c = [NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[av]"
                                                                    options:0
                                                                    metrics:metrics
                                                                      views:views][0];
    self.arrowToContainerHorizontalConstraint = c;
    [self addConstraint:c];
}


#pragma mark - Properties (and helpers)

- (LIREChooserBorderView *)borderView {
    if (!_borderView) {
        _borderView = [[LIREChooserBorderView alloc] initWithFrame:CGRectMake(0,
                                                                              0,
                                                                              self.bounds.size.width,
                                                                              self.boundaryViewHeight)];
        [self setupBorderView:_borderView];
    }
    return _borderView;
}

- (LIREChooserArrowView *)arrowView {
    if (!_arrowView) {
        BOOL arrowPointingUp;
        switch (self.borderMode) {
            case LIREChooserBorderModeTop:
                arrowPointingUp = YES;
                break;
            case LIREChooserBorderModeNone:
            case LIREChooserBorderModeBottom:
                arrowPointingUp = NO;
                break;
        }
        _arrowView = [LIREChooserArrowView chooserArrowViewPointingUp:arrowPointingUp];
        [self setupArrowView:_arrowView];
        [self bringSubviewToFront:self.borderView];
    }
    return _arrowView;
}

- (UIView *)tableViewBufferView {
    if (!_tableViewBufferView) {
        _tableViewBufferView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                                        self.bounds.size.width,
                                                                        self.boundaryViewHeight)];
        _tableViewBufferView.backgroundColor = [UIColor clearColor];
    }
    return _tableViewBufferView;
}

- (void)setBorderMode:(LIREChooserBorderMode)borderMode {
    [self updateSubviewsForMode:borderMode];
    [super setBorderMode:borderMode];
}

@synthesize insertionPointMarkerEnabled = _insertionPointMarkerEnabled;
- (void)setInsertionPointMarkerEnabled:(BOOL)insertionPointMarkerEnabled {
    _insertionPointMarkerEnabled = insertionPointMarkerEnabled;
    self.arrowView.hidden = !insertionPointMarkerEnabled;
    self.borderView.arrowVisible = insertionPointMarkerEnabled;
    [self updateSubviewsForMode:self.borderMode];
}

- (CGFloat)boundaryViewHeight {
    return 8.0;
}

- (CGFloat)shadowViewHeight {
    return 3.0;
}


#pragma mark - Properties (overrides)

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self.chooserWidthConstraint setConstant:frame.size.width];
    [self.chooserHeightConstraint setConstant:frame.size.height];
}


#pragma mark - Accessibility

- (BOOL)isAccessibilityElement {
    return NO;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return [self.tableView accessibilityElementAtIndex:index];
}

- (NSInteger)accessibilityElementCount {
    return [self.tableView accessibilityElementCount];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return [self.tableView indexOfAccessibilityElement:element];
}

@end