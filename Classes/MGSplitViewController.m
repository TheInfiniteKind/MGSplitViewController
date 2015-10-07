//
//  MGSplitViewController.m
//  MGSplitView
//
//  Created by Matt Gemmell on 26/07/2010.
//  Copyright 2010 Instinctive Code.
//

#import "MGSplitViewController.h"
#import "MGSplitDividerView.h"

#define MG_DEFAULT_SPLIT_POSITION		320.0	// default width of master view in UISplitViewController.
#define MG_DEFAULT_SPLIT_WIDTH			1.0		// default width of split-gutter in UISplitViewController.

#define MG_PANESPLITTER_SPLIT_WIDTH		25.0	// width of split-gutter for MGSplitViewDividerStylePaneSplitter style.
#define MG_DIVIDER_COLOR				[UIColor blackColor]

#define MG_MIN_VIEW_WIDTH				200.0	// minimum width a view is allowed to become as a result of changing the splitPosition.

#define MG_ANIMATION_CHANGE_SPLIT_ORIENTATION	@"ChangeSplitOrientation"	// Animation ID for internal use.
#define MG_ANIMATION_CHANGE_SUBVIEWS_ORDER		@"ChangeSubviewsOrder"	// Animation ID for internal use.


@interface MGSplitViewController () {
    UIViewController* _masterViewController;
    UIViewController* _detailViewController;
}

- (void)setup;
- (void)layoutSubviews;
- (BOOL)shouldShowMasterForInterfaceOrientation:(UIInterfaceOrientation)theOrientation;
- (BOOL)shouldShowMaster;
- (NSString *)nameOfInterfaceOrientation:(UIInterfaceOrientation)theOrientation;
- (void)reconfigureForMasterInPopover:(BOOL)inPopover;

@end


@implementation MGSplitViewController


#pragma mark -
#pragma mark Orientation helpers


- (NSString *)nameOfInterfaceOrientation:(UIInterfaceOrientation)theOrientation
{
	NSString *orientationName = nil;
	switch (theOrientation) {
		case UIInterfaceOrientationPortrait:
			orientationName = @"Portrait"; // Home button at bottom
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			orientationName = @"Portrait (Upside Down)"; // Home button at top
			break;
		case UIInterfaceOrientationLandscapeLeft:
			orientationName = @"Landscape (Left)"; // Home button on left
			break;
		case UIInterfaceOrientationLandscapeRight:
			orientationName = @"Landscape (Right)"; // Home button on right
			break;
		default:
			break;
	}
	
	return orientationName;
}


- (BOOL)isLandscape
{
	return UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
}


- (BOOL)shouldShowMasterForInterfaceOrientation:(UIInterfaceOrientation)theOrientation
{
	// Returns YES if master view should be shown directly embedded in the splitview, instead of hidden in a popover.
	return ((UIInterfaceOrientationIsLandscape(theOrientation)) ? _showsMasterInLandscape : _showsMasterInPortrait);
}


- (BOOL)shouldShowMaster
{
	return [self shouldShowMasterForInterfaceOrientation:self.interfaceOrientation];
}


- (BOOL)isShowingMaster
{
	return [self shouldShowMaster] && self.masterViewController && self.masterViewController.view && ([self.masterViewController.view superview] == self.view);
}


#pragma mark -
#pragma mark Setup and Teardown


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		[self setup];
	}
	
	return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder])) {
		[self setup];
	}
	
	return self;
}


- (void)setup
{
	// Configure default behaviour.
	_viewControllers = [[NSMutableArray alloc] initWithObjects:[NSNull null], [NSNull null], nil];
	_splitWidth = MG_DEFAULT_SPLIT_WIDTH;
	_showsMasterInPortrait = NO;
	_showsMasterInLandscape = YES;
	_reconfigurePopup = NO;
	_vertical = YES;
	_masterBeforeDetail = YES;
	_splitPosition = MG_DEFAULT_SPLIT_POSITION;
	CGRect divRect = self.view.bounds;
	if ([self isVertical]) {
		divRect.origin.y = _splitPosition;
		divRect.size.height = _splitWidth;
	} else {
		divRect.origin.x = _splitPosition;
		divRect.size.width = _splitWidth;
	}
	_dividerView = [[MGSplitDividerView alloc] initWithFrame:divRect];
	_dividerView.splitViewController = self;
	_dividerView.backgroundColor = MG_DIVIDER_COLOR;
	_dividerStyle = MGSplitViewDividerStyleThin;
}



