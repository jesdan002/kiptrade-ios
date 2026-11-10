import Foundation

enum ApiError: Error {
    case sinConexion
    case sesionExpirada
    case mensaje(String)
    case respuestaInvalida
}

extension ApiError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sinConexion: return "No hubo conexión con el servidor. Revisa tu internet e inténtalo de nuevo."
        case .sesionExpirada: return "Tu sesión expiró. Vuelve a iniciar sesión."
        case .mensaje(let texto): return texto
        case .respuestaInvalida: return "Algo salió mal. Inténtalo de nuevo."
        }
    }
}

/// La puerta de la app a la API de Kiptrade AW: la misma base y las
/// mismas rutas que usa la app Android (mapa-kiptrade.md). El token
/// viaja en el encabezado Authorization y lo pone esta clase.
///
/// Regla de la casa (Android): un 401 NUNCA muestra el cuerpo
/// (`Unauthenticated.` del servidor): siempre es «sesión expirada».
/// El mensaje visible de un error = primer error de campo ?? message.
enum Api {
    static let base = "https://app.kiptrade.net/"

    private static var sesion: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }

    private static let decodificador = JSONDecoder()

    // MARK: - Auth y cuenta

    static func login(correo: String, contrasena: String) async throws -> RespuestaLogin {
        try await post("api/v1/login", cuerpo: [
            "email": correo.trimmingCharacters(in: .whitespaces),
            "password": contrasena,
            "timezone": TimeZone.current.identifier,
        ], respaldo: "Revisa tu correo y tu contraseña.")
    }

    static func usuario() async throws -> UsuarioDto {
        let r: RespuestaUsuario = try await get("api/v1/user", respaldo: "No se pudo cargar tu cuenta.")
        return r.user
    }

    static func logoutRemoto() async {
        _ = try? await postCrudo("api/v1/logout")
    }

    static func registroConfig() async -> RegistroConfig {
        (try? await get("api/v1/registro", respaldo: "")) ?? RegistroConfig(modo: "beta", requiereCodigo: true, diasPrueba: 14)
    }

    static func registro(nombre: String, correo: String, contrasena: String, confirmacion: String, codigo: String?, acepta: Bool) async throws -> MensajeDto {
        var cuerpo: [String: Any] = [
            "name": nombre,
            "email": correo.trimmingCharacters(in: .whitespaces),
            "password": contrasena,
            "password_confirmation": confirmacion,
            "terms": acepta,
            "timezone": TimeZone.current.identifier,
        ]
        if let codigo = codigo, !codigo.isEmpty { cuerpo["code"] = codigo }
        return try await post("api/v1/registro", cuerpo: cuerpo, respaldo: "No se pudo crear tu cuenta. Revisa los datos.")
    }

    static func recuperarContrasena(correo: String) async throws -> MensajeDto {
        try await post("api/v1/recuperar-contrasena", cuerpo: [
            "email": correo.trimmingCharacters(in: .whitespaces),
        ], respaldo: "No se pudo enviar el enlace. Inténtalo de nuevo.")
    }

    // MARK: - Panel

    static func panel(rango: String?, desde: String?, hasta: String?) async throws -> PanelDto {
        try await get("api/v1/panel" + sufijoQuery([("rango", rango), ("desde", desde), ("hasta", hasta)]),
                      respaldo: "No se pudo cargar tu panel.")
    }

    static func guardarDonas(_ claves: [String]) async throws -> MensajeDto {
        try await post("api/v1/panel/donas", cuerpo: ["donas": claves], respaldo: "No se pudieron guardar tus métricas.")
    }

    static func guardarTarjetas(_ claves: [String]) async throws -> MensajeDto {
        try await post("api/v1/panel/tarjetas", cuerpo: ["tarjetas": claves], respaldo: "No se pudo guardar tu panel.")
    }

    static func guardarBarra(_ secciones: [String]) async throws -> MensajeDto {
        try await post("api/v1/panel/barra", cuerpo: ["secciones": secciones], respaldo: "No se pudo guardar tu barra.")
    }

    // MARK: - Diario

    static func diario(query: [(String, String?)]) async throws -> DiarioDto {
        try await get("api/v1/diario" + sufijoQuery(query), respaldo: "No se pudieron cargar tus operaciones.")
    }

    static func mensual(mes: String?, ticker: String?) async throws -> MensualDto {
        try await get("api/v1/diario/mensual" + sufijoQuery([("mes", mes), ("ticker", ticker)]),
                      respaldo: "No se pudo cargar el mes.")
    }

    static func calendario(mes: String?) async throws -> CalendarioDto {
        try await get("api/v1/diario/calendario" + sufijoQuery([("mes", mes)]),
                      respaldo: "No se pudo cargar el calendario.")
    }

    static func detalleTrade(id: Int) async throws -> RespuestaTradeDetalle {
        try await get("api/v1/diario/\(id)", respaldo: "No se pudo cargar la operación.")
    }

    /// El PUT del trade va con las claves EN INGLES (contrato del servidor).
    static func guardarTrade(id: Int, cuerpo: [String: Any]) async throws -> MensajeDto {
        try await metodo("PUT", "api/v1/diario/\(id)", cuerpo: cuerpo, respaldo: "No se pudieron guardar los cambios.")
    }

    static func subirAudioTrade(id: Int, datos: Data) async throws -> MensajeDto {
        try await multipart("api/v1/diario/\(id)/audio",
                            partes: [(nombre: "audio", archivo: "nota.m4a", mime: "audio/mp4", datos: datos, texto: nil)],
                            respaldo: "No se pudo subir tu nota de voz.")
    }

    static func subirCapturaTrade(id: Int, datos: Data) async throws -> MensajeDto {
        try await multipart("api/v1/diario/\(id)/captura",
                            partes: [(nombre: "screenshot", archivo: "captura.jpg", mime: "image/jpeg", datos: datos, texto: nil)],
                            respaldo: "No se pudo subir la captura.")
    }

    static func borrarCapturaTrade(id: Int) async throws -> MensajeDto {
        try await metodo("DELETE", "api/v1/diario/\(id)/captura", cuerpo: nil, respaldo: "No se pudo quitar la captura.")
    }

    /// La captura guardada, con Bearer, desde la URL que se construye
    /// a mano con el contador de version (no viene en ningun DTO).
    static func descargarCaptura(id: Int, version: Int) async -> Data? {
        guard let url = URL(string: base + "api/v1/diario/\(id)/captura?v=\(version)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (datos, respuesta) = (try? await sesion.data(for: req)) ?? (nil, nil)
        guard let http = respuesta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return datos
    }

    static func exportarDiario() async -> Data? {
        try? await descargar("api/v1/diario/exportar")
    }

    static func exportarTodo() async -> Data? {
        try? await descargar("api/v1/exportar-todo")
    }

    // MARK: - Estadisticas

    static func estadisticas(query: [(String, String?)]) async throws -> EstadisticasDto {
        try await get("api/v1/estadisticas" + sufijoQuery(query), respaldo: "No se pudieron cargar tus estadísticas.")
    }

    // MARK: - Plan, Journal, Coach

    static func plan() async throws -> RespuestaPlan {
        try await get("api/v1/plan", respaldo: "No se pudo cargar tu plan.")
    }

    static func guardarPlan(_ cuerpo: [String: Any]) async throws -> RespuestaPlanGuardado {
        try await metodo("PUT", "api/v1/plan", cuerpo: cuerpo, respaldo: "No se pudo guardar tu plan.")
    }

    static func aplicarPlantilla(clave: String) async throws -> RespuestaPlanGuardado {
        try await post("api/v1/plan/plantilla", cuerpo: ["template": clave], respaldo: "No se pudo aplicar la plantilla.")
    }

    static func journal(fecha: String) async throws -> JournalDto {
        try await get("api/v1/journal" + sufijoQuery([("fecha", fecha)]), respaldo: "No se pudo cargar tu journal.")
    }

    /// El journal viaja con claves EN INGLES: entry_date / reflection.
    static func guardarJournal(fecha: String, reflexion: String?) async throws -> RespuestaJournalGuardado {
        var cuerpo: [String: Any] = ["entry_date": fecha]
        if let reflexion = reflexion { cuerpo["reflection"] = reflexion } else { cuerpo["reflection"] = NSNull() }
        return try await post("api/v1/journal", cuerpo: cuerpo, respaldo: "No se pudo guardar tu reflexión.")
    }

    static func subirAudioJournal(fecha: String, datos: Data) async throws -> MensajeDto {
        try await multipart("api/v1/journal/audio",
                            partes: [(nombre: "audio", archivo: "nota.m4a", mime: "audio/mp4", datos: datos, texto: nil),
                                     (nombre: "date", archivo: nil, mime: nil, datos: nil, texto: fecha)],
                            respaldo: "No se pudo subir tu nota de voz.")
    }

    static func coach() async throws -> CoachDto {
        try await get("api/v1/coach", respaldo: "No se pudo cargar KipCoach.")
    }

    static func analizarCoach() async throws -> RespuestaAnalisis {
        try await post("api/v1/coach/analizar", cuerpo: [:], respaldo: "No se pudo generar el análisis.")
    }

    // MARK: - Broker, importar, membresia

    static func broker() async throws -> BrokerDto {
        try await get("api/v1/broker", respaldo: "No se pudo cargar tu conexión.")
    }

    static func portalBroker() async throws -> EnlaceDto {
        try await post("api/v1/broker/portal", cuerpo: [:], respaldo: "No se pudo abrir el portal.")
    }

    static func actualizarBroker() async throws -> MensajeDto {
        try await post("api/v1/broker/actualizar", cuerpo: [:], respaldo: "No se pudieron actualizar las conexiones.")
    }

    static func sincronizarCuenta(id: Int) async throws -> MensajeDto {
        try await post("api/v1/broker/cuentas/\(id)/sincronizar", cuerpo: [:], respaldo: "No se pudo sincronizar la cuenta.")
    }

    static func subirCsv(datos: Data) async throws -> ImportarSubidaDto {
        try await multipart("api/v1/importar",
                            partes: [(nombre: "csv", archivo: "trades.csv", mime: "text/csv", datos: datos, texto: nil)],
                            respaldo: "No se pudo subir el archivo.")
    }

    static func mapearImportar(token: String, mapeo: [String: Int]) async throws -> MensajeDto {
        try await post("api/v1/importar/mapear", cuerpo: ["token": token, "mapeo": mapeo], respaldo: "No se pudo guardar el mapeo.")
    }

    static func vistaPreviaImportar(token: String) async throws -> VistaPreviaDto {
        try await get("api/v1/importar/vista-previa" + sufijoQuery([("token", token)]), respaldo: "No se pudo cargar la vista previa.")
    }

    static func confirmarImportar(token: String) async throws -> RespuestaImportarResultado {
        try await post("api/v1/importar/confirmar", cuerpo: ["token": token], respaldo: "No se pudo terminar la importación.")
    }

    static func plantillaCsv() async -> Data? {
        try? await descargar("api/v1/importar/plantilla")
    }

    static func membresia() async throws -> MembresiaDto {
        try await get("api/v1/membresia", respaldo: "No se pudo cargar tu membresía.")
    }

    static func checkoutMembresia() async throws -> EnlaceDto {
        try await post("api/v1/membresia/checkout", cuerpo: [:], respaldo: "No se pudo abrir el pago.")
    }

    static func portalMembresia() async throws -> EnlaceDto {
        try await post("api/v1/membresia/portal", cuerpo: [:], respaldo: "No se pudo abrir tu suscripción.")
    }

    static func cancelarMembresia() async throws -> MensajeDto {
        try await post("api/v1/membresia/cancelar", cuerpo: [:], respaldo: "No se pudo cancelar la suscripción.")
    }

    // MARK: - Ajustes

    static func ajustes() async throws -> UsuarioAjustesDto {
        let r: RespuestaAjustes = try await get("api/v1/ajustes", respaldo: "No se pudieron cargar tus ajustes.")
        return r.user
    }

    static func guardarPerfil(nombre: String, correo: String, zona: String?) async throws -> RespuestaPerfil {
        var cuerpo: [String: Any] = ["name": nombre, "email": correo]
        if let zona = zona { cuerpo["timezone"] = zona }
        return try await metodo("PUT", "api/v1/ajustes/perfil", cuerpo: cuerpo, respaldo: "No se pudo guardar tu perfil.")
    }

    static func guardarPerfilTrading(apodo: String?, ciudad: String?, pais: String?, tamano: Double?) async throws -> RespuestaPerfil {
        let cuerpo: [String: Any] = [
            "nickname": apodo ?? NSNull(),
            "city": ciudad ?? NSNull(),
            "country": pais ?? NSNull(),
            "account_size": tamano ?? NSNull(),
        ]
        return try await metodo("PUT", "api/v1/ajustes/perfil-trading", cuerpo: cuerpo, respaldo: "No se pudo guardar tu perfil de trading.")
    }

    static func subirFoto(datos: Data) async throws -> RespuestaFoto {
        try await multipart("api/v1/ajustes/foto",
                            partes: [(nombre: "photo", archivo: "foto.jpg", mime: "image/jpeg", datos: datos, texto: nil)],
                            respaldo: "No se pudo subir tu foto.")
    }

    static func cambiarContrasena(actual: String, nueva: String, confirmacion: String) async throws -> MensajeDto {
        try await metodo("PUT", "api/v1/ajustes/contrasena", cuerpo: [
            "current_password": actual, "password": nueva, "password_confirmation": confirmacion,
        ], respaldo: "No se pudo cambiar tu contraseña.")
    }

    static func cambiarTema(_ tema: String) async throws -> MensajeDto {
        try await post("api/v1/ajustes/tema", cuerpo: ["tema": tema], respaldo: "No se pudo guardar el tema.")
    }

    /// DELETE con body (la contrasena): URLRequest con httpBody a mano.
    static func eliminarCuenta(contrasena: String) async throws -> MensajeDto {
        try await metodo("DELETE", "api/v1/ajustes/cuenta", cuerpo: ["password": contrasena], respaldo: "No se pudo eliminar tu cuenta.")
    }

    static func invitaciones() async throws -> [InvitacionDto] {
        let r: RespuestaInvitaciones = try await get("api/v1/invitaciones", respaldo: "No se pudieron cargar las invitaciones.")
        return r.invitaciones
    }

    static func crearInvitacion(correo: String?) async throws -> RespuestaCodigoInvitacion {
        var cuerpo: [String: Any] = [:]
        if let correo = correo, !correo.isEmpty { cuerpo["email"] = correo }
        return try await post("api/v1/invitaciones", cuerpo: cuerpo, respaldo: "No se pudo crear la invitación.")
    }

    static func revocarInvitacion(id: Int64) async throws -> MensajeDto {
        try await metodo("DELETE", "api/v1/invitaciones/\(id)", cuerpo: nil, respaldo: "No se pudo revocar la invitación.")
    }

    /// Mejora: la respuesta del servidor no se muestra (el exito es local,
    /// como en la Android); aqui solo importa que no lance.
    static func enviarMejora(tipo: String, intentabas: String, mensaje: String, correo: String?) async throws -> RespuestaMejora {
        var cuerpo: [String: Any] = [
            "tipo": tipo,
            "intentabas": intentabas,
            "mensaje": mensaje,
            "version": "ios \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")",
        ]
        if let correo = correo, !correo.isEmpty { cuerpo["email"] = correo }
        return try await post("api/v1/mejora", cuerpo: cuerpo, respaldo: "No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.")
    }

    // MARK: - Notificaciones y push

    static func notificaciones() async throws -> NotificacionesDto {
        try await get("api/v1/notificaciones", respaldo: "No se pudieron cargar tus avisos.")
    }

    static func leerNotificacion(id: Int64) async throws -> RespuestaOk {
        try await post("api/v1/notificaciones/\(id)/leer", cuerpo: [:], respaldo: "No se pudo marcar como leída.")
    }

    static func leerTodasNotificaciones() async throws -> RespuestaOk {
        try await post("api/v1/notificaciones/leer-todas", cuerpo: [:], respaldo: "No se pudieron marcar como leídas.")
    }

    static func preferenciasNotificaciones() async throws -> PreferenciasNotifDto {
        try await get("api/v1/notificaciones/preferencias", respaldo: "No se pudieron cargar tus preferencias.")
    }

    static func guardarPreferenciasNotificaciones(_ mapa: [String: Bool]) async throws -> PreferenciasNotifDto {
        try await metodo("PUT", "api/v1/notificaciones/preferencias", cuerpo: ["preferencias": mapa], respaldo: "No se pudieron guardar tus preferencias.")
    }

    static func registrarPush(token: String) async {
        _ = try? await post("api/v1/push/token", cuerpo: [
            "token": token, "plataforma": "ios", "nombre_dispositivo": "iPhone",
        ], respaldo: "") as RespuestaOk
    }

    /// La baja del push va ANTES de cerrar sesion, con la sesion viva.
    static func bajaPush(token: String) async {
        _ = try? await metodo("DELETE", "api/v1/push/token", cuerpo: ["token": token], respaldo: "") as RespuestaOk
    }

    // MARK: - Transporte generico

    typealias Parte = (nombre: String, archivo: String?, mime: String?, datos: Data?, texto: String?)

    private static func multipart<T: Decodable>(_ ruta: String, partes: [Parte], respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "POST"
        let frontera = "KipFrontera-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(frontera)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var cuerpo = Data()
        for parte in partes {
            cuerpo.append("--\(frontera)\r\n".data(using: .utf8)!)
            if let texto = parte.texto {
                cuerpo.append("Content-Disposition: form-data; name=\"\(parte.nombre)\"\r\n\r\n".data(using: .utf8)!)
                cuerpo.append("\(texto)\r\n".data(using: .utf8)!)
            } else if let datos = parte.datos {
                cuerpo.append("Content-Disposition: form-data; name=\"\(parte.nombre)\"; filename=\"\(parte.archivo ?? "archivo")\"\r\n".data(using: .utf8)!)
                cuerpo.append("Content-Type: \(parte.mime ?? "application/octet-stream")\r\n\r\n".data(using: .utf8)!)
                cuerpo.append(datos)
                cuerpo.append("\r\n".data(using: .utf8)!)
            }
        }
        cuerpo.append("--\(frontera)--\r\n".data(using: .utf8)!)
        req.httpBody = cuerpo
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func descargar(_ ruta: String) async throws -> Data {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesion.data(for: req)
        } catch {
            throw ApiError.sinConexion
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ApiError.respuestaInvalida }
        if http.statusCode == 401 { throw ApiError.sesionExpirada }
        if !(200..<300).contains(http.statusCode) { throw ApiError.mensaje(mensajeDeError(datos) ?? "No se pudo descargar.") }
        return datos
    }

    private static func sufijoQuery(_ pares: [(String, String?)]) -> String {
        let partes = pares.compactMap { (clave, valor) -> String? in
            guard let valor = valor,
                  let k = clave.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let v = valor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return "\(k)=\(v)"
        }
        return partes.isEmpty ? "" : "?" + partes.joined(separator: "&")
    }

    private static func metodo<T: Decodable>(_ nombre: String, _ ruta: String, cuerpo: [String: Any]?, respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = nombre
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cuerpo = cuerpo {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        }
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func get<T: Decodable>(_ ruta: String, respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func post<T: Decodable>(_ ruta: String, cuerpo: [String: Any], respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func postCrudo(_ ruta: String) async throws {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        _ = try await sesion.data(for: req)
    }

    private static func ejecutar<T: Decodable>(_ req: URLRequest, respaldo: String) async throws -> T {
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesion.data(for: req)
        } catch {
            throw ApiError.sinConexion
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ApiError.respuestaInvalida }
        if http.statusCode == 401 { throw ApiError.sesionExpirada }
        if !(200..<300).contains(http.statusCode) {
            throw ApiError.mensaje(mensajeDeError(datos) ?? respaldo)
        }
        do {
            return try decodificador.decode(T.self, from: datos)
        } catch {
            throw ApiError.respuestaInvalida
        }
    }

    /// El mensaje visible de un error de Laravel: el primer error de
    /// campo si viene `errors`, si no el `message`. El 401 nunca llega
    /// aqui (se corta antes).
    private static func mensajeDeError(_ datos: Data) -> String? {
        guard let objeto = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else { return nil }
        if let errores = objeto["errors"] as? [String: Any] {
            for clave in errores.keys.sorted() {
                if let lista = errores[clave] as? [String], let primero = lista.first { return primero }
            }
        }
        return objeto["message"] as? String
    }
}
