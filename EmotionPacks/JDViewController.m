//
//  JDViewController.m
//  EmotionPacks
//
//  Created by Ryan Wang on 7/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "JDViewController.h"
#import "AIEmoticonController.h"
#import "AIEmoticonPack.h"

@interface JDViewController ()

@end

@implementation JDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *testString = @":-[:-[:-[:-[:[:'(";    //Pass
//    NSString *testString = @":-[fsdflskj(A)(A)(a)((A))fklasjfnv,xnvmx :) ;) >:-o :[:[:[:[";
//    NSString *testString = nil;//pass
    
    NSString *output = [[AIEmoticonController sharedController] styleStringWithString:testString];
    NSLog(@"%@",testString);
    NSLog(@"%@",output);
    
    
    NSArray *packs = [[AIEmoticonController sharedController] defaultPacks];
    NSLog(@"packs \n %@",packs);
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
