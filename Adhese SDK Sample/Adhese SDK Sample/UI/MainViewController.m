//
//  MainViewController.m
//  Adhese SDK Sample
//
//  Created by Axel Jonckheere on 10/01/2020.
//  Copyright © 2020 Axel Jonckheere. All rights reserved.
//

#import "MainViewController.h"
#import <AdheseSDK/Adhese.h>
#import <AdheseSDK/CookieMode.h>

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // TODO: init view
    [self.adView setDelegate:self];
    
    [self loadAds];
}

- (void)loadAds {
    // Build Adhese options
    AdheseOptions *options = [[AdheseOptions alloc] initWithLocation:@"_demo_ster_a_"];
    options.cookieMode = kAll;
    options.slots = @[@"billboard", @"halfpage"];
  
    [Adhese loadAds:options withCompletionHandler:^(NSArray<Ad *> * _Nonnull ads, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"Failed loading ads with errors: %@", error.localizedDescription);
            return;
        }
        
        Ad *billboard = [self findAd:ads byType:@"billboard"];
        Ad *halfPage = [self findAd:ads byType:@"halfpage"];

        if (billboard) {
            [self.adView setAd:billboard];
            // TODO: assign ad to AdView
        } else {
            // TODO: set view hidden
        }

        if (halfPage) {
            // TODO: assign ad to AdView
        } else {
            // TODO: set view hidden
        }
    }];
}

- (Ad *)findAd:(NSArray<Ad *> *)ads byType:(NSString *)type {
    for (Ad *ad in ads) {
        if ([ad.adType isEqualToString:type]) {
            return ad;
        }
    }
    return nil;
}

#pragma mark - AdViewDelegate
-(void)adDidLoad:(id)adView {
    
}

-(void)viewImpressionWasNotified:(id)adView {
    
}

-(void)trackerWasNotified:(id)adView {
    
}


@end
