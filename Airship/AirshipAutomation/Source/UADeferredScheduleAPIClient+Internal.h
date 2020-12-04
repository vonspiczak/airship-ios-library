/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UADeferredScheduleResult+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAAPIClient.h"
#import "UAAuthTokenManager+Internal.h"
#import "UADispatcher.h"
#import "UAStateOverrides+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents possible deferred schedule API client errors.
 */
typedef NS_ENUM(NSInteger, UADeferredScheduleAPIClientError) {
    /**
     * Indicates auth token unavailable.
     */
    UADeferredScheduleAPIClientErrorMissingAuthToken,

    /**
     * Indicates connection timeout.
     */
    UADeferredScheduleAPIClientErrorTimedOut,

    /**
     * Indicates an unsuccessful client status.
     */
    UADeferredScheduleAPIClientErrorUnsuccessfulStatus
};

/**
 * The domain for NSErrors generated by the deferred schedule client.
 */
extern NSString * const UADeferredScheduleAPIClientErrorDomain;

/**
 * Deferred schedule API client.
 */
@interface UADeferredScheduleAPIClient : UAAPIClient

/**
 * UADeferredScheduleAPIClient class factory method. Used for testing.
 *
 * @param config The runtime config.
 * @param session The request session.
 * @param dispatcher The serial dispatcher.
 * @param authManager The auth manager.
 * @param stateOverridesProvider The state overrides provider block.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
                      dispatcher:(UADispatcher *)dispatcher
                     authManager:(UAAuthTokenManager *)authManager
          stateOverridesProvider:(UAStateOverrides * (^)(void))stateOverridesProvider;

/**
 * UADeferredScheduleAPIClient class factory method.
 *
 * @param config The runtime config.
 * @param authManager The auth manager.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config authManager:(UAAuthTokenManager *)authManager;

/**
 * Resolves a deferred schedule.
 * @param URL The URL.
 * @param channelID The channel ID.
 * @param triggerContext The optional trigger context.
 * @param tagOverrides The tag overrides.
 * @param attributeOverrides The attribute overrides.
 * @param completionHandler The completion handler. The completion handler is called on an internal serial queue.
 */
- (void)resolveURL:(NSURL *)URL
         channelID:(NSString *)channelID
    triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
      tagOverrides:(NSArray<UATagGroupsMutation *> *)tagOverrides
attributeOverrides:(UAAttributePendingMutations *)attributeOverrides
 completionHandler:(void (^)(UADeferredScheduleResult * _Nullable, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END