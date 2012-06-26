/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAPush.h"
#import "UAPush+Internal.h"
#import "UAEvent.h"
#import "UAAnalytics.h"
#import "UAUtils.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_ASIHTTPRequestDelegate.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>
#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

static BOOL messageReceived = NO;

@interface UAUtils (Test)
+ (void)setMessageReceivedYES;
@end
@implementation UAUtils (Test)
+ (void)setMessageReceivedYES {
    messageReceived = YES;
}
@end

// inteface to delegate callback methods
@interface UAPush (Test)
- (void)registerDeviceTokenSucceeded:(UA_ASIHTTPRequest*)request;
- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)unRegisterDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request;
@end

@interface UAPushTest : SenTestCase{
    UAPush *push;
    NSString *token;    
}
@end



@implementation UAPushTest

- (void)setUp {
    push = [UAPush shared];
    token = @"5824c969fb8498b3ba0f588fb29e9925c867a9b1d0accff5e44537f3f65290e2";
    messageReceived = NO;
    [push removeObservers];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushTagsSettingsKey];
}


- (void)testSetTags {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"TagTest" ofType:@"plist"];
    NSArray *testTags = [NSArray arrayWithContentsOfFile:path];
    STAssertNotNil(testTags, @"Array of test tags failed to load");
    // Test setTags
    [push setTags:nil];
    [push setTags:testTags];
    STAssertTrue([testTags isEqualToArray:[push tags]], @"Tag arrays should be equal");
}

- (void)testSetAlias {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushAliasSettingsKey];
    [push setAlias:@"cats"];
    STAssertTrue([[push alias] isEqualToString:@"cats"], @"Alias set/get methods are broken");
}

// TODO: keep an eye on the performance of this test, it may be too heavy. 
- (void)testAddTagsToCurrentDevice {
    //There should be no cats in defaults, and addTagToCurrentDevice: becomes addTagsToCurrentDevice
    [[NSUserDefaults standardUserDefaults] setObject:[NSMutableArray array] forKey:UAPushTagsSettingsKey];
    [push addTagToCurrentDevice:@"cats"]; 
    NSArray *tagsWithCats = [push tags];
    STAssertTrue([tagsWithCats containsObject:@"cats"], @"There should be cats in the tags");
    // Test first run
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushTagsSettingsKey];
    [push addTagToCurrentDevice:@"CATS"];
    tagsWithCats = [push tags];
    STAssertTrue([tagsWithCats containsObject:@"CATS"], @"There should be CATS in the tags");
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"TagTest" ofType:@"plist"];
    // Add a bunch of tags
    NSArray *testTags = [NSArray arrayWithContentsOfFile:path];
    [push setTags:testTags];
    // Create a sub array of the tags just added, then re add the sub array (lots of duplicates)
    NSArray *subArray = [testTags subarrayWithRange:NSMakeRange(0, 750)];
    [push setTags:subArray];
    NSArray *existingTags = [push tags];
    // Test for duplicates
    __block NSString *firstValue = [testTags objectAtIndex:0];
    NSIndexSet *passingTest = [existingTags indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([(NSString*)obj isEqualToString:firstValue]) {
            return YES;
        }
        return NO;
    }];
    STAssertTrue([passingTest count] == 1, @"There should be exactly one copy of this tag, tag error in UAPush");
}

- (void)testRemoveTags {
    NSArray *someTags = [NSArray arrayWithObjects:@"one", @"two", @"cats", nil];
    [push setTags:someTags];
    [push removeTagsFromCurrentDevice:[NSArray arrayWithObjects:@"one", @"two", nil]];
    STAssertTrue([[push tags] count] == 1, @"There should only be one tag remaining");
    STAssertTrue([@"cats" isEqualToString:[[push tags] objectAtIndex:0]], @"Remaining tag is incorrect");
    [push removeTagFromCurrentDevice:@"cats"];
    STAssertTrue([[push tags] count] == 0, @"Tag array should be empty");
}

// Token and data were pulled from a funcitoning test app.
- (void)testDeviceTokenParsing{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    STAssertNil(dataError, @"Error reading device token data %@", dataError.description);
    NSString* actualToken = token;
    [[NSUserDefaults standardUserDefaults] setObject:actualToken forKey:UAPushDeviceTokenSettingsKey];
    [push setDeviceToken:actualToken];
    NSString* parsedToken = [push parseDeviceToken:[deviceTokenData description]];
    STAssertTrue([parsedToken isEqualToString:actualToken], @"ERROR: Device token parsing has failed in UAPush");
}

