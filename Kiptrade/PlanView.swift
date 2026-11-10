import SwiftUI

// Mi plan (mapa §3.7): limites de disciplina, las cuatro listas una
// por linea, el checklist de entrada con su nucleo, y las plantillas.
// El PUT manda stopPct NO opcional y limitePerdidaDiaria opcional.

@MainActor
final class PlanModel: ObservableObject {
    @Published var respuesta: RespuestaPlan? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var aviso: String? = nil
    @Published var sesionExpirada = false
    @Published var guardando = false
    // Formulario
    @Published var limiteSuave = ""
    @Published var limiteDuro = ""
    @Published var interruptor = ""
    @Published var stopPct = ""
    @Published var limiteDiario = ""
    @Published var estrategias = ""
    @Published var patrones = ""
    @Published var motivos = ""
    @Published var errores = ""
    @Published var checklist: [ChecklistPlanDto] = []

    func cargar() {
        cargando = true
        Task {
            do {
                let datos = try await Api.plan()
                respuesta = datos
                sembrar(datos.plan)
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla { sesionExpirada = true; Sesion.cerrar() }
                else if respuesta == nil { errorTexto = falla.errorDescription }
            } catch {
                cargando = false
                if respuesta == nil { errorTexto = "Algo salió mal. Inténtalo de nuevo." }
            }
        }
    }

    private func sembrar(_ plan: PlanDto) {
        limiteSuave = "\(plan.limiteSuave)"
        limiteDuro = "\(plan.limiteDuro)"
        interruptor = "\(plan.interruptorRacha)"
        stopPct = plan.stopPct.map { numeroSemilla($0) } ?? "30"
        limiteDiario = plan.limitePerdidaDiaria.map { numeroSemilla($0) } ?? ""
        estrategias = plan.estrategias.joined(separator: "\n")
        patrones = plan.patrones.joined(separator: "\n")
        motivos = plan.motivosSalida.joined(separator: "\n")
        errores = plan.errores.joined(separator: "\n")
        checklist = plan.checklist
    }

    private func lineas(_ texto: String) -> [String] {
        texto.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Devuelve el cuerpo del PUT, o nil si los limites no son numeros.
    private func cuerpo() -> [String: Any]? {
        guard let suave = Int(limiteSuave), let duro = Int(limiteDuro),
              let inter = Int(interruptor), let stop = Double(stopPct) else {
            return nil
        }
        let limiteD: Any = limiteDiario.trimmingCharacters(in: .whitespaces).isEmpty
            ? NSNull()
            : (Double(limiteDiario) as Any)
        let checklistLimpio = checklist
            .filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ["key": $0.key, "label": $0.label, "core": $0.core] as [String: Any] }
        return [
            "estrategias": lineas(estrategias),
            "patrones": lineas(patrones),
            "motivos_salida": lineas(motivos),
            "errores": lineas(errores),
            "checklist": checklistLimpio,
            "limite_suave": suave,
            "limite_duro": duro,
            "interruptor_racha": inter,
            "stop_pct": stop,
            "limite_perdida_diaria": limiteD,
        ]
    }

