//
//  EntitlementsParser.swift
//  StosSign
//
//  Created by Stossy11 on 25/03/2025.
//

import Foundation
// import MachO
// Should be cross platform now

// Thank you: https://github.com/matrejek/SwiftEntitlements

private let MH_MAGIC: UInt32 = 0xfeedface
private let MH_MAGIC_64: UInt32 = 0xfeedfacf
private let FAT_MAGIC: UInt32 = 0xcafebabe
private let LC_CODE_SIGNATURE: UInt32 = 0x1d

private struct mach_header {
    var magic: UInt32
    var cputype: Int32
    var cpusubtype: Int32
    var filetype: UInt32
    var ncmds: UInt32
    var sizeofcmds: UInt32
    var flags: UInt32
}

private struct mach_header_64 {
    var magic: UInt32
    var cputype: Int32
    var cpusubtype: Int32
    var filetype: UInt32
    var ncmds: UInt32
    var sizeofcmds: UInt32
    var flags: UInt32
    var reserved: UInt32
}

private struct load_command {
    var cmd: UInt32
    var cmdsize: UInt32
}

private struct fat_header {
    var magic: UInt32
    var nfat_arch: UInt32
}

public class EntitlementsParser {

    public enum Error: Swift.Error {
        case binaryOpeningError
        case unknownBinaryFormat
        case codeSignatureCommandMissing
        case signatureReadingError
        case unsupportedFatBinary

        var localizedDescription: String {
            switch self {
            case .binaryOpeningError:
                return "Error while opening application binary for reading"
            case .unknownBinaryFormat:
                return "The binary format is not supported"
            case .codeSignatureCommandMissing:
                return "Unable to find code signature load command"
            case .signatureReadingError:
                return "Signature reading error occurred"
            case .unsupportedFatBinary:
                return "Fat application binaries are unsupported"
            }
        }
    }

    private struct CSSuperBlob {
        var magic: UInt32
        var lentgh: UInt32
        var count: UInt32
    }

    private struct CSBlob {
        var type: UInt32
        var offset: UInt32
    }

    private struct CSMagic {
        static let embeddedSignature: UInt32 = 0xfade0cc0
        static let embededEntitlements: UInt32 = 0xfade7171
    }

    private enum BinaryType {
        struct HeaderData {
            let headerSize: Int
            let commandCount: Int
        }
        case singleArch(headerInfo: HeaderData)
        case fat(header: fat_header)
    }

    private let binary: ApplicationBinary

    public init(_ binaryPath: String) throws {
        guard let binary = ApplicationBinary(binaryPath) else {
            throw Error.binaryOpeningError
        }
        self.binary = binary
    }

    private func getBinaryType(fromSliceStartingAt offset: UInt64 = 0) -> BinaryType? {
        binary.seek(to: offset)
        let header: mach_header = binary.read()
        let commandCount = Int(header.ncmds)
        switch header.magic {
        case MH_MAGIC:
            let data = BinaryType.HeaderData(headerSize: MemoryLayout<mach_header>.size,
                                             commandCount: commandCount)
            return .singleArch(headerInfo: data)
        case MH_MAGIC_64:
            let data = BinaryType.HeaderData(headerSize: MemoryLayout<mach_header_64>.size,
                                             commandCount: commandCount)
            return .singleArch(headerInfo: data)
        default:
            binary.seek(to: 0)
            let fatHeader: fat_header = binary.read()
            return CFSwapInt32(fatHeader.magic) == FAT_MAGIC ? .fat(header: fatHeader) : nil
        }
    }

    public func readEntitlements() throws -> Entitlements {
        switch getBinaryType() {
        case .singleArch(let headerInfo):
            let headerSize = headerInfo.headerSize
            let commandCount = headerInfo.commandCount
            return try readEntitlementsFromBinarySlice(startingAt: headerSize, cmdCount: commandCount)
        case .fat:
            return try readEntitlementsFromFatBinary()
        case .none:
            throw Error.unknownBinaryFormat
        }
    }

    private func readEntitlementsFromBinarySlice(startingAt offset: Int, cmdCount: Int) throws -> Entitlements {
        binary.seek(to: UInt64(offset))
        for _ in 0..<cmdCount {
            let command: load_command = binary.read()
            if command.cmd == LC_CODE_SIGNATURE {
                let signatureOffset: UInt32 = binary.read()
                return try readEntitlementsFromSignature(startingAt: signatureOffset)
            }
            binary.seek(to: binary.currentOffset + UInt64(command.cmdsize - UInt32(MemoryLayout<load_command>.size)))
        }
        throw Error.codeSignatureCommandMissing
    }

    private func readEntitlementsFromFatBinary() throws -> Entitlements {
        throw Error.unsupportedFatBinary
    }

    private func readEntitlementsFromSignature(startingAt offset: UInt32) throws -> Entitlements {
        binary.seek(to: UInt64(offset))
        let metaBlob: CSSuperBlob = binary.read()
        if CFSwapInt32(metaBlob.magic) == CSMagic.embeddedSignature {
            let metaBlobSize = UInt32(MemoryLayout<CSSuperBlob>.size)
            let blobSize = UInt32(MemoryLayout<CSBlob>.size)
            let itemCount = CFSwapInt32(metaBlob.count)
            for index in 0..<itemCount {
                let readOffset = UInt64(offset + metaBlobSize + index * blobSize)
                binary.seek(to: readOffset)
                let blob: CSBlob = binary.read()
                binary.seek(to: UInt64(offset + CFSwapInt32(blob.offset)))
                let blobMagic = CFSwapInt32(binary.read())
                if blobMagic == CSMagic.embededEntitlements {
                    let signatureLength = CFSwapInt32(binary.read())
                    let signatureData = binary.readData(ofLength: Int(signatureLength) - 8)
                    return Entitlements.entitlements(from: signatureData)
                }
            }
        }
        throw Error.signatureReadingError
    }
}

public class ApplicationBinary {

    private let handle: FileHandle

    public init?(_ path: String) {
        guard let binaryHandle = FileHandle(forReadingAtPath: path) else {
            return nil
        }
        handle = binaryHandle
    }

    var currentOffset: UInt64 { handle.offsetInFile }

    func seek(to offset: UInt64) {
        handle.seek(toFileOffset: offset)
    }

    func read<T>() -> T {
        handle.readData(ofLength: MemoryLayout<T>.size).withUnsafeBytes( { $0.load(as: T.self) })
    }

    func readData(ofLength length: Int) -> Data {
        handle.readData(ofLength: length)
    }

    deinit {
        handle.closeFile()
    }
}

public class Entitlements {

    public struct Key {

        let rawKey: String

        public init(_ name: String) {
            self.rawKey = name
        }
    }

   public static let empty: Entitlements = Entitlements([:])

    public let values: [String: Any]

    public init(_ values: [String: Any]) {
        self.values = values
    }

    public func value(forKey key: Entitlements.Key) -> Any? {
        values[key.rawKey]
    }

    class func entitlements(from data: Data) -> Entitlements {
        guard let rawValues = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return .empty
        }
        return Entitlements(rawValues)
    }
}
