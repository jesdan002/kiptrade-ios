import SwiftUI
import UniformTypeIdentifiers

// Importar CSV (mapa §3.10): la maquina de pasos 0-3 — subir, mapear,
// vista previa, resultado. El archivo viaja con nombre fijo trades.csv.

@MainActor
final class ImportarModel: ObservableObject {
    @Published var paso = 0
    @Published var subida: ImportarSubidaDto? = nil
    @Published var mapeo: [String: Int] = [:]
    @Published var previa: VistaPreviaDto? = nil
    @Published var resultado: RespuestaImportarResultado? = nil
    @Published var trabajando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false

    func subir(datos: Data) {
        trabajando = true
        errorTexto = nil
        Task {
            do {
                let r = try await Api.subirCsv(datos: datos)
                subida = r
                // Las sugerencias del servidor vienen preseleccionadas.
                var inicial: [String: Int] = [:]
                for columna in r.columnas {
                    if let sugerido = columna.suggested {
                        inicial[sugerido] = columna.index
                    }
                }
                mapeo = inicial
                paso = 1
                trabajando = false
            } catch let falla as ApiError {
                trabajando = false
                if case .sesionExpirada = falla { sesionExpirada = true; Sesion.cerrar() }
                else { errorTexto = falla.errorDescription }
            } catch {
                trabajando = false
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    func guardarMapeoYPrevia() {
        guard let subida = subida else { return }
        // Una misma columna no puede ir a dos campos.
        let indices = Array(mapeo.values)
        if Set(indices).count != indices.count {
            errorTexto = "Una misma columna no puede ir a dos campos. Revisa el mapeo."
            return
        }
        trabajando = true
        errorTexto = nil
        Task {
            do {
                _ = try await Api.mapearImportar(token: subida.token, mapeo: mapeo)
                previa = try await Api.vistaPreviaImportar(token: subida.token)
                paso = 2
                trabajando = false
            } catch let falla as ApiError {
                trabajando = false
                errorTexto = falla.errorDescription
            } catch {
                trabajando = false
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    func confirmar() {
        guard let subida = subida else { return }
        trabajando = true
        errorTexto = nil
        Task {
            do {
                resultado = try await Api.confirmarImportar(token: subida.token)
                paso = 3
                trabajando = false
            } catch let falla as ApiError {
                trabajando = false
                errorTexto = falla.errorDescription
            } catch {
                trabajando = false
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }

    func reiniciar() {
        paso = 0
        subida = nil
        mapeo = [:]
        previa = nil
        resultado = nil
        errorTexto = nil
    }
}

struct VistaImportar: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = ImportarModel()
    @State private var elegirArchivo = false
    @State private var plantillaCompartida: URL? = nil
    var alIrAlDiario: () -> Void = {}
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        switch modelo.paso {
                        case 0: pasoCero
                        case 1: pasoMapeo
                        case 2: pasoPrevia
                        default: pasoResultado
                        }
                        if let error = modelo.errorTexto {
                            Text(error)
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(KipColor.error(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if modelo.trabajando {
                            ProgressView().tint(KipColor.accent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
            }
        }
        .fileImporter(isPresented: $elegirArchivo, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { resultado in
            if let url = try? resultado.get().first {
                let acceso = url.startAccessingSecurityScopedResource()
                defer { if acceso { url.stopAccessingSecurityScopedResource() } }
                if let datos = try? Data(contentsOf: url) {
                    modelo.subir(datos: datos)
                }
            }
        }
        .sheet(item: $plantillaCompartida) { url in
            HojaCompartir(elementos: [url])
        }
    }

    // MARK: Paso 0

    private var pasoCero: some View {
        VStack(spacing: 14) {
            KipCard {
                VStack(alignment: .leading, spacing: 10) {
                    TituloTarjeta(texto: "Trae tu historial")
                    Text("Sube un CSV con tus operaciones. Si usas la plantilla de Kiptrade, el mapeo de columnas sale casi solo; si es de otro lado, en el siguiente paso dices qué columna es cada campo.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    BotonKip(texto: "Elegir archivo CSV", deshabilitado: modelo.trabajando) { elegirArchivo = true }
                }
            }
            KipCard {
                VStack(alignment: .leading, spacing: 10) {
                    TituloTarjeta(texto: "Plantilla de Kiptrade")
                    BotonBordeKip(texto: "Descargar la plantilla") {
                        Task {
                            // Si falla, silencio (Android).
                            if let datos = await Api.plantillaCsv() {
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiptrade-plantilla-trades.csv")
                                try? datos.write(to: url)
                                plantillaCompartida = url
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Paso 1 (mapeo)

    private var pasoMapeo: some View {
        VStack(spacing: 12) {
            if let subida = modelo.subida {
                Text("Tu archivo trae \(subida.filas) filas. Di qué columna es cada campo (los de * son obligatorios).")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(subida.campos) { campo in
                    KipCard {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(campo.etiqueta + (campo.obligatorio ? " *" : ""))
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Menu {
                                Button("Sin asignar") { modelo.mapeo[campo.clave] = nil }
                                ForEach(Array(subida.columnas.enumerated()), id: \.offset) { _, columna in
                                    Button("\(columna.name)\(columna.samples.first.map { " — ej.: \($0)" } ?? "")") {
                                        modelo.mapeo[campo.clave] = columna.index
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(etiquetaColumna(subida: subida, campo: campo.clave))
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.text(scheme))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .background(KipColor.card(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                BotonKip(texto: "Guardar y ver la previa", deshabilitado: modelo.trabajando) {
                    modelo.guardarMapeoYPrevia()
                }
            }
        }
    }

    private func etiquetaColumna(subida: ImportarSubidaDto, campo: String) -> String {
        guard let indice = modelo.mapeo[campo],
              let columna = subida.columnas.first(where: { $0.index == indice }) else {
            return "Sin asignar"
        }
        return columna.name
    }

    // MARK: Paso 2 (vista previa)

    private var pasoPrevia: some View {
        VStack(spacing: 12) {
            if let previa = modelo.previa {
                KipCard {
                    VStack(alignment: .leading, spacing: 9) {
                        TituloTarjeta(texto: "Vista previa")
                        Text("\(previa.total) filas: \(previa.validas) válidas, \(previa.duplicadas) duplicadas, \(previa.conError) con error.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                        ForEach(Array(previa.filas.prefix(30).enumerated()), id: \.offset) { _, fila in
                            HStack(spacing: 8) {
                                Text("Fila \(fila.n): \(fila.detail)")
                                    .font(.manrope(13))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                if fila.status == "ok" {
                                    Text("✓")
                                        .font(.manrope(13, weight: .heavy))
                                        .foregroundStyle(KipColor.verdePnl(scheme))
                                } else if fila.status == "duplicado" {
                                    Text("duplicada")
                                        .font(.manrope(12, weight: .bold))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                } else {
                                    Text("error")
                                        .font(.manrope(12, weight: .bold))
                                        .foregroundStyle(KipColor.rojoPnl(scheme))
                                }
                            }
                        }
                        if previa.filas.count > 30 {
                            Text("… y \(previa.filas.count - 30) filas más.")
                                .font(.manrope(13))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                    }
                }
                BotonKip(texto: "Importar \(previa.validas) operaciones", deshabilitado: previa.validas == 0 || modelo.trabajando) {
                    modelo.confirmar()
                }
                BotonBordeKip(texto: "Empezar de nuevo") { modelo.reiniciar() }
            }
        }
    }

    // MARK: Paso 3 (resultado)

    private var pasoResultado: some View {
        VStack(spacing: 12) {
            if let respuesta = modelo.resultado {
                KipCard {
                    VStack(alignment: .leading, spacing: 9) {
                        TituloTarjeta(texto: "Importación terminada")
                        Text("Importadas: \(respuesta.resultado.importados) · Duplicadas: \(respuesta.resultado.duplicados)")
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                        ForEach(Array(respuesta.resultado.errores.enumerated()), id: \.offset) { _, error in
                            Text("• \(error)")
                                .font(.manrope(13))
                                .foregroundStyle(KipColor.rojoPnl(scheme))
                        }
                    }
                }
                BotonKip(texto: "Ver mi Diario") { alIrAlDiario() }
                BotonBordeKip(texto: "Importar otro archivo") { modelo.reiniciar() }
            }
        }
    }
}
