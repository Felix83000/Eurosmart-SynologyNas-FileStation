//
//  Keychain.h
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

#ifndef Keychain_h
#define Keychain_h

NSData *getPublicKeyBitsFromKey(SecKeyRef givenKey);

#endif /* Keychain_h */
