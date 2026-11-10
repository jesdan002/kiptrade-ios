import SwiftUI
import LocalAuthentication

// La raiz de Kiptrade iOS (AppRoot de la Android): fases de acceso,
// puerta biometrica y la principal con la capsula flotante, la pila
// de navegacion (detalle de trade, Ajustes, Notificaciones) y el
// menu lateral.
//
// Tema: el `tema` de la cuenta manda sobre el del sistema (dark ->
// oscuro, light -> claro, otro/ninguno -> sistema).

enum RutaKT: Hashable {
    case trade(Int)
    case ajustes
    case notificaciones
}

enum PantallaAcceso {
    case login, registro, recuperar
}

struct ContentView: View {
    @Environment(\.colorScheme) private var esquemaSistema
    @State private var sesionViva = Sesion.haySesion
    @State private var puertaPasada = false
    @State private var pantallaAcceso: PantallaAcceso = .login
    @State private var destino = "panel"
    @State private var pila: [RutaKT] = []
    @State private var diarioSeccionInicial = 0
    @State private var abrirDiarioEnTrade: Int? = nil
    @State private var menuAbierto = false
    @State private var barraLaterales: [String] = Destino.laterales(desde: Sesion.usuarioLocal?.barra ?? ["panel", "diario", "estadisticas", "coach", "plan"])
    @State private var biometriaEnAparato = false
    @AppStorage("kt-huella-activada") private var huellaActivada = false

