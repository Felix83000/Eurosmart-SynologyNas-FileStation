//
//  TransportHelper.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation

final class TransportHelper {
    
    enum CommandType: UInt8 {
        case ping = 0x81
        case keepAlive = 0x82
        case message = 0x83
        case error = 0xbf
    }
    
    enum ChunkType {
        case ping
        case keepAlive
        case message
        case error
        case continuation
        case unknown
    }
    
    static func getChunkType(_ data: Data) -> ChunkType {
        let reader = DataReader(data: data)
        guard let byte = reader.readNextUInt8() else {
            return .unknown
        }
        
        if byte & 0x80 == 0 {
            return .continuation
        }
        
        switch byte {
        case CommandType.ping.rawValue: return .ping
        case CommandType.keepAlive.rawValue: return .keepAlive
        case CommandType.message.rawValue: return .message
        case CommandType.error.rawValue: return .error
        default: return .unknown
        }
    }
    
    static func split(_ data: Data, command: CommandType, chuncksize: Int) -> [Data]? {
        guard chuncksize >= 8 && data.count > 0 && data.count <= Int(UInt16.max) else { return nil }
        var chunks: [Data] = []
        var remainingLength = data.count
        var firstChunk = true
        var sequence: UInt8 = 0
        var offset = 0
        
        while remainingLength > 0 {
            var length = 0
            let writer = DataWriter()
            
            if firstChunk {
                writer.writeNextUInt8(command.rawValue)
                writer.writeNextBigEndianUInt16(UInt16(remainingLength))
                length = min(chuncksize - 3, remainingLength)
            }
            else {
                writer.writeNextUInt8(sequence)
                length = min(chuncksize - 1, remainingLength)
            }
            writer.writeNextData(data.subdata(in: offset..<(offset+length)))
            remainingLength -= length
            offset += length
            chunks.append(writer.data as Data)
            if !firstChunk {
                sequence += 1
            }
            firstChunk = false
        }
        return chunks
    }
    
    static func join(_ chunks: [Data], command: CommandType) -> Data? {
        let writer = DataWriter()
        var sequence: UInt8 = 0
        var length = -1
        var firstChunk = true
        
        for chunk in chunks {
            let reader = DataReader(data: chunk)

            if firstChunk {
                guard
                    let readCommand = reader.readNextUInt8(),
                    let readLength = reader.readNextBigEndianUInt16(),
                    readCommand == command.rawValue
                else
                    { return nil }
                
                length = Int(readLength)
                writer.writeNextData(chunk.subdata(in: 3..<chunk.count))
                length -= chunk.count - 3
                firstChunk = false
            }
            else {
                guard
                    let readSequence = reader.readNextUInt8(),
                    readSequence == sequence
                else
                    { return nil }
                
                writer.writeNextData(chunk.subdata(in: 1..<chunk.count))
                length -= chunk.count - 1
                sequence += 1
            }
        }
        if length != 0 {
            return nil
        }
        return writer.data as Data
    }
    
}
