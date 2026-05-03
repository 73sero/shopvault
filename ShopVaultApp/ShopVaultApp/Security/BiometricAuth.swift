import LocalAuthentication
import Foundation

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case authenticationFailed
    case userCancelled
    case lockedOut
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric data enrolled"
        case .authenticationFailed:
            return "Authentication failed"
        case .userCancelled:
            return "Authentication cancelled"
        case .lockedOut:
            return "Too many failed attempts. Try again later."
        case .unknown(let message):
            return message
        }
    }
}

class BiometricAuth {
    
    // MARK: - Public Methods
    
    /// Check if biometric authentication is available
    static func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get biometric type (FaceID, TouchID, or None)
    static func biometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Returns biometric type even when not enrolled/temporarily locked
    static func biometricTypeForSetup() -> LABiometryType {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType
        }

        if let error,
           error.domain == LAError.errorDomain,
           [LAError.biometryNotEnrolled.rawValue, LAError.biometryLockout.rawValue].contains(error.code) {
            return context.biometryType
        }

        return .none
    }
    
    /// Authenticate user with biometric
    static func authenticate(
        localizedReason: String = "Unlock ShopVault to access your private data"
    ) async -> Result<Void, BiometricError> {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            if let error = error {
                return .failure(mapLAError(error))
            }
            return .failure(.notAvailable)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: localizedReason
            )
            
            return success ? .success(()) : .failure(.authenticationFailed)
        } catch let error as NSError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
    
    /// Authenticate with biometric OR device passcode
    static func authenticateWithFallback(
        localizedReason: String = "Unlock ShopVault"
    ) async -> Result<Void, BiometricError> {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &error
        ) else {
            if let error = error {
                return .failure(mapLAError(error))
            }
            return .failure(.notAvailable)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: localizedReason
            )
            
            return success ? .success(()) : .failure(.authenticationFailed)
        } catch let error as NSError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
    
    // MARK: - Private Helpers
    
    private static func mapLAError(_ error: NSError) -> BiometricError {
        switch error.code {
        case LAError.authenticationFailed.rawValue:
            return .authenticationFailed
        case LAError.userCancel.rawValue, LAError.userFallback.rawValue:
            return .userCancelled
        case LAError.biometryNotAvailable.rawValue:
            return .notAvailable
        case LAError.biometryNotEnrolled.rawValue:
            return .notEnrolled
        case LAError.biometryLockout.rawValue:
            return .lockedOut
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