- (void)testTimeZoneSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:UAPushTimeZoneSettingsKey];
    STAssertNil([push timeZone], nil);
    [push setTimeZone:[NSTimeZone localTimeZone]];
    STAssertTrue([[[NSTimeZone localTimeZone] name] isEqualToString:[[push timeZone] name]], nil);
}

- (void)testRegistrationPayload {
    // Setup some payload variables using the methods in UAPush
    NSString *testAlias = @"test_alias";
    NSMutableArray *tags = [NSMutableArray arrayWithObjects:@"tag_one", @"tag_two", nil];
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"America/Dawson_Creek"]; // Ah, Dawson's creek.....
    NSDate *now = [NSDate date];
    NSDate *oneHour = [NSDate dateWithTimeIntervalSinceNow:360];
    push.canEditTagsFromDevice = NO;
    push.alias = testAlias;
    push.tags = tags;
    [push setQuietTimeFrom:now to:oneHour withTimeZone:timeZone];
    push.autobadgeEnabled = YES;
    // Get a payload, should be NO tag info, the BOOL is set to no
    NSDictionary *payload = [push registrationPayload];
    NSDictionary *quietTimePayload = [payload valueForKey:UAPushQuietTimeJSONKey];
    STAssertNotNil(quietTimePayload, @"UAPushJSON payload is missing quiet time payload");
    NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSDateComponents *fromComponents = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:now];
    NSDateComponents *toComponents = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:oneHour];
    NSArray *fromHourMinute = [[quietTimePayload valueForKey:UAPushQuietTimeStartJSONKey] componentsSeparatedByString:@":"];
    NSArray *toHourMinute = [[quietTimePayload valueForKey:UAPushQuietTimeEndJSONKey] componentsSeparatedByString:@":"];
    // Quiet times
    STAssertTrue([[timeZone name] isEqualToString:[payload valueForKey:UAPushTimeZoneJSONKey]], nil);
    STAssertTrue(fromComponents.hour == [[fromHourMinute objectAtIndex:0] doubleValue], nil);
    STAssertTrue(fromComponents.minute == [[fromHourMinute objectAtIndex:1] doubleValue], nil);
    STAssertTrue(toComponents.hour == [[toHourMinute objectAtIndex:0] doubleValue], nil);
    STAssertTrue(toComponents.minute == [[toHourMinute objectAtIndex:1] doubleValue], nil);
    // Alias
    STAssertTrue([[payload valueForKey:UAPushAliasJSONKey] isEqualToString:testAlias], nil);
    // Badge number
    STAssertTrue([[payload valueForKey:UAPushBadgeJSONKey] intValue] == 
                 [[UIApplication sharedApplication] applicationIconBadgeNumber], nil);
    // Tags when canEdit is NO
    STAssertNil([payload valueForKey:UAPushMultipleTagsJSONKey], nil);
    // Setup tag editing from the device
    push.canEditTagsFromDevice = YES;
    push.tags = tags;
    payload = [push registrationPayload];
    STAssertTrue([(NSArray*)[payload valueForKey:UAPushMultipleTagsJSONKey] isEqualToArray:tags], nil);

}

//Quiet time was tested above, set test with a nil timezone 
- (void)testQuietTimeWithNilTimeZone {
    [push setQuietTimeFrom:[NSDate date] to:[NSDate dateWithTimeIntervalSinceNow:35] withTimeZone:nil];
    STAssertTrue([[[NSTimeZone defaultTimeZone] name] isEqualToString:[[push timeZone] name]], nil);
}
 

- (void)testUpdateRegistrationLogic {
    [push setPushEnabled:YES];
    // update with just push enabled
    push.deviceToken = nil;
    push.notificationTypes = UIRemoteNotificationTypeSound | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert;
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] registerForRemoteNotificationTypes:push.notificationTypes];
    [push updateRegistration];
    [mockPush verify];
    // update with push enabled and device token
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    STAssertNil(dataError, @"Error reading device token data %@", dataError.description);
    push.deviceToken = [push parseDeviceToken:[deviceTokenData description]];
    [[mockPush expect] registerDeviceToken:nil];
    [push updateRegistration];
    [mockPush verify];
    push.pushEnabled = NO;
    [[mockPush expect] unRegisterDeviceToken];
    [push updateRegistration];
    [mockPush verify];
}

- (void)testRegisterForRemoteNotificationTypes {
    id mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    UIRemoteNotificationType type = UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert;
    [[mockApplication expect] registerForRemoteNotificationTypes:type];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [push registerForRemoteNotificationTypes:type];
    [mockApplication verify];
}

