//
//  OpenSSL-Bridging.c
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

#include "OpenSSL-Bridge.h"

bool create_p12_data(const unsigned char *certData, int certDataLength,
                    const unsigned char *privateKeyData, int privateKeyDataLength,
                    const char *password,
                    unsigned char **outP12Data, size_t *outP12DataLength) {
    X509 *certificate = NULL;
    EVP_PKEY *privateKey = NULL;
    PKCS12 *outputP12 = NULL;
    BIO *p12Buffer = NULL;
    BIO *certBio = NULL;
    BIO *keyBio = NULL;
    bool result = false;
    
    static bool providersLoaded = false;
    if (!providersLoaded) {
        if (!OSSL_PROVIDER_load(NULL, "legacy")) {
            fprintf(stderr, "Warning: failed to load OpenSSL legacy provider\n");
        }
        if (!OSSL_PROVIDER_load(NULL, "default")) {
            fprintf(stderr, "Warning: failed to load OpenSSL default provider\n");
        }
        providersLoaded = true;
    }
    
    certBio = BIO_new_mem_buf((const void *)certData, certDataLength);
    if (!certBio) {
        fprintf(stderr, "Failed to create certificate BIO\n");
        goto cleanup;
    }
    
    certificate = PEM_read_bio_X509(certBio, NULL, NULL, NULL);
    if (!certificate) {
        BIO_free(certBio);
        certBio = BIO_new_mem_buf((const void *)certData, certDataLength);
        certificate = d2i_X509_bio(certBio, NULL);
        if (!certificate) {
            fprintf(stderr, "Failed to parse certificate as PEM or DER\n");
            goto cleanup;
        }
    }
    BIO_free(certBio);
    certBio = NULL;
    
    keyBio = BIO_new_mem_buf((const void *)privateKeyData, privateKeyDataLength);
    if (!keyBio) {
        fprintf(stderr, "Failed to create key BIO\n");
        goto cleanup;
    }
    
    privateKey = PEM_read_bio_PrivateKey(keyBio, NULL, NULL, NULL);
    if (!privateKey) {
        BIO_free(keyBio);
        keyBio = BIO_new_mem_buf((const void *)privateKeyData, privateKeyDataLength);
        
        const unsigned char *tempPtr = privateKeyData;
        privateKey = d2i_AutoPrivateKey(NULL, &tempPtr, privateKeyDataLength);
        if (!privateKey) {
            fprintf(stderr, "Failed to parse private key as PEM or DER\n");
            goto cleanup;
        }
    }
    BIO_free(keyBio);
    keyBio = NULL;
    
    if (!X509_check_private_key(certificate, privateKey)) {
        fprintf(stderr, "Private key does not match certificate\n");
        goto cleanup;
    }
    
    {
        char emptyString[] = "";
        const char *p12Password = (password && strlen(password) > 0) ? password : "";
        
        outputP12 = PKCS12_create((char *)p12Password,
                                  emptyString,
                                  privateKey,
                                  certificate,
                                  NULL,
                                  NID_pbe_WithSHA1And3_Key_TripleDES_CBC,
                                  NID_pbe_WithSHA1And40BitRC2_CBC,
                                  PKCS12_DEFAULT_ITER,
                                  PKCS12_DEFAULT_ITER,
                                  0);
        if (!outputP12) {
            fprintf(stderr, "PKCS12_create failed\n");
            goto cleanup;
        }
        
        if (!PKCS12_set_mac(outputP12, p12Password, -1, NULL, 0, PKCS12_DEFAULT_ITER, EVP_sha1())) {
            fprintf(stderr, "PKCS12_set_mac failed\n");
            goto cleanup;
        }
    }
    
    p12Buffer = BIO_new(BIO_s_mem());
    if (!p12Buffer) {
        fprintf(stderr, "Failed to create P12 buffer BIO\n");
        goto cleanup;
    }
    
    if (i2d_PKCS12_bio(p12Buffer, outputP12) != 1) {
        fprintf(stderr, "i2d_PKCS12_bio failed\n");
        goto cleanup;
    }
    
    {
        char *buffer = NULL;
        *outP12DataLength = BIO_get_mem_data(p12Buffer, &buffer);
        if (*outP12DataLength == 0) {
            fprintf(stderr, "No P12 data generated\n");
            goto cleanup;
        }
        
        *outP12Data = (unsigned char *)malloc(*outP12DataLength);
        if (!*outP12Data) {
            fprintf(stderr, "Failed to allocate memory for P12 data\n");
            goto cleanup;
        }
        memcpy(*outP12Data, buffer, *outP12DataLength);
    }
    
    result = true;
    
cleanup:
    if (certBio) {
        BIO_free(certBio);
    }
    if (keyBio) {
        BIO_free(keyBio);
    }
    if (certificate) {
        X509_free(certificate);
    }
    if (privateKey) {
        EVP_PKEY_free(privateKey);
    }
    if (outputP12) {
        PKCS12_free(outputP12);
    }
    if (p12Buffer) {
        BIO_free(p12Buffer);
    }

    return result;
}
