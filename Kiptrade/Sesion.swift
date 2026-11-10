import Foundation
import Security

/// La sesion de Kiptrade iOS: el token de Sanctum vive en el Keychain
/// del aparato (nunca en archivos planos), igual que en la app Android
/// el token vive en su almacen cifrado. El servidor es la unica verdad.
///
/// «Recuerdame»: marcado (default) el token persiste en el Keychain;
/// sin marcar, la sesion vive solo en memoria y cualquier sesion
/// persistida anterior se borra.
///
/// Respaldo DEBUG: los builds de simulador corren sin firma y el
/// Keychain sin identidad falla con errSecMissingEntitlement (-34018);
/// en DEBUG, si el Keychain no confirma la escritura, el token cae a
/// UserDefaults. En Release solo Keychain.
enum Sesion {
    private static let servicio = "net.kiptrade.app"
    private static let cuentaToken = "token-api"
    private static let claveRespaldo = "kt-token-respaldo-debug"

    private static var tokenMemoria: String? = nil

    static var token: String? {
        get {
            if let t = tokenMemoria { return t }
            if let delLlavero = leer(cuentaToken) { return delLlavero }
            #if DEBUG
            return UserDefaults.standard.string(forKey: claveRespaldo)
            #else
            return nil
            #endif
        }
        set {
            tokenMemoria = newValue
            if let nuevo = newValue {
                if guardar(nuevo, cuenta: cuentaToken) {
                    #if DEBUG
                    UserDefaults.standard.removeObject(forKey: claveRespaldo)
                    #endif
                } else {
                    #if DEBUG
                    UserDefaults.standard.set(nuevo, forKey: claveRespaldo)
                    #endif
                }
            }
        }
    }

    /// Entrada con «Recuerdame» apagado: sesion solo en memoria y sin
    /// rastro persistido anterior.
    static func entrarSinRecordar(token: String) {
        borrarPersistido()
        tokenMemoria = token
    }

    static var haySesion: Bool { token != nil }

    static func cerrar() {
        tokenMemoria = nil
        borrarPersistido()
    }

    private static func borrarPersistido() {
        borrar(cuentaToken)
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: claveRespaldo)
        #endif
    }

    /// El usuario guardado en el telefono para pintar la cabecera sin
    /// esperar a la red (nombre, apodo, correo, verificado, admin).
    static var usuarioLocal: UsuarioGuardado? {
        get {
            guard let datos = UserDefaults.standard.data(forKey: "kt-usuario"),
                  let u = try? JSONDecoder().decode(UsuarioGuardado.self, from: datos) else { return nil }
            return u
        }
        set {
            if let nuevo = newValue, let datos = try? JSONEncoder().encode(nuevo) {
                UserDefaults.standard.set(datos, forKey: "kt-usuario")
            } else {
                UserDefaults.standard.removeObject(forKey: "kt-usuario")
            }
        }
    }

    /// El tema de la cuenta ("dark"/"light"); nil = seguir al sistema.
    static var tema: String? {
        get { UserDefaults.standard.string(forKey: "kt-tema") }
        set { UserDefaults.standard.set(newValue, forKey: "kt-tema") }
    }

    // MARK: - Keychain

    @discardableResult
    private static func guardar(_ valor: String, cuenta: String) -> Bool {
        let datos = Data(valor.utf8)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
        var alta = consulta
        alta[kSecValueData as String] = datos
        alta[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let estado = SecItemAdd(alta as CFDictionary, nil)
        if estado == errSecSuccess { return true }
        #if DEBUG
        NSLog("KT-DEBUG Sesion: Keychain SecItemAdd fallo con OSStatus %d; usando respaldo DEBUG", estado)
        #endif
        return false
    }

    private static func leer(_ cuenta: String) -> String? {
        var consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    private static func borrar(_ cuenta: String) {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }
}

/// La copia local del usuario (solo para pintar sin red).
struct UsuarioGuardado: Codable {
    var nombre: String
    var apodo: String?
    var correo: String
    var verificado: Bool
    var esAdmin: Bool
    var avatarUrl: String?
    var barra: [String]
}
