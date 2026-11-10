import SwiftUI

// Las secciones Mensual y Calendario del Diario (mapa §3.5).

// MARK: - Cabecera de mes (anterior/siguiente del servidor)

struct CabeceraMes: View {
    @Environment(\.colorScheme) private var scheme
    let mes: String
    var alAnterior: () -> Void = {}
    var alSiguiente: () -> Void = {}
    var body: some View {
        HStack {
            Button { alAnterior() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(tituloMes(mes))
                .font(.manrope(18, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
            Button { alSiguiente() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    private func tituloMes(_ clave: String) -> String {
        guard clave.count >= 7 else { return clave }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es")
        f.dateFormat = "yyyy-MM"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let d = f.date(from: String(clave.prefix(7))) else { return clave }
        let salida = DateFormatter()
        salida.locale = Locale(identifier: "es")
        salida.dateFormat = "MMMM yyyy"
        salida.timeZone = TimeZone(secondsFromGMT: 0)
        let texto = salida.string(from: d)
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }
}

// MARK: - Mensual

@MainActor
final class MensualModel: ObservableObject {
    @Published var datos: MensualDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var mes: String? = nil
    @Published var ticker: String? = nil

    func cargar() {
        cargando = true
        let mesLocal = mes
        let tickerLocal = ticker
        Task {
            do {
                datos = try await Api.mensual(mes: mesLocal, ticker: tickerLocal)
                if let d = datos { mes = d.mes }
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

    func irA(_ mesNuevo: String) {
        mes = mesNuevo
        cargar()
    }

    func elegirTicker(_ nuevo: String?) {
        ticker = nuevo
        cargar()
    }
}

struct SeccionMensual: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = MensualModel()
    @State private var verTrades = false
    @State private var verStats = false
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 14) {
                        CabeceraMes(mes: datos.mes,
                                    alAnterior: { modelo.irA(datos.anterior) },
                                    alSiguiente: { modelo.irA(datos.siguiente) })
                        chipsTicker(datos)
                        filaTotales(datos)
                        if datos.curva.count >= 2 {
                            KipCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    TituloTarjeta(texto: "Curva del mes")
                                    CurvaConEjes(puntos: datos.curva)
                                }
                            }
                        }
                        HStack(spacing: 10) {
                            BotonBordeKip(texto: verTrades ? "Ocultar trades" : "Ver trades") { verTrades.toggle() }
                            BotonBordeKip(texto: verStats ? "Ocultar stats" : "Ver stats") { verStats.toggle() }
                        }
                        if verStats {
                            bloqueStats(datos)
                        }
                        if datos.cerrados > 0 {
                            donasPractica(datos)
                        }
                        if verTrades {
                            VStack(alignment: .leading, spacing: 4) {
                                TituloTarjeta(texto: "Operaciones del mes")
                                ForEach(Array(datos.trades.enumerated()), id: \.offset) { indice, trade in
                                    Button { alAbrirTrade(trade.id) } label: { FilaTrade(trade: trade) }
                                        .buttonStyle(.plain)
                                    if indice < datos.trades.count - 1 { Divider() }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar el mes.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
    }

    private func chipsTicker(_ datos: MensualDto) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipMes(etiqueta: "Todos · \(dinero(datos.neto))", activo: modelo.ticker == nil) {
                    modelo.elegirTicker(nil)
                }
                ForEach(Array(datos.chips.enumerated()), id: \.offset) { _, chip in
                    chipMes(etiqueta: "\(chip.ticker) · \(dinero(chip.net))", activo: modelo.ticker == chip.ticker) {
                        modelo.elegirTicker(chip.ticker)
                    }
                }
            }
        }
    }

    private func chipMes(etiqueta: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button { accion() } label: {
            Text(etiqueta)
                .font(.manrope(13, weight: .bold))
                .foregroundStyle(activo ? KipColor.onAccent : KipColor.textSecondary(scheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(activo ? KipColor.accent : KipColor.elevated(scheme))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func filaTotales(_ datos: MensualDto) -> some View {
        HStack(alignment: .top) {
            totalMes(titulo: "Neto del mes", valor: dinero(datos.neto),
                     color: datos.neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
            totalMes(titulo: "Aciertos", valor: datos.winRate.map { "\($0)%" } ?? "—", color: KipColor.text(scheme))
            totalMes(titulo: "Cerrados", valor: "\(datos.cerrados)", color: KipColor.text(scheme))
            totalMes(titulo: "Factor", valor: datos.resumen.profitFactor.map { String(format: "%.2f", $0) } ?? "—", color: KipColor.text(scheme))
        }
    }

    private func totalMes(titulo: String, valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(valor)
                .font(.manrope(15, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Stats del mes

    private func bloqueStats(_ datos: MensualDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloTarjeta(texto: "Estadísticas de este mes")
            TablaDetalle(titulo: "Ganancia y pérdida", fila: datos.detalle.gainLoss)
            TablaDetalle(titulo: "Largos y cortos", fila: datos.detalle.longShort)
            TablaDetalle(titulo: "Tiempos", fila: datos.detalle.timing)
            TablaMejores(fila: datos.detalle.bestWorst)
        }
    }

    // MARK: Donas de practica 2x2

    private func donasPractica(_ datos: MensualDto) -> some View {
        let r = datos.resumen
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            DonaPractica(titulo: "Profit ($)", valor: dinero(r.neto ?? datos.neto), subleyenda: "neto",
                         verde: r.gananciaBruta, roja: r.perdidaBruta.map { abs($0) },
                         colorValor: ((r.neto ?? datos.neto) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)))
            DonaPractica(titulo: "Avg Gain ($)", valor: dinero(r.promedioGanancia), subleyenda: "por trade",
                         verde: r.promedioGanancia, roja: r.promedioPerdida.map { abs($0) },
                         colorValor: KipColor.verdePnl(scheme))
            DonaPractica(titulo: "Winning Trades", valor: "\(r.ganadores ?? 0)", subleyenda: "ganados",
                         verde: (r.ganadores ?? 0) > 0 ? Double(r.ganadores ?? 0) : nil,
                         roja: (datos.cerrados - (r.ganadores ?? 0)) > 0 ? Double(datos.cerrados - (r.ganadores ?? 0)) : nil,
                         colorValor: KipColor.text(scheme))
            DonaPractica(titulo: "Avg Gain %", valor: r.promedioGananciaPct.map { String(format: "+%.2f%%", $0) } ?? "—", subleyenda: "por trade",
                         verde: nil, roja: nil, colorValor: KipColor.text(scheme))
        }
    }
}

/// Una tabla del detalle: columnas Todo / Ganados / Perdidos con los
/// textos [S] del servidor; null -> «—».
struct TablaDetalle: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    let fila: FilaDetalleDto
    var body: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 8) {
                TituloTarjeta(texto: titulo)
                HStack(alignment: .top) {
                    columnaDetalle(titulo: "Todo", valor: fila.all)
                    columnaDetalle(titulo: "Ganados", valor: fila.won)
                    columnaDetalle(titulo: "Perdidos", valor: fila.lost)
                }
            }
        }
    }

    private func columnaDetalle(titulo: String, valor: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(valor ?? "—")
                .font(.manrope(14, weight: .semibold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La tabla «Mejores operaciones»: la columna Todo siempre «—»; cada
/// lado trae el OBJETO {ticker, detail} (trampa §5.1 del mapa).
struct TablaMejores: View {
    @Environment(\.colorScheme) private var scheme
    let fila: FilaMejorPeorDto
    var body: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 8) {
                TituloTarjeta(texto: "Mejores operaciones")
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Todo")
                            .font(.manrope(11, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Text("—")
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ladoMejor(titulo: "Ganados", objeto: fila.won)
                    ladoMejor(titulo: "Perdidos", objeto: fila.lost)
                }
            }
        }
    }

    private func ladoMejor(titulo: String, objeto: MejorPeorDto?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            if let objeto = objeto {
                Text(objeto.ticker)
                    .font(.manrope(14, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(objeto.detail)
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            } else {
                Text("—")
                    .font(.manrope(14, weight: .semibold))
                    .foregroundStyle(KipColor.text(scheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La dona de practica de Mensual: anillo con fondo #35485A, dos arcos
/// desde -90 grados, centro con valor + subleyenda, titulo debajo.
struct DonaPractica: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    let valor: String
    let subleyenda: String
    let verde: Double?
    let roja: Double?
    let colorValor: Color
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color(hex: 0x35485A), lineWidth: 11)
                if let verde = verde, let roja = roja, (verde + roja) > 0 {
                    let fraccion = verde / (verde + roja)
                    Circle()
                        .trim(from: 0, to: CGFloat(fraccion))
                        .stroke(KipColor.verdePnl(scheme), style: StrokeStyle(lineWidth: 11, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .trim(from: CGFloat(fraccion), to: 1)
                        .stroke(KipColor.rojoPnl(scheme), style: StrokeStyle(lineWidth: 11, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 1) {
                    Text(valor)
                        .font(.manrope(15, weight: .heavy))
                        .foregroundStyle(colorValor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 8)
                    Text(subleyenda)
                        .font(.manrope(10))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
            .frame(width: 104, height: 104)
            Text(titulo)
                .font(.manrope(13, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(KipColor.card(scheme))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Calendario

@MainActor
final class CalendarioModel: ObservableObject {
    @Published var datos: CalendarioDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var mes: String? = nil

    func cargar() {
        cargando = true
        let mesLocal = mes
        Task {
            do {
                datos = try await Api.calendario(mes: mesLocal)
                if let d = datos { mes = d.mes }
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

    func irA(_ mesNuevo: String) {
        mes = mesNuevo
        cargar()
    }
}

struct SeccionCalendario: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = CalendarioModel()
    @State private var diaElegido: String? = nil
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 14) {
                        CabeceraMes(mes: datos.mes,
                                    alAnterior: { modelo.irA(datos.anterior); diaElegido = nil },
                                    alSiguiente: { modelo.irA(datos.siguiente); diaElegido = nil })
                        if !datos.mapa.isEmpty {
                            mapaCalor(datos)
                        }
                        rejillaMes(datos)
                        tarjetaTotales(datos)
                        if let dia = diaElegido {
                            operacionesDelDia(datos, dia: dia)
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
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudo cargar el calendario.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
    }

    // MARK: Mapa de calor (semanas lunes a viernes, sin sabado/domingo)

    private func mapaCalor(_ datos: CalendarioDto) -> some View {
        let referencia = datos.limiteDiario ?? (datos.mapa.map { abs($0.neto) }.max() ?? 0)
        let porFecha = Dictionary(uniqueKeysWithValues: datos.mapa.map { ($0.fecha, $0.neto) })
        let semanas = semanasDelMapa(datos.mapa.map { $0.fecha })
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Mapa de calor P&L")
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(semanas.enumerated()), id: \.offset) { _, semana in
                        HStack(spacing: 3) {
                            Text(etiquetaMesSemana(semana))
                                .font(.manrope(10, weight: .bold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(width: 26, alignment: .leading)
                            ForEach(Array(semana.enumerated()), id: \.offset) { _, clave in
                                celdaMapa(clave: clave, neto: porFecha[clave ?? ""], referencia: referencia)
                            }
                        }
                    }
                }
            }
        }
    }

    private func celdaMapa(clave: String?, neto: Double?, referencia: Double) -> some View {
        let color: Color
        if let neto = neto {
            let alfa = min(0.18 + 0.45 * abs(neto) / max(referencia, 0.0001), 0.85)
            color = (neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)).opacity(alfa)
        } else {
            color = KipColor.elevated(scheme).opacity(0.35)
        }
        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 14, height: 14)
    }

    /// Agrupa las fechas del mapa (ordenadas) en semanas lun-vie.
    private func semanasDelMapa(_ fechas: [String]) -> [[String?]] {
        guard let primera = fechas.first, let ultima = fechas.last else { return [] }
        var resultado: [[String?]] = []
        var cursor = lunesDe(primera)
        let conjunto = Set(fechas)
        while cursor <= ultima {
            var semana: [String?] = []
            for i in 0..<5 {
                let clave = claveFecha(cursor, masDias: i)
                semana.append(conjunto.contains(clave) ? clave : nil)
            }
            resultado.append(semana)
            cursor = claveFecha(cursor, masDias: 7)
        }
        return resultado
    }

    private func lunesDe(_ clave: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let d = f.date(from: clave) else { return clave }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let semana = cal.component(.weekday, from: d)
        let retroceso = (semana + 5) % 7
        return claveFecha(clave, masDias: -retroceso)
    }

    private func etiquetaMesSemana(_ semana: [String?]) -> String {
        guard let lunes = semana.compactMap({ $0 }).first ?? semana.first ?? nil else { return "" }
        // Etiqueta si es la primera semana o el lunes cae en dia <= 7
        let dia = Int(lunes.suffix(2)) ?? 0
        let esPrimera = modelo.datos.map { (lunesDe($0.mapa.first?.fecha ?? "") == lunes) } ?? false
        if esPrimera || dia <= 7 {
            let f = DateFormatter()
            f.locale = Locale(identifier: "es")
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = f.date(from: lunes) {
                let salida = DateFormatter()
                salida.locale = Locale(identifier: "es")
                salida.dateFormat = "MMM"
                salida.timeZone = TimeZone(secondsFromGMT: 0)
                return salida.string(from: d)
            }
        }
        return ""
    }

    // MARK: Rejilla del mes (la semana empieza en LUNES)

    private func rejillaMes(_ datos: CalendarioDto) -> some View {
        let maximoMes = datos.porDia.values.map { abs($0.net) }.max() ?? 0
        let referencia = datos.limiteDiario ?? maximoMes
        let celdas = celdasDelMes(datos.mes)
        return KipCard {
            VStack(spacing: 6) {
                HStack {
                    ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { letra in
                        Text(letra)
                            .font(.manrope(11, weight: .heavy))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(Array(celdas.enumerated()), id: \.offset) { _, clave in
                        if let clave = clave {
                            celdaDia(clave: clave, datos: datos, referencia: referencia)
                        } else {
                            Color.clear.frame(height: 52)
                        }
                    }
                }
            }
        }
    }

    private func celdaDia(clave: String, datos: CalendarioDto, referencia: Double) -> some View {
        let dia = datos.porDia[clave]
        let elegido = diaElegido == clave
        let alfa: Double = {
            guard let dia = dia else { return 0 }
            return min(0.18 + 0.45 * abs(dia.net) / max(referencia, 0.0001), 0.65)
        }()
        return Button {
            diaElegido = elegido ? nil : clave
        } label: {
            VStack(spacing: 1) {
                Text(String(clave.suffix(2)))
                    .font(.manrope(12, weight: elegido ? .heavy : .semibold))
                    .foregroundStyle(KipColor.text(scheme))
                if let dia = dia, dia.trades > 0 {
                    Text(dineroBarraFormato(dia.net))
                        .font(.manrope(9, weight: .bold))
                        .foregroundStyle(dia.net >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(dia == nil ? Color.clear : (dia!.net >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)).opacity(alfa))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(elegido ? KipColor.accent : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// Las celdas del mes con los huecos iniciales (lunes primero).
    private func celdasDelMes(_ mes: String) -> [String?] {
        let clavePrimero = String(mes.prefix(7)) + "-01"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let primero = f.date(from: clavePrimero) else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let diasEnMes = cal.range(of: .day, in: .month, for: primero)?.count ?? 30
        let semana = cal.component(.weekday, from: primero)
        let huecos = (semana + 5) % 7
        var celdas: [String?] = Array(repeating: nil, count: huecos)
        for d in 1...diasEnMes {
            celdas.append(String(format: "%@-%02d", String(mes.prefix(7)), d))
        }
        return celdas
    }

    private func tarjetaTotales(_ datos: CalendarioDto) -> some View {
        KipCard {
            HStack(alignment: .top) {
                totalCal(titulo: "Ganancia", valor: dinero(datos.ganancia), color: KipColor.verdePnl(scheme))
                totalCal(titulo: "Pérdida", valor: dinero(-datos.perdida), color: KipColor.rojoPnl(scheme))
                totalCal(titulo: "Neto", valor: dinero(datos.neto), color: datos.neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                totalCal(titulo: "Trades", valor: "\(datos.totalTrades)", color: KipColor.text(scheme))
            }
        }
    }

    private func totalCal(titulo: String, valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(valor)
                .font(.manrope(15, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func operacionesDelDia(_ datos: CalendarioDto, dia: String) -> some View {
        let delDia = datos.trades.filter { ($0.cerradoEn ?? "").hasPrefix(dia) }
        return VStack(alignment: .leading, spacing: 4) {
            TituloTarjeta(texto: "Operaciones del \(String(dia.suffix(2)))")
            if delDia.isEmpty {
                Text("Sin cierres ese día.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            } else {
                ForEach(Array(delDia.enumerated()), id: \.offset) { indice, trade in
                    Button { alAbrirTrade(trade.id) } label: { FilaTrade(trade: trade) }
                        .buttonStyle(.plain)
                    if indice < delDia.count - 1 { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
