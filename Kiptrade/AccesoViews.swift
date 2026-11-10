import SwiftUI
import LocalAuthentication

// El acceso de Kiptrade iOS, espejo de la Android/web: Login (con
// «Recuerdame» y puerta biometrica), Registro por invitacion y
// Recuperar. Sin MFA en AW (mapa §4.1). Los textos son literales.

/// Marca de la casa: el logo oficial y el wordmark «Kip» + «trade».
struct MarcaKiptrade: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(KipColor.darkBg)
                    .frame(width: 96, height: 96)
                Image("LogoK")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            }
            HStack(spacing: 0) {
                Text("Kip")
                    .font(.manrope(30, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("trade")
                    .font(.manrope(30, weight: .heavy))
                    .foregroundStyle(KipColor.gradientEnd)
            }
        }
    }
}

/// El pie de enlaces del acceso.
struct PieAcceso: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 8) {
            Text("Espejo, no maestro")
                .font(.manrope(12, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            HStack(spacing: 4) {
                Link("Privacidad", destination: URL(string: "https://app.kiptrade.net/privacidad")!)
                Text("·")
                Link("Términos", destination: URL(string: "https://app.kiptrade.net/terminos")!)
                Text("·")
                Link("Eliminar cuenta", destination: URL(string: "https://app.kiptrade.net/eliminar-cuenta")!)
                Text("·")
                Link("Contacto", destination: URL(string: "https://app.kiptrade.net/contacto")!)
            }
            .font(.manrope(12, weight: .semibold))
            .foregroundStyle(KipColor.accent)
            .tint(KipColor.accent)
        }
        .foregroundStyle(KipColor.textSecondary(scheme))
    }
}

// MARK: - Login

@MainActor
final class LoginModel: ObservableObject {
    @Published var correo = ""
    @Published var contrasena = ""
    @Published var recuerda = true
    @Published var errorTexto: String? = nil
    @Published var entrando = false

    func entrar(alEntrar: @escaping (UsuarioDto) -> Void) {
        if correo.trimmingCharacters(in: .whitespaces).isEmpty || contrasena.isEmpty {
            errorTexto = "Escribe tu correo y tu contraseña."
            return
        }
        entrando = true
        errorTexto = nil
        let recuerdaLocal = recuerda
        Task {
            do {
                let r = try await Api.login(correo: correo, contrasena: contrasena)
                if recuerdaLocal {
                    Sesion.token = r.token
                } else {
                    Sesion.entrarSinRecordar(token: r.token)
                }
                Sesion.usuarioLocal = UsuarioGuardado(nombre: r.user.name, apodo: r.user.nickname,
                                                      correo: r.user.email, verificado: r.user.verificado,
                                                      esAdmin: r.user.isAdmin, avatarUrl: r.user.avatarUrl,
                                                      barra: r.user.barra)
                if let tema = r.user.tema { Sesion.tema = tema }
                entrando = false
                alEntrar(r.user)
            } catch let falla as ApiError {
                entrando = false
                errorTexto = falla.errorDescription
            } catch {
                entrando = false
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }
}

struct LoginView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = LoginModel()
    var alEntrar: (UsuarioDto) -> Void = { _ in }
    var alRecuperar: () -> Void = {}
    var alRegistro: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                MarcaKiptrade()
                    .padding(.top, 24)
                Text("Entrar a Kiptrade")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                VStack(spacing: 14) {
                    CampoKip(etiqueta: "Correo electrónico", texto: $modelo.correo,
                             teclado: .emailAddress, autocapitalizacion: .never)
                    CampoKip(etiqueta: "Contraseña", texto: $modelo.contrasena, esContrasena: true,
                             autocapitalizacion: .never)
                }
                if let error = modelo.errorTexto {
                    Text(error)
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.error(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Toggle(isOn: $modelo.recuerda) {
                        Text("Recuérdame")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .toggleStyle(CheckboxKipStyle())
                    Spacer()
                }
                BotonKip(texto: modelo.entrando ? "Entrando…" : "Entrar", deshabilitado: modelo.entrando) {
                    modelo.entrar(alEntrar: alEntrar)
                }
                Button { alRecuperar() } label: {
                    Text("¿Olvidaste tu contraseña?")
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.verdePnl(scheme))
                }
                .buttonStyle(.plain)
                Divider()
                VStack(spacing: 6) {
                    Text("¿Aún no tienes cuenta?")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Button { alRegistro() } label: {
                        Text("Créala con tu invitación")
                            .font(.manrope(14, weight: .bold))
                            .foregroundStyle(KipColor.verdePnl(scheme))
                    }
                    .buttonStyle(.plain)
                }
                PieAcceso()
                    .padding(.top, 6)
                bloqueSobre()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
    }

    private func bloqueSobre() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sobre Kiptrade")
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Text("Kiptrade es un diario de trading para traders que operan por su cuenta. Importa tus operaciones desde tu broker, registra tu psicología en cada trade y mide tu disciplina contra tu propio plan. Kiptrade no recomienda operaciones ni da señales: es un espejo de registro y análisis, 100% en español.")
                .font(.manrope(13))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text("Operar conlleva un riesgo considerable de pérdida. No es adecuado para todos los inversores y debes asegurarte de comprender los riesgos, buscando asesoría independiente si es necesario. Nunca operes con dinero que no puedas permitirte perder. Los resultados pasados, reales o de la cuenta demo, no garantizan resultados futuros. Kiptrade es una herramienta educativa y de registro; no es un asesor financiero ni un broker, y nada de lo que muestra constituye una recomendación de inversión. Cada usuario es el único responsable de sus decisiones de trading.")
                .font(.manrope(11))
                .foregroundStyle(KipColor.textSecondary(scheme).opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

/// La casilla de la familia: cuadro en los colores de la marca, no el
/// azul por defecto del sistema.
struct CheckboxKipStyle: ToggleStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(configuration.isOn ? KipColor.accent : Color.clear)
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(configuration.isOn ? KipColor.accent : KipColor.border(scheme), lineWidth: 1.5)
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(KipColor.onAccent)
                    }
                }
                .frame(width: 20, height: 20)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Registro

struct RegistroView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var config = RegistroConfig(modo: "beta", requiereCodigo: true, diasPrueba: 14)
    @State private var nombre = ""
    @State private var correo = ""
    @State private var contrasena = ""
    @State private var confirmacion = ""
    @State private var codigo = ""
    @State private var acepta = false
    @State private var errorTexto: String? = nil
    @State private var exito: String? = nil
    @State private var enviando = false
    var alVolver: () -> Void = {}

