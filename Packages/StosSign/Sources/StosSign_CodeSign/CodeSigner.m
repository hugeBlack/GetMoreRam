//
//  codesigner.m
//  codesign
//
//  Created by samsam on 1/15/26.
//

#import "CodeSigner.h"
#import "SecCodeSignerSPI.h"
#import "SecCodeSigner.h"
#import "SecCode.h"
#import "CSCommon.h"
#import "SecCodePriv.h"
#import "SecStaticCode.h"
#import "CodeSigner.h"
#import "SecPolicyPriv.h"
#import "CMSDecoder.h"
#import <dlfcn.h>

NSArray<NSString *> *allNestedCodePathsSorted(NSString *bundlePath) {
	NSMutableArray<NSString *> *results = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:bundleURL
								 includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsPackageKey]
													options:0
											   errorHandler:nil];

	for (NSURL *fileURL in enumerator) {
		NSString *path = [fileURL path];
		NSString *filename = [path lastPathComponent];
		
		if ([filename hasPrefix:@"."]) continue;

		NSNumber *isDirectory = nil;
		[fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
		
		NSString *extension = [[path pathExtension] lowercaseString];

		if ([isDirectory boolValue]) {
			if ([extension isEqualToString:@"app"] ||
				[extension isEqualToString:@"appex"] ||
				[extension isEqualToString:@"framework"]) {
				[results addObject:path];
			}
		} else {
			BOOL isMachO = NO;
			if ([extension isEqualToString:@"dylib"]) {
				isMachO = YES;
			} else {
				NSData *header = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
				if (header.length >= 4) {
					uint32_t magic = *(const uint32_t *)header.bytes;
					if (magic == 0xfeedface || magic == 0xcefaedfe || // 32-bit
						magic == 0xfeedfacf || magic == 0xcffaedfe || // 64-bit
						magic == 0xcafebabe || magic == 0xbebafeca) { // Universal/Fat
						isMachO = YES;
					}
				}
			}
			
			if (isMachO) {
				[results addObject:path];
			}
		}
	}

	if (![results containsObject:bundlePath]) {
		[results addObject:bundlePath];
	}

	[results sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
		NSUInteger countA = [[a pathComponents] count];
		NSUInteger countB = [[b pathComponents] count];
		
		if (countA > countB) return NSOrderedAscending;
		if (countA < countB) return NSOrderedDescending;
		return [a compare:b];
	}];

	return results;
}

static NSString * const kRootCA_PEM = // root ca
@"-----BEGIN CERTIFICATE-----\n"
"MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS\n"
"QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u\n"
"IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN\n"
"MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS\n"
"b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y\n"
"aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49\n"
"AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf\n"
"TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517\n"
"IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr\n"
"MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA\n"
"MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4\n"
"at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM\n"
"6BgD56KyKA==\n"
"-----END CERTIFICATE-----";

static NSString * const kIntermediateCA_PEM = // G3
@"-----BEGIN CERTIFICATE-----\n"
"MIIEUTCCAzmgAwIBAgIQfK9pCiW3Of57m0R6wXjF7jANBgkqhkiG9w0BAQsFADBi\n"
"MQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBw\n"
"bGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3Qg\n"
"Q0EwHhcNMjAwMjE5MTgxMzQ3WhcNMzAwMjIwMDAwMDAwWjB1MUQwQgYDVQQDDDtB\n"
"cHBsZSBXb3JsZHdpZGUgRGV2ZWxvcGVyIFJlbGF0aW9ucyBDZXJ0aWZpY2F0aW9u\n"
"IEF1dGhvcml0eTELMAkGA1UECwwCRzMxEzARBgNVBAoMCkFwcGxlIEluYy4xCzAJ\n"
"BgNVBAYTAlVTMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2PWJ/KhZ\n"
"C4fHTJEuLVaQ03gdpDDppUjvC0O/LYT7JF1FG+XrWTYSXFRknmxiLbTGl8rMPPbW\n"
"BpH85QKmHGq0edVny6zpPwcR4YS8Rx1mjjmi6LRJ7TrS4RBgeo6TjMrA2gzAg9Dj\n"
"+ZHWp4zIwXPirkbRYp2SqJBgN31ols2N4Pyb+ni743uvLRfdW/6AWSN1F7gSwe0b\n"
"5TTO/iK1nkmw5VW/j4SiPKi6xYaVFuQAyZ8D0MyzOhZ71gVcnetHrg21LYwOaU1A\n"
"0EtMOwSejSGxrC5DVDDOwYqGlJhL32oNP/77HK6XF8J4CjDgXx9UO0m3JQAaN4LS\n"
"VpelUkl8YDib7wIDAQABo4HvMIHsMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0j\n"
"BBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wRAYIKwYBBQUHAQEEODA2MDQGCCsG\n"
"AQUFBzABhihodHRwOi8vb2NzcC5hcHBsZS5jb20vb2NzcDAzLWFwcGxlcm9vdGNh\n"
"MC4GA1UdHwQnMCUwI6AhoB+GHWh0dHA6Ly9jcmwuYXBwbGUuY29tL3Jvb3QuY3Js\n"
"MB0GA1UdDgQWBBQJ/sAVkPmvZAqSErkmKGMMl+ynsjAOBgNVHQ8BAf8EBAMCAQYw\n"
"EAYKKoZIhvdjZAYCAQQCBQAwDQYJKoZIhvcNAQELBQADggEBAK1lE+j24IF3RAJH\n"
"Qr5fpTkg6mKp/cWQyXMT1Z6b0KoPjY3L7QHPbChAW8dVJEH4/M/BtSPp3Ozxb8qA\n"
"HXfCxGFJJWevD8o5Ja3T43rMMygNDi6hV0Bz+uZcrgZRKe3jhQxPYdwyFot30ETK\n"
"XXIDMUacrptAGvr04NM++i+MZp+XxFRZ79JI9AeZSWBZGcfdlNHAwWx/eCHvDOs7\n"
"bJmCS1JgOLU5gm3sUjFTvg+RTElJdI+mUcuER04ddSduvfnSXPN/wmwLCTbiZOTC\n"
"NwMUGdXqapSqqdv+9poIZ4vvK7iqF0mDr8/LvOnP6pVxsLRFoszlh6oKw0E6eVza\n"
"UDSdlTs=\n"
"-----END CERTIFICATE-----";

