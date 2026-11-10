import SwiftUI
import PhotosUI

// Las vistas de Ajustes: Perfil, Barra, Notificaciones (preferencias),
// Mejora e Invitaciones. Los textos son los de la Android (mapa §3.12–3.16).

// MARK: - Perfil

@MainActor
final class PerfilModel: ObservableObject {
    @Published var usuario: UsuarioAjustesDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var aviso: String? = nil
    @Published var guardando = false
    @Published var nombre = ""
    @Published var correo = ""
    @Published var zona = "America/Chicago"
    @Published var apodo = ""
    @Published var ciudad = ""
    @Published var pais = ""
    @Published var tamano = ""
    private var sembradoPara: Int64 = -1

    func cargar() {
        cargando = true
        Task {
            do {
                let datos = try await Api.ajustes()
                usuario = datos
                if sembradoPara != datos.id {
                    sembradoPara = datos.id
                    nombre = datos.name
                    correo = datos.email
                    zona = datos.timezone ?? TimeZone.current.identifier
                    apodo = datos.nickname ?? ""
                    ciudad = datos.city ?? ""
                    pais = datos.country ?? ""
                    tamano = datos.accountSize.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
                }
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla {
                    Sesion.cerrar()
                    errorTexto = "Tu sesión expiró. Vuelve a iniciar sesión."
                } else if usuario == nil {
                    errorTexto = falla.errorDescription
                }
            } catch {
                cargando = false
                if usuario == nil { errorTexto = "Algo salió mal. Inténtalo de nuevo." }
            }
        }
    }

    private func accion(_ bloque: @escaping () async throws -> String) {
        if guardando { return }
        guardando = true
        aviso = nil
        errorTexto = nil
        Task {
            do {
                aviso = try await bloque()
                guardando = false
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
                guardando = false
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
                guardando = false
            }
        }
    }

    func guardarPerfil() {
        let nombreLocal = nombre.trimmingCharacters(in: .whitespaces)
        let correoLocal = correo.trimmingCharacters(in: .whitespaces)
        let zonaLocal = zona
        accion {
            let r = try await Api.guardarPerfil(nombre: nombreLocal, correo: correoLocal, zona: zonaLocal)
            Sesion.usuarioLocal = UsuarioGuardado(nombre: r.user.name, apodo: r.user.nickname, correo: r.user.email,
                                                  verificado: r.user.verificado, esAdmin: r.user.isAdmin,
                                                  avatarUrl: r.user.avatarUrl, barra: r.user.barra)
            return r.message
        }
    }

    func guardarPerfilTrading() {
        let apodoLocal = apodo.trimmingCharacters(in: .whitespaces)
        let ciudadLocal = ciudad.trimmingCharacters(in: .whitespaces)
        let paisLocal = pais.trimmingCharacters(in: .whitespaces)
        let tamanoLocal = Double(tamano.replacingOccurrences(of: ",", with: ""))
        accion {
            let r = try await Api.guardarPerfilTrading(apodo: apodoLocal.isEmpty ? nil : apodoLocal,
                                                       ciudad: ciudadLocal.isEmpty ? nil : ciudadLocal,
                                                       pais: paisLocal.isEmpty ? nil : paisLocal,
                                                       tamano: tamanoLocal)
            Sesion.usuarioLocal = UsuarioGuardado(nombre: r.user.name, apodo: r.user.nickname, correo: r.user.email,
                                                  verificado: r.user.verificado, esAdmin: r.user.isAdmin,
                                                  avatarUrl: r.user.avatarUrl, barra: r.user.barra)
            return r.message
        }
    }

    func subirFoto(_ datos: Data) {
        accion {
            let r = try await Api.subirFoto(datos: datos)
            return r.message
        }
    }

    func cambiarTema(_ tema: String) {
        accion {
            Sesion.tema = tema
            let r = try await Api.cambiarTema(tema)
            return r.message
        }
    }
}