#pragma mark -
#pragma mark View management


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(self.masterViewController && ![self.masterViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation]) {
        return NO;
    }
    if (self.detailViewController  && ![self.detailViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation]) {
        return NO;
    }
    return YES;
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.masterViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.detailViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.masterViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[self.detailViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self layoutSubviews];
}


-(CGRect)masterRectForViewRect:(CGRect)rect
{
    return CGRectMake(rect.origin.x, rect.origin.y, _splitPosition, rect.size.height);
}

-(CGRect)detailRectForViewRect:(CGRect)rect
{
    return CGRectMake(rect.origin.x + _splitPosition + MG_DEFAULT_SPLIT_WIDTH, rect.origin.y,
                      rect.size.width - _splitPosition - MG_DEFAULT_SPLIT_WIDTH, rect.size.height);
}

-(CGRect)dividerRectForViewRect:(CGRect)rect
{
    return CGRectMake(rect.origin.x + _splitPosition, rect.origin.y,
                      MG_DEFAULT_SPLIT_WIDTH, rect.size.height);
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    self.masterViewController.view.frame = [self masterRectForViewRect:rect];
    DLog(@"master: %@", self.masterViewController.view);
    [self.masterViewController.view setNeedsLayout];
    self.detailViewController.view.frame = [self detailRectForViewRect:rect];
//    NSLog(@"laying out subviews in transition to size: %@,  master: %@    detail: %@",
//          NSStringFromCGSize(size), NSStringFromCGRect([self masterRectForViewRect:rect]),
//          NSStringFromCGRect([self detailRectForViewRect:rect]));
    //[self.view setNeedsLayout];
    //[self.view setNeedsDisplay]; // layoutSubviews];
    [coordinator notifyWhenInteractionEndsUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self layoutSubviews];
    }];
    //[self.view setNeedsLayout]; // layoutSubviews];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    [self.masterViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.detailViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // Hide popover.
	if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
		[_hiddenPopoverController dismissPopoverAnimated:NO];
	}
	
	// Re-tile views.
	_reconfigurePopup = YES;
}


- (void)willAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.masterViewController willAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[self.detailViewController willAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}


- (void)didAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	[self.masterViewController didAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation];
	[self.detailViewController didAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation];
}


- (void)willAnimateSecondHalfOfRotationFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.masterViewController willAnimateSecondHalfOfRotationFromInterfaceOrientation:fromInterfaceOrientation duration:duration];
	[self.detailViewController willAnimateSecondHalfOfRotationFromInterfaceOrientation:fromInterfaceOrientation duration:duration];
}


-(void)layoutSubviews
{
    [self.view layoutSubviews];
}

- (void)viewDidLayoutSubviews
{
    CGRect rect = self.view.frame;
    rect.origin = CGPointMake(0, 0);
    self.masterViewController.view.frame = [self masterRectForViewRect:rect];
    self.detailViewController.view.frame = [self detailRectForViewRect:rect];
    DLog(@"master: %@", self.masterViewController.view);

    // Position divider.
    UIView* theView = _dividerView;
    theView.frame = [self dividerRectForViewRect:rect];
    if (!theView.superview) {
        [self.view addSubview:theView];
    }
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewWillAppear:animated];
	}
	[self.detailViewController viewWillAppear:animated];
    
	_reconfigurePopup = YES;
	[self layoutSubviews];
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewDidAppear:animated];
	}
	[self.detailViewController viewDidAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewWillDisappear:animated];
	}
	[self.detailViewController viewWillDisappear:animated];
}


- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	if ([self isShowingMaster]) {
		[self.masterViewController viewDidDisappear:animated];
	}
	[self.detailViewController viewDidDisappear:animated];
}


#pragma mark -
#pragma mark Popover handling


