import SwiftUI

// KipCoach + Journal (mapa §3.8): pastillas Coach/Journal. El Coach:
// Hoy (con las claves camelCase del servidor), tu semana (claves en
// ingles), el analisis, el historial y el mapa de calor emocional.
// El Journal: navegador de dia, reflexion, nota de voz, cerrados y
// abiertos del dia, e historial.

@MainActor
final class CoachModel: ObservableObject {
    @Published var datos: CoachDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var analizando = false
    @Published var analisisElegido: AnalisisDto? = nil

    func cargar() {
        cargando = true
        Task {
            do {
                datos = try await Api.coach()
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

    func analizar() {
        analizando = true
        Task {
            do {
                let r = try await Api.analizarCoach()
                analisisElegido = r.analisis
                analizando = false
                cargar()
            } catch let falla as ApiError {
                analizando = false
                errorTexto = falla.errorDescription
            } catch {
                analizando = false
                errorTexto = "Algo salió mal. Inténtalo de nuevo."
            }
        }
    }
}

struct CoachView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var pestana = 0
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("KipCoach")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            PastillasSeccion(opciones: ["Coach", "Journal"], elegida: $pestana)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            if pestana == 0 {
                SeccionCoach(alEntrarDeNuevo: alEntrarDeNuevo)
            } else {
                SeccionJournal(alAbrirTrade: alAbrirTrade, alEntrarDeNuevo: alEntrarDeNuevo)
            }
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
    }
}

struct SeccionCoach: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = CoachModel()
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 14) {
                        tarjetaHoy(datos)
                        tarjetaSemana(datos)
                        tarjetaAnalisis(datos)
                        if datos.historial.count > 1 {
                            historial(datos)
                        }
                        if !datos.mapaEmociones.dias.isEmpty {
                            mapaCalorEmocional(datos.mapaEmociones)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            } else if modelo.cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar KipCoach.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
    }

    private func tarjetaHoy(_ datos: CoachDto) -> some View {
        let hoy = datos.hoy
        let colorEstado: Color = hoy.status == "rojo" ? KipColor.rojoPnl(scheme)
            : (hoy.status == "ambar" ? Color(hex: 0xF2C14E) : KipColor.verdePnl(scheme))
        return KipCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle().fill(colorEstado).frame(width: 11, height: 11)
                    TituloTarjeta(texto: "Hoy")
                }
                Text("\(hoy.tradesToday) operaciones hoy · neto \(dinero(hoy.netToday))")
                    .font(.manrope(15, weight: .semibold))
                    .foregroundStyle(KipColor.text(scheme))
                if hoy.signals.isEmpty {
                    Text("Sin señales de sesgo hoy. Tu espejo está tranquilo.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                } else {
                    ForEach(Array(hoy.signals.enumerated()), id: \.offset) { _, senal in
                        Text("• \(senal.text)")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                }
            }
        }
    }

    private func tarjetaSemana(_ datos: CoachDto) -> some View {
        let s = datos.semana
        let filas: [(etiqueta: String, sesgo: SesgoSemanaDto)] = [
            ("Revancha", s.revenge), ("Salidas por miedo", s.fear), ("FOMO", s.fomo),
            ("Desviaciones del plan", s.deviated), ("Siguiendo el plan", s.followed),
            ("Total de la semana", s.total),
        ]
        return KipCard {
            VStack(alignment: .leading, spacing: 9) {
                TituloTarjeta(texto: "Tu semana (últimos 7 días)")
                ForEach(Array(filas.enumerated()), id: \.offset) { _, fila in
                    HStack {
                        Text("\(fila.etiqueta) · \(fila.sesgo.trades)")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer()
                        Text(dinero(fila.sesgo.net))
                            .font(.manrope(14, weight: .bold))
                            .foregroundStyle(fila.sesgo.net >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                    }
                }
            }
        }
    }

    private func tarjetaAnalisis(_ datos: CoachDto) -> some View {
        let analisis = modelo.analisisElegido ?? datos.ultimoAnalisis
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Análisis de KipCoach")
                if let analisis = analisis {
                    Text(analisis.contenido)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    Text((analisis.fuente == "ai" ? "Generado con IA" : "Análisis automático (reglas)") + (analisis.creadoEn.map { " · \(fechaHora($0))" } ?? ""))
                        .font(.manrope(12))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    if !datos.iaActiva {
                        Text("La IA conversacional aún no está activa en el servidor: el análisis se genera con reglas a partir de tus registros.")
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                } else {
                    Text("Todavía no hay análisis. Genera el primero con el botón: resume tus sesgos de la semana contra tu plan.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                if let error = modelo.errorTexto, modelo.datos != nil {
                    Text(error)
                        .font(.manrope(13, weight: .semibold))
                        .foregroundStyle(KipColor.error(scheme))
                }
                BotonKip(texto: modelo.analizando ? "Analizando…" : "Analizar mi semana", deshabilitado: modelo.analizando) {
                    modelo.analizar()
                }
            }
        }
    }

    private func historial(_ datos: CoachDto) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TituloTarjeta(texto: "Análisis anteriores")
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(datos.historial.enumerated()), id: \.offset) { _, analisis in
                Button {
                    modelo.analisisElegido = analisis
                } label: {
                    KipCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fechaHora(analisis.creadoEn) + (analisis.fuente == "ai" ? " · con IA" : " · automático"))
                                .font(.manrope(12, weight: .semibold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                            Text(analisis.contenido)
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.text(scheme))
                                .lineLimit(2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func mapaCalorEmocional(_ mapa: MapaEmocionesDto) -> some View {
        let emociones = mapa.filas.keys.sorted()
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Mapa de calor emocional")
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Color.clear.frame(width: 104, height: 18)
                            ForEach(mapa.dias, id: \.self) { dia in
                                Text(etiquetaDiaCorta(dia))
                                    .font(.manrope(10, weight: .bold))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                    .frame(width: 46)
                            }
                        }
                        ForEach(emociones, id: \.self) { emocion in
                            HStack(spacing: 4) {
                                Text(emocion)
                                    .font(.manrope(12, weight: .semibold))
                                    .foregroundStyle(KipColor.text(scheme))
                                    .frame(width: 104, alignment: .leading)
                                    .lineLimit(1)
                                ForEach(mapa.dias, id: \.self) { dia in
                                    celdaEmocion(valor: (mapa.filas[emocion] ?? [:])[dia] ?? nil, maxAbs: mapa.maxAbs)
                                }
                            }
                        }
                    }
                }
                Text("Neto por día según tu emoción efectiva (la tuya o la detectada en tu voz).")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private func celdaEmocion(valor: Double?, maxAbs: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(colorCeldaEmocion(valor: valor, maxAbs: maxAbs))
            if let valor = valor {
                Text(dineroBarraFormato(valor))
                    .font(.manrope(9, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 2)
            }
        }
        .frame(width: 46, height: 34)
    }

    private func colorCeldaEmocion(valor: Double?, maxAbs: Double) -> Color {
        guard let valor = valor else { return KipColor.elevated(scheme).opacity(0.35) }
        let alfa = min(0.2 + 0.5 * abs(valor) / max(maxAbs, 0.0001), 0.7)
        return (valor >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)).opacity(alfa)
    }

    private func etiquetaDiaCorta(_ clave: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let d = f.date(from: clave) else { return clave }
        let salida = DateFormatter()
        salida.locale = Locale(identifier: "es")
        salida.dateFormat = "d MMM"
        salida.timeZone = TimeZone(secondsFromGMT: 0)
        return salida.string(from: d)
    }
}

