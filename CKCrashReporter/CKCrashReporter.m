/* ----------------------------------------------------------------------
 CKCrashReporter.m
 Copyright 2012 Giulio Petek. All rights reserved.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ---------------------------------------------------------------------- */

#import "CKCrashReporter.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>

/* ----------------------------------------------------------------------
 @constants CKCrashReporter
 ---------------------------------------------------------------------- */

NSString *const CKCrashInfoExceptionNameKey = @"Name";
NSString *const CKCrashInfoExceptionReasonKey = @"Reason";
NSString *const CKCrashInfoBacktraceKey = @"Backtrace";
NSString *const CKCrashInfoHashKey = @"Hash";
NSString *const CKCrashReporterUnknownInformation = @"Unknown";


NSString *const CKCrashReporterErrorDomain = @"de.Giulio_Petek.CKCrashReporter";


/* ----------------------------------------------------------------------
 @interface CKCrashReporter ()
 ---------------------------------------------------------------------- */

@interface CKCrashReporter ()

- (void)_willCreateExceptionWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userinfo;

- (void)_swizzleNSExceptionInit;
- (void)_resetNSExceptionInit;

- (NSString *)_md5HashOfBacktrace:(NSArray *)backtrace name:(NSString *)name;

@end

/* ----------------------------------------------------------------------
 @implementation CKCrashReporter
 ---------------------------------------------------------------------- */

@implementation CKCrashReporter
@synthesize catchExceptions = _catchExceptions;

#pragma mark Init

+ (CKCrashReporter *)sharedReporter {
    static dispatch_once_t __sharedToken = 0;
    static CKCrashReporter * __sharedReporter = nil;
    dispatch_once(&__sharedToken, ^{
        __sharedReporter = [[self alloc] initSharedReporter];
    });
    return __sharedReporter;
}

- (id)init {
    @throw @"Do not initialize your own CKCrashReporter. Use the singleton instead.";
    
    return nil;
}

#pragma mark Swizzling

- (void)_swizzleNSExceptionInit {
    Class origClass = [NSException class];
    Class newClass = [self class];
    SEL origSelector = @selector(initWithName:reason:userInfo:);
    SEL newSelector = @selector(_willCreateExceptionWithName:reason:userInfo:);
    Method origMethod = class_getInstanceMethod(origClass, origSelector);
    Method newMethod = class_getInstanceMethod(newClass, newSelector);
    
    if (class_addMethod(origClass, origSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(newClass, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

- (void)_resetNSExceptionInit {
    Class origClass = [self class];
    Class newClass = [NSException class];
    SEL origSelector = @selector(_willCreateExceptionWithName:reason:userInfo:);
    SEL newSelector = @selector(initWithName:reason:userInfo:);
    Method origMethod = class_getInstanceMethod(origClass, origSelector);
    Method newMethod = class_getInstanceMethod(newClass, newSelector);
    
    if (class_addMethod(origClass, origSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(newClass, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

#pragma mark Subclassing

- (id)initSharedReporter {
    if ((self = [super init])) {
        _catchExceptions = NO;
    }
    
    return self;
}

- (NSString *)crashPath {
    NSString *caches_dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [caches_dir stringByAppendingFormat:@"%@_crash.plist", NSStringFromClass([self class])];
}

- (void)saveCrash:(NSMutableDictionary *)crash {
    [crash writeToFile:[self crashPath] atomically:YES];
}

#pragma mark Helper

- (NSString *)_md5HashOfBacktrace:(NSArray *)backtrace name:(NSString *)name {
    NSMutableString *string = [NSMutableString string];
    for (NSString *frame in backtrace) {
        [string appendString:frame];
    }
    [string appendString:name];
        
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(ptr, (unsigned int)strlen(ptr), md5Buffer);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", md5Buffer[i]];
    }
    
    return [output copy];
}

#pragma mark Manage catching

- (void)setCatchExceptions:(BOOL)catchExceptions {
    if (catchExceptions == _catchExceptions) {
        return;
    }
    
    _catchExceptions = catchExceptions;
    
    if (_catchExceptions) {
        [self _swizzleNSExceptionInit];
    }
    else {
        [self _resetNSExceptionInit];
    }
}

#pragma mark Private - Handle catches (In NSException context)

- (void)_willCreateExceptionWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userinfo {
    CKCrashReporter *reporter = [CKCrashReporter sharedReporter];
    
    NSArray *backtrace = [NSThread callStackSymbols];
    
    NSDictionary *crash = @{
        CKCrashInfoExceptionReasonKey : [reason length] ? reason : CKCrashReporterUnknownInformation,
        CKCrashInfoExceptionNameKey : [name length] ? name : CKCrashReporterUnknownInformation,
        CKCrashInfoBacktraceKey : backtrace,
        CKCrashInfoHashKey : [reporter _md5HashOfBacktrace:backtrace name:name]
    };
    
    [reporter saveCrash:[crash mutableCopy]];
    NSLog(@"%@",crash);
    NSString *str = [NSString stringWithFormat:@"%@",crash];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"crash" message:str delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
    
//    Class varClass = NSClassFromString(@"ViewController");
//    class_addMethod([varClass class], @selector(fakeCrash), (IMP)dynamicMethodIMP, "v@:");
//    abort();
}

void dynamicMethodIMP(id self,SEL _cmd)
{
    NSLog(@"dynamicMethodIMP");
}
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    NSLog(@"resolveInstanceMethod");
    return YES;
}



#pragma mark Manage crash

- (BOOL)hasCrashAvailable {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self crashPath]];
}

- (NSDictionary *)savedCrash {
    if (![self hasCrashAvailable]) {
        return nil;
    }
    
    return [NSDictionary dictionaryWithContentsOfFile:[self crashPath]];
}

- (void)removeSavedCrash {
    [[NSFileManager defaultManager] removeItemAtPath:[self crashPath] error:nil];
}

#pragma mark Memory

- (void)dealloc {
    if (self.catchExceptions) {
        [self _resetNSExceptionInit];
    }
}


#pragma mark Mailing

- (MFMailComposeViewController *)mailComposeViewControllerWithLatestCrashAsAttachmentAndError:(NSError *__autoreleasing *)error {
    if (![self hasCrashAvailable])
        *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:001 userInfo:[NSDictionary dictionaryWithObject:@"No crash available." forKey:NSLocalizedDescriptionKey]];
    
    if (![MFMailComposeViewController canSendMail])
        *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:002 userInfo:[NSDictionary dictionaryWithObject:@"No eMail account available." forKey:NSLocalizedDescriptionKey]];
    
    if (*error)
        return nil;
    
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:[self savedCrash]
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                                options:0
                                                                  error:&*error];
    if (*error)
        return nil;
    
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    [mailViewController addAttachmentData:xmlData
                                 mimeType:@"plist"
                                 fileName:[NSString stringWithFormat:@"%@_crash.plist", NSStringFromClass([self class])]];
    
    if (mailViewController)
        return mailViewController;
    
    *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:003 userInfo:[NSDictionary dictionaryWithObject:@"Not able to create MFMailComposeViewController." forKey:NSLocalizedDescriptionKey]];
    
    return nil;
}

@end