- (void)reconfigureForMasterInPopover:(BOOL)inPopover
{
	_reconfigurePopup = NO;
	
	if ((inPopover && _hiddenPopoverController) || (!inPopover && !_hiddenPopoverController) || !self.masterViewController) {
		// Nothing to do.
		return;
	}
	
	if (inPopover && !_hiddenPopoverController && !_barButtonItem) {
		// Create and configure popover for our masterViewController.
		_hiddenPopoverController = nil;
		[self.masterViewController viewWillDisappear:NO];
		_hiddenPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.masterViewController];
		[self.masterViewController viewDidDisappear:NO];
		
		// Create and configure _barButtonItem.
		_barButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Master", nil) 
														  style:UIBarButtonItemStyleBordered 
														 target:self 
														 action:@selector(showMasterPopover:)];
		
		// Inform delegate of this state of affairs.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:willHideViewController:withBarButtonItem:forPopoverController:)]) {
			[(NSObject <MGSplitViewControllerDelegate> *)_delegate splitViewController:self 
																willHideViewController:self.masterViewController 
																	 withBarButtonItem:_barButtonItem 
																  forPopoverController:_hiddenPopoverController];
		}
		
	} else if (!inPopover && _hiddenPopoverController && _barButtonItem) {
		// I know this looks strange, but it fixes a bizarre issue with UIPopoverController leaving masterViewController's views in disarray.
		[_hiddenPopoverController presentPopoverFromRect:CGRectZero inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
		
		// Remove master from popover and destroy popover, if it exists.
		[_hiddenPopoverController dismissPopoverAnimated:NO];
		_hiddenPopoverController = nil;
		
		// Inform delegate that the _barButtonItem will become invalid.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:willShowViewController:invalidatingBarButtonItem:)]) {
			[(NSObject <MGSplitViewControllerDelegate> *)_delegate splitViewController:self 
																willShowViewController:self.masterViewController 
															 invalidatingBarButtonItem:_barButtonItem];
		}
		
		// Destroy _barButtonItem.
		_barButtonItem = nil;
		
		// Move master view.
		UIView *masterView = self.masterViewController.view;
		if (masterView && masterView.superview != self.view) {
			[masterView removeFromSuperview];
		}
	}
}


- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	[self reconfigureForMasterInPopover:NO];
}


- (void)notePopoverDismissed
{
	[self popoverControllerDidDismissPopover:_hiddenPopoverController];
}


#pragma mark -
#pragma mark IB Actions


- (IBAction)toggleSplitOrientation:(id)sender
{
    [UIView animateWithDuration:0.25 animations:^{
        self.vertical = (!self.vertical);
        [self layoutSubviews];
    }];
}


- (IBAction)toggleMasterBeforeDetail:(id)sender
{
    [UIView animateWithDuration:0.25 animations:^{
        self.masterBeforeDetail = (!self.masterBeforeDetail);
        [self layoutSubviews];
    }];
}


- (IBAction)toggleMasterView:(id)sender
{
	if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
		[_hiddenPopoverController dismissPopoverAnimated:NO];
	}
	
	if (![self isShowingMaster]) {
		// We're about to show the master view. Ensure it's in place off-screen to be animated in.
		_reconfigurePopup = YES;
		[self reconfigureForMasterInPopover:NO];
		[self layoutSubviews];
    }
    
    // This action functions on the current primary orientation; it is independent of the other primary orientation.
    [UIView animateWithDuration:0.25 animations:^{
        if (self.isLandscape) {
            self.showsMasterInLandscape = !_showsMasterInLandscape;
        } else {
            self.showsMasterInPortrait = !_showsMasterInPortrait;
        }
        [self layoutSubviews];
    }];
}


- (IBAction)showMasterPopover:(id)sender
{
	if (_hiddenPopoverController && !(_hiddenPopoverController.popoverVisible)) {
		// Inform delegate.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:popoverController:willPresentViewController:)]) {
			[(NSObject <MGSplitViewControllerDelegate> *)_delegate splitViewController:self 
																	 popoverController:_hiddenPopoverController 
															 willPresentViewController:self.masterViewController];
		}
		
		// Show popover.
		[_hiddenPopoverController presentPopoverFromBarButtonItem:_barButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	}
}