// Test device token registration, with the proper analytics event
- (void)testRegisterDeviceTokenWithToken {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    id mockPush = [OCMockObject partialMockForObject:push];
    id mockAnalytics = [OCMockObject partialMockForObject:[[UAirship shared] analytics]];
    [[[mockPush expect] andForwardToRealObject] registerDeviceToken:deviceTokenData withExtraInfo:OCMOCK_ANY];
    [[[mockPush expect] andForwardToRealObject] setDeviceToken:OCMOCK_ANY];
    [[mockPush expect] registerDeviceTokenWithExtraInfo:OCMOCK_ANY];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics expect] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [push registerDeviceToken:deviceTokenData];
    STAssertTrue([arg isKindOfClass:[UAEventDeviceRegistration class]], @"UAEventDeviceRegistration not sent during registration");
}

// Test registering an nil device token
- (void)testRegisterDeviceTokenWithNil {
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] registerDeviceTokenWithExtraInfo:OCMOCK_ANY];
    [push registerDeviceToken:nil];
    [mockPush verify];
}

// Test no registration in background
- (void)testRegisterDeviceTokenInBackground {
    id mockAppliction = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    id mockPush =  [OCMockObject partialMockForObject:push];
    UIApplicationState state = UIApplicationStateBackground;
    [[[mockAppliction stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];
    [[mockPush reject] requestToRegisterDeviceTokenWithInfo:OCMOCK_ANY];
    [push registerDeviceToken:nil];
}

- (void)testRegisterDeviceTokenWithExtraInfo {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[[mockPush stub] andReturn:mockRequest] requestToRegisterDeviceTokenWithInfo:OCMOCK_ANY];
    [[mockRequest expect] startAsynchronous];
    [push registerDeviceTokenWithExtraInfo:nil];
    [mockRequest verify];
}

- (void)testRequestToRegisterDeviceTokenWithInfo {
    UA_ASIHTTPRequest *request = [push requestToRegisterDeviceTokenWithInfo:nil];
    STAssertEqualObjects(push, request.delegate, @"Registration equest delegate not set properly");
    STAssertNil(request.postBody, nil);
    STAssertTrue([request.requestMethod isEqualToString:@"PUT"], nil);
    SEL actualSucceeded = request.didFinishSelector;
    SEL actualFailed = request.didFailSelector;
    SEL correctSucceeded = @selector(registerDeviceTokenSucceeded:);
    SEL correctFailed = @selector(registerDeviceTokenFailed:);
    STAssertTrue(sel_isEqual(actualSucceeded, correctSucceeded), @"Request success selectors incorrect");
    STAssertTrue(sel_isEqual(correctFailed, actualFailed), @"Request fail selectors incorrect");
    NSString *correctServer = [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].server, @"/api/device_tokens/", push.deviceToken];
    NSString *actualServer = request.url.absoluteString;
    STAssertTrue([actualServer isEqualToString:correctServer], @"UA registration API URL incorrect");
    NSDictionary* payload = [push registrationPayload];
    request = [push requestToRegisterDeviceTokenWithInfo:payload];
    NSDictionary* requestHeaders = request.requestHeaders;
    NSString *acceptJSON = [requestHeaders valueForKey:@"Content-Type"];
    STAssertTrue([acceptJSON isEqualToString:@"application/json"], @"Request Content-type incorrect");
    NSError *errorJSON = nil;
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:request.postBody options:NSJSONReadingAllowFragments error:&errorJSON];
    STAssertNil(errorJSON, nil);
    STAssertTrue([[payload allKeys] isEqualToArray:[JSON allKeys]], nil);
    STAssertTrue([[payload allValues] isEqualToArray:[JSON allValues]], nil);
}

- (void)testUnregisterDeviceToken {
    id mockPush = [OCMockObject partialMockForObject:push];
    id mockRequest = [OCMockObject mockForClass:[UA_ASIHTTPRequest class]];
    [[[mockPush stub] andReturn:mockRequest] requestToDeleteDeviceToken];
    [[mockRequest expect] startAsynchronous];
    [push unRegisterDeviceToken];
    [mockRequest verify];
    push.deviceToken = nil;
    [[mockPush reject] requestToDeleteDeviceToken];
    [push unRegisterDeviceToken];
    [push registerDeviceTokenWithExtraInfo:nil];
}

