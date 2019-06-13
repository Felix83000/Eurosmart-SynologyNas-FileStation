//
//  Keychain.h
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 17/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

#ifndef Keychain_h
#define Keychain_h

NSData *getPublicKeyBitsFromKey(SecKeyRef givenKey);

#endif /* Keychain_h */