static SecCertificateRef CreateCertFromPEM(NSString *pem) {
	NSString *clean =
		[[pem componentsSeparatedByCharactersInSet:
		  [NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];

	clean = [clean stringByReplacingOccurrencesOfString:@"-----BEGIN CERTIFICATE-----" withString:@""];
	clean = [clean stringByReplacingOccurrencesOfString:@"-----END CERTIFICATE-----" withString:@""];

	NSData *der = [[NSData alloc] initWithBase64EncodedString:clean
													  options:NSDataBase64DecodingIgnoreUnknownCharacters];
	if (!der) return NULL;

	return SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)der);
}

static void AddCertToAppKeychainIfNeeded(SecCertificateRef cert) {
	if (!cert) return;

	NSDictionary *item = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassCertificate,
		(__bridge id)kSecValueRef: (__bridge id)cert,
		(__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock
	};

	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);

	if (status == errSecDuplicateItem) return;
	if (status != errSecSuccess) {
		NSLog(@"SecItemAdd failed: %d", (int)status);
	}
}

int codesignAllNested(NSString *bundlePath,
					  const char *p12Path,
					  const char *p12Password,
					  const char *mobileProvisionPath,
                      NSDictionary *entitlements) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		SecCertificateRef rootCert = CreateCertFromPEM(kRootCA_PEM);
		SecCertificateRef intermediateCert = CreateCertFromPEM(kIntermediateCA_PEM);

		AddCertToAppKeychainIfNeeded(rootCert);
		AddCertToAppKeychainIfNeeded(intermediateCert);

		if (rootCert) CFRelease(rootCert);
		if (intermediateCert) CFRelease(intermediateCert);
	});

	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSString *rootExtension = [[bundlePath pathExtension] lowercaseString];
	if (mobileProvisionPath && ([rootExtension isEqualToString:@"app"] || [rootExtension isEqualToString:@"appex"])) {
		NSString *destPath = [bundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"];
		[fm removeItemAtPath:destPath error:nil];
		NSError *copyError = nil;
		if (![fm copyItemAtPath:[NSString stringWithUTF8String:mobileProvisionPath]
						 toPath:destPath
						  error:&copyError]) {
			NSLog(@"Failed to copy mobileprovision to root: %@", copyError);
			return 408;
		}
	}
	
	NSArray<NSString *> *paths = allNestedCodePathsSorted(bundlePath);
	NSLog(@"Signing: %@", paths);
	for (NSString *path in paths) {
		NSLog(@"Signing: %@", path);
		
		NSString *extension = [[path pathExtension] lowercaseString];
		const char *provToUse = NULL;
		
		// Pass the mobileprovision ONLY if the current item is an app or extension
		// Frameworks and dylibs should generally NOT have entitlements applied directly from a provision
		if (mobileProvisionPath && ([extension isEqualToString:@"app"] || [extension isEqualToString:@"appex"])) {
			provToUse = mobileProvisionPath;
		}

		int status = codesign_sign_with_p12_and_mobileprovision(
			path.UTF8String,
			p12Path,
			p12Password,
			provToUse,
            entitlements
		);

		if (status != 0) {
			NSLog(@"Failed signing %@ with status %d", path, status);
			return status;
		}
	}
	return 0;
}