- (void)testUnregisterDeviceTokenRequest {
    UA_ASIHTTPRequest *request = [push requestToDeleteDeviceToken];
    NSString *correctServer = [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].server, @"/api/device_tokens/", push.deviceToken];
    NSString *actualServer = request.url.absoluteString;
    STAssertTrue([actualServer isEqualToString:correctServer], @"UA registration API URL incorrect");
    STAssertTrue([request.requestMethod isEqualToString:@"DELETE"], nil);
    STAssertEqualObjects(push, request.delegate, nil);
    BOOL successSelector = sel_isEqual(@selector(unRegisterDeviceTokenSucceeded:), request.didFinishSelector);
    BOOL failSelector = sel_isEqual(@selector(unRegisterDeviceTokenFailed:), request.didFailSelector);
    STAssertTrue(successSelector, nil);
    STAssertTrue(failSelector, nil);
}

- (void)testQuietTimeDisable {
    [push setQuietTimeFrom:[NSDate date] to:[NSDate dateWithTimeIntervalSinceNow:60] withTimeZone:[NSTimeZone defaultTimeZone]];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] updateRegistration];
    [push disableQuietTime];
    NSDictionary* quietTime = [push quietTime];
    STAssertNil(quietTime, nil);
    [mockPush verify];
}

- (void)testSetBadgeNumber {
    [push setAutobadgeEnabled:NO];
    [push setBadgeNumber:42];
    STAssertTrue(42 == [[UIApplication sharedApplication] applicationIconBadgeNumber], nil);
    [push setDeviceToken:token];
    [push setAutobadgeEnabled:YES];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] updateRegistration];
    [push setBadgeNumber:7];
    [mockPush verify];
}

- (void)testPushTypeString {
    UIRemoteNotificationType types = (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert);
    NSString *string = [UAPush pushTypeString:types];
    NSArray *array = [string componentsSeparatedByString:@","];
    // Don't forget the whitespace when separating components
    STAssertTrue([array containsObject:@"Badges"], nil);
    STAssertTrue([array containsObject:@" Alerts"], nil);
    STAssertTrue([array containsObject:@" Sounds"], nil);
}

- (void)testRegisterDeviceTokenWithAlias {
    id mockPush = [OCMockObject partialMockForObject:push];
    __block NSMutableDictionary *body = nil;
    void (^getSingleArg)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&body atIndex:3];
    };
    [[[mockPush stub] andDo:getSingleArg] registerDeviceToken:OCMOCK_ANY withExtraInfo:OCMOCK_ANY];
    [push registerDeviceToken:nil withAlias:@"CATS"];
    STAssertTrue([(NSString*)[body valueForKey:@"alias"] isEqualToString:@"CATS"], nil);
}

- (void)testHandleNotificationApplicationState {
    // Setup a notification payload
    NSMutableDictionary* notification = [NSMutableDictionary dictionaryWithCapacity:4];
    NSMutableDictionary* apsDict = [NSMutableDictionary dictionary];
    [push setAutobadgeEnabled:YES];
    [apsDict setValue:@"ALERT" forKey:@"alert"];
    [apsDict setValue:@"42" forKey:@"badge"];
    [apsDict setValue:@"SOUND" forKey:@"sound"];
    [apsDict setValue:@"CUSTOM" forKey:@"custom"];
    [notification setObject:apsDict forKey:@"aps"];
    // Setup a mock object to receive the parsed payload
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[mockAnalytics expect] handleNotification:notification];
    // Setup a mock delegate to make sure the proper messages are passed when a notification
    // has been received 
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UAPushNotificationDelegate)];
    [push setDelegate:mockDelegate];
    [[mockDelegate expect] displayNotificationAlert:@"ALERT"];
    [[mockDelegate expect] playNotificationSound:@"SOUND"];
    // Call the handle notification method with our fake payload
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    // Verify the calls were received
    [mockAnalytics verify];
    [mockDelegate verify];
    // Setup a notification that is just a badge update
    [[mockAnalytics stub] handleNotification:notification];
    [push setAutobadgeEnabled:NO];
    [apsDict removeObjectForKey:@"alert"];
    [apsDict removeObjectForKey:@"sound"];
    [[mockDelegate expect] handleBadgeUpdate:42];
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    [mockDelegate verify];
    // Setup localized notification
    [apsDict removeObjectForKey:@"badge"];
    NSDictionary *alertDictionary = [NSDictionary dictionaryWithObject:@"not a" forKey:@"string"];
    [apsDict setObject:alertDictionary forKey:@"alert"];
    [[mockDelegate expect] displayLocalizedNotificationAlert:alertDictionary];
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    [mockDelegate verify];
    // Setup a custom payload to see if it's parsed out correctly
    NSDictionary* customPayload = [NSDictionary dictionaryWithObject:@"PAYLOAD" forKey:@"custom_payload"];
    [notification setObject:customPayload forKey:@"custom_payload"];
    [apsDict removeAllObjects];
    // Setup a block to pull out the arg sent to the handleNotification:withCustomPayload method
    __block NSDictionary *customPayloadArg = nil;
    void (^getSingleArg)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&customPayloadArg atIndex:3];
    };
    [[[mockDelegate stub] andDo:getSingleArg]handleNotification:notification withCustomPayload:OCMOCK_ANY];
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    STAssertTrue([[customPayloadArg objectForKey:@"custom_payload"] isEqualToDictionary:customPayload],nil);    
    // Make sure the app passes a background notification message properly
    [[mockDelegate expect] handleBackgroundNotification:notification];
    [push handleNotification:notification applicationState:UIApplicationStateBackground];
    [mockDelegate verify];
}

