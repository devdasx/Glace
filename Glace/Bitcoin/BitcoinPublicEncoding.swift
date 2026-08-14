import CryptoKit
import Foundation

enum BitcoinPublicEncodingError: Error, Equatable {
    case invalidBase58Character
    case invalidChecksum
    case invalidDataLength
    case invalidBech32
}

enum BitcoinPublicEncoding {
    private static let base58Alphabet = Array(
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8
    )
    private static let base58Indexes: [UInt8: Int] = Dictionary(
        uniqueKeysWithValues: base58Alphabet.enumerated().map { ($1, $0) }
    )
    private static let bech32Alphabet = Array(
        "qpzry9x8gf2tvdw0s3jn54khce6mua7l".utf8
    )
    private static let bech32Indexes: [UInt8: Int] = Dictionary(
        uniqueKeysWithValues: bech32Alphabet.enumerated().map { ($1, $0) }
    )

    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    static func doubleSHA256(_ data: Data) -> Data {
        sha256(sha256(data))
    }

    static func base58CheckDecode(_ value: String) throws -> Data {
        let decoded = try base58Decode(value)
        guard decoded.count >= 5 else {
            throw BitcoinPublicEncodingError.invalidDataLength
        }
        let payload = decoded.dropLast(4)
        let checksum = decoded.suffix(4)
        guard checksum.elementsEqual(doubleSHA256(Data(payload)).prefix(4)) else {
            throw BitcoinPublicEncodingError.invalidChecksum
        }
        return Data(payload)
    }

    static func base58Decode(_ value: String) throws -> Data {
        guard !value.isEmpty else {
            throw BitcoinPublicEncodingError.invalidDataLength
        }

        let input = Array(value.utf8)
        let leadingZeroCount = input.prefix { $0 == base58Alphabet[0] }.count
        var bytes = [UInt8]()

        for character in input {
            guard let characterValue = base58Indexes[character] else {
                throw BitcoinPublicEncodingError.invalidBase58Character
            }
            var carry = characterValue
            for index in bytes.indices.reversed() {
                let result = Int(bytes[index]) * 58 + carry
                bytes[index] = UInt8(result & 0xff)
                carry = result >> 8
            }
            while carry > 0 {
                bytes.insert(UInt8(carry & 0xff), at: 0)
                carry >>= 8
            }
        }
        return Data(repeating: 0, count: leadingZeroCount)
            + Data(bytes.drop { $0 == 0 })
    }

    static func decodeSegWitAddress(
        _ address: String
    ) throws -> (humanReadablePart: String, witnessVersion: UInt8, witnessProgram: Data) {
        let utf8 = Array(address.utf8)
        guard (8...90).contains(utf8.count),
              !utf8.contains(where: { $0 < 33 || $0 > 126 }) else {
            throw BitcoinPublicEncodingError.invalidBech32
        }

        let hasLowercase = address.unicodeScalars.contains {
            CharacterSet.lowercaseLetters.contains($0)
        }
        let hasUppercase = address.unicodeScalars.contains {
            CharacterSet.uppercaseLetters.contains($0)
        }
        guard !(hasLowercase && hasUppercase) else {
            throw BitcoinPublicEncodingError.invalidBech32
        }

        let normalized = address.lowercased()
        guard let separator = normalized.lastIndex(of: "1") else {
            throw BitcoinPublicEncodingError.invalidBech32
        }
        let hrp = String(normalized[..<separator])
        let payloadStart = normalized.index(after: separator)
        let characters = Array(normalized[payloadStart...].utf8)
        guard !hrp.isEmpty, characters.count >= 7 else {
            throw BitcoinPublicEncodingError.invalidBech32
        }

        let values = try characters.map { character -> UInt8 in
            guard let value = bech32Indexes[character] else {
                throw BitcoinPublicEncodingError.invalidBech32
            }
            return UInt8(value)
        }
        guard let witnessVersion = values.first, witnessVersion <= 16 else {
            throw BitcoinPublicEncodingError.invalidBech32
        }

        let checksum = polymod(hrpExpand(hrp) + values)
        let expectedChecksum: UInt32 = witnessVersion == 0 ? 1 : 0x2bc830a3
        guard checksum == expectedChecksum else {
            throw BitcoinPublicEncodingError.invalidChecksum
        }

        let programValues = Array(values.dropFirst().dropLast(6))
        let program = Data(
            try convertBits(programValues, from: 5, to: 8, pad: false)
        )
        guard (2...40).contains(program.count),
              witnessVersion != 0 || program.count == 20 || program.count == 32 else {
            throw BitcoinPublicEncodingError.invalidBech32
        }
        return (hrp, witnessVersion, program)
    }

    static func uint32(_ bytes: Data) throws -> UInt32 {
        guard bytes.count == 4 else {
            throw BitcoinPublicEncodingError.invalidDataLength
        }
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func hrpExpand(_ value: String) -> [UInt8] {
        let bytes = Array(value.utf8)
        return bytes.map { $0 >> 5 } + [0] + bytes.map { $0 & 31 }
    }

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        let generators: [UInt32] = [
            0x3b6a57b2,
            0x26508e6d,
            0x1ea119fa,
            0x3d4233dd,
            0x2a1462b3
        ]
        return values.reduce(UInt32(1)) { checksum, value in
            let top = checksum >> 25
            var next = ((checksum & 0x1ffffff) << 5) ^ UInt32(value)
            for index in 0..<5 where ((top >> index) & 1) == 1 {
                next ^= generators[index]
            }
            return next
        }
    }

    private static func convertBits(
        _ data: [UInt8],
        from sourceBits: Int,
        to destinationBits: Int,
        pad: Bool
    ) throws -> [UInt8] {
        var accumulator = 0
        var bitCount = 0
        var result = [UInt8]()
        let maximumValue = (1 << destinationBits) - 1
        let maximumAccumulator = (1 << (sourceBits + destinationBits - 1)) - 1

        for value in data {
            guard (Int(value) >> sourceBits) == 0 else {
                throw BitcoinPublicEncodingError.invalidBech32
            }
            accumulator = ((accumulator << sourceBits) | Int(value)) & maximumAccumulator
            bitCount += sourceBits
            while bitCount >= destinationBits {
                bitCount -= destinationBits
                result.append(UInt8((accumulator >> bitCount) & maximumValue))
            }
        }

        if pad {
            if bitCount > 0 {
                result.append(UInt8((accumulator << (destinationBits - bitCount)) & maximumValue))
            }
        } else if bitCount >= sourceBits
                    || ((accumulator << (destinationBits - bitCount)) & maximumValue) != 0 {
            throw BitcoinPublicEncodingError.invalidBech32
        }
        return result
    }
}
