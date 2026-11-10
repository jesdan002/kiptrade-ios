import SwiftUI

// La pantalla de Notificaciones (mapa §3.17): pastillas Sin leer /
// Leidas con el filtro EN CLIENTE, «Marcar todas como leidas», y la
// fila de aviso con su icono por clave. La `fecha` llega [S].

@MainActor
final class NotificacionesModel: ObservableObject {
    @Published var datos: NotificacionesDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false

    func cargar() {
        cargando = true
        Task {
            do {
                datos = try await Api.notificaciones()
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla {
                    sesionExpirada = true
                    Sesion.cerrar()
                } else if datos == nil {
                    errorTexto = "No se pudieron cargar tus avisos."
                }
            } catch {
                cargando = false
                if datos == nil { errorTexto = "Sin conexión para cargar tus avisos." }
            }
        }
    }

    func leer(id: Int64) {
        Task {
            _ = try? await Api.leerNotificacion(id: id)
            if var actual = datos,
               let indice = actual.notificaciones.firstIndex(where: { $0.id == id }) {
                actual.notificaciones[indice].leida = true
                actual.sinLeer = max(actual.sinLeer - 1, 0)
                datos = actual
            }
        }
    }

    func leerTodas() {
        Task {
            _ = try? await Api.leerTodasNotificaciones()
            cargar()
        }
    }
}

struct NotificacionesView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = NotificacionesModel()
    @State private var pestana = 0
    var alVolver: () -> Void = {}
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { alVolver() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                Text("Notificaciones")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            Text("Lo importante de tu cuenta: tu broker, tus importaciones, tu plan y tu membresía.")
                .font(.manrope(13))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            contenido
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
    }

    @ViewBuilder
    private var contenido: some View {
        if modelo.sesionExpirada {
            VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para ver tus avisos.", alEntrar: alEntrarDeNuevo)
        } else if let datos = modelo.datos {
            let sinLeerLista = datos.notificaciones.filter { !$0.leida }
            let leidasLista = datos.notificaciones.filter { $0.leida }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    PastillasSeccion(opciones: [
                        datos.sinLeer > 0 ? "Sin leer · \(datos.sinLeer)" : "Sin leer",
                        "Leídas",
                    ], elegida: $pestana)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                if pestana == 0 && datos.sinLeer > 0 {
                    HStack {
                        Spacer()
                        Button { modelo.leerTodas() } label: {
                            Text("Marcar todas como leídas")
                                .font(.manrope(13, weight: .bold))
                                .foregroundStyle(KipColor.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                ScrollView {
                    VStack(spacing: 10) {
                        let lista = pestana == 0 ? sinLeerLista : leidasLista
                        if lista.isEmpty {
                            Text(pestana == 0
                                 ? "No tienes avisos sin leer. Cuando pase algo importante con tu cuenta, tu broker o tu diario, lo verás aquí."
                                 : "Todavía no tienes avisos leídos.")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .padding(.vertical, 20)
                        } else {
                            ForEach(lista) { aviso in
                                FilaAviso(aviso: aviso) {
                                    if !aviso.leida { modelo.leer(id: aviso.id) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            }
        } else if modelo.cargando {
            ProgressView().tint(KipColor.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudieron cargar tus avisos.") { modelo.cargar() }
        }
    }
}

/// La fila de un aviso: circulo con el icono por clave, titulo (negrita
/// si no leida), cuerpo y la fecha [S]; punto Accent si no leida.
struct FilaAviso: View {
    @Environment(\.colorScheme) private var scheme
    let aviso: NotificacionDto
    var alTocar: () -> Void = {}

    private var icono: String {
        switch aviso.icono {
        case "sync": return "arrow.triangle.2.circlepath"
        case "sync_alerta": return "exclamationmark.triangle"
        case "importacion": return "square.and.arrow.down"
        case "membresia": return "creditcard"
        case "diario": return "book"
        default: return "bell"
        }
    }

    var body: some View {
        Button { alTocar() } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(KipColor.elevated(scheme))
                        .frame(width: 40, height: 40)
                    Image(systemName: icono)
                        .font(.system(size: 17))
                        .foregroundStyle(aviso.leida ? KipColor.textSecondary(scheme) : KipColor.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(aviso.titulo)
                            .font(.manrope(15, weight: aviso.leida ? .semibold : .heavy))
                            .foregroundStyle(KipColor.text(scheme))
                            .multilineTextAlignment(.leading)
                        if !aviso.leida {
                            Circle().fill(KipColor.accent).frame(width: 9, height: 9)
                        }
                        Spacer()
                    }
                    Text(aviso.cuerpo)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.leading)
                    if !aviso.fecha.isEmpty {
                        Text(aviso.fecha)
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
