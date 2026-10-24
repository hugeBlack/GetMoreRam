//
//  CodeSigner.h
//  codesign
//
//  Created by samsam on 1/15/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
int codesignAllNested(NSString *bundlePath,
                      const char *p12Path,
                      const char *p12Password,
                      const char *mobileProvisionPath,
                      NSDictionary *entitlements);

int codesign_sign_with_p12_and_mobileprovision(
    const char *appPath,
    const char *p12Path,
    const char *p12Password,
    const char * _Nullable mobileProvisionPath,
    NSDictionary *entitlements);

NS_ASSUME_NONNULL_END