/// Las 19 zonas del selector de la Android.
let zonasHorariasKip: [(clave: String, etiqueta: String)] = [
    ("America/New_York", "Nueva York (Este)"), ("America/Chicago", "Chicago / Dallas (Central)"),
    ("America/Denver", "Denver (Montaña)"), ("America/Phoenix", "Phoenix (Arizona)"),
    ("America/Los_Angeles", "Los Ángeles (Pacífico)"), ("America/Anchorage", "Anchorage (Alaska)"),
    ("Pacific/Honolulu", "Honolulu (Hawái)"), ("America/Toronto", "Toronto"),
    ("America/Mexico_City", "Ciudad de México"), ("America/Tijuana", "Tijuana"),
    ("America/Bogota", "Bogotá"), ("America/Lima", "Lima"), ("America/Santiago", "Santiago"),
    ("America/Argentina/Buenos_Aires", "Buenos Aires"), ("America/Caracas", "Caracas"),
    ("America/Santo_Domingo", "Santo Domingo"), ("America/Puerto_Rico", "Puerto Rico"),
    ("Europe/Madrid", "Madrid"), ("UTC", "UTC"),
]

struct VistaPerfil: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = PerfilModel()
    @State private var fotoElegida: PhotosPickerItem? = nil
    @State private var passActual = ""
    @State private var passNueva = ""
    @State private var passConfirma = ""
    @State private var errorLocal: String? = nil
    @State private var confirmarBorrado = false
    @State private var passBorrado = ""
    @State private var exportando = false
    @State private var archivoExportado: URL? = nil
    var alCerrarSesion: () -> Void = {}
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.cargando && modelo.usuario == nil {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let usuario = modelo.usuario {
                ScrollView {
                    VStack(spacing: 12) {
                        if let aviso = modelo.aviso {
                            Text(aviso)
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(KipColor.verdePnl(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let error = modelo.errorTexto ?? errorLocal {
                            Text(error)
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(KipColor.error(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        tarjetaCuenta(usuario)
                        tarjetaPerfil
                        tarjetaPerfilTrading
                        tarjetaApariencia(usuario)
                        tarjetaContrasena
                        tarjetaLegales
                        tarjetaDatos
                        tarjetaEliminar
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            } else {
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudieron cargar tus ajustes.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.usuario == nil { modelo.cargar() } }
        .onChange(of: fotoElegida) { _, nuevo in
            guard let nuevo = nuevo else { return }
            Task {
                if let datos = try? await nuevo.loadTransferable(type: Data.self) {
                    // La foto se sube tal cual, sin reducir (Android).
                    modelo.subirFoto(datos)
                    modelo.cargar()
                }
                fotoElegida = nil
            }
        }
        .sheet(item: $archivoExportado) { url in
            HojaCompartir(elementos: [url])
        }
        .confirmationDialog("¿Eliminar tu cuenta?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
            TextField("Tu contraseña", text: $passBorrado)
            Button("Eliminar para siempre", role: .destructive) { eliminarCuenta() }
                .disabled(passBorrado.isEmpty || modelo.guardando)
            Button("Cancelar", role: .cancel) { passBorrado = "" }
        } message: {
            Text("Se borran tu diario, tu plan, tus conexiones y tu foto. Escribe tu contraseña para confirmar.")
        }
    }

    private func tarjetaCuenta(_ usuario: UsuarioAjustesDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Tu cuenta")
                HStack(spacing: 12) {
                    AvatarKip(urlTexto: usuario.avatarUrl, nombre: usuario.nickname ?? usuario.name, tamano: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(usuario.nickname ?? usuario.name)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(usuario.email)
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        PhotosPicker(selection: $fotoElegida, matching: .images) {
                            Text("Cambiar foto")
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(KipColor.accent)
                        }
                    }
                }
            }
        }
    }

    private var tarjetaPerfil: some View {
        let opcionesZona: [(clave: String, etiqueta: String)] = {
            var lista = zonasHorariasKip
            if !lista.contains(where: { $0.clave == modelo.zona }) {
                lista.insert((modelo.zona, modelo.zona), at: 0)
            }
            return lista
        }()
        return KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Perfil")
                CampoKip(etiqueta: "Nombre", texto: $modelo.nombre)
                CampoKip(etiqueta: "Correo", texto: $modelo.correo, teclado: .emailAddress, autocapitalizacion: .never)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zona horaria")
                        .font(.manrope(13, weight: .semibold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Menu {
                        ForEach(opcionesZona, id: \.clave) { opcion in
                            Button(opcion.etiqueta) { modelo.zona = opcion.clave }
                        }
                    } label: {
                        HStack {
                            Text(opcionesZona.first { $0.clave == modelo.zona }?.etiqueta ?? modelo.zona)
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(KipColor.card(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                Text("Tu día de trading (Journal, límites y KipCoach) se calcula con esta zona. Al entrar, la app adopta sola la de tu teléfono.")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Text("Si cambias el correo, te enviamos un enlace al nuevo para verificarlo; sin verificarlo no podrás volver a entrar.")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                BotonKip(texto: "Guardar perfil", deshabilitado: modelo.guardando) { modelo.guardarPerfil() }
            }
        }
    }

    private var tarjetaPerfilTrading: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Perfil de trading")
                CampoKip(etiqueta: "Apodo (como te ves en la app)", texto: $modelo.apodo)
                CampoKip(etiqueta: "Ciudad", texto: $modelo.ciudad)
                CampoKip(etiqueta: "País", texto: $modelo.pais)
                CampoKip(etiqueta: "Tamaño de cuenta (USD)", texto: $modelo.tamano, teclado: .decimalPad)
                BotonKip(texto: "Guardar perfil de trading", deshabilitado: modelo.guardando) { modelo.guardarPerfilTrading() }
            }
        }
    }

    private func tarjetaApariencia(_ usuario: UsuarioAjustesDto) -> some View {
        let temaActual = Sesion.tema ?? usuario.tema ?? "dark"
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Apariencia")
                HStack(spacing: 8) {
                    BotonBordeKip(texto: "Oscuro", deshabilitado: temaActual == "dark" || modelo.guardando) { modelo.cambiarTema("dark") }
                    BotonBordeKip(texto: "Claro", deshabilitado: temaActual == "light" || modelo.guardando) { modelo.cambiarTema("light") }
                }
                Text("El tema se guarda en tu cuenta y se aplica igual en la web y en la app.")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private var tarjetaContrasena: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Contraseña")
                CampoKip(etiqueta: "Contraseña actual", texto: $passActual, esContrasena: true, autocapitalizacion: .never)
                CampoKip(etiqueta: "Contraseña nueva", texto: $passNueva, esContrasena: true, autocapitalizacion: .never)
                CampoKip(etiqueta: "Confirmar la nueva", texto: $passConfirma, esContrasena: true, autocapitalizacion: .never)
                BotonKip(texto: "Cambiar contraseña", deshabilitado: modelo.guardando) { cambiarContrasena() }
            }
        }
    }

    private var tarjetaLegales: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 6) {
                TituloTarjeta(texto: "Ayuda y legales")
                enlaceLegal("Términos del servicio", "https://app.kiptrade.net/terminos")
                enlaceLegal("Política de privacidad", "https://app.kiptrade.net/privacidad")
                enlaceLegal("Contacto", "https://app.kiptrade.net/contacto")
            }
        }
    }

    private func enlaceLegal(_ texto: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Text(texto)
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(KipColor.accent)
        }
    }

    private var tarjetaDatos: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Tus datos")
                Text("Descarga todo lo tuyo en un solo archivo: tus operaciones con sus notas, tu diario personal, tu plan y los datos de tu cuenta. Tus datos son tuyos, siempre.")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                BotonKip(texto: exportando ? "Preparando…" : "Exportar todos mis datos", deshabilitado: exportando) { exportar() }
            }
        }
    }

    private var tarjetaEliminar: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Eliminar cuenta")
                Text("Borra tu cuenta y todos tus datos de Kiptrade de forma permanente. No se puede deshacer.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.text(scheme))
                Button { confirmarBorrado = true } label: {
                    Text("Eliminar mi cuenta")
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(KipColor.error(scheme))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cambiarContrasena() {
        if passNueva != passConfirma {
            errorLocal = "La contraseña nueva y su confirmación no coinciden."
            return
        }
        errorLocal = nil
        let actual = passActual
        let nueva = passNueva
        let confirma = passConfirma
        Task {
            do {
                let r = try await Api.cambiarContrasena(actual: actual, nueva: nueva, confirmacion: confirma)
                modelo.aviso = r.message
                passActual = ""
                passNueva = ""
                passConfirma = ""
            } catch let falla as ApiError {
                modelo.errorTexto = falla.errorDescription
            } catch {
                modelo.errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    private func exportar() {
        exportando = true
        Task {
            if let datos = await Api.exportarTodo() {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiptrade-mis-datos.zip")
                try? datos.write(to: url)
                archivoExportado = url
            }
            exportando = false
        }
    }

    private func eliminarCuenta() {
        let contrasena = passBorrado
        passBorrado = ""
        Task {
            do {
                _ = try await Api.eliminarCuenta(contrasena: contrasena)
                alCerrarSesion()
            } catch let falla as ApiError {
                modelo.errorTexto = falla.errorDescription
            } catch {
                modelo.errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }
}

// MARK: - Barra de navegacion

struct VistaBarra: View {
    @Environment(\.colorScheme) private var scheme
    @State private var laterales: [String] = Destino.laterales(desde: Sesion.usuarioLocal?.barra ?? ["panel", "diario", "estadisticas", "coach", "plan"])
    @State private var estado: String? = nil
    @State private var esError = false
    var alCambiarBarra: ([String]) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("El Panel queda fijo en el centro de la barra, en el botón grande verde. Aquí ordenas los cuatro botones de los lados arrastrando: los dos primeros quedan a la izquierda del Panel y los otros dos a la derecha. Tu orden se guarda en tu cuenta y te sigue a cualquier teléfono.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                vistaPrevia
                Text("Arrastra para reordenar (se guarda al terminar de mover):")
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                List {
                    ForEach(laterales, id: \.self) { clave in
                        HStack(spacing: 10) {
                            Image(systemName: Destino.iconos[clave] ?? "circle")
                                .foregroundStyle(KipColor.accent)
                            Text(Destino.etiquetas[clave] ?? clave)
                                .font(.manrope(15, weight: .semibold))
                                .foregroundStyle(KipColor.text(scheme))
                        }
                        .listRowBackground(KipColor.card(scheme))
                    }
                    .onMove { desde, hasta in
                        laterales.move(fromOffsets: desde, toOffset: hasta)
                        guardar()
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .frame(height: 230)
                .scrollContentBackground(.hidden)
                if let estado = estado {
                    Text(estado)
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(esError ? KipColor.error(scheme) : KipColor.verdePnl(scheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .task {
            if let u = try? await Api.usuario() {
                let nuevos = Destino.laterales(desde: u.barra)
                if !nuevos.isEmpty { laterales = nuevos }
            }
        }
    }

    private var vistaPrevia: some View {
        HStack(spacing: 4) {
            ForEach(Array(laterales.prefix(2).enumerated()), id: \.offset) { _, clave in
                previaIcono(clave)
            }
            ZStack {
                Circle().fill(degradadoMarca).frame(width: 44, height: 44)
                Image(systemName: "house.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(KipColor.onAccent)
            }
            .frame(maxWidth: .infinity)
            ForEach(Array(laterales.suffix(2).enumerated()), id: \.offset) { _, clave in
                previaIcono(clave)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(KipColor.card(scheme))
        .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(Capsule())
    }

    private func previaIcono(_ clave: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: Destino.iconos[clave] ?? "circle")
                .font(.system(size: 17))
            Text(Destino.etiquetas[clave] ?? clave)
                .font(.manrope(9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(KipColor.textSecondary(scheme))
        .frame(maxWidth: .infinity)
    }

    private func guardar() {
        estado = "Guardando…"
        esError = false
        let secciones = [laterales[0], laterales[1], "panel", laterales[2], laterales[3]]
        Task {
            do {
                let r = try await Api.guardarBarra(secciones)
                estado = r.message
                if var local = Sesion.usuarioLocal {
                    local.barra = secciones
                    Sesion.usuarioLocal = local
                }
                alCambiarBarra(secciones)
            } catch let falla as ApiError {
                estado = falla.errorDescription
                esError = true
            } catch {
                estado = "Algo salió mal. Inténtalo de nuevo."
                esError = true
            }
        }
    }
}

// MARK: - Notificaciones (preferencias)

struct VistaNotificacionesPref: View {
    @Environment(\.colorScheme) private var scheme
    @State private var datos: PreferenciasNotifDto? = nil
    @State private var sinLeer = 0
    @State private var cargando = false
    @State private var errorTexto: String? = nil
    var alIrANotificaciones: () -> Void = {}

    var body: some View {
        Group {
            if let datos = datos {
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Tus avisos viven en la campana del Panel. Estos interruptores mandan solo sobre el aviso que llega al teléfono (push): si apagas un canal, sus avisos siguen guardándose en el centro, sin empujar.")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(datos.canales) { canal in
                            KipCard {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(canal.titulo)
                                            .font(.manrope(15, weight: .bold))
                                            .foregroundStyle(KipColor.text(scheme))
                                        if !canal.detalle.isEmpty {
                                            Text(canal.detalle)
                                                .font(.manrope(12))
                                                .foregroundStyle(KipColor.textSecondary(scheme))
                                        }
                                    }
                                    Spacer()
                                    KipInterruptor(prendido: Binding(
                                        get: { datos.preferencias[canal.clave] ?? true },
                                        set: { _ in }
                                    )) { nuevo in
                                        alternar(canal: canal.clave, nuevo: nuevo)
                                    }
                                }
                            }
                        }
                        KipCard {
                            VStack(alignment: .leading, spacing: 10) {
                                TituloTarjeta(texto: "Mis avisos")
                                Text(sinLeer > 0 ? "Tienes \(sinLeer) sin leer." : "Estás al día: nada sin leer.")
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.text(scheme))
                                BotonBordeKip(texto: "Ver") { alIrANotificaciones() }
                            }
                        }
                        Text("El permiso de notificaciones del teléfono manda sobre todo esto: si iOS lo tiene apagado para Kiptrade, ningún push llega aunque el canal esté encendido.")
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { cargar() }
            } else if cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ErrorCarga(mensaje: errorTexto ?? "No se pudieron cargar tus preferencias.") { cargar() }
            }
        }
        .onAppear { if datos == nil { cargar() } }
    }

    private func cargar() {
        cargando = true
        Task {
            do {
                datos = try await Api.preferenciasNotificaciones()
                if let n = try? await Api.notificaciones() { sinLeer = n.sinLeer }
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if datos == nil { errorTexto = falla.errorDescription }
            } catch {
                cargando = false
                if datos == nil { errorTexto = "Algo salió mal. Inténtalo de nuevo." }
            }
        }
    }

    /// Guardado al tocar, con reversa local si el servidor falla.
    private func alternar(canal: String, nuevo: Bool) {
        guard var actual = datos else { return }
        let anterior = actual.preferencias[canal] ?? true
        actual.preferencias[canal] = nuevo
        datos = actual
        let mapa = actual.preferencias
        let respaldo = actual
        Task {
            do {
                datos = try await Api.guardarPreferenciasNotificaciones(mapa)
            } catch {
                var revertido = respaldo
                revertido.preferencias[canal] = anterior
                datos = revertido
            }
        }
    }
}

// MARK: - Ayudame a mejorar

struct VistaMejora: View {
    @Environment(\.colorScheme) private var scheme
    @State private var tipo: String? = nil
    @State private var intentabas = ""
    @State private var mensaje = ""
    @State private var correo = ""
    @State private var errorTexto: String? = nil
    @State private var enviado = false
    @State private var enviando = false

    private let tipos: [(clave: String, etiqueta: String)] = [
        ("no_se_entiende", "Algo no se entiende"), ("fallo", "Algo falló"),
        ("idea", "Tengo una idea"), ("otro", "Otro"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if enviado {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("¡Gracias! Tu mensaje ya va en camino.")
                            .font(.manrope(18, weight: .heavy))
                            .foregroundStyle(KipColor.text(scheme))
                        Text("Lo leo personalmente. Si dejaste tu correo, te respondo ahí mismo.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        BotonBordeKip(texto: "Escribir otro mensaje") {
                            enviado = false
                            tipo = nil
                            intentabas = ""
                            mensaje = ""
                            correo = ""
                        }
                    }
                } else {
                    Text("Kiptrade lo construye una sola persona, y cada mensaje de esta pantalla lo leo yo, el creador. Si algo no se entiende, algo falló o tienes una idea, cuéntamelo: es la forma más directa de mejorar la app.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Este espacio es solo sobre la app (pantallas, botones y textos). No es asesoría de operaciones: Kiptrade nunca recomienda qué comprar o vender. Solo llega tu mensaje y la versión de la app — nunca datos de tus operaciones ni de tu broker.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Text("¿Qué tipo de mensaje es?")
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(tipos, id: \.clave) { opcion in
                            Button { tipo = opcion.clave } label: {
                                Text(opcion.etiqueta)
                                    .font(.manrope(13, weight: .bold))
                                    .foregroundStyle(tipo == opcion.clave ? KipColor.onAccent : KipColor.textSecondary(scheme))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(tipo == opcion.clave ? KipColor.accent : KipColor.elevated(scheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    CampoKip(etiqueta: "¿Qué intentabas hacer?", texto: $intentabas, placeholder: "Ej.: conectar mi broker, revisar mi semana…")
                    CampoKip(etiqueta: "Tu mensaje", texto: $mensaje, multilinea: true, lineasMinimas: 4,
                             placeholder: "Cuéntalo con tus palabras, sin tecnicismos.")
                    CampoKip(etiqueta: "Tu correo (solo si quieres respuesta)", texto: $correo, teclado: .emailAddress, autocapitalizacion: .never)
                    if let error = errorTexto {
                        Text(error)
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.error(scheme))
                    }
                    BotonKip(texto: enviando ? "Enviando…" : "Enviar mensaje", deshabilitado: enviando) { enviar() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private func enviar() {
        if tipo == nil {
            errorTexto = "Elige qué tipo de mensaje es."
            return
        }
        if intentabas.trimmingCharacters(in: .whitespaces).isEmpty {
            errorTexto = "Cuéntame qué intentabas hacer."
            return
        }
        if mensaje.trimmingCharacters(in: .whitespaces).isEmpty {
            errorTexto = "Escribe tu mensaje."
            return
        }
        enviando = true
        errorTexto = nil
        let tipoLocal = tipo ?? "otro"
        Task {
            do {
                _ = try await Api.enviarMejora(tipo: tipoLocal, intentabas: intentabas, mensaje: mensaje,
                                               correo: correo.isEmpty ? nil : correo)
                enviado = true
                enviando = false
            } catch {
                errorTexto = "No se pudo enviar. Revisa tu conexión e inténtalo de nuevo."
                enviando = false
            }
        }
    }
}

// MARK: - Invitaciones (solo admin)

struct VistaInvitaciones: View {
    @Environment(\.colorScheme) private var scheme
    @State private var invitaciones: [InvitacionDto] = []
    @State private var cargando = false
    @State private var errorTexto: String? = nil
    @State private var aviso: String? = nil
    @State private var codigoNuevo: String? = nil
    @State private var correoNuevo = ""
    @State private var guardando = false
    @State private var revocarPendiente: InvitacionDto? = nil

    var body: some View {
        Group {
            if cargando && invitaciones.isEmpty {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        KipCard {
                            VStack(alignment: .leading, spacing: 10) {
                                TituloTarjeta(texto: "Crear invitación")
                                CampoKip(etiqueta: "Correo (opcional)", texto: $correoNuevo, teclado: .emailAddress, autocapitalizacion: .never)
                                BotonKip(texto: guardando ? "Creando…" : "Crear código", deshabilitado: guardando) { crear() }
                                if let codigo = codigoNuevo {
                                    HStack {
                                        Text(codigo)
                                            .font(.manrope(19, weight: .heavy))
                                            .foregroundStyle(KipColor.text(scheme))
                                        Spacer()
                                        Button {
                                            UIPasteboard.general.string = codigo
                                        } label: {
                                            Text("Copiar")
                                                .font(.manrope(14, weight: .bold))
                                                .foregroundStyle(KipColor.accent)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if let aviso = aviso {
                                    Text(aviso)
                                        .font(.manrope(14, weight: .semibold))
                                        .foregroundStyle(KipColor.verdePnl(scheme))
                                }
                                if let error = errorTexto {
                                    Text(error)
                                        .font(.manrope(14, weight: .semibold))
                                        .foregroundStyle(KipColor.error(scheme))
                                }
                            }
                        }
                        TituloTarjeta(texto: "Invitaciones recientes")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(invitaciones) { invitacion in
                            tarjetaInvitacion(invitacion)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { cargar() }
            }
        }
        .onAppear { if invitaciones.isEmpty { cargar() } }
        .confirmationDialog("¿Revocar esta invitación?", isPresented: Binding(
            get: { revocarPendiente != nil },
            set: { if !$0 { revocarPendiente = nil } }
        ), titleVisibility: .visible) {
            Button("Revocar", role: .destructive) {
                if let invitacion = revocarPendiente { revocar(invitacion) }
                revocarPendiente = nil
            }
            Button("Cancelar", role: .cancel) { revocarPendiente = nil }
        } message: {
            Text("El código dejará de funcionar de inmediato.")
        }
    }

    private func tarjetaInvitacion(_ invitacion: InvitacionDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(invitacion.codigo)
                        .font(.manrope(15, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    Text(invitacion.usada ? "Usada" : "Disponible")
                        .font(.manrope(12, weight: .bold))
                        .foregroundStyle(invitacion.usada ? KipColor.textSecondary(scheme) : KipColor.verdePnl(scheme))
                }
                Text(invitacion.usada
                     ? "Usada por \(invitacion.usadaPor ?? "—")"
                     : (invitacion.email.map { "Reservada para \($0)" } ?? "Sin correo asignado"))
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                if !invitacion.usada {
                    Button { revocarPendiente = invitacion } label: {
                        Text("Revocar")
                            .font(.manrope(13, weight: .bold))
                            .foregroundStyle(KipColor.rojoPnl(scheme))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cargar() {
        cargando = true
        Task {
            do {
                invitaciones = try await Api.invitaciones()
                cargando = false
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
                cargando = false
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
                cargando = false
            }
        }
    }

    private func crear() {
        guardando = true
        Task {
            do {
                let r = try await Api.crearInvitacion(correo: correoNuevo.isEmpty ? nil : correoNuevo)
                aviso = r.message
                codigoNuevo = r.codigo
                correoNuevo = ""
                guardando = false
                cargar()
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
                guardando = false
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
                guardando = false
            }
        }
    }

    private func revocar(_ invitacion: InvitacionDto) {
        Task {
            do {
                let r = try await Api.revocarInvitacion(id: invitacion.id)
                aviso = r.message
                cargar()
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }
}
