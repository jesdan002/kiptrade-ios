import SwiftUI
import WebKit
import PhotosUI

// El detalle de la operacion (mapa §3.6), bloque por bloque: heroe,
// grafica de TradingView en WKWebView (con la receta iOS: tamano
// interno en pixeles y vigilante), multi-pata, datos del broker, nota
// de voz, captura, y «Tu registro» con el PUT de claves en ingles.

@MainActor
final class DetalleTradeModel: ObservableObject {
    @Published var respuesta: RespuestaTradeDetalle? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var aviso: String? = nil
    @Published var sesionExpirada = false
    @Published var guardando = false
    // Semillas del formulario
    @Published var emocion = ""
    @Published var estrategia = ""
    @Published var patron = ""
    @Published var motivo = ""
    @Published var errorPrincipal = ""
    @Published var siguioPlan: Bool? = nil
    @Published var stopTexto = ""
    @Published var objetivoTexto = ""
    @Published var riesgoTexto = ""
    @Published var notas = ""
    @Published var checklistMarcas: [String: Bool] = [:]

    let idTrade: Int
    init(idTrade: Int) { self.idTrade = idTrade }

    func cargar(sembrar: Bool = true) {
        cargando = true
        let id = idTrade
        Task {
            do {
                let datos = try await Api.detalleTrade(id: id)
                respuesta = datos
                if sembrar { sembrarFormulario(datos) }
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

    private func sembrarFormulario(_ datos: RespuestaTradeDetalle) {
        let t = datos.trade
        emocion = t.base.emocion ?? ""
        estrategia = t.estrategia ?? ""
        patron = t.patronEntrada ?? ""
        motivo = t.motivoSalida ?? ""
        errorPrincipal = t.errorPrincipal ?? ""
        siguioPlan = t.siguioPlan
        stopTexto = numeroSemilla(t.stopPlanificado)
        objetivoTexto = numeroSemilla(t.objetivoPlanificado)
        riesgoTexto = numeroSemilla(t.riesgo)
        notas = t.notas ?? ""
        checklistMarcas = t.checklist
    }

    /// El PUT viaja con las claves EN INGLES; campo vacio -> null.
    func guardar() {
        guardando = true
        aviso = nil
        errorTexto = nil
        func numero(_ texto: String) -> Any {
            let limpio = texto.trimmingCharacters(in: .whitespaces)
            if limpio.isEmpty { return NSNull() }
            if let v = Double(limpio) { return v }
            return NSNull()
        }
        func textoONull(_ texto: String) -> Any {
            texto.isEmpty ? NSNull() : texto
        }
        var cuerpo: [String: Any] = [
            "emotion": textoONull(emocion),
            "exit_reason": textoONull(motivo),
            "notes": textoONull(notas),
            "checklist": checklistMarcas,
            "strategy": textoONull(estrategia),
            "entry_pattern": textoONull(patron),
            "planned_stop": numero(stopTexto),
            "planned_target": numero(objetivoTexto),
            "risk_amount": numero(riesgoTexto),
            "main_error": textoONull(errorPrincipal),
        ]
        if let plan = siguioPlan { cuerpo["followed_plan"] = plan } else { cuerpo["followed_plan"] = NSNull() }
        let id = idTrade
        Task {
            do {
                let r = try await Api.guardarTrade(id: id, cuerpo: cuerpo)
                aviso = r.message
                guardando = false
                cargar(sembrar: false)
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

struct DetalleTradeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelo: DetalleTradeModel
    @State private var tf = "5"
    @State private var capturaVersion = 1
    @State private var fotoCaptura: PhotosPickerItem? = nil
    @State private var subiendoCaptura = false
    @State private var preparandoCaptura = false
    @State private var confirmarQuitarCaptura = false
    @State private var verCapturaGrande = false
    @StateObject private var grabadora = GrabadoraVoz()
    @State private var subiendoAudio = false

    init(idTrade: Int) {
        _modelo = StateObject(wrappedValue: DetalleTradeModel(idTrade: idTrade))
    }

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: { dismiss() })
            } else if let respuesta = modelo.respuesta {
                ScrollView {
                    VStack(spacing: 14) {
                        heroe(respuesta.trade)
                        grafica(respuesta.trade)
                        if respuesta.trade.grupoPatasDetalle.count > 1 {
                            multiPata(respuesta.trade)
                        }
                        datosBroker(respuesta.trade)
                        notaVoz(respuesta.trade)
                        captura(respuesta.trade)
                        tuRegistro(respuesta)
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
                        BotonKip(texto: modelo.guardando ? "Guardando…" : "Guardar cambios", deshabilitado: modelo.guardando) {
                            modelo.guardar()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
                .refreshable { modelo.cargar(sembrar: false) }
            } else if modelo.cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar la operación.") { modelo.cargar() }
            }
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .navigationTitle("Detalle de la operación")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if modelo.respuesta == nil { modelo.cargar() } }
        .onChange(of: fotoCaptura) { _, nuevo in
            guard let nuevo = nuevo else { return }
            preparandoCaptura = true
            Task {
                if let datos = try? await nuevo.loadTransferable(type: Data.self),
                   let imagen = UIImage(data: datos),
                   let jpeg = procesarCaptura(imagen) {
                    subiendoCaptura = true
                    _ = try? await Api.subirCapturaTrade(id: modelo.idTrade, datos: jpeg)
                    capturaVersion += 1
                    subiendoCaptura = false
                    modelo.cargar(sembrar: false)
                }
                preparandoCaptura = false
                fotoCaptura = nil
            }
        }
    }

    // MARK: - Heroe

    private func heroe(_ t: TradeDetalleDto) -> some View {
        let titulo: String = {
            if t.base.esOpcion {
                var texto = "\(t.base.ticker) \(t.base.tipo)"
                if let strike = t.base.strike { texto += " " + strikeTexto(strike) }
                return texto
            }
            return "\(t.base.ticker) · Acción"
        }()
        return KipCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo)
                        .font(.manrope(20, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    if let contrato = t.contrato, !contrato.isEmpty {
                        Text(contrato)
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Text(dinero(t.base.neto))
                        .font(.manrope(24, weight: .heavy))
                        .foregroundStyle((t.base.neto ?? 0) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let r = t.rMultiple {
                        Text("R: \(String(format: "%.2f", r))")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    if let pct = t.base.pnlPct {
                        Text(String(format: "%+.2f%%", pct))
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
            }
        }
    }

    // MARK: - Grafica del subyacente

    private func grafica(_ t: TradeDetalleDto) -> some View {
        let chips: [(etiqueta: String, valor: String)] = [
            ("1m", "1"), ("5m", "5"), ("15m", "15"), ("30m", "30"), ("1h", "60"), ("1D", "D"),
        ]
        let simbolo = (t.base.ticker == "SPXW" || t.base.ticker == "SPX") ? "SPX" : t.base.ticker
        let tema = scheme == .dark ? "dark" : "light"
        let urlWidget = "https://app.kiptrade.net/widget/grafica?simbolo=\(simbolo)&tf=\(tf)&tema=\(tema)&zona=\(TimeZone.current.identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Gráfica del subyacente")
                HStack(spacing: 6) {
                    ForEach(chips, id: \.valor) { chip in
                        Button { tf = chip.valor } label: {
                            Text(chip.etiqueta)
                                .font(.manrope(12, weight: .bold))
                                .foregroundStyle(tf == chip.valor ? KipColor.onAccent : KipColor.textSecondary(scheme))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tf == chip.valor ? KipColor.accent : KipColor.elevated(scheme))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                VistaGraficaTV(simbolo: simbolo, tf: tf, tema: tema, zona: TimeZone.current.identifier)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 10) {
                    Link("Ver en el navegador", destination: URL(string: urlWidget)!)
                        .font(.manrope(13, weight: .bold))
                        .foregroundStyle(KipColor.accent)
                    Spacer()
                    NavigationLink {
                        VistaGraficaTV(simbolo: simbolo, tf: tf, tema: tema, zona: TimeZone.current.identifier)
                            .ignoresSafeArea()
                            .navigationTitle(simbolo)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Text("Ver en grande")
                            .font(.manrope(13, weight: .bold))
                            .foregroundStyle(KipColor.accent)
                    }
                }
            }
        }
    }

    // MARK: - Multi-pata

    private func multiPata(_ t: TradeDetalleDto) -> some View {
        let patas = t.grupoPatasDetalle
        let todasCerradas = patas.allSatisfy { $0.estado == "closed" && $0.neto != nil }
        let netoConjunto = patas.compactMap { $0.neto }.reduce(0, +)
        return KipCard {
            VStack(alignment: .leading, spacing: 8) {
                TituloTarjeta(texto: "Operación de \(patas.count) patas")
                Text("Las patas entraron en la misma orden: se leen juntas, no como operaciones sueltas.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                if todasCerradas {
                    Text("Neto del conjunto: \(dinero(netoConjunto))")
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(netoConjunto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                }
                ForEach(patas) { pata in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(pata.tipo ?? "") \(pata.strike.map { strikeTexto($0) } ?? "") · \(pata.lado == "short" ? "vendida" : "comprada") ×\(pata.cantidad)")
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(KipColor.text(scheme))
                            if pata.id == t.base.id {
                                Text("esta pata")
                                    .font(.manrope(12))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                        }
                        Spacer()
                        Text(pata.neto.map { dinero($0) } ?? "abierta")
                            .font(.manrope(14, weight: .bold))
                            .foregroundStyle((pata.neto ?? 0) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Datos del broker

    private func datosBroker(_ t: TradeDetalleDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 8) {
                TituloTarjeta(texto: "Datos de tu broker")
                Text("Vienen de tu cuenta y no se editan.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                datoBroker("Entrada", dineroSinSigno(t.base.precioApertura))
                datoBroker("Salida", dineroSinSigno(t.base.precioCierre))
                datoBroker("Cantidad", "\(t.base.cantidad)")
                datoBroker("Apertura", fechaHora(t.base.abiertoEn))
                datoBroker("Cierre", fechaHora(t.base.cerradoEn))
                if let vencimiento = t.vencimiento {
                    datoBroker("Vencimiento", vencimiento)
                }
                if let cuenta = t.cuenta {
                    datoBroker("Cuenta", cuenta)
                }
                datoBroker("Comisiones", dineroSinSigno(t.base.fees))
                datoBroker("Bruto", dinero(t.bruto))
            }
        }
    }

    private func datoBroker(_ etiqueta: String, _ valor: String) -> some View {
        HStack {
            Text(etiqueta)
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Spacer()
            Text(valor.isEmpty ? "—" : valor)
                .font(.manrope(14, weight: .semibold))
                .foregroundStyle(KipColor.text(scheme))
        }
    }

    // MARK: - Nota de voz

    private func notaVoz(_ t: TradeDetalleDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 9) {
                TituloTarjeta(texto: "Nota de voz")
                if let transcripcion = t.transcripcion, !transcripcion.isEmpty {
                    Text(transcripcion)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    if let emocion = t.emocionDetectada {
                        Text("Emoción detectada: \(emocion)")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                } else if t.tieneAudio {
                    Text("Audio guardado. La transcripción está en proceso…")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                if grabadora.sinPermiso {
                    Text("Sin permiso de micrófono no se puede grabar. Actívalo para esta app en los ajustes del teléfono.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.error(scheme))
                }
                if grabadora.grabando {
                    Text("Grabando… habla de tu operación.")
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.rojoPnl(scheme))
                    Button {
                        grabadora.alternar { datos in
                            if let datos = datos { subirAudio(datos) }
                        }
                    } label: {
                        Text("Detener y guardar")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(KipColor.rojoPnl(scheme))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    BotonBordeKip(texto: subiendoAudio ? "Subiendo…" : (t.tieneAudio ? "Grabar de nuevo" : "Grabar nota de voz"), deshabilitado: subiendoAudio) {
                        grabadora.alternar { datos in
                            if let datos = datos { subirAudio(datos) }
                        }
                    }
                }
            }
        }
    }

    private func subirAudio(_ datos: Data) {
        subiendoAudio = true
        Task {
            _ = try? await Api.subirAudioTrade(id: modelo.idTrade, datos: datos)
            subiendoAudio = false
            modelo.cargar(sembrar: false)
            // La transcripcion tarda: se recarga a los 6 s y 15 s.
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            modelo.cargar(sembrar: false)
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            modelo.cargar(sembrar: false)
        }
    }

    // MARK: - Captura

    private func captura(_ t: TradeDetalleDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 9) {
                TituloTarjeta(texto: "Captura de la entrada")
                if t.tieneCaptura {
                    Text("Tu captura guardada. Tócala para verla en grande.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Button { verCapturaGrande = true } label: {
                        CapturaImagen(id: modelo.idTrade, version: capturaVersion)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $fotoCaptura, matching: .images) {
                            Text(preparandoCaptura || subiendoCaptura ? "Subiendo…" : "Cambiar")
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(KipColor.accent)
                        }
                        Spacer()
                        Button { confirmarQuitarCaptura = true } label: {
                            Text("Quitar")
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(KipColor.rojoPnl(scheme))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Guarda la foto de tu gráfica al entrar: cuando revises el trade, la captura te dice lo que viste en ese momento.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    PhotosPicker(selection: $fotoCaptura, matching: .images) {
                        Text(preparandoCaptura || subiendoCaptura ? "Subiendo…" : "Subir captura")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: 1))
                    }
                }
            }
        }
        .confirmationDialog("¿Quitar la captura?", isPresented: $confirmarQuitarCaptura, titleVisibility: .visible) {
            Button("Quitar", role: .destructive) {
                Task {
                    _ = try? await Api.borrarCapturaTrade(id: modelo.idTrade)
                    capturaVersion += 1
                    modelo.cargar(sembrar: false)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borra la imagen guardada de este trade. No se puede deshacer.")
        }
        .sheet(isPresented: $verCapturaGrande) {
            VisorCaptura(id: modelo.idTrade, version: capturaVersion)
        }
    }

    // MARK: - Tu registro

    private func tuRegistro(_ respuesta: RespuestaTradeDetalle) -> some View {
        let opciones = respuesta.opciones
        return KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Tu registro")
                Text("Sé completamente honesto: reconocer lo que hiciste mal y lo que hiciste bien es lo que te hará progresar.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                SelectorRegistro(etiqueta: "Emoción", opciones: opciones.emociones, valor: $modelo.emocion)
                SelectorRegistro(etiqueta: "Estrategia", opciones: opciones.estrategias, valor: $modelo.estrategia)
                SelectorRegistro(etiqueta: "Patrón de entrada", opciones: opciones.patrones, valor: $modelo.patron)
                SelectorRegistro(etiqueta: "Motivo de salida", opciones: opciones.motivosSalida, valor: $modelo.motivo)
                SelectorRegistro(etiqueta: "Error principal", opciones: opciones.errores, valor: $modelo.errorPrincipal)
                VStack(alignment: .leading, spacing: 7) {
                    Text("¿Seguiste tu plan?")
                        .font(.manrope(13, weight: .semibold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    HStack(spacing: 8) {
                        chipPlan(texto: "Sí", activo: modelo.siguioPlan == true) { modelo.siguioPlan = true }
                        chipPlan(texto: "No", activo: modelo.siguioPlan == false) { modelo.siguioPlan = false }
                        chipPlan(texto: "Sin registrar", activo: modelo.siguioPlan == nil) { modelo.siguioPlan = nil }
                    }
                }
                CampoKip(etiqueta: "Stop planificado ($)", texto: $modelo.stopTexto, teclado: .decimalPad)
                CampoKip(etiqueta: "Objetivo planificado ($)", texto: $modelo.objetivoTexto, teclado: .decimalPad)
                CampoKip(etiqueta: "Riesgo del trade ($)", texto: $modelo.riesgoTexto, teclado: .decimalPad)
                if !opciones.checklist.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Checklist de tu plan")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        ForEach(opciones.checklist) { item in
                            Toggle(isOn: Binding(
                                get: { modelo.checklistMarcas[item.key] ?? false },
                                set: { modelo.checklistMarcas[item.key] = $0 }
                            )) {
                                Text(item.label)
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.text(scheme))
                            }
                            .toggleStyle(CheckboxKipStyle())
                        }
                    }
                }
                CampoKip(etiqueta: "Notas", texto: $modelo.notas, multilinea: true, lineasMinimas: 3)
            }
        }
    }

    private func chipPlan(texto: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button { accion() } label: {
            Text(texto)
                .font(.manrope(13, weight: .bold))
                .foregroundStyle(activo ? KipColor.onAccent : KipColor.textSecondary(scheme))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(activo ? KipColor.accent : KipColor.elevated(scheme))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Un selector del registro: «Sin registrar» primero, despues las
/// opciones que manda el servidor (no se inventa vocabulario).
struct SelectorRegistro: View {
    @Environment(\.colorScheme) private var scheme
    let etiqueta: String
    let opciones: [String]
    @Binding var valor: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(etiqueta)
                .font(.manrope(13, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Menu {
                Button("Sin registrar") { valor = "" }
                ForEach(opciones, id: \.self) { opcion in
                    Button(opcion) { valor = opcion }
                }
            } label: {
                HStack {
                    Text(valor.isEmpty ? "Sin registrar" : valor)
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
    }
}

/// La imagen de la captura, descargada con Bearer y cache-busting.
struct CapturaImagen: View {
    let id: Int
    let version: Int
    @State private var imagen: UIImage? = nil
    var body: some View {
        ZStack {
            Color(hex: 0x2C3B49)
            if let imagen = imagen {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .task(id: version) {
            if let datos = await Api.descargarCaptura(id: id, version: version) {
                imagen = UIImage(data: datos)
            }
        }
    }
}

/// El visor en grande de la captura, con zoom 1-5x.
struct VisorCaptura: View {
    @Environment(\.dismiss) private var dismiss
    let id: Int
    let version: Int
    @State private var imagen: UIImage? = nil
    @State private var escala: CGFloat = 1
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let imagen = imagen {
                    Image(uiImage: imagen)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(escala)
                        .gesture(MagnificationGesture().onChanged { escala = min(max($0, 1), 5) })
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle("Captura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task {
                if let datos = await Api.descargarCaptura(id: id, version: version) {
                    imagen = UIImage(data: datos)
                }
            }
        }
    }
}

/// Procesa la captura como la Android: max. 2048 px, correccion EXIF
/// y re-codificacion JPEG calidad 88.
func procesarCaptura(_ imagen: UIImage) -> Data? {
    var img = imagen
    let maximo: CGFloat = 2048
    if img.size.width > maximo || img.size.height > maximo {
        let escala = maximo / max(img.size.width, img.size.height)
        let nuevo = CGSize(width: img.size.width * escala, height: img.size.height * escala)
        let render = UIGraphicsImageRenderer(size: nuevo)
        img = render.image { _ in img.draw(in: CGRect(origin: .zero, size: nuevo)) }
    }
    return img.jpegData(compressionQuality: 0.88)
}

// MARK: - La grafica de TradingView en WKWebView

/// El widget advanced-chart de TradingView con el HTML de la Android
/// (tamano fijado en pixeles por JS + vigilante que avisa por el
/// puente KipChart), para no repetir la saga del WebView en blanco.
struct VistaGraficaTV: UIViewRepresentable {
    let simbolo: String
    let tf: String
    let tema: String
    let zona: String

    func makeCoordinator() -> Coordinador {
        Coordinador()
    }

    func makeUIView(context: Context) -> WebGraficaTV {
        let config = WKWebViewConfiguration()
        let controlador = WKUserContentController()
        controlador.add(context.coordinator, name: "KipChart")
        config.userContentController = controlador
        let web = WebGraficaTV(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(Color(hex: tema == "dark" ? 0x131722 : 0xFFFFFF))
        web.scrollView.isScrollEnabled = false
        // La carga ocurre cuando el visor YA tiene su tamano real
        // (la leccion de la Android 0.14.16: si la pagina nace contra
        // un visor sin maquetar, window.innerHeight vale 0 y el
        // widget de TradingView nace muerto, en blanco).
        context.coordinator.vincular(web)
        return web
    }

    func updateUIView(_ web: WebGraficaTV, context: Context) {
        context.coordinator.pedir(simbolo: simbolo, tf: tf, tema: tema, zona: zona)
    }

    final class Coordinador: NSObject, WKScriptMessageHandler {
        private weak var web: WebGraficaTV?
        private var claveCargada = ""
        private var pendiente: (clave: String, html: String)? = nil

        func vincular(_ web: WebGraficaTV) {
            self.web = web
            web.alTenerTamano = { [weak self] in self?.cargarSiListo() }
        }

        func pedir(simbolo: String, tf: String, tema: String, zona: String) {
            let clave = "\(simbolo)|\(tf)|\(tema)|\(zona)"
            if clave == claveCargada || clave == pendiente?.clave { return }
            pendiente = (clave, htmlGraficaTV(simbolo: simbolo, tf: tf, tema: tema, zona: zona))
            cargarSiListo()
        }

        private func cargarSiListo() {
            guard let web, web.bounds.height > 0, web.bounds.width > 0,
                  let pendiente else { return }
            claveCargada = pendiente.clave
            self.pendiente = nil
            // El origen de la pagina es tradingview.com, como en la
            // Android (loadDataWithBaseURL): con otro origen el
            // script de embed no levanta el widget.
            web.loadHTMLString(pendiente.html, baseURL: URL(string: "https://www.tradingview.com"))
        }

        func userContentController(_ controller: WKUserContentController, didReceive mensaje: WKScriptMessage) {}
    }
}

/// WKWebView que avisa cuando por fin tiene tamano real.
final class WebGraficaTV: WKWebView {
    var alTenerTamano: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.height > 0 && bounds.width > 0 {
            alTenerTamano?()
        }
    }
}

/// El HTML de la grafica, el mismo de htmlGrafica() de la Android.
func htmlGraficaTV(simbolo: String, tf: String, tema: String, zona: String) -> String {
    let permitido = simbolo.filter { $0.isLetter || $0.isNumber || ".-/:".contains($0) }
    let simboloSeguro = permitido.isEmpty ? "SPX" : permitido
    let fondo = tema == "dark" ? "#131722" : "#FFFFFF"
    return """
    <!DOCTYPE html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>html,body{margin:0;padding:0;background:\(fondo);overflow:hidden}
    .tradingview-widget-container{width:100%}
    .tradingview-widget-container__widget{width:100%}</style>
    </head><body><div class="tradingview-widget-container">
    <div class="tradingview-widget-container__widget"></div>
    </div>
    <script>
    window.addEventListener('load', function () {
        setTimeout(function () {
            var c = document.querySelector('.tradingview-widget-container');
            var w = document.querySelector('.tradingview-widget-container__widget');
            var h = window.innerHeight + 'px';
            c.style.height = h;
            w.style.height = h;
            var s = document.createElement('script');
            s.type = 'text/javascript';
            s.async = true;
            s.src = 'https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js';
            s.innerHTML = '{' +
                '"autosize": true,' +
                '"symbol": "\(simboloSeguro)",' +
                '"interval": "\(tf)",' +
                '"timezone": "\(zona)",' +
                '"theme": "\(tema)",' +
                '"style": "1",' +
                '"locale": "es",' +
                '"hide_top_toolbar": true,' +
                '"hide_side_toolbar": true,' +
                '"hide_legend": true,' +
                '"hide_volume": true,' +
                '"allow_symbol_change": false,' +
                '"save_image": false,' +
                '"support_host": "https://www.tradingview.com"' +
            '}';
            c.appendChild(s);
        }, 60);
    });
    </script>
    <script>
    (function () {
        var n = 0;
        var avisado = false;
        var t = setInterval(function () {
            n++;
            var ifr = document.querySelector('.tradingview-widget-container iframe');
            if (ifr && !avisado) {
                avisado = true;
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.KipChart) {
                    window.webkit.messageHandlers.KipChart.postMessage('listo');
                }
                var r0 = ifr.getBoundingClientRect();
                if (r0.height < window.innerHeight * 0.9) {
                    ifr.style.width = '100%';
                    ifr.style.height = window.innerHeight + 'px';
                }
            }
            if (ifr && n >= 8) {
                clearInterval(t);
            } else if (!ifr && n >= 40) {
                clearInterval(t);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.KipChart) {
                    window.webkit.messageHandlers.KipChart.postMessage('fallo');
                }
            }
        }, 500);
    })();
    </script>
    </body></html>
    """
}