    /// El esquema efectivo: el tema de la cuenta manda.
    private var esquema: ColorScheme? {
        switch Sesion.tema {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    var body: some View {
        Group {
            if !sesionViva {
                acceso
            } else if huellaActivada && biometriaEnAparato && !puertaPasada {
                PuertaBiometricaView(alDesbloquear: { puertaPasada = true },
                                     alUsarContrasena: { cerrarSesionLocal() })
            } else {
                principal
            }
        }
        .preferredColorScheme(esquema)
        .onAppear {
            biometriaEnAparato = Biometria.disponible()
        }
    }

    // MARK: - Acceso

    @ViewBuilder
    private var acceso: some View {
        switch pantallaAcceso {
        case .login:
            LoginView(alEntrar: { _ in
                sesionViva = true
                puertaPasada = true
                barraLaterales = Destino.laterales(desde: Sesion.usuarioLocal?.barra ?? barraLaterales)
                destino = "panel"
            }, alRecuperar: { pantallaAcceso = .recuperar },
               alRegistro: { pantallaAcceso = .registro })
        case .registro:
            RegistroView(alVolver: { pantallaAcceso = .login })
        case .recuperar:
            RecuperarView(alVolver: { pantallaAcceso = .login })
        }
    }

    // MARK: - Principal

    private var principal: some View {
        NavigationStack(path: $pila) {
            ZStack(alignment: .bottom) {
                contenidoDestino
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                BarraCapsulaKT(laterales: barraLaterales, seleccion: destino) { clave in
                    irA(clave)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                if menuAbierto {
                    MenuLateralKT(alCerrar: { menuAbierto = false },
                                  alIr: { clave in irA(clave) },
                                  alAbrirAjustes: { vista in
                                      menuAbierto = false
                                      ajustesVistaInicial = vista
                                      pila.append(.ajustes)
                                  },
                                  alCerrarSesion: { cerrarSesionCompleta() })
                    .transition(.move(edge: .leading))
                    .zIndex(5)
                }
            }
            .background(KipColor.bg(esquema ?? esquemaSistema).ignoresSafeArea())
            .navigationDestination(for: RutaKT.self) { ruta in
                destinoRuta(ruta)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: menuAbierto)
    }

    @State private var ajustesVistaInicial: VistaAjustes = .menu

    @ViewBuilder
    private var contenidoDestino: some View {
        switch destino {
        case "diario", "estadisticas":
            DiarioView(alAbrirTrade: { id in pila.append(.trade(id)) },
                       alEntrarDeNuevo: { volverAlLogin() },
                       seccionInicial: destino == "estadisticas" ? 3 : diarioSeccionInicial)
            .id(destino + "-" + String(destino == "estadisticas" ? 3 : diarioSeccionInicial))
            .onAppear {
                if let id = abrirDiarioEnTrade {
                    abrirDiarioEnTrade = nil
                    pila.append(.trade(id))
                }
            }
        case "coach":
            CoachView(alAbrirTrade: { id in pila.append(.trade(id)) },
                      alEntrarDeNuevo: { volverAlLogin() })
        case "plan":
            PlanView(alEntrarDeNuevo: { volverAlLogin() })
        default:
            PanelView(alAbrirMenu: { menuAbierto = true },
                      alAbrirNotificaciones: { pila.append(.notificaciones) },
                      alAbrirTrade: { id in
                          diarioSeccionInicial = 0
                          abrirDiarioEnTrade = id
                          destino = "diario"
                      },
                      alVerTodos: {
                          diarioSeccionInicial = 0
                          destino = "diario"
                      },
                      alEntrarDeNuevo: { volverAlLogin() })
        }
    }

    @ViewBuilder
    private func destinoRuta(_ ruta: RutaKT) -> some View {
        switch ruta {
        case .trade(let id):
            DetalleTradeView(idTrade: id)
        case .ajustes:
            AjustesConVistaInicial(vistaInicial: ajustesVistaInicial,
                                   alCerrarSesion: { cerrarSesionCompleta() },
                                   alIrAlPlan: {
                                       pila.removeAll()
                                       destino = "plan"
                                   },
                                   alIrAlDiario: {
                                       pila.removeAll()
                                       destino = "diario"
                                   },
                                   alIrANotificaciones: { pila.append(.notificaciones) },
                                   alCambiarBarra: { secciones in
                                       barraLaterales = Destino.laterales(desde: secciones)
                                   })
        case .notificaciones:
            NotificacionesView(alVolver: { pila.removeLast() },
                               alEntrarDeNuevo: { volverAlLogin() })
        }
    }

    // MARK: - Navegacion y sesion

    private func irA(_ clave: String) {
        menuAbierto = false
        pila.removeAll()
        if clave == "estadisticas" {
            diarioSeccionInicial = 3
            destino = "diario"
        } else {
            if clave == "diario" { diarioSeccionInicial = 0 }
            destino = clave
        }
    }

    private func volverAlLogin() {
        Sesion.cerrar()
        Sesion.usuarioLocal = nil
        pila.removeAll()
        sesionViva = false
        pantallaAcceso = .login
    }

    private func cerrarSesionLocal() {
        Sesion.cerrar()
        Sesion.usuarioLocal = nil
        sesionViva = false
        puertaPasada = false
        pantallaAcceso = .login
    }

    /// El cierre de sesion completo, en el orden de la Android:
    /// (el push APNs llega con el registro de la Fase de tiendas; sin
    /// token no hay baja que dar) -> logout remoto -> limpiar -> local.
    private func cerrarSesionCompleta() {
        menuAbierto = false
        Task {
            await Api.logoutRemoto()
            await MainActor.run {
                pila.removeAll()
                destino = "panel"
                cerrarSesionLocal()
            }
        }
    }
}

/// Biometria del aparato (para decidir si la puerta aplica).
enum Biometria {
    static func disponible() -> Bool {
        let contexto = LAContext()
        var error: NSError?
        return contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}

/// Ajustes con la vista inicial que pidio el menu lateral.
typealias AjustesConVistaInicial = AjustesView

/// El menu lateral (drawer) de la Android: cabecera con avatar,
/// nombre, verificado y la linea Win rate / Profit; items de destino
/// y de Ajustes; cerrar sesion al final.
struct MenuLateralKT: View {
    @Environment(\.colorScheme) private var scheme
    var alCerrar: () -> Void = {}
    var alIr: (String) -> Void = { _ in }
    var alAbrirAjustes: (VistaAjustes) -> Void = { _ in }
    var alCerrarSesion: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cabecera
                Divider().padding(.vertical, 10)
                itemDestino("Panel", clave: "panel")
                itemDestino("Diario", clave: "diario")
                itemDestino("Estadísticas", clave: "estadisticas")
                itemDestino("KipCoach", clave: "coach")
                itemDestino("Mi plan", clave: "plan")
                Divider().padding(.vertical, 10)
                itemAjustes("Conectar broker", vista: .broker)
                itemAjustes("Importar CSV", vista: .importar)
                itemAjustes("Membresía", vista: .membresia)
                itemMenu("Ajustes") { alAbrirAjustes(.menu) }
                itemAjustes("Ayúdame a mejorar", vista: .mejora)
                if Sesion.usuarioLocal?.esAdmin == true {
                    itemAjustes("Invitaciones", vista: .invitaciones)
                }
                Divider().padding(.vertical, 10)
                itemMenu("Cerrar sesión") { alCerrarSesion() }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .frame(width: 292)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(KipColor.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 0))
            Color.black.opacity(0.35)
                .onTapGesture { alCerrar() }
        }
        .ignoresSafeArea()
    }

    private var cabecera: some View {
        let local = Sesion.usuarioLocal
        let nombre = local?.apodo ?? local?.nombre ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            AvatarKip(urlTexto: local?.avatarUrl, nombre: nombre, tamano: 56)
            Text(nombre)
                .font(.manrope(17, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Text(local?.correo ?? "")
                .font(.manrope(13))
                .foregroundStyle(KipColor.textSecondary(scheme))
            if local?.verificado == true {
                Text("✓ Verificado")
                    .font(.manrope(12, weight: .semibold))
                    .foregroundStyle(KipColor.verdePnl(scheme))
            }
        }
    }

    private func itemDestino(_ texto: String, clave: String) -> some View {
        itemMenu(texto) { alIr(clave) }
    }

    private func itemAjustes(_ texto: String, vista: VistaAjustes) -> some View {
        itemMenu(texto) { alAbrirAjustes(vista) }
    }

    private func itemMenu(_ texto: String, accion: @escaping () -> Void) -> some View {
        Button { accion() } label: {
            HStack {
                Text(texto)
                    .font(.manrope(15, weight: .semibold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// La capsula flotante de la familia (0.18.0): margen 16/12, radio 34,
/// alto 70, heroe de 64 con el degradado desplazado -13, y la pastilla
/// activa al 16% tras el icono. La sombra va en una capsula gemela SIN
/// recorte en el fondo, para que el heroe no salga cortado.
struct BarraCapsulaKT: View {
    @Environment(\.colorScheme) private var scheme
    let laterales: [String]
    let seleccion: String
    var alElegir: (String) -> Void = { _ in }

    var body: some View {
        // Estructura gemela de la de Kipwallet: el cuerpo visible va
        // recortado en capsula, pero el heroe vive en una fila SIN
        // recorte sobre el, anclado al fondo, ya que con offset dentro
        // de la capsula recortada iOS le cortaba la corona (aunque la
        // sombra fuera en un fondo sin recorte).
        ZStack(alignment: .bottom) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(laterales.prefix(2).enumerated()), id: \.offset) { _, clave in
                    botonLateral(clave)
                }
                Color.clear.frame(width: 68)
                ForEach(Array(laterales.suffix(2).enumerated()), id: \.offset) { _, clave in
                    botonLateral(clave)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 62)
            .background(KipColor.card(scheme))
            .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(Capsule())
            .background(
                Capsule()
                    .fill(KipColor.card(scheme))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.18), radius: 14, y: 6)
            )
            heroe
                .padding(.bottom, 17)
        }
        .frame(height: 62)
    }

    private var heroe: some View {
        Button { alElegir("panel") } label: {
            ZStack {
                Circle()
                    .fill(degradadoMarca)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                Image(systemName: "house.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(KipColor.onAccent)
            }
        }
        .buttonStyle(.plain)
        .zIndex(1)
    }

    private func botonLateral(_ clave: String) -> some View {
        let activo = seleccion == clave || (clave == "estadisticas" && seleccion == "diario")
        return Button { alElegir(clave) } label: {
            VStack(spacing: 2) {
                ZStack {
                    if activo {
                        Capsule()
                            .fill(KipColor.primary(scheme).opacity(0.16))
                            .frame(width: 48, height: 27)
                    }
                    Image(systemName: Destino.iconos[clave] ?? "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(activo ? KipColor.primary(scheme) : Color(hex: 0x9FB0BF))
                }
                .frame(height: 27)
                Text(Destino.etiquetas[clave] ?? clave)
                    .font(.manrope(10, weight: .semibold))
                    .foregroundStyle(activo ? KipColor.primary(scheme) : KipColor.textSecondary(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