    private var esPrueba: Bool { config.modo == "trial" }

    private var subtitulo: String {
        if esPrueba { return "Prueba gratis de \(config.diasPrueba) días, sin tarjeta. Después, $14.99 al mes, cancelas cuando quieras." }
        if config.requiereCodigo { return "Kiptrade está en beta privada: necesitas un código de invitación." }
        return "Mide tu disciplina, no tus ilusiones."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button { alVolver() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                MarcaKiptrade()
                Text("Crea tu cuenta")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text(subtitulo)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .multilineTextAlignment(.center)
                if let exito = exito {
                    VStack(spacing: 10) {
                        Text(exito)
                            .font(.manrope(15, weight: .semibold))
                            .foregroundStyle(KipColor.verdePnl(scheme))
                            .multilineTextAlignment(.center)
                        Text("Si no lo ves, revisa la carpeta de spam.")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        BotonKip(texto: "Ir a entrar") { alVolver() }
                    }
                } else {
                    VStack(spacing: 14) {
                        CampoKip(etiqueta: "Nombre", texto: $nombre)
                        CampoKip(etiqueta: "Correo", texto: $correo, teclado: .emailAddress, autocapitalizacion: .never)
                        CampoKip(etiqueta: "Contraseña", texto: $contrasena, esContrasena: true, autocapitalizacion: .never)
                        CampoKip(etiqueta: "Confirma tu contraseña", texto: $confirmacion, esContrasena: true, autocapitalizacion: .never)
                        if config.requiereCodigo || esPrueba {
                            CampoKip(etiqueta: esPrueba ? "Código de invitación (opcional)" : "Código de invitación",
                                     texto: $codigo, autocapitalizacion: .never)
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Toggle(isOn: $acepta) { EmptyView() }
                            .toggleStyle(CheckboxKipStyle())
                            .labelsHidden()
                        Text("Acepto los Términos y la Política de Privacidad")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let error = errorTexto {
                        Text(error)
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.error(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    BotonKip(texto: enviando ? "Creando…" : "Crear mi cuenta", deshabilitado: enviando) { enviar() }
                }
                Button { alVolver() } label: {
                    Text("Ya tengo cuenta · Volver")
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.verdePnl(scheme))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .task { config = await Api.registroConfig() }
    }

    private func enviar() {
        if nombre.isEmpty || correo.isEmpty || contrasena.isEmpty {
            errorTexto = "Completa tu nombre, tu correo y tu contraseña."
            return
        }
        if contrasena != confirmacion {
            errorTexto = "Las contraseñas no coinciden."
            return
        }
        if config.requiereCodigo && !esPrueba && codigo.isEmpty {
            errorTexto = "Escribe tu código de invitación."
            return
        }
        if !acepta {
            errorTexto = "Debes aceptar los Términos y la Política de Privacidad para crear tu cuenta."
            return
        }
        enviando = true
        errorTexto = nil
        Task {
            do {
                let r = try await Api.registro(nombre: nombre, correo: correo, contrasena: contrasena,
                                               confirmacion: confirmacion, codigo: codigo.isEmpty ? nil : codigo,
                                               acepta: acepta)
                exito = r.message
                enviando = false
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
                enviando = false
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
                enviando = false
            }
        }
    }
}

// MARK: - Recuperar

struct RecuperarView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var correo = ""
    @State private var errorTexto: String? = nil
    @State private var exito: String? = nil
    @State private var enviando = false
    var alVolver: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button { alVolver() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                MarcaKiptrade()
                Text("Recupera tu contraseña")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("Escribe tu correo y te mandamos un enlace. Al tocarlo podrás escribir tu contraseña nueva.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .multilineTextAlignment(.center)
                if let exito = exito {
                    VStack(spacing: 10) {
                        Text(exito)
                            .font(.manrope(15, weight: .semibold))
                            .foregroundStyle(KipColor.verdePnl(scheme))
                            .multilineTextAlignment(.center)
                        Text("Si no lo ves, revisa la carpeta de spam.")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        BotonKip(texto: "Volver a entrar") { alVolver() }
                    }
                } else {
                    CampoKip(etiqueta: "Correo", texto: $correo, teclado: .emailAddress, autocapitalizacion: .never)
                    if let error = errorTexto {
                        Text(error)
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.error(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    BotonKip(texto: enviando ? "Enviando…" : "Enviarme el enlace", deshabilitado: enviando) { enviar() }
                    Button { alVolver() } label: {
                        Text("Volver")
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.verdePnl(scheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
    }

    private func enviar() {
        if correo.trimmingCharacters(in: .whitespaces).isEmpty {
            errorTexto = "Escribe tu correo para enviarte el enlace."
            return
        }
        enviando = true
        errorTexto = nil
        Task {
            do {
                let r = try await Api.recuperarContrasena(correo: correo)
                exito = r.message
                enviando = false
            } catch let falla as ApiError {
                errorTexto = falla.errorDescription
                enviando = false
            } catch {
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
                enviando = false
            }
        }
    }
}

// MARK: - Puerta biometrica

/// La puerta al abrir con sesion guardada (Face ID / Touch ID).
/// Cancelar NO cierra la sesion: la puerta se queda puesta. «Usar
/// contrasena» si cierra la sesion local y lleva al login.
struct PuertaBiometricaView: View {
    @Environment(\.colorScheme) private var scheme
    var alDesbloquear: () -> Void = {}
    var alUsarContrasena: () -> Void = {}
    @State private var falló = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MarcaKiptrade()
            Text("Kiptrade está bloqueado")
                .font(.manrope(20, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
            Text("Usa tu huella para ver tu diario.")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
            BotonKip(texto: "Desbloquear con huella") { pedir() }
                .padding(.horizontal, 40)
            Button { alUsarContrasena() } label: {
                Text("Usar contraseña")
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.verdePnl(scheme))
            }
            .buttonStyle(.plain)
            if falló {
                Text("No se pudo verificar. Inténtalo de nuevo.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.error(scheme))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .onAppear { pedir() }
    }

    private func pedir() {
        let contexto = LAContext()
        var errorLA: NSError?
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorLA) else {
            // Sin biometria disponible en el aparato: se entra directo
            // (la puerta no puede quedarse puesta para siempre).
            alDesbloquear()
            return
        }
        contexto.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Usa tu huella para ver tu diario") { ok, _ in
            DispatchQueue.main.async {
                if ok { alDesbloquear() } else { falló = true }
            }
        }
    }
}