// MARK: - Journal

@MainActor
final class JournalModel: ObservableObject {
    @Published var datos: JournalDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var fecha: String = claveFechaHoy()
    @Published var texto = ""
    @Published var aviso: String? = nil
    @Published var guardando = false

    func cargar() {
        cargando = true
        let fechaLocal = fecha
        Task {
            do {
                let respuesta = try await Api.journal(fecha: fechaLocal)
                datos = respuesta
                texto = respuesta.entrada?.reflexion ?? ""
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

    func irA(_ fechaNueva: String) {
        fecha = fechaNueva
        aviso = nil
        cargar()
    }

    func guardar() {
        guardando = true
        aviso = nil
        let fechaLocal = fecha
        let textoLocal = texto
        Task {
            do {
                let r = try await Api.guardarJournal(fecha: fechaLocal, reflexion: textoLocal.isEmpty ? nil : textoLocal)
                aviso = r.message
                guardando = false
                cargar()
            } catch let falla as ApiError {
                aviso = falla.errorDescription
                guardando = false
            } catch {
                aviso = "Algo salió mal. Inténtalo de nuevo."
                guardando = false
            }
        }
    }
}

struct SeccionJournal: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = JournalModel()
    @StateObject private var grabadora = GrabadoraVoz()
    @State private var subiendoAudio = false
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 14) {
                        navegadorDia
                        if modelo.fecha != claveFechaHoy() {
                            Text("Toca el día de hoy en el historial para volver, o avanza con la flecha.")
                                .font(.manrope(13))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        tarjetaReflexion(datos)
                        tarjetaVoz(datos)
                        if !datos.tradesCerrados.isEmpty {
                            seccionTradesJournal(titulo: "Cerrados ese día", trades: datos.tradesCerrados)
                        }
                        if !datos.tradesDelDia.isEmpty {
                            seccionTradesJournal(titulo: "Abiertos ese día", trades: datos.tradesDelDia)
                        }
                        if !datos.historial.isEmpty {
                            historial(datos)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            } else if modelo.cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar tu journal.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
    }

    private var navegadorDia: some View {
        HStack {
            Button { modelo.irA(claveFecha(modelo.fecha, masDias: -1)) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(fechaPuntoLarga(modelo.fecha))
                .font(.manrope(16, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
            Button { modelo.irA(claveFecha(modelo.fecha, masDias: 1)) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    private func tarjetaReflexion(_ datos: JournalDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Tu reflexión")
                CampoKip(etiqueta: "", texto: $modelo.texto, multilinea: true, lineasMinimas: 4,
                         placeholder: "¿Cómo fue tu día operando? Sé honesto…")
                if let aviso = modelo.aviso {
                    Text(aviso)
                        .font(.manrope(13, weight: .semibold))
                        .foregroundStyle(KipColor.verdePnl(scheme))
                }
                BotonKip(texto: modelo.guardando ? "Guardando…" : "Guardar reflexión", deshabilitado: modelo.guardando) {
                    modelo.guardar()
                }
            }
        }
    }

    private func tarjetaVoz(_ datos: JournalDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 9) {
                TituloTarjeta(texto: "Nota de voz del día")
                if let transcripcion = datos.entrada?.transcripcion, !transcripcion.isEmpty {
                    Text(transcripcion)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    if let emocion = datos.entrada?.emocionDetectada {
                        Text("Emoción detectada: \(emocion)")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                } else if datos.entrada?.tieneAudio == true {
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
                    Text("Grabando… cuenta tu día.")
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.rojoPnl(scheme))
                    Button {
                        grabadora.alternar { datosAudio in
                            if let datosAudio = datosAudio { subirAudio(datosAudio) }
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
                    BotonBordeKip(texto: subiendoAudio ? "Subiendo…" : (datos.entrada?.tieneAudio == true ? "Grabar de nuevo" : "Grabar nota de voz"), deshabilitado: subiendoAudio) {
                        grabadora.alternar { datosAudio in
                            if let datosAudio = datosAudio { subirAudio(datosAudio) }
                        }
                    }
                }
            }
        }
    }

    private func subirAudio(_ datosAudio: Data) {
        subiendoAudio = true
        let fecha = modelo.fecha
        Task {
            _ = try? await Api.subirAudioJournal(fecha: fecha, datos: datosAudio)
            subiendoAudio = false
            modelo.cargar()
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            modelo.cargar()
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            modelo.cargar()
        }
    }

    private func seccionTradesJournal(titulo: String, trades: [TradeDto]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TituloTarjeta(texto: titulo)
            KipCard {
                VStack(spacing: 0) {
                    ForEach(Array(trades.enumerated()), id: \.offset) { indice, trade in
                        Button { alAbrirTrade(trade.id) } label: { FilaTrade(trade: trade) }
                            .buttonStyle(.plain)
                        if indice < trades.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func historial(_ datos: JournalDto) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TituloTarjeta(texto: "Historial")
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(datos.historial.enumerated()), id: \.offset) { _, entrada in
                Button { modelo.irA(entrada.fecha) } label: {
                    KipCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fechaCorta(entrada.fecha) + (entrada.emocionDetectada.map { " · \($0)" } ?? ""))
                                .font(.manrope(12, weight: .semibold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                            Text(entrada.reflexion ?? entrada.transcripcion ?? "(sin reflexión escrita)")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.text(scheme))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
