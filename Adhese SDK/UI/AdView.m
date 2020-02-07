//
//  AdView.m
//  Adhese SDK
//
//  Created by Axel Jonckheere on 14/01/2020.
//  Copyright © 2020 Axel Jonckheere. All rights reserved.
//

#import "AdView.h"
#import <WebKit/WebKit.h>
#import "AdheseLogger.h"
#import "APIManager.h"
#import "Adhese.h"

@implementation AdView
{
    BOOL isContentLoaded;
    BOOL hasViewImpressionBeenCalled;
    BOOL isViewImpressionCallInProgress;
    BOOL isViewCurrentlyVisible;
    CGFloat actualWidth;
    CGFloat actualHeight;
}

#pragma mark - Init


-(instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithFrame:CGRectZero configuration:[[WKWebViewConfiguration alloc] init]];
    
    if (self) {
        [self bootstrap];
    }
    
    return self;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame configuration:[[WKWebViewConfiguration alloc] init]];
    
    if (self) {
        [self bootstrap];
    }
    
    return self;
}

-(instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frame configuration:configuration];
    
    if (self) {
        [self bootstrap];
    }
    
    return self;
}

-(void)bootstrap {
    self.navigationDelegate = self;
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.shouldOpenAd = YES;
}

#pragma mark - Getters/Setters

-(void)setAd:(Ad *)ad {
    _ad = ad;
    isContentLoaded = NO;
    [self loadAd];
}

#pragma mark - Helpers

-(void)loadAd {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [self loadContentWithActualBounds];
    }];
}

-(void)loadContentWithActualBounds {
    [self evaluateJavaScript:[Adhese getSizeReporterScript] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
        if (error) {
            [AdheseLogger logEvent:SDK_ERROR withMessage:[NSString stringWithFormat:@"Couldn't determine AdView width/height. Ad won't load: %@", error.localizedDescription]];
            return;
        }
        
        NSDictionary *rect = (NSDictionary *) result;
        self->actualWidth = [[rect valueForKey:@"width"] floatValue];
        self->actualHeight = [[rect valueForKey:@"height"] floatValue];
        
        [self loadHTMLString:[self wrapinHtmlWrapper] baseURL:nil];
    }];
}

-(NSString *)wrapinHtmlWrapper {
    float scale = [self determineContentScale];
    
    return [NSString stringWithFormat:[Adhese getHtmlWrapper], self.ad.adType, scale, scale, actualWidth, actualHeight, self.ad.content];
}

-(CGFloat)determineContentScale {
    if (!self.ad) { return 1; }
    
    if (self.ad.width < actualHeight) {
        return self.ad.height != 0 ? actualHeight / self.ad.height : 1;
    } else {
        return self.ad.width != 0 ? actualWidth / self.ad.width : 1;
    }
}

-(void)notifyTracker {
    [AdheseLogger logEvent:SDK_EVENT withMessage:[NSString stringWithFormat:@"Will notify the tracker for slot %@", self.ad.slotName]];
    
    [[[APIManager alloc] initWithBaseUrl:nil] getForUrl:self.ad.trackerUrl withCompletionHandler:^(AdheseAPIResponse * _Nonnull response) {
        
        if (response.error) {
            [AdheseLogger logEvent:SDK_ERROR withMessage:[NSString stringWithFormat:@"Failed to notify the tracker for slot %@. %@", self.ad.slotName, response.error.description]];
            [self.delegate trackerWasNotified:self withError:response.error];
            return;
        }
        
        [AdheseLogger logEvent:SDK_EVENT withMessage:[NSString stringWithFormat:@"Notified tracker for slot  %@", self.ad.slotName]];
        
        [self.delegate trackerWasNotified:self withError:nil];
    }];
}

-(void)notifyViewImpression {
    isViewImpressionCallInProgress = YES;
    [AdheseLogger logEvent:SDK_EVENT withMessage:[NSString stringWithFormat:@"Will notify the view impression for slot %@", self.ad.slotName]];

    [[[APIManager alloc] initWithBaseUrl:nil] getForUrl:self.ad.trackerUrl withCompletionHandler:^(AdheseAPIResponse * _Nonnull response) {
        
        if (response.error) {
            [AdheseLogger logEvent:SDK_ERROR withMessage:[NSString stringWithFormat:@"Failed to send view impression for slot %@. %@", self.ad.slotName, response.error.description]];
            [self.delegate viewImpressionWasNotified:self withError:response.error];
            return;
        }
        
        [AdheseLogger logEvent:SDK_EVENT withMessage:[NSString stringWithFormat:@"Notified tracker for slot %@", self.ad.slotName]];
        
        [self.delegate viewImpressionWasNotified:self  withError:nil];
    }];
}

-(void)triggerViewImpressionWhenVisible {
    if (!hasViewImpressionBeenCalled
        && !isViewImpressionCallInProgress
        && self.ad
        && self.ad.viewableImpressionUrl
        && self.ad.viewableImpressionUrl.length > 0
        && !self.isHidden
        && isViewCurrentlyVisible) {
            [AdheseLogger logEvent:SDK_EVENT withMessage:[NSString stringWithFormat:@"%@ is visible", self.ad.slotName]];
            [self notifyViewImpression];
    }
}

#pragma mark - WKNavigationDelegate

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    if (isContentLoaded) {
        return;
    }
    
    isContentLoaded = YES;
    
    [self.delegate adDidLoad:self withError:nil];
    
    [AdheseLogger logEvent:SDK_EVENT withMessage:[NSString stringWithFormat:@"Finished loading slot %@", self.ad.slotName]];

    [self notifyTracker];
    [self triggerViewImpressionWhenVisible];
}

-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

    if (!isContentLoaded) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    BOOL isClickEvent = navigationAction.navigationType == WKNavigationTypeLinkActivated;
    if (self.shouldOpenAd && [navigationAction.request.URL.absoluteString hasPrefix:@"http"] && isClickEvent) {
        [[UIApplication sharedApplication] openURL:navigationAction.request.URL];
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Overrides

- (void)didMoveToWindow {
    [super didMoveToWindow];
    
    isViewCurrentlyVisible = self.window != nil;
}

@end
