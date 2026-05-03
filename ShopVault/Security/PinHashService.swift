import Foundation
import CommonCrypto
import CryptoKit

struct PinHashService {
    private static let defaultIterations = 100_000
    private static let hashLength = 32
    private static let saltLength = 16

    func hash(pin: String, length: Int) -> String {
        guard pin.count == length, pin.allSatisfy(\.isNumber) else {
            return ""
        }

        let salt = Data((0..<Self.saltLength).map { _ in UInt8.random(in: 0...UInt8.max) })
        let derived = pbkdf2(pin: pin, salt: salt, iterations: Self.defaultIterations)
        return "v3l\(length)i\(Self.defaultIterations)$\(salt.hexString)$\(derived.hexString)"
    }

    func verify(pin: String, storedHash: String) -> Bool {
        if storedHash.hasPrefix("v3l") {
            let parts = storedHash.split(separator: "$")
            guard parts.count == 3,
                  let metadata = parts.first,
                  let pinLength = parseLength(from: String(metadata)),
                  let iterations = parseIterations(from: String(metadata)),
                  pin.count == pinLength,
                  pin.allSatisfy(\.isNumber),
                  let salt = Data(hexString: String(parts[1])),
                  let expected = Data(hexString: String(parts[2])) else {
                return false
            }

            let derived = pbkdf2(pin: pin, salt: salt, iterations: iterations)
            return constantTimeCompare(derived, expected)
        }

        if storedHash.hasPrefix("v2l") {
            let parts = storedHash.split(separator: "$")
            guard parts.count == 3,
                  let metadata = parts.first,
                  let pinLength = Int(String(metadata).replacingOccurrences(of: "v2l", with: "")),
                  pin.count == pinLength,
                  let salt = Data(hexString: String(parts[1])),
                  let expected = Data(hexString: String(parts[2])),
                  let pinData = pin.data(using: .utf8) else {
                return false
            }

            var input = Data()
            input.append(salt)
            input.append(pinData)
            let digest = Data(SHA256.hash(data: input))
            return constantTimeCompare(digest, expected)
        }

        if storedHash.hasPrefix("v2$") {
            let parts = storedHash.split(separator: "$")
            guard parts.count == 3,
                  pin.count == 6,
                  let salt = Data(hexString: String(parts[1])),
                  let expected = Data(hexString: String(parts[2])),
                  let pinData = pin.data(using: .utf8) else {
                return false
            }

            var input = Data()
            input.append(salt)
            input.append(pinData)
            let digest = Data(SHA256.hash(data: input))
            return constantTimeCompare(digest, expected)
        }

        guard pin.count == 6,
              let combinedData = Data(hexString: storedHash),
              combinedData.count == Self.saltLength + Self.hashLength else {
            return false
        }

        let salt = combinedData.prefix(Self.saltLength)
        let expected = combinedData.suffix(Self.hashLength)
        let derived = pbkdf2(pin: pin, salt: Data(salt), iterations: 10_000)
        return constantTimeCompare(derived, Data(expected))
    }

    func pinLength(from storedHash: String?) -> Int {
        guard let storedHash else { return 6 }

        if storedHash.hasPrefix("v3l") {
            return parseLength(from: storedHash) ?? 6
        }

        if storedHash.hasPrefix("v2l") {
            let prefix = storedHash.split(separator: "$").first.map(String.init) ?? ""
            return Int(prefix.replacingOccurrences(of: "v2l", with: "")) ?? 6
        }

        return 6
    }

    private func parseLength(from metadata: String) -> Int? {
        guard metadata.hasPrefix("v3l") else { return nil }
        let payload = metadata.replacingOccurrences(of: "v3l", with: "")
        guard let separatorIndex = payload.firstIndex(of: "i") else { return nil }
        return Int(payload[..<separatorIndex])
    }

    private func parseIterations(from metadata: String) -> Int? {
        guard metadata.hasPrefix("v3l") else { return nil }
        let payload = metadata.replacingOccurrences(of: "v3l", with: "")
        guard let separatorIndex = payload.firstIndex(of: "i") else { return nil }
        let iterationsString = payload[payload.index(after: separatorIndex)...]
        return Int(iterationsString)
    }

    private func pbkdf2(pin: String, salt: Data, iterations: Int) -> Data {
        var result = [UInt8](repeating: 0, count: Self.hashLength)
        let saltBytes = [UInt8](salt)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            pin,
            pin.utf8.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(iterations),
            &result,
            Self.hashLength
        )

        guard status == kCCSuccess else {
            return Data()
        }

        return Data(result)
    }

    private func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for index in 0..<lhs.count {
            diff |= lhs[index] ^ rhs[index]
        }
        return diff == 0
    }
}

private extension Data {
    init?(hexString: String) {
        self.init()

        let chars = Array(hexString)
        guard chars.count % 2 == 0 else { return nil }

        var index = 0
        while index < chars.count {
            let byteString = String(chars[index]) + String(chars[index + 1])
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            append(byte)
            index += 2
        }
    }

    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