#pragma mark -
#pragma mark Accessors and properties


- (id)delegate
{
	return _delegate;
}


- (void)setDelegate:(id <MGSplitViewControllerDelegate>)newDelegate
{
	if (newDelegate != _delegate && 
		(!newDelegate || [(NSObject *)newDelegate conformsToProtocol:@protocol(MGSplitViewControllerDelegate)])) {
		_delegate = newDelegate;
	}
}


- (BOOL)showsMasterInPortrait
{
	return _showsMasterInPortrait;
}


- (void)setShowsMasterInPortrait:(BOOL)flag
{
	if (flag != _showsMasterInPortrait) {
		_showsMasterInPortrait = flag;
		
		if (![self isLandscape]) { // i.e. if this will cause a visual change.
			if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
				[_hiddenPopoverController dismissPopoverAnimated:NO];
			}
			
			// Rearrange views.
			_reconfigurePopup = YES;
			[self layoutSubviews];
		}
	}
}


- (BOOL)showsMasterInLandscape
{
	return _showsMasterInLandscape;
}


- (void)setShowsMasterInLandscape:(BOOL)flag
{
	if (flag != _showsMasterInLandscape) {
		_showsMasterInLandscape = flag;
		
		if ([self isLandscape]) { // i.e. if this will cause a visual change.
			if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
				[_hiddenPopoverController dismissPopoverAnimated:NO];
			}
			
			// Rearrange views.
			_reconfigurePopup = YES;
			[self layoutSubviews];
		}
	}
}


- (BOOL)isVertical
{
	return _vertical;
}


- (void)setVertical:(BOOL)flag
{
	if (flag != _vertical) {
		if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
			[_hiddenPopoverController dismissPopoverAnimated:NO];
		}
		
		_vertical = flag;
		
		// Inform delegate.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:willChangeSplitOrientationToVertical:)]) {
			[_delegate splitViewController:self willChangeSplitOrientationToVertical:_vertical];
		}
		
		[self layoutSubviews];
	}
}


- (BOOL)isMasterBeforeDetail
{
	return _masterBeforeDetail;
}


- (void)setMasterBeforeDetail:(BOOL)flag
{
	if (flag != _masterBeforeDetail) {
		if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
			[_hiddenPopoverController dismissPopoverAnimated:NO];
		}
		
		_masterBeforeDetail = flag;
		
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (float)splitPosition
{
	return _splitPosition;
}


- (void)setSplitPosition:(float)posn
{
    // Check to see if delegate wishes to constrain the position.
    float newPosn = posn;
    BOOL constrained = NO;
    CGSize fullSize = [self masterRectForViewRect:self.view.frame].size;
    if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:constrainSplitPosition:splitViewSize:)]) {
        newPosn = [_delegate splitViewController:self constrainSplitPosition:newPosn splitViewSize:fullSize];
        constrained = YES; // implicitly trust delegate's response.
    } else {
        // Apply default constraints if delegate doesn't wish to participate.
        float minPos = MG_MIN_VIEW_WIDTH;
        float maxPos = ((_vertical) ? fullSize.width : fullSize.height) - (MG_MIN_VIEW_WIDTH + _splitWidth);
        constrained = (newPosn != _splitPosition && newPosn >= minPos && newPosn <= maxPos);
    }
    
    if (constrained) {
        if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
            [_hiddenPopoverController dismissPopoverAnimated:NO];
        }
        
        _splitPosition = newPosn;
        
        // Inform delegate.
		if (_delegate && [_delegate respondsToSelector:@selector(splitViewController:willMoveSplitToPosition:)]) {
			[_delegate splitViewController:self willMoveSplitToPosition:_splitPosition];
		}
		
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (void)setSplitPosition:(float)posn animated:(BOOL)animate
{
	BOOL shouldAnimate = (animate && [self isShowingMaster]);
	if (shouldAnimate) {
		[UIView beginAnimations:@"SplitPosition" context:nil];
	}
	[self setSplitPosition:posn];
	if (shouldAnimate) {
		[UIView commitAnimations];
	}
}


- (float)splitWidth
{
	return _splitWidth;
}


