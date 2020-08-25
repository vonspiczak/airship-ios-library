/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAEventAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAKeychainUtils.h"

@interface UAEventAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockAnalytics;
@property (nonatomic, strong) id mockDelegate;

@property (nonatomic, strong) UAEventAPIClient *client;
@end

@implementation UAEventAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAEventAPIClient clientWithConfig:self.config session:self.mockSession];
}

/**
 * Test the event request
 */
- (void)testEventRequest {
    NSDictionary *headers = @{@"cool": @"story"};

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://combine.urbanairship.com/warp9/"]) {
            return NO;
        }

        // check that its a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // check the body is set
        if (!request.body.length) {
            return NO;
        }

        // check header was included
        if (![request.headers[@"cool"] isEqual:@"story"]) {
            return NO;
        }

        return YES;
    };

    [(UARequestSession *)[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                                     completionHandler:OCMOCK_ANY];

    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(NSDictionary *responseHeaders, NSError *error) {}];

    [self.mockSession verify];
}


/**
 * Test that a successful event upload passes the response headers with no errors
 */
- (void)testUploadEvents {

    NSDictionary *headers = @{@"foo" : @"bar"};

    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:headers];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, expectedResponse, nil);
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];


    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(NSDictionary *responseHeaders, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(responseHeaders, headers);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test that a non-200 event upload passes the response headers with an unsuccessful status error
 */
- (void)testUploadEventsUnsuccessfulStatus {

    NSDictionary *headers = @{@"foo" : @"bar"};

    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:headers];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, expectedResponse, nil);
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(NSDictionary *responseHeaders, NSError *error) {
        XCTAssertEqualObjects(error.domain, UAEventAPIClientErrorDomain);
        XCTAssertEqual(error.code, UAEventAPIClientErrorUnsuccessfulStatus);
        XCTAssertEqualObjects(responseHeaders, headers);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test that a failed event upload passes nil response headers, and the error, when a non-HTTP error is encountered
 */
- (void)testUploadEventsError {

    NSDictionary *headers = @{@"foo" : @"bar"};
    NSError *expectedError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{}];

    [(UARequestSession *)[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, nil, expectedError);
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [self.client uploadEvents:@[@{@"some": @"event"}] headers:headers
            completionHandler:^(NSDictionary *responseHeaders, NSError *error) {
        XCTAssertEqualObjects(error, expectedError);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

@end
