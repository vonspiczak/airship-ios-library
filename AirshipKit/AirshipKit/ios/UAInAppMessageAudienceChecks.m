/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAirship+Internal.h"
#import "UALocation+Internal.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAPush+Internal.h"
#import "UAInAppMessageTagSelector.h"
#import "UAVersionMatcher+Internal.h"
#import <CommonCrypto/CommonDigest.h>

@implementation UAInAppMessageAudienceChecks

+ (BOOL)checkScheduleAudienceConditions:(UAInAppMessageAudience *)audience isNewUser:(BOOL)isNewUser {
    if (!audience) {
        return YES;
    }
    
    if ((audience.isNewUser) && ([audience.isNewUser boolValue] != isNewUser)) {
        return NO;
    }

    if (audience.testDevices.count) {
        NSString *channel = [UAirship push].channelID;
        if (!channel) {
            return NO;
        }

        NSString *hash = [self sha256HexStringForString:channel];
        if (![audience.testDevices containsObject:hash]) {
            return NO;
        }
    }

    return YES;
}

+ (BOOL)checkDisplayAudienceConditions:(UAInAppMessageAudience *)audience {
    if (!audience) {
        return YES;
    }
    
    // Location opt-in
    if (audience.locationOptIn && ([audience.locationOptIn boolValue] != [self isLocationOptedIn])) {
        return NO;
    }
    
    // Notification opt-in
    if (audience.notificationsOptIn && ([audience.notificationsOptIn boolValue] != [self isNotificationsOptedIn])) {
        return NO;
    }

    // Tag Selector
    if (audience.tagSelector && ![audience.tagSelector apply:[UAirship push].tags]) {
        return NO;
    }

    // Locales
    if ((audience.languageIDs) && [audience.languageIDs isKindOfClass:[NSArray class]]) {
        NSLocale *currentLocale = [NSLocale currentLocale];
        for (NSString *audienceLanguageID in audience.languageIDs) {
            NSLocale *audienceLocale = [NSLocale localeWithLocaleIdentifier:audienceLanguageID];

            // check language code
            NSString *currentLanguageCode;
            NSString *audienceLanguageCode;
            if (@available(iOS 10.0, tvOS 10.0, *)) {
                currentLanguageCode = currentLocale.languageCode;
                audienceLanguageCode = audienceLocale.languageCode;
            } else {
                NSDictionary *currentComponents = [NSLocale componentsFromLocaleIdentifier:currentLocale.localeIdentifier];
                currentLanguageCode = currentComponents[NSLocaleLanguageCode];
                NSDictionary *audienceComponents = [NSLocale componentsFromLocaleIdentifier:audienceLocale.localeIdentifier];
                audienceLanguageCode = audienceComponents[NSLocaleLanguageCode];
            }
            if (![currentLanguageCode isEqualToString:audienceLanguageCode]) {
                continue;
            }
            NSString *currentCountryCode;
            NSString *audienceCountryCode;
            if (@available(iOS 10.0, tvOS 10.0, *)) {
                currentCountryCode = currentLocale.countryCode;
                audienceCountryCode = audienceLocale.countryCode;
            } else {
                NSDictionary *currentComponents = [NSLocale componentsFromLocaleIdentifier:currentLocale.localeIdentifier];
                currentCountryCode = currentComponents[NSLocaleCountryCode];
                NSDictionary *audienceComponents = [NSLocale componentsFromLocaleIdentifier:audienceLocale.localeIdentifier];
                audienceCountryCode = audienceComponents[NSLocaleCountryCode];
            }
            if (audienceCountryCode && ![currentCountryCode isEqualToString:audienceCountryCode]) {
                continue;
            }
            return YES;
        }
        return NO;
    }
    
    // version
    if (audience.versionMatcher) {
        NSString *currentAppVersion = [UAirship shared].applicationMetrics.currentAppVersion;
        if (![audience.versionMatcher evaluateObject:currentAppVersion]) {
            return NO;
        }
    }
    
    return YES;
}


+ (BOOL)isLocationOptedIn {
    if (![UAirship location].locationUpdatesEnabled) {
        return NO;
    }

    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusNotDetermined:
            return NO;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return YES;
    }
}

+ (BOOL)isNotificationsOptedIn {
    return [UAirship push].userPushNotificationsEnabled && [UAirship push].authorizedNotificationOptions != UANotificationOptionNone;
}

+ (NSString*)sha256HexStringForString:(NSString*)input {
    NSData *dataIn = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *dataOut = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(dataIn.bytes, (CC_LONG) dataIn.length, dataOut.mutableBytes);

    const unsigned char *bytes = (const unsigned char *)[dataOut bytes];
    NSMutableString* hexString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];

    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }

    return [hexString copy];
}

@end