- (void)setSplitWidth:(float)width
{
	if (width != _splitWidth && width >= 0) {
		_splitWidth = width;
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (NSArray *)viewControllers
{
    return [_viewControllers copy];
}


- (UIViewController *)masterViewController
{
    return _masterViewController;
}

- (void)setMasterViewController:(UIViewController *)master
{
    NSObject *newMaster = master ? master : [NSNull null];
    
    if(_masterViewController!=newMaster) {
        [_masterViewController removeFromParentViewController];
        [_masterViewController.view removeFromSuperview];
        NSObject* detail = _detailViewController ? _detailViewController : [NSNull null];
        _viewControllers = @[newMaster, detail];
        _masterViewController = master;
        if(master) {
            [self addChildViewController:master];
            [self.view addSubview:master.view];
            master.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        [self.view setNeedsLayout];
    }
}


- (UIViewController *)detailViewController
{
    return _detailViewController;
}


- (void)setDetailViewController:(UIViewController *)detail
{
    NSObject *newDetail = detail ? detail : [NSNull null];
    
    if(_detailViewController!=newDetail) {
        [_detailViewController removeFromParentViewController];
        [_detailViewController.view removeFromSuperview];
        NSObject* master = _masterViewController ? _masterViewController : [NSNull null];
        _viewControllers = @[master, newDetail];
        _detailViewController = detail;
        if(detail) {
            [self addChildViewController:detail];
            [self.view addSubview:detail.view];
            detail.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        [self.view setNeedsLayout];
    }
}


- (MGSplitDividerView *)dividerView
{
    return _dividerView;
}


- (void)setDividerView:(MGSplitDividerView *)divider
{
	if (divider != _dividerView) {
		[_dividerView removeFromSuperview];
        _dividerView = divider;
		_dividerView.splitViewController = self;
        _dividerView.backgroundColor = MG_DIVIDER_COLOR;
		if ([self isShowingMaster]) {
			[self layoutSubviews];
		}
	}
}


- (BOOL)allowsDraggingDivider
{
	if (_dividerView) {
		return _dividerView.allowsDragging;
	}
	
	return NO;
}


- (void)setAllowsDraggingDivider:(BOOL)flag
{
	if (self.allowsDraggingDivider != flag && _dividerView) {
		_dividerView.allowsDragging = flag;
	}
}


- (MGSplitViewDividerStyle)dividerStyle
{
	return _dividerStyle;
}


- (void)setDividerStyle:(MGSplitViewDividerStyle)newStyle
{
	if (_hiddenPopoverController && _hiddenPopoverController.popoverVisible) {
		[_hiddenPopoverController dismissPopoverAnimated:NO];
	}
	
	// We don't check to see if newStyle equals _dividerStyle, because it's a meta-setting.
	// Aspects could have been changed since it was set.
	_dividerStyle = newStyle;
    
    // Reconfigure general appearance and behaviour.
    if (_dividerStyle == MGSplitViewDividerStyleThin) {
		_splitWidth = MG_DEFAULT_SPLIT_WIDTH;
		self.allowsDraggingDivider = NO;
		
	} else if (_dividerStyle == MGSplitViewDividerStylePaneSplitter) {
		_splitWidth = MG_PANESPLITTER_SPLIT_WIDTH;
		self.allowsDraggingDivider = YES;
	}
	
	// Update divider
	[_dividerView setNeedsDisplay];
    
	// Layout all views.
	[self layoutSubviews];
}


- (void)setDividerStyle:(MGSplitViewDividerStyle)newStyle animated:(BOOL)animate
{
	BOOL shouldAnimate = (animate && [self isShowingMaster]);
	if (shouldAnimate) {
		[UIView beginAnimations:@"DividerStyle" context:nil];
	}
	[self setDividerStyle:newStyle];
	if (shouldAnimate) {
		[UIView commitAnimations];
	}
}



@synthesize showsMasterInPortrait;
@synthesize showsMasterInLandscape;
@synthesize vertical;
@synthesize delegate;
@synthesize viewControllers;
@synthesize masterViewController;
@synthesize detailViewController;
@synthesize dividerView;
@synthesize splitPosition;
@synthesize splitWidth;
@synthesize allowsDraggingDivider;
@synthesize dividerStyle;


@end
