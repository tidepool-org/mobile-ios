//
//  Bugsee.h
//  Bugsee
//
//  Created by Dmitry Fink on 11.10.15.
//  Copyright © 2016 Bugsee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "BugseeLogger.h"
#import "BugseeConstants.h"
#import "BugseeAttachment.h"
#import "BugseeReport.h"
#import "BugseeNetworkEvent.h"

#define BUGSEE_ASSERT(condition, description) \
if (!condition) {[Bugsee logAssert:description withLocation:[NSString stringWithFormat:@"%s (%@:%d)", __PRETTY_FUNCTION__, [[NSString stringWithFormat:@"%s", __FILE__] lastPathComponent], __LINE__]]; }

@class Bugsee;
@protocol BugseeDelegate <NSObject>

@optional
/**
 *  Use this delegate to filter network events and their properties.
 *
 *  @param event         network event with properties
 *  @param decisionBlock pass event into this block
 */
-(void) bugseeFilterNetworkEvent:(nonnull BugseeNetworkEvent *)event completionHandler:(nonnull BugseeNetworkFilterDecisionBlock)decisionBlock;

/**
 *  This delegate allows you, to attach 3 files less than 1 MB each to a report.
 *
 *  @param report       report about to be sent
 *  @return pass array of attachments here.
 */
-(nonnull NSArray<BugseeAttachment* >*) bugseeAttachmentsForReport:(nonnull BugseeReport *)report;

@end

@interface Bugsee : NSObject

@property (weak, nonatomic) id _Nullable delegate;
@property (assign, nonatomic, readonly) BOOL launched;

+ (nullable Bugsee *)sharedInstance;
+ (nullable Bugsee *)launchWithToken:(nonnull NSString* )appToken NS_SWIFT_NAME(launch(token:));
+ (nullable Bugsee *)launchWithToken:(nonnull NSString*)appToken andOptions:(nonnull NSDictionary *) options NS_SWIFT_NAME(launch(token:options:));

+ (void) showReportController;
+ (void) showReportControllerWithSummary:(nonnull NSString *)summ description:(nonnull NSString*)descr severity:(BugseeSeverityLevel)level NS_SWIFT_NAME(showReportController(summary:description:severity:));

/**
 *  Pause bugsee video and loggers
 */
+ (void) pause;
/**
 *  Resume bugsee video and loggers
 */
+ (void) resume;

+ (void) traceKey:(nonnull NSString*)traceKey withValue:(nonnull id)value NS_SWIFT_NAME(trace(key:value:));

+ (void) registerEvent:(nonnull NSString*)eventName NS_SWIFT_NAME(event(_:));
+ (void) registerEvent:(nonnull NSString*)eventName withParams:(nonnull NSDictionary*)params NS_SWIFT_NAME(event(_:params:));

/**
 *  Observe all property changes, please don't forget remove observer with stopTracePropertyOfObject:forKey:
 *
 *  @param object object with property
 *  @param key    property name
 */
+ (void) tracePropertyOfObject:(nonnull NSObject*)object forKey:(nonnull NSString*)key;

/**
 *  Observe all property changes, please don't forget remove observer with stopTracePropertyOfObject:forKey:
 *
 *  @param object object with property
 *  @param key    property name
 *  @param name   the name that will be shown on web interface
 */
+ (void) tracePropertyOfObject:(nonnull NSObject*)object forKey:(nonnull NSString*)key withName:(nonnull NSString*)name;

/**
 *  Remove observer from object's property
 *
 *  @param object object with property
 *  @param key    property name. Same name will be used in the traces
 */
+ (void) stopTracePropertyOfObject:(nonnull NSObject*)object forKey:(nonnull NSString*)key;

+ (void) uploadWithSummary:(nonnull NSString*)summary description:(nonnull NSString*)descr severity:(BugseeSeverityLevel)severity NS_SWIFT_NAME(upload(summary:description:severity:));

+ (void) logError:(nonnull NSError *)error NS_SWIFT_NAME(logError(error:));

+ (void) logAssert:(nonnull NSString *)description withLocation:(nonnull NSString*)location NS_SWIFT_NAME(logAssert(description:location:));

+ (void) log:(nonnull NSString*)message NS_SWIFT_NAME(log(_:));

+ (void) log:(nonnull NSString*)message level:(BugseeLogLevel)level NS_SWIFT_NAME(log(_:level:));

+ (void) log:(nonnull NSString*)message level:(BugseeLogLevel)level timestamp:(int64_t)timestamp NS_SWIFT_NAME(log(_:level:timestamp:));

+ (void) logEx:(nonnull NSDictionary*)entry;

/**
 *  Use this method to filter network events and their properties.
 *
 *  Always call removeNetworkEventFilter method if you deallocate
 *  class where setNetworkEventFilter: was called Bugsee.removeNetworkEventFilter();
 *
 *  @param filterBlock pass BugseeNetworkEvent into this block
 */
+ (void) setNetworkEventFilter:(nonnull BugseeNetworkEventFilterBlock)filterBlock;
/**
 *  Remove exists filter that was setup with setNetworkEventFilter: method
 */
+ (void) removeNetworkEventFilter;

+ (nonnull NSString*) accessToken;

/**
 *  Set reporter's email
 *
 *  @param email string with email
 *  @return YES on success, NO on falure
 */
+ (BOOL) setEmail:(nonnull NSString *)email NS_SWIFT_NAME(setEmail(_:));;

/**
 *  Get reporter's email
 *
 *  @return NSString* with email on success, or nil on failure
 */
+ (nullable NSString *) getEmail;

/**
 *  Clear reporter's email
 *
 *  @return YES on success, NO on falure
 */
+ (BOOL) clearEmail;

/**
 *  Hides your view on video same thing you can get from Bugsee+UIView category
 *  view.bugseeProtectedView
 *
 *  @param view     view that you need to protect
 *  @param isHidden bool value
 */
+ (void) setView:(nonnull UIView *)view asHidden:(BOOL) isHidden NS_SWIFT_NAME(setView(_:asHidden:));
+ (BOOL) isViewHidden:(nonnull UIView *) view NS_SWIFT_NAME(isViewHidden(_:));


@end

@interface UIView (Bugsee)

/**
 *  Hides your view on video
 */
@property (nonatomic, assign) BOOL bugseeProtectedView;

@end