int codesign_sign_with_p12_and_mobileprovision(
	const char *appPath,
	const char *p12Path,
	const char *p12Password,
	const char * _Nullable mobileProvisionPath,
    NSDictionary *entitlements) {
    
	OSStatus (*__SecCodeSignerCreate)(CFDictionaryRef, SecCSFlags, SecCodeSignerRef *) =
		dlsym(RTLD_DEFAULT, "SecCodeSignerCreate");
	OSStatus (*__SecCodeSignerAddSignatureWithErrors)(SecCodeSignerRef, SecStaticCodeRef, SecCSFlags, CFErrorRef *) =
		dlsym(RTLD_DEFAULT, "SecCodeSignerAddSignatureWithErrors");

	if (!__SecCodeSignerCreate || !__SecCodeSignerAddSignatureWithErrors) {
		NSLog(@"Failed to load private SecCodeSigner symbols");
		return 404;
	}

	NSString *filePath = [NSString stringWithUTF8String:appPath];

	NSData *p12Data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:p12Path]];
	if (!p12Data) return 405;

	CFArrayRef items = NULL;
	NSDictionary *options = @{ (__bridge id)kSecImportExportPassphrase : [NSString stringWithUTF8String:p12Password] };
	OSStatus secStatus = SecPKCS12Import((__bridge CFDataRef)p12Data, (__bridge CFDictionaryRef)options, &items);
	if (secStatus != errSecSuccess || CFArrayGetCount(items) == 0) return 406;

	CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
	SecIdentityRef identity = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
	if (!identity) { CFRelease(items); return 407; }

	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	parameters[(__bridge NSString *)kSecCodeSignerIdentity] = (__bridge id)identity;

    NSDictionary *localEntitlements = entitlements;

	if (mobileProvisionPath) {
		NSData *mpData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:mobileProvisionPath]];
		if (mpData) {
			CMSDecoderRef decoder = NULL;
			if (CMSDecoderCreate(&decoder) == errSecSuccess &&
				CMSDecoderUpdateMessage(decoder, mpData.bytes, mpData.length) == errSecSuccess &&
				CMSDecoderFinalizeMessage(decoder) == errSecSuccess) {

				CFDataRef plistData = NULL;
				if (CMSDecoderCopyContent(decoder, &plistData) == errSecSuccess && plistData) {
					NSError *error = nil;
					NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:(__bridge NSData *)plistData
																					options:NSPropertyListImmutable
																					 format:nil
																					  error:&error];
					if (plist) {
                        NSMutableDictionary *entitlements = plist[@"Entitlements"];
						if (entitlements) {
                            [entitlements addEntriesFromDictionary:localEntitlements];
							NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlements
																						   format:NSPropertyListXMLFormat_v1_0
																						  options:0
																							error:nil];
							uint32_t entitlementsData[xmlData.length + 8];
							entitlementsData[0] = OSSwapHostToBigInt32(0xFADE7171);
							entitlementsData[1] = OSSwapHostToBigInt32((uint32_t)(xmlData.length + 8));
							[xmlData getBytes:&entitlementsData[2] length:xmlData.length];

							parameters[(__bridge NSString *)kSecCodeSignerEntitlements] =
								[NSData dataWithBytes:entitlementsData length:xmlData.length + 8];
						}
					}
					CFRelease(plistData);
				}
				CFRelease(decoder);
			}
		}
	}

	NSLog(@"Signer parameters: %@", parameters);
	SecCodeSignerRef signerRef = NULL;
	secStatus = __SecCodeSignerCreate((__bridge CFDictionaryRef)parameters, kSecCSDefaultFlags, &signerRef);
	if (secStatus != errSecSuccess || !signerRef) {
		NSLog(@"SecCodeSignerCreate failed! OSStatus = %d", (int)secStatus);
		CFRelease(items);
		return 201;
	}

	SecStaticCodeRef staticCode = NULL;
	secStatus = SecStaticCodeCreateWithPathAndAttributes((__bridge CFURLRef)[NSURL fileURLWithPath:filePath],
														 kSecCSDefaultFlags,
														 (__bridge CFDictionaryRef)@{},
														 &staticCode);
	if (secStatus != errSecSuccess || !staticCode) {
		NSLog(@"SecStaticCodeCreateWithPathAndAttributes failed! OSStatus = %d", (int)secStatus);
		CFRelease(signerRef);
		CFRelease(items);
		return 202;
	}

	CFErrorRef errorRef = NULL;
	secStatus = __SecCodeSignerAddSignatureWithErrors(signerRef, staticCode, kSecCSDefaultFlags, &errorRef);

	if (secStatus != errSecSuccess) {
		if (errorRef) {
			NSError *nsError = (__bridge NSError *)errorRef;
			NSLog(@"Error signing: %@ (OSStatus: %d)", nsError, (int)secStatus);
			if (nsError.userInfo) {
				for (NSString *key in nsError.userInfo) {
					NSLog(@"  %@: %@", key, nsError.userInfo[key]);
				}
			}
			CFRelease(errorRef);
		} else {
			NSLog(@"Error signing with unknown reason (OSStatus: %d)", (int)secStatus);
		}
		CFRelease(staticCode);
		CFRelease(signerRef);
		CFRelease(items);
		return 203;
	}

	CFRelease(staticCode);
	CFRelease(signerRef);
	CFRelease(items);

	return 0;
}