    func guardar() {
        guard let cuerpo = cuerpo() else {
            errorTexto = "Revisa los límites: deben ser números (el % de stop puede llevar decimales)."
            aviso = nil
            return
        }
        guardando = true
        errorTexto = nil
        aviso = nil
        Task {
            do {
                let r = try await Api.guardarPlan(cuerpo)
                aviso = r.message
                sembrar(r.plan)
                if let actual = respuesta {
                    respuesta = RespuestaPlanReconstruida(plan: r.plan, plantillas: actual.plantillas)
                }
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

    func aplicarPlantilla(_ plantilla: PlantillaDto) {
        guardando = true
        errorTexto = nil
        aviso = nil
        Task {
            do {
                let r = try await Api.aplicarPlantilla(clave: plantilla.clave)
                aviso = r.message
                sembrar(r.plan)
                if let actual = respuesta {
                    respuesta = RespuestaPlanReconstruida(plan: r.plan, plantillas: actual.plantillas)
                }
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
}

/// Reconstruye la respuesta del plan tras guardar (la lista de
/// plantillas no viene en la respuesta de guardado).
private func RespuestaPlanReconstruida(plan: PlanDto, plantillas: [PlantillaDto]) -> RespuestaPlan {
    // Se decodifica de un JSON vacio y se rellena: el DTO es de solo
    // lectura desde la red; aqui se compone en memoria.
    var r = RespuestaPlanVacia.hacer()
    r.plan = plan
    r.plantillas = plantillas
    return r
}

enum RespuestaPlanVacia {
    static func hacer() -> RespuestaPlan {
        try! JSONDecoder().decode(RespuestaPlan.self, from: Data("{}".utf8))
    }
}

struct PlanView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = PlanModel()
    @State private var plantillaPendiente: PlantillaDto? = nil
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let respuesta = modelo.respuesta {
                ScrollView {
                    VStack(spacing: 14) {
                        HStack {
                            Text("Mi plan")
                                .font(.manrope(24, weight: .heavy))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                        }
                        Text("Tus límites y tu vocabulario. Kiptrade mide tu disciplina contra lo que declaras aquí.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        tarjetaLimites
                        tarjetaListas
                        tarjetaChecklist
                        if !respuesta.plantillas.isEmpty {
                            tarjetaPlantillas(respuesta.plantillas)
                        }
                        if let aviso = modelo.aviso {
                            Text(aviso)
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(KipColor.verdePnl(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let error = modelo.errorTexto {
                            Text(error)
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(KipColor.error(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        BotonKip(texto: modelo.guardando ? "Guardando…" : "Guardar mi plan", deshabilitado: modelo.guardando) {
                            modelo.guardar()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            } else if modelo.cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar tu plan.") { modelo.cargar() }
            }
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .onAppear { if modelo.respuesta == nil { modelo.cargar() } }
        .confirmationDialog("Aplicar plantilla", isPresented: Binding(
            get: { plantillaPendiente != nil },
            set: { if !$0 { plantillaPendiente = nil } }
        ), titleVisibility: .visible) {
            Button("Aplicar") {
                if let plantilla = plantillaPendiente { modelo.aplicarPlantilla(plantilla) }
                plantillaPendiente = nil
            }
            Button("Cancelar", role: .cancel) { plantillaPendiente = nil }
        } message: {
            if let plantilla = plantillaPendiente {
                Text("«\(plantilla.nombre)» reemplazará tus listas y tu checklist. Tus límites quedan como están. ¿Seguir?")
            }
        }
    }

    private var tarjetaLimites: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Tus límites de disciplina")
                CampoKip(etiqueta: "Límite suave de trades al día", texto: $modelo.limiteSuave, teclado: .numberPad)
                CampoKip(etiqueta: "Límite duro de trades al día", texto: $modelo.limiteDuro, teclado: .numberPad)
                CampoKip(etiqueta: "Pérdidas seguidas para detenerte (interruptor)", texto: $modelo.interruptor, teclado: .numberPad)
                CampoKip(etiqueta: "% de stop sobre la prima", texto: $modelo.stopPct, teclado: .decimalPad)
                CampoKip(etiqueta: "Límite de pérdida diaria en $ (opcional)", texto: $modelo.limiteDiario, teclado: .decimalPad)
                Text("Es la referencia del mapa de calor del calendario. Déjalo vacío si no lo declaras.")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private var tarjetaListas: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Tus listas (una por línea)")
                CampoKip(etiqueta: "Estrategias", texto: $modelo.estrategias, multilinea: true, lineasMinimas: 3)
                CampoKip(etiqueta: "Patrones de entrada", texto: $modelo.patrones, multilinea: true, lineasMinimas: 3)
                CampoKip(etiqueta: "Motivos de salida", texto: $modelo.motivos, multilinea: true, lineasMinimas: 3)
                CampoKip(etiqueta: "Errores principales", texto: $modelo.errores, multilinea: true, lineasMinimas: 3)
            }
        }
    }

    private var tarjetaChecklist: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Checklist de entrada")
                Text("Marca el núcleo: los puntos que SÍ cuentan para tu KipScore y tu % de checklist.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                ForEach(Array(modelo.checklist.enumerated()), id: \.offset) { indice, _ in
                    HStack(spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { modelo.checklist[indice].core },
                            set: { modelo.checklist[indice].core = $0 }
                        )) { EmptyView() }
                        .toggleStyle(CheckboxKipStyle())
                        .labelsHidden()
                        TextField("Punto del checklist", text: Binding(
                            get: { modelo.checklist[indice].label },
                            set: { modelo.checklist[indice].label = $0 }
                        ))
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(KipColor.card(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button {
                            modelo.checklist.remove(at: indice)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(KipColor.rojoPnl(scheme))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    modelo.checklist.append(ChecklistPlanDto(key: "", label: "", core: false))
                } label: {
                    Text("Agregar punto")
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(KipColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tarjetaPlantillas(_ plantillas: [PlantillaDto]) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Plantillas")
                Text("Aplicar una plantilla reemplaza tus listas y tu checklist. Tus límites no cambian.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                ForEach(plantillas) { plantilla in
                    BotonBordeKip(texto: plantilla.nombre) {
                        plantillaPendiente = plantilla
                    }
                }
            }
        }
    }
}