#pragma mark -
#pragma mark UA API Registration callbacks

- (void)testRegisterDeviceTokenFailed {
    NSError *swizzleError = nil;
    [UAUtils jr_swizzleClassMethod:@selector(requestWentWrong:keyword:) withClassMethod:@selector(setMessageReceivedYES) error:&swizzleError];
    STAssertNil(swizzleError, @"UAUtils method swizzling failed in testRegisterDeviceTokenFailed");
    UA_ASIHTTPRequest *request = [[[UA_ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:@"cats"]] autorelease];
    id mockObserver = [OCMockObject mockForProtocol:@protocol(UARegistrationObserver)];
    [push addObserver:mockObserver];
    [[mockObserver expect] registerDeviceTokenFailed:request];
    [push registerDeviceTokenFailed:request];
    [mockObserver verify];
    STAssertTrue(messageReceived, nil);
    [UAUtils jr_swizzleClassMethod:@selector(setMessageReceivedYES) withClassMethod:@selector(requestWentWrong:keyword:) error:&swizzleError];
    STAssertNil(swizzleError, @"UAUtils method swizzling failed in testRegisterDeviceTokenFailed");
}

- (void)testRegisterDeviceTokenSucceeded {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int code = 42;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(code)] responseStatusCode];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] registerDeviceTokenFailed:mockRequest];
    [push registerDeviceTokenSucceeded:mockRequest];
    [mockPush verify];
    id mockObserver = [OCMockObject niceMockForProtocol:@protocol(UARegistrationObserver)];
    [[mockObserver expect] registerDeviceTokenSucceeded];
    [push addObserver:mockObserver];
    code = 200;
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(code)] responseStatusCode];
    [push registerDeviceTokenSucceeded:mockRequest];
    [mockObserver verify];
                       
}

- (void)testUnregisterDeviceTokenFailed {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int code = 200;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(code)] responseStatusCode];
    NSError *swizzleError = nil;
    [UAUtils jr_swizzleClassMethod:@selector(requestWentWrong:keyword:) withClassMethod:@selector(setMessageReceivedYES) error:&swizzleError];
    STAssertNil(swizzleError, @"UAUtils method swizzling failed in testRegisterDeviceTokenFailed");
    id mockObserver = [OCMockObject mockForProtocol:@protocol(UARegistrationObserver)];
    [[mockObserver expect] unRegisterDeviceTokenFailed:mockRequest];
    [push addObserver:mockObserver];
    [push unRegisterDeviceTokenFailed:mockRequest];
    [mockObserver verify];
    STAssertTrue(messageReceived, nil);
    [UAUtils jr_swizzleClassMethod:@selector(setMessageReceivedYES) withClassMethod:@selector(requestWentWrong:keyword:) error:&swizzleError];
    STAssertNil(swizzleError, @"UAUtils method swizzling failed in testRegisterDeviceTokenFailed");
}

- (void)testUnregisterDeviceTokenSucceeded {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int code = 200;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(code)] responseStatusCode];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] unRegisterDeviceTokenFailed:mockRequest];
    [push unRegisterDeviceTokenSucceeded:mockRequest];
    [mockPush verify];
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    code = 204;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(code)] responseStatusCode];
    [[mockPush expect] setDeviceToken:nil];
    id mockObserver = [OCMockObject mockForProtocol:@protocol(UARegistrationObserver)];
    [[mockObserver expect] unRegisterDeviceTokenSucceeded];
    [push addObserver:mockObserver];
    [push unRegisterDeviceTokenSucceeded:mockRequest];
    [mockPush verify];
    [mockObserver verify];
    
}


@end
