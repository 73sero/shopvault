import Foundation
import CommonCrypto
import CryptoKit

struct ExportEnvelope: Decodable {
    let format: String
    let version: Int
    let generated_at: String
    let kdf: KDFMetadata
    let cipher: CipherMetadata
    let payload_base64: String
}

struct KDFMetadata: Decodable {
    let name: String
    let iterations: Int
    let salt_base64: String
    let key_length_bytes: Int
}

struct CipherMetadata: Decodable {
    let name: String
    let payload_encoding: String
    let payload_layout: String
}

struct ExportPayload {
    let format: String
    let version: Int
    let exportedAt: String
    let strippedColumns: [String]
    let tables: [String: [[String: Any]]]
}

struct DecryptedExport {
    let sourceURL: URL
    let envelope: ExportEnvelope
    let payload: ExportPayload
}

enum DecodeError: LocalizedError {
    case fileUnreadable(String)
    case envelopeMalformed(String)
    case unsupportedFormat(String)
    case unsupportedVersion(Int)
    case unsupportedKDF(String)
    case unsupportedCipher(String)
    case invalidSalt
    case invalidPayloadBase64
    case kdfFailed(Int32)
    case decryptionFailed(String)
    case payloadMalformed(String)

    var errorDescription: String? {
        switch self {
        case .fileUnreadable(let detail):
            return "Datei kann nicht gelesen werden: \(detail)"
        case .envelopeMalformed(let detail):
            return "Envelope JSON ungültig: \(detail)"
        case .unsupportedFormat(let format):
            return "Unbekanntes Format: \(format)"
        case .unsupportedVersion(let version):
            return "Nicht unterstützte Envelope-Version: \(version)"
        case .unsupportedKDF(let name):
            return "Nicht unterstützter KDF: \(name)"
        case .unsupportedCipher(let name):
            return "Nicht unterstützter Cipher: \(name)"
        case .invalidSalt:
            return "Salt im Envelope ist kein valides Base64."
        case .invalidPayloadBase64:
            return "Verschlüsselter Payload ist kein valides Base64."
        case .kdfFailed(let status):
            return "PBKDF2 fehlgeschlagen (Status \(status))."
        case .decryptionFailed(let detail):
            return "Entschlüsselung fehlgeschlagen: \(detail). Falsches Passwort oder beschädigte Datei."
        case .payloadMalformed(let detail):
            return "Entschlüsselter Payload ungültig: \(detail)"
        }
    }
}

enum VaultExportDecoder {
    static let supportedEnvelopeFormat = "shopvault-encrypted-export"
    static let supportedPayloadFormat = "shopvault-export-payload"

    static func decode(fileURL: URL, passphrase: String) async throws -> DecryptedExport {
        try await Task.detached(priority: .userInitiated) {
            try decodeSync(fileURL: fileURL, passphrase: passphrase)
        }.value
    }

    private static func decodeSync(fileURL: URL, passphrase: String) throws -> DecryptedExport {
        let envelopeData: Data
        do {
            envelopeData = try Data(contentsOf: fileURL)
        } catch {
            throw DecodeError.fileUnreadable(error.localizedDescription)
        }

        let envelope: ExportEnvelope
        do {
            envelope = try JSONDecoder().decode(ExportEnvelope.self, from: envelopeData)
        } catch {
            throw DecodeError.envelopeMalformed(error.localizedDescription)
        }

        guard envelope.format == supportedEnvelopeFormat else {
            throw DecodeError.unsupportedFormat(envelope.format)
        }

        guard envelope.version == 1 else {
            throw DecodeError.unsupportedVersion(envelope.version)
        }

        guard envelope.kdf.name == "PBKDF2-HMAC-SHA256" else {
            throw DecodeError.unsupportedKDF(envelope.kdf.name)
        }

        guard envelope.cipher.name == "AES-256-GCM" else {
            throw DecodeError.unsupportedCipher(envelope.cipher.name)
        }

        guard let salt = Data(base64Encoded: envelope.kdf.salt_base64) else {
            throw DecodeError.invalidSalt
        }

        guard let ciphertext = Data(base64Encoded: envelope.payload_base64) else {
            throw DecodeError.invalidPayloadBase64
        }

        let key = try pbkdf2(
            password: passphrase,
            salt: salt,
            iterations: envelope.kdf.iterations,
            keyLength: envelope.kdf.key_length_bytes
        )

        let plaintext: Data
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
            plaintext = try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
        } catch {
            throw DecodeError.decryptionFailed(error.localizedDescription)
        }

        let payload = try parsePayload(plaintext)

        return DecryptedExport(sourceURL: fileURL, envelope: envelope, payload: payload)
    }

    private static func parsePayload(_ data: Data) throws -> ExportPayload {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw DecodeError.payloadMalformed("JSON parse: \(error.localizedDescription)")
        }

        guard let root = json as? [String: Any] else {
            throw DecodeError.payloadMalformed("Root ist kein Objekt")
        }

        guard let format = root["format"] as? String, format == supportedPayloadFormat else {
            throw DecodeError.payloadMalformed("payload format unbekannt")
        }

        let version = (root["version"] as? Int) ?? -1
        guard version == 1 else {
            throw DecodeError.payloadMalformed("payload version \(version) nicht unterstützt")
        }

        let exportedAt = (root["exported_at"] as? String) ?? ""
        let strippedColumns = (root["stripped_columns"] as? [String]) ?? []

        guard let rawTables = root["tables"] as? [String: [[String: Any]]] else {
            throw DecodeError.payloadMalformed("tables fehlt oder ungültig")
        }

        return ExportPayload(
            format: format,
            version: version,
            exportedAt: exportedAt,
            strippedColumns: strippedColumns,
            tables: rawTables
        )
    }

    private static func pbkdf2(
        password: String,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derived = [UInt8](repeating: 0, count: keyLength)
        let passwordBytes = Array(password.utf8)
        let saltBytes = Array(salt)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBytes,
            passwordBytes.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(iterations),
            &derived,
            keyLength
        )

        guard status == kCCSuccess else {
            throw DecodeError.kdfFailed(status)
        }

        return Data(derived)
    }
}
