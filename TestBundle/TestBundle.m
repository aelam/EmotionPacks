//
//  TestBundle.m
//  TestBundle
//
//  Created by Ryan Wang on 12-7-25.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "TestBundle.h"
#import "AIEmoticonController.h"

@implementation TestBundle

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
    [SenTestLog testLogWithFormat:@"%@",[[AIEmoticonController sharedController] styleStringWithString:@"Hello"]];
    STFail(@"Unit tests are not implemented yet in TestBundle");
}

@end
