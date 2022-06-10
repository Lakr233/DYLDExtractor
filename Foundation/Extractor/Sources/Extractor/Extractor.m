#import "Extractor.h"

static extractor_func executor = NULL;

#define EXIT_WITH_FAILURE(e) do { \
    NSLog(e); \
    exit(EPERM); \
    assert(FALSE); \
    return; \
} while (0);

NSString *resolveRelativePath(NSString *atPath) {
    NSString *expandedPath = [[atPath stringByExpandingTildeInPath]
                              stringByStandardizingPath];
    return expandedPath;
}

// MARK: PRE_SWIFT_UI_MAIN_HOOK
__attribute__((constructor)) void preload(void) {
    NSProcessInfo *info = NSProcessInfo.processInfo;
    NSArray<NSString*> *arguments = info.arguments;
#if DEBUG
    // [*] calling extract from -NSDocumentRevisionsDebugMode to YES 🤯
    if ([info.environment[@"DEBUG_IN_XCODE"] isEqualToString:@"YES"]) {
        return;
    }
#endif
    if (arguments.count > 1) {
        // by using constructor, we are no longer interrupt SwiftUI app lifecycle
        // this could be improved, but that is a story for another day
        if (arguments.count == 3) {
            DYLDExtractor *extractor = [DYLDExtractor sharedExtractor];
            NSString *cachePath = arguments[1];
            cachePath = resolveRelativePath(cachePath);
            NSString *outputPath = arguments[2];
            outputPath = resolveRelativePath(outputPath);
            if (!cachePath || !outputPath) {
                EXIT_WITH_FAILURE(@"[E] malformed arguments");
            }
            if ([NSFileManager.defaultManager fileExistsAtPath:outputPath]) {
                EXIT_WITH_FAILURE(@"[E] output destination already exists, please remove it yourself");
            }
            NSLog(@"[*] calling extract from %@ to %@", cachePath, outputPath);
            int ret = [extractor extractWithCacheAtPath:cachePath
                                    toDestinationAtPath:outputPath
                                    withProgressCallback:NULL];
            exit(ret);
        } else {
            NSString *name = info.processName;
            NSLog(@"usage: %@ /path/to/dyld_shared_cache /path/to/output", name);
            EXIT_WITH_FAILURE(@"[E] could not understand command line");
        }
    }
}

@implementation DYLDExtractor

+ (DYLDExtractor *)sharedExtractor
{
    static DYLDExtractor *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared setup];
    });
    assert(shared);
    return shared;
}

- (void)setup
{
    NSURL *bundleLocation = [[NSBundle mainBundle] URLForResource:@"dsc_extractor"
                                                    withExtension:@"bundle"];
    
    // CHECK IF BUNDLE OVERWRITE
    NSProcessInfo *info = NSProcessInfo.processInfo;
    NSString *processPath = info.arguments.firstObject;
    if (processPath) {
        NSURL *url = [[NSURL alloc] initFileURLWithPath:processPath];
        NSURL *overwriteBundle = [[url URLByDeletingLastPathComponent]
                                  URLByAppendingPathComponent:@"dsc_extractor.bundle" isDirectory:NO];
        if ([NSFileManager.defaultManager fileExistsAtPath:overwriteBundle.path]) {
            NSLog(@"[*] dsc_extractor.bundle was overwritten by current path environment");
            bundleLocation = overwriteBundle;
            self.bundleWasOverwritten = YES;
        }
    }
    self.bundleURL = bundleLocation;
    
    if (!bundleLocation || bundleLocation.path.length < 1) {
        EXIT_WITH_FAILURE(@"[E] failed to load bundle");
    }
    
    void* handle = dlopen([bundleLocation.path UTF8String], RTLD_LAZY);
    if (!handle) {
        dlerror();
        EXIT_WITH_FAILURE(@"[E] dlopen failed");
    }
    
    executor = (extractor_func)dlsym(handle, "dyld_shared_cache_extract_dylibs_progress");
    if (!executor) {
        dlerror();
        EXIT_WITH_FAILURE(@"[E] dlsym failed");
    }
    
    NSLog(@"[*] bundle was loaded successfully");
    NSLog(@"[*] dyld_shared_cache_extract_dylibs_progress at %p", executor);
}

- (NSString*)currentBundleVersion {
    return @CURRENT_BUNDLE_VERSION;
}

- (int)extractWithCacheAtPath:(NSString *)cacheAtPath
          toDestinationAtPath:(NSString *)destinationAtPath
         withProgressCallback:(DYLDExtractorProgressCallback)progressCallback
{
    NSLock *lock = [[NSLock alloc] init];
    __block BOOL firstOutput = YES;
    int result = (*executor)([cacheAtPath UTF8String],
                             [destinationAtPath UTF8String],
                             ^(unsigned curr, unsigned total) {
        [lock lock];
        NSProgress *progress = [[NSProgress alloc] init];
        progress.completedUnitCount = curr;
        progress.totalUnitCount = total;
        if (firstOutput) {
            firstOutput = NO;
            NSLog(@"[*] extracting %d items", total);
        }
        if (progressCallback) {
            progressCallback(progress);
        } else {
            printf(".");
            fflush(stdout);
        }
        [lock unlock];
    });
    
    printf("\n");
    NSLog(@"[*] extractor result: %d", result);
    return result;
}

@end

