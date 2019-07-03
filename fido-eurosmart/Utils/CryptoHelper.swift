//
//  CryptoHelper.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation
import Security

@objc final class CryptoHelper: NSObject {
    
    static func verifyRegisterSignature(_ APDU: RegisterAPDU) ->  Bool {
        guard
            let certificate = APDU.certificate,
            let signature = APDU.signature,
            let keyHandle = APDU.keyHandle,
            let publicKey = APDU.publicKey,
            let extractedSignaturePoints = extractPointsFromSignature(signature as Data)
        else {
            return false
        }
        
        // Extract certificate publickey
        var trustRef: SecTrust? = nil
        let policy = SecPolicyCreateBasicX509()
        guard
            let certificateRef = SecCertificateCreateWithData(nil, certificate as CFData),
            SecTrustCreateWithCertificates(certificateRef, policy, &trustRef) == errSecSuccess &&
            trustRef != nil
        else {
            return false
        }
        let key = SecTrustCopyPublicKey(trustRef!)
        let certificatePublicKey = getPublicKeyBitsFromKey(key)

        // Check signature
        let crypto = GMEllipticCurveCrypto(forKey: certificatePublicKey)
        let data = NSMutableData()
        data.append([0x00] as [UInt8], length: 1)
        data.append(APDU.applicationParameter as Data)
        data.append(APDU.challenge as Data)
        data.append(keyHandle as Data)
        data.append(publicKey as Data)
        let extractedSignature = NSMutableData()
        extractedSignature.append(extractedSignaturePoints.r)
        extractedSignature.append(extractedSignaturePoints.s)
        return crypto!.hashSHA256AndVerifySignature(extractedSignature as Data?, for: data as Data?)
    }
    
    static func verifyAuthenticateSignature(_ APDU: AuthenticateAPDU) ->  Bool {
        guard
            let publicKey = APDU.registerAPDU.publicKey,
            let userPresenceFlag = APDU.userPresenceFlag,
            let counter = APDU.counter,
            let signature = APDU.signature,
            let extractedSignaturePoints = extractPointsFromSignature(signature as Data)
        else {
            return false
        }
        
        // Check signature
        let crypto = GMEllipticCurveCrypto(forKey: publicKey as Data?)
        let writer = DataWriter()
        writer.writeNextData(APDU.applicationParameter)
        writer.writeNextUInt8(userPresenceFlag)
        writer.writeNextBigEndianUInt32(counter)
        writer.writeNextData(APDU.challenge)
        let extractedSignature = NSMutableData()
        extractedSignature.append(extractedSignaturePoints.r)
        extractedSignature.append(extractedSignaturePoints.s)
        return crypto!.hashSHA256AndVerifySignature(extractedSignature as Data?, for: writer.data as Data?)
    }
    
    static func extractPointsFromSignature(_ signature: Data) -> (r: Data, s: Data)? {
        let reader = DataReader(data: signature)
        guard
            let _ = reader.readNextUInt8(), // 0x30
            let _ = reader.readNextUInt8(), // length
            let _ = reader.readNextUInt8(), // 0x20
            let rLength = reader.readNextUInt8(),
            let r = reader.readNextMutableDataOfLength(Int(rLength)),
            let _ = reader.readNextUInt8(), // 0x20
            let sLength = reader.readNextUInt8(),
            let s = reader.readNextMutableDataOfLength(Int(sLength))
        else {
            return nil
        }
        let rBytes = r.bytes.bindMemory(to: UInt8.self, capacity: r.length)
        if rBytes[0] == 0x00 {
            r.replaceBytes(in: NSMakeRange(0, 1), withBytes: nil, length: 0)
        }
        let sBytes = s.bytes.bindMemory(to: UInt8.self, capacity: s.length)
        if sBytes[0] == 0x00 {
            s.replaceBytes(in: NSMakeRange(0, 1), withBytes: nil, length: 0)
        }
        return (r as Data, s as Data)
    }
}
