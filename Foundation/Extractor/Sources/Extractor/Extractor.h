#import <Foundation/Foundation.h>

// MARK: IMPORT

#include <dlfcn.h>

// TODO: PLEASE UPDATE THIS WHEN MAKING RELEASE
#define CURRENT_BUNDLE_VERSION "14.0.0 - 14A5228q"

NS_ASSUME_NONNULL_BEGIN

typedef int (*extractor_func)(const char* shared_cache_file_path,
                              const char* extraction_root_path,
                              void (^progress)(unsigned current, unsigned total));

// MARK: EXPORT

typedef void (^DYLDExtractorProgressCallback)(NSProgress*);

@interface DYLDExtractor : NSObject

@property(nonatomic) BOOL bundleWasOverwritten;
@property(nonatomic) NSURL *bundleURL;

+ (DYLDExtractor *)sharedExtractor;

- (NSString*)currentBundleVersion;

- (int)extractWithCacheAtPath:(NSString*)cacheAtPath
          toDestinationAtPath:(NSString*)destinationAtPath
         withProgressCallback:(_Nullable DYLDExtractorProgressCallback)progressCallback;

@end

NS_ASSUME_NONNULL_END
