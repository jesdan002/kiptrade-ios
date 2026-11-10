import SwiftUI
import PhotosUI
import LinkPresentation

// Ajustes (el destino «ajustes»/Mas de la Android, mapa §3.9–3.16):
// menu con las filas exactas y las vistas internas Broker, Importar,
// Membresia, Perfil, Invitaciones (solo admin), Barra, Mejora y
// Notificaciones. El cobro es SOLO por la web: checkout y portal se
// abren como enlaces externos en Safari.

enum VistaAjustes: Equatable {
    case menu, broker, importar, membresia, perfil, invitaciones, barra, mejora, notificaciones
}

struct AjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var vista: VistaAjustes
    var vistaInicial: VistaAjustes = .menu

    init(vistaInicial: VistaAjustes = .menu,
         alCerrarSesion: @escaping () -> Void = {},
         alIrAlPlan: @escaping () -> Void = {},
         alIrAlDiario: @escaping () -> Void = {},
         alIrANotificaciones: @escaping () -> Void = {},
         alCambiarBarra: @escaping ([String]) -> Void = { _ in },
         alEntrarDeNuevo: @escaping () -> Void = {}) {
        _vista = State(initialValue: vistaInicial)
        self.vistaInicial = vistaInicial
        self.alCerrarSesion = alCerrarSesion
        self.alIrAlPlan = alIrAlPlan
        self.alIrAlDiario = alIrAlDiario
        self.alIrANotificaciones = alIrANotificaciones
        self.alCambiarBarra = alCambiarBarra
        self.alEntrarDeNuevo = alEntrarDeNuevo
    }
    var alCerrarSesion: () -> Void = {}
    var alIrAlPlan: () -> Void = {}
    var alIrAlDiario: () -> Void = {}
    var alIrANotificaciones: () -> Void = {}
    var alCambiarBarra: ([String]) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}

    private var tituloVista: String {
        switch vista {
        case .menu: return "Ajustes"
        case .broker: return "Conectar broker"
        case .importar: return "Importar CSV"
        case .membresia: return "Membresía"
        case .perfil: return "Perfil"
        case .invitaciones: return "Invitaciones"
        case .barra: return "Barra de navegación"
        case .mejora: return "Ayúdame a mejorar"
        case .notificaciones: return "Notificaciones"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if vista != .menu {
                    Button { vista = .menu } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                Text(tituloVista)
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            switch vista {
            case .menu:
                MenuAjustes(alElegir: { vista = $0 },
                            alCerrarSesion: alCerrarSesion,
                            alIrAlPlan: alIrAlPlan,
                            alIrAlDiario: alIrAlDiario)
            case .broker:
                VistaBroker()
            case .importar:
                VistaImportar(alIrAlDiario: alIrAlDiario)
            case .membresia:
                VistaMembresia()
            case .perfil:
                VistaPerfil(alCerrarSesion: alCerrarSesion, alEntrarDeNuevo: alEntrarDeNuevo)
            case .invitaciones:
                VistaInvitaciones()
            case .barra:
                VistaBarra(alCambiarBarra: alCambiarBarra)
            case .mejora:
                VistaMejora()
            case .notificaciones:
                VistaNotificacionesPref(alIrANotificaciones: alIrANotificaciones)
            }
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
    }
}

// MARK: - Menu de Ajustes

struct MenuAjustes: View {
    @Environment(\.colorScheme) private var scheme
    @State private var usuario: UsuarioDto? = nil
    var alElegir: (VistaAjustes) -> Void = { _ in }
    var alCerrarSesion: () -> Void = {}
    var alIrAlPlan: () -> Void = {}
    var alIrAlDiario: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                tarjetaCuenta
                fila(titulo: "Conectar broker", detalle: "Sincroniza tus cuentas vía SnapTrade") { alElegir(.broker) }
                fila(titulo: "Importar CSV", detalle: "Trae tu historial desde un archivo") { alElegir(.importar) }
                fila(titulo: "Membresía", detalle: "Tu plan y tu suscripción") { alElegir(.membresia) }
                fila(titulo: "Notificaciones", detalle: "Qué avisos te llegan por push") { alElegir(.notificaciones) }
                fila(titulo: "Mi plan", detalle: "Tus límites y tu checklist") { alIrAlPlan() }
                fila(titulo: "Diario", detalle: "Tus operaciones y estadísticas") { alIrAlDiario() }
                fila(titulo: "Barra de navegación", detalle: "Ordena los botones de abajo arrastrando") { alElegir(.barra) }
                fila(titulo: "Perfil", detalle: "Foto, nombre, correo, tema, contraseña y tu cuenta") { alElegir(.perfil) }
                fila(titulo: "Ayúdame a mejorar", detalle: "Qué no se entiende, qué falló o tu idea: lo leo yo") { alElegir(.mejora) }
                if usuario?.isAdmin == true {
                    fila(titulo: "Invitaciones", detalle: "Códigos de la beta privada") { alElegir(.invitaciones) }
                }
                Button { alCerrarSesion() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cerrar sesión")
                                .font(.manrope(15, weight: .bold))
                                .foregroundStyle(KipColor.rojoPnl(scheme))
                            Text("Sal de tu cuenta en este teléfono")
                                .font(.manrope(12))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KipColor.card(scheme))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .task {
            usuario = try? await Api.usuario()
            if let u = usuario {
                Sesion.usuarioLocal = UsuarioGuardado(nombre: u.name, apodo: u.nickname, correo: u.email,
                                                      verificado: u.verificado, esAdmin: u.isAdmin,
                                                      avatarUrl: u.avatarUrl, barra: u.barra)
                if let tema = u.tema { Sesion.tema = tema }
            }
        }
    }

    private var tarjetaCuenta: some View {
        let local = Sesion.usuarioLocal
        let nombre = usuario?.nickname ?? usuario?.name ?? local?.nombre ?? ""
        return KipCard {
            HStack(spacing: 12) {
                AvatarKip(urlTexto: usuario?.avatarUrl ?? local?.avatarUrl, nombre: nombre, tamano: 52)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(nombre)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .lineLimit(1)
                        if usuario?.verificado == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color(hex: 0x5EC96E))
                                .font(.system(size: 14))
                        }
                    }
                    Text(usuario?.email ?? local?.correo ?? "")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .lineLimit(1)
                }
                Spacer()
            }
        }
    }

    private func fila(titulo: String, detalle: String, accion: @escaping () -> Void) -> some View {
        Button { accion() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text(detalle)
                        .font(.manrope(12))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conectar broker

@MainActor
final class BrokerModel: ObservableObject {
    @Published var datos: BrokerDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var aviso: String? = nil
    @Published var sesionExpirada = false

    func cargar() {
        cargando = true
        Task {
            do {
                datos = try await Api.broker()
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla { sesionExpirada = true; Sesion.cerrar() }
                else if datos == nil { errorTexto = falla.errorDescription }
            } catch {
                cargando = false
                if datos == nil { errorTexto = "Algo salió mal. Inténtalo de nuevo." }
            }
        }
    }
}

struct VistaBroker: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var abrirURL
    @StateObject private var modelo = BrokerModel()
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 14) {
                        KipCard {
                            VStack(alignment: .leading, spacing: 10) {
                                TituloTarjeta(texto: "Tu conexión")
                                Text(datos.verificado
                                     ? "✓ Cuenta verificada: tus trades vienen de tu broker."
                                     : "Todavía no tienes un broker real conectado y sincronizado.")
                                    .font(.manrope(14, weight: .semibold))
                                    .foregroundStyle(datos.verificado ? KipColor.verdePnl(scheme) : KipColor.text(scheme))
                                Text("Nunca vemos tu contraseña: entras a tu broker en su página oficial (autorización OAuth vía SnapTrade), Kiptrade solo lee tus operaciones — no puede operar ni mover dinero — y puedes revocar el acceso cuando quieras desde tu broker.")
                                    .font(.manrope(13))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                if let aviso = modelo.aviso {
                                    Text(aviso)
                                        .font(.manrope(14, weight: .semibold))
                                        .foregroundStyle(KipColor.verdePnl(scheme))
                                }
                                if let error = modelo.errorTexto {
                                    Text(error)
                                        .font(.manrope(14, weight: .semibold))
                                        .foregroundStyle(KipColor.error(scheme))
                                }
                                BotonKip(texto: "Conectar broker", deshabilitado: !datos.configurado) { abrirPortal() }
                                BotonBordeKip(texto: "Actualizar conexiones") { actualizar() }
                                if !datos.configurado {
                                    Text("La conexión de brokers aún no está activa en el servidor.")
                                        .font(.manrope(14, weight: .semibold))
                                        .foregroundStyle(KipColor.error(scheme))
                                }
                            }
                        }
                        ForEach(datos.conexiones) { conexion in
                            VStack(alignment: .leading, spacing: 10) {
                                TituloTarjeta(texto: conexion.broker ?? "Broker")
                                ForEach(conexion.cuentas) { cuenta in
                                    TarjetaCuentaBroker(cuenta: cuenta) { sincronizar(cuenta) }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !datos.cuentasSueltas.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                TituloTarjeta(texto: "Cuentas")
                                ForEach(datos.cuentasSueltas) { cuenta in
                                    TarjetaCuentaBroker(cuenta: cuenta) { sincronizar(cuenta) }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("Para desconectar un broker, hazlo dentro del portal de SnapTrade con el botón «Conectar broker».")
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            } else if modelo.cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar tu conexión.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
    }

    private func abrirPortal() {
        Task {
            do {
                let enlace = try await Api.portalBroker()
                if let urlTexto = enlace.url, let url = URL(string: urlTexto) {
                    await abrirURL(url)
                } else {
                    modelo.errorTexto = enlace.message ?? "No se pudo abrir el portal."
                }
            } catch let falla as ApiError {
                modelo.errorTexto = falla.errorDescription
            } catch {
                modelo.errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    private func actualizar() {
        Task {
            do {
                let r = try await Api.actualizarBroker()
                modelo.aviso = r.message
                modelo.cargar()
            } catch let falla as ApiError {
                modelo.errorTexto = falla.errorDescription
            } catch {
                modelo.errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    private func sincronizar(_ cuenta: CuentaBrokerDto) {
        Task {
            do {
                // Muestra el message pero NO recarga la lista (Android).
                let r = try await Api.sincronizarCuenta(id: cuenta.id)
                modelo.aviso = r.message
            } catch let falla as ApiError {
                modelo.errorTexto = falla.errorDescription
            } catch {
                modelo.errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }
}

struct TarjetaCuentaBroker: View {
    @Environment(\.colorScheme) private var scheme
    let cuenta: CuentaBrokerDto
    var alSincronizar: () -> Void = {}
    var body: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 7) {
                Text(cuenta.nombre ?? cuenta.broker ?? "Cuenta")
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text("••••\(cuenta.numero ?? "") · \(cuenta.broker ?? "")")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                if !cuenta.esCsv, let saludTexto = cuenta.saludTexto {
                    Text(saludTexto)
                        .font(.manrope(13, weight: .semibold))
                        .foregroundStyle(colorSalud(cuenta.salud))
                    if let detalle = cuenta.saludDetalle {
                        Text(detalle)
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
                if cuenta.esCsv {
                    Text("Cuenta de importación CSV.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                } else {
                    BotonBordeKip(texto: "Sincronizar ahora") { alSincronizar() }
                }
            }
        }
    }

    private func colorSalud(_ salud: String?) -> Color {
        switch salud {
        case "fallo", "reconectar": return KipColor.rojoPnl(scheme)
        case "atrasada", "nunca": return KipColor.ambarPnl(scheme)
        default: return KipColor.verdePnl(scheme)
        }
    }
}

// MARK: - Membresia

struct VistaMembresia: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var abrirURL
    @State private var datos: MembresiaDto? = nil
    @State private var cargando = false
    @State private var errorTexto: String? = nil
    @State private var aviso: String? = nil
    @State private var sesionExpirada = false
    @State private var confirmarCancelar = false
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = datos {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Array(datos.avisos.enumerated()), id: \.offset) { _, avisoBilling in
                            KipCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(avisoBilling.titulo)
                                        .font(.manrope(15, weight: .bold))
                                        .foregroundStyle(KipColor.ambarPnl(scheme))
                                    Text(avisoBilling.detalle)
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.text(scheme))
                                }
                            }
                        }
                        KipCard {
                            VStack(alignment: .leading, spacing: 10) {
                                TituloTarjeta(texto: "Tu membresía")
                                Text(textoEstado(datos))
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.text(scheme))
                                Text("Plan: \(datos.precio). Sin permanencia: cancelas cuando quieras y el acceso dura hasta el fin del periodo pagado.")
                                    .font(.manrope(13))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
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
                                if datos.puedeCheckout {
                                    BotonKip(texto: "Suscribirme") { abrirEnlace(checkout: true) }
                                }
                                if datos.puedePortal {
                                    BotonBordeKip(texto: "Gestionar mi suscripción") { abrirEnlace(checkout: false) }
                                }
                                if datos.puedeCancelar {
                                    Button { confirmarCancelar = true } label: {
                                        Text("Cancelar suscripción")
                                            .font(.manrope(14, weight: .bold))
                                            .foregroundStyle(KipColor.rojoPnl(scheme))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Text("El pago se hace en la página segura de Stripe; tu tarjeta nunca pasa por Kiptrade.")
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
                ErrorCarga(mensaje: errorTexto ?? "No se pudo cargar tu membresía.") { cargar() }
            }
        }
        .onAppear { if datos == nil { cargar() } }
        .confirmationDialog("¿Cancelar tu suscripción?", isPresented: $confirmarCancelar, titleVisibility: .visible) {
            Button("Sí, cancelar", role: .destructive) { cancelar() }
            Button("Seguir suscrito", role: .cancel) {}
        } message: {
            Text("Sigues con acceso completo hasta el fin del periodo y no se te cobra nada más. Tu diario y tus datos se quedan aquí.")
        }
    }

    private func textoEstado(_ m: MembresiaDto) -> String {
        if m.exento || m.estado == "founder" { return "Tienes acceso completo: tu cuenta no necesita suscripción." }
        if !m.cobroActivo { return "Estás en la beta privada. El cobro aún no está activo: disfruta el acceso completo mientras tanto." }
        switch m.estado {
        case "trialing":
            if let fecha = m.trialTermina { return "Estás en tu prueba gratis hasta el \(fechaCorta(fecha))." }
            return "Estás en tu prueba gratis de 14 días."
        case "active": return "Tu suscripción está activa."
        case "past_due": return "Tu último pago no pasó. Actualiza tu tarjeta para no perder el acceso."
        case "expired": return "Tu prueba gratis terminó. Puedes seguir viendo y exportando todo tu diario; para volver a registrar, importar o sincronizar, activa tu suscripción."
        default: return "Estado: \(m.estado)"
        }
    }

    private func cargar() {
        cargando = true
        Task {
            do {
                datos = try await Api.membresia()
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla { sesionExpirada = true; Sesion.cerrar() }
                else if datos == nil { errorTexto = falla.errorDescription }
            } catch {
                cargando = false
                if datos == nil { errorTexto = "Algo salió mal. Inténtalo de nuevo." }
            }
        }
    }

    private func abrirEnlace(checkout: Bool) {
        Task {
            do {
                let enlace = checkout ? try await Api.checkoutMembresia() : try await Api.portalMembresia()
                if let urlTexto = enlace.url, let url = URL(string: urlTexto) {
                    await abrirURL(url)
                } else {
                    errorTexto = enlace.message ?? "No se pudo abrir la página."
                }
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    private func cancelar() {
        Task {
            do {
                let r = try await Api.cancelarMembresia()
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
