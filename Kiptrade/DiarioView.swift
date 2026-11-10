import SwiftUI

// El Diario de Kiptrade iOS (mapa §3.5): pastillas Trades / Mensual /
// Calendario / Estadisticas. Trades: buscador con icono de filtros y
// badge, chips rapidos, lista agrupada por dia con TarjetaDia y grupos
// multi-pata. La cuota de filtros es la de la Android (Filtros.kt).

struct FiltrosDiario: Equatable {
    var q: String = ""
    var ticker: String? = nil
    var tipo: String? = nil
    var estrategia: String? = nil
    var estado: String? = nil
    var cuenta: Int? = nil
    var emocion: String? = nil
    var resultado: String? = nil
    var lado: String? = nil
    var orden: String = "recientes"
    var desde: String? = nil
    var hasta: String? = nil

    var activos: Int {
        var n = 0
        if ticker != nil { n += 1 }
        if tipo != nil { n += 1 }
        if estrategia != nil { n += 1 }
        if estado != nil { n += 1 }
        if emocion != nil { n += 1 }
        if resultado != nil { n += 1 }
        if lado != nil { n += 1 }
        if desde != nil { n += 1 }
        if hasta != nil { n += 1 }
        if cuenta != nil { n += 1 }
        if orden != "recientes" { n += 1 }
        return n
    }

    func query() -> [(String, String?)] {
        [
            ("q", q.isEmpty ? nil : q), ("ticker", ticker), ("tipo", tipo),
            ("estrategia", estrategia), ("estado", estado), ("emocion", emocion),
            ("resultado", resultado), ("orden", orden),
            ("cuenta", cuenta.map { "\($0)" }), ("lado", lado),
            ("desde", desde), ("hasta", hasta),
        ]
    }
}

@MainActor
final class DiarioModel: ObservableObject {
    @Published var datos: DiarioDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var filtros = FiltrosDiario()

    func cargar() {
        cargando = true
        let query = filtros.query()
        Task {
            do {
                datos = try await Api.diario(query: query)
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

    func aplicar(_ nuevos: FiltrosDiario) {
        // Aplicar filtros NO pisa la busqueda q (vive en su caja).
        var copia = nuevos
        copia.q = filtros.q
        filtros = copia
        cargar()
    }
}

struct DiarioView: View {
    @Environment(\.colorScheme) private var scheme
    /// 0 = Trades, 1 = Mensual, 2 = Calendario, 3 = Estadisticas
    @State private var seccion = 0
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}
    /// Al llegar desde «Ver todos» del Panel o desde el destino
    /// Estadisticas, el shell ajusta la seccion.
    var seccionInicial: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Diario")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                BotonExportar()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            PastillasSeccion(opciones: ["Trades", "Mensual", "Calendario", "Estadísticas"], elegida: $seccion)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            switch seccion {
            case 0:
                SeccionTrades(alAbrirTrade: alAbrirTrade, alEntrarDeNuevo: alEntrarDeNuevo)
            case 1:
                SeccionMensual(alAbrirTrade: alAbrirTrade, alEntrarDeNuevo: alEntrarDeNuevo)
            case 2:
                SeccionCalendario(alAbrirTrade: alAbrirTrade, alEntrarDeNuevo: alEntrarDeNuevo)
            default:
                SeccionEstadisticas(alEntrarDeNuevo: alEntrarDeNuevo)
            }
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .onAppear { seccion = seccionInicial }
    }
}

/// Exportar el diario (CSV): si falla, silencio — como la Android.
struct BotonExportar: View {
    @Environment(\.colorScheme) private var scheme
    @State private var compartiendo: URL? = nil
    var body: some View {
        Button {
            Task {
                if let datos = await Api.exportarDiario() {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiptrade-trades.csv")
                    try? datos.write(to: url)
                    compartiendo = url
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 19))
                .foregroundStyle(KipColor.text(scheme))
        }
        .buttonStyle(.plain)
        .sheet(item: $compartiendo) { url in
            HojaCompartir(elementos: [url])
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

/// La hoja de compartir del sistema (UIActivityViewController).
struct HojaCompartir: UIViewControllerRepresentable {
    let elementos: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: elementos, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Seccion Trades

struct GrupoDia {
    var claveDia: String
    var trades: [TradeDto]
}

func agruparPorDia(_ trades: [TradeDto]) -> [GrupoDia] {
    var orden: [String] = []
    var mapa: [String: [TradeDto]] = [:]
    for t in trades {
        let fecha = t.cerradoEn ?? t.abiertoEn ?? ""
        let clave = String(fecha.prefix(10))
        if mapa[clave] == nil { orden.append(clave) }
        mapa[clave, default: []].append(t)
    }
    return orden.map { GrupoDia(claveDia: $0, trades: mapa[$0] ?? []) }
}

struct SeccionTrades: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = DiarioModel()
    @State private var textoBusqueda = ""
    @State private var mostrarFiltros = false
    @State private var diasExpandidos: Set<String> = []
    @State private var gruposExpandidos: Set<String> = []
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alEntrarDeNuevo: () -> Void = {}

    private let chipsRapidos: [(etiqueta: String, tipo: String?)] = [
        ("Todos", nil), ("Calls", "call"), ("Puts", "put"), ("Acciones", "acciones"),
    ]

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 12) {
                        buscador
                        chips
                        Text("\(datos.resumen.total) operaciones · neto del filtro \(dinero(datos.resumen.neto))")
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(datos.resumen.neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if datos.trades.isEmpty {
                            Text("No hay operaciones con ese filtro.")
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .padding(.vertical, 24)
                        } else {
                            listaDias(datos.trades)
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
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudieron cargar tus operaciones.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
        .sheet(isPresented: $mostrarFiltros) {
            if let datos = modelo.datos {
                FiltrosView(filtros: modelo.filtros, datos: datos) { nuevos in
                    modelo.aplicar(nuevos)
                }
            }
        }
    }

    private var buscador: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KipColor.textSecondary(scheme))
            TextField("Buscar ticker", text: $textoBusqueda)
                .font(.manrope(15))
                .foregroundStyle(KipColor.text(scheme))
                .autocapitalization(.allCharacters)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit {
                    modelo.filtros.q = textoBusqueda
                    modelo.cargar()
                }
            Button { mostrarFiltros = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 21))
                        .foregroundStyle(KipColor.text(scheme))
                    if modelo.filtros.activos > 0 {
                        Text("\(modelo.filtros.activos)")
                            .font(.manrope(10, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(Color(hex: 0xD64545))
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(KipColor.card(scheme))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(chipsRapidos, id: \.etiqueta) { chip in
                let activo = modelo.filtros.tipo == chip.tipo
                Button {
                    var nuevos = modelo.filtros
                    nuevos.tipo = chip.tipo
                    modelo.filtros = nuevos
                    modelo.cargar()
                } label: {
                    Text(chip.etiqueta)
                        .font(.manrope(13, weight: .bold))
                        .foregroundStyle(activo ? KipColor.onAccent : KipColor.textSecondary(scheme))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(activo ? KipColor.accent : KipColor.elevated(scheme))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private struct BloqueMes: Identifiable {
        var id: String { mes }
        let mes: String
        let titulo: String
        let dias: [GrupoDia]
    }

    private func bloquesPorMes(_ trades: [TradeDto]) -> [BloqueMes] {
        var bloques: [BloqueMes] = []
        for grupo in agruparPorDia(trades) {
            let mes = String(grupo.claveDia.prefix(7))
            if bloques.last?.mes == mes {
                bloques[bloques.count - 1] = BloqueMes(mes: mes, titulo: bloques[bloques.count - 1].titulo,
                                                       dias: bloques[bloques.count - 1].dias + [grupo])
            } else {
                bloques.append(BloqueMes(mes: mes, titulo: nombreMes(grupo.claveDia), dias: [grupo]))
            }
        }
        return bloques
    }

    @ViewBuilder
    private func listaDias(_ trades: [TradeDto]) -> some View {
        ForEach(bloquesPorMes(trades)) { bloque in
            Text(bloque.titulo)
                .font(.manrope(24, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            ForEach(Array(bloque.dias.enumerated()), id: \.offset) { _, grupo in
                TarjetaDia(grupo: grupo,
                           expandido: diasExpandidos.contains(grupo.claveDia),
                           gruposExpandidos: $gruposExpandidos,
                           alAlternar: {
                               if diasExpandidos.contains(grupo.claveDia) { diasExpandidos.remove(grupo.claveDia) }
                               else { diasExpandidos.insert(grupo.claveDia) }
                           },
                           alAbrirTrade: alAbrirTrade)
            }
        }
    }

    private func nombreMes(_ clave: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let d = f.date(from: clave) else { return "" }
        let salida = DateFormatter()
        salida.locale = Locale(identifier: "es")
        salida.dateFormat = "MMMM"
        salida.timeZone = TimeZone(secondsFromGMT: 0)
        let mes = salida.string(from: d)
        return mes.prefix(1).uppercased() + mes.dropFirst()
    }
}

/// La tarjeta de un dia: numero grande y dia de semana FUERA, a la
/// izquierda; dentro, la rejilla PnL / Win % / Trades / Comisiones,
/// contadores y chips de tickers.
struct TarjetaDia: View {
    @Environment(\.colorScheme) private var scheme
    let grupo: GrupoDia
    let expandido: Bool
    @Binding var gruposExpandidos: Set<String>
    var alAlternar: () -> Void = {}
    var alAbrirTrade: (Int) -> Void = { _ in }
    @State private var notaDelDia = false

    private var cerrados: [TradeDto] { grupo.trades.filter { $0.estado == "closed" } }
    private var netoCerrados: Double { cerrados.compactMap { $0.neto }.reduce(0, +) }
    private var ganados: Int { cerrados.filter { $0.ganador == true }.count }
    private var perdidos: Int { cerrados.filter { $0.ganador == false }.count }
    private var abiertas: Int { grupo.trades.filter { $0.estado == "open" }.count }
    private var feesTotal: Double? {
        let conFees = cerrados.compactMap { $0.fees }
        return conFees.isEmpty ? nil : conFees.reduce(0, +)
    }

    private var numeroDia: Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let fecha = f.date(from: grupo.claveDia) else { return 0 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.component(.day, from: fecha)
    }

    private var diaSemana: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let fecha = f.date(from: grupo.claveDia) else { return "" }
        let salida = DateFormatter()
        salida.locale = Locale(identifier: "es")
        salida.dateFormat = "EEE"
        salida.timeZone = TimeZone(secondsFromGMT: 0)
        return salida.string(from: fecha).replacingOccurrences(of: ".", with: "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Text("\(numeroDia)")
                    .font(.manrope(32, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text(diaSemana.prefix(1).uppercased() + diaSemana.dropFirst())
                    .font(.manrope(12, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .frame(width: 52)
            KipCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        celdaDia(titulo: "PnL", valor: dinero(netoCerrados),
                                 color: netoCerrados >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                        celdaDia(titulo: "Win %", valor: cerrados.isEmpty ? "—" : "\(Int((Double(ganados) / Double(cerrados.count) * 100).rounded()))%",
                                 color: KipColor.text(scheme))
                        celdaDia(titulo: "Trades", valor: "\(grupo.trades.count)", color: KipColor.text(scheme))
                        celdaDia(titulo: "Comisiones", valor: feesTotal.map { dinero(-$0) } ?? "—", color: KipColor.text(scheme))
                    }
                    HStack(spacing: 12) {
                        Text("Wins \(ganados)")
                            .foregroundStyle(KipColor.verdePnl(scheme))
                        Text("Losses \(perdidos)")
                            .foregroundStyle(KipColor.rojoPnl(scheme))
                        Text("Abiertas \(abiertas)")
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .font(.manrope(12, weight: .bold))
                    chipsTickers
                    HStack(spacing: 8) {
                        botonPildora(expandido ? "Ocultar" : "Ver trades") { alAlternar() }
                        botonPildora("Nota del día") { notaDelDia = true }
                    }
                    if expandido {
                        listaTradesDia
                    }
                }
            }
        }
        .sheet(isPresented: $notaDelDia) {
            NotaDelDiaView(fecha: grupo.claveDia)
        }
    }

    private func celdaDia(titulo: String, valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(valor)
                .font(.manrope(14, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chipsTickers: some View {
        let porTicker = Dictionary(grouping: cerrados, by: { $0.ticker })
        let claves = porTicker.keys.sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(claves, id: \.self) { ticker in
                    let neto = (porTicker[ticker] ?? []).compactMap { $0.neto }.reduce(0, +)
                    Text(ticker)
                        .font(.manrope(12, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background((neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)).opacity(0.16))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func botonPildora(_ texto: String, accion: @escaping () -> Void) -> some View {
        Button { accion() } label: {
            Text(texto)
                .font(.manrope(13, weight: .bold))
                .foregroundStyle(KipColor.bg(scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(KipColor.text(scheme))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Las operaciones del dia, con los grupos multi-pata agrupados.
    @ViewBuilder
    private var listaTradesDia: some View {
        let conGrupo = grupo.trades.filter { ($0.grupo ?? "") != "" }
        let sinGrupo = grupo.trades.filter { ($0.grupo ?? "") == "" }
        let gruposPatas = Dictionary(grouping: conGrupo, by: { $0.grupo ?? "" })
        VStack(spacing: 0) {
            ForEach(Array(gruposPatas.keys.sorted().enumerated()), id: \.offset) { _, claveGrupo in
                let patas = (gruposPatas[claveGrupo] ?? []).sorted { ($0.strike ?? 0) < ($1.strike ?? 0) }
                if patas.count > 1 {
                    filaGrupoPatas(claveGrupo: claveGrupo, patas: patas)
                } else {
                    ForEach(patas) { trade in
                        filaTrade(trade)
                    }
                }
            }
            ForEach(sinGrupo) { trade in
                filaTrade(trade)
            }
        }
    }

    private func filaTrade(_ trade: TradeDto) -> some View {
        Button { alAbrirTrade(trade.id) } label: {
            FilaTrade(trade: trade)
        }
        .buttonStyle(.plain)
    }

    private func filaGrupoPatas(claveGrupo: String, patas: [TradeDto]) -> some View {
        let expandidoGrupo = gruposExpandidos.contains(claveGrupo)
        let netoGrupo = patas.first?.grupoNeto
        return VStack(alignment: .leading, spacing: 2) {
            Button {
                if expandidoGrupo { gruposExpandidos.remove(claveGrupo) } else { gruposExpandidos.insert(claveGrupo) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(patas.first?.ticker ?? "")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(expandidoGrupo ? "Operación de \(patas.count) patas · toca para ocultar" : "Operación de \(patas.count) patas · toca para ver las patas")
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Spacer()
                    Text(netoGrupo.map { dinero($0) } ?? "En curso")
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle((netoGrupo ?? 0) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            if expandidoGrupo {
                ForEach(patas) { pata in
                    filaTrade(pata)
                }
            }
        }
    }
}

/// La nota del dia: el Journal de esa fecha en un dialogo.
struct NotaDelDiaView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let fecha: String
    @State private var texto = ""
    @State private var cargando = true
    @State private var guardando = false
    @State private var aviso: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(fechaPuntoLarga(fecha))
                        .font(.manrope(17, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Sé completamente honesto: reconocer lo que hiciste mal y lo que hiciste bien es lo que te hará progresar.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    CampoKip(etiqueta: "Tu reflexión del día", texto: $texto, multilinea: true, lineasMinimas: 5)
                    if let aviso = aviso {
                        Text(aviso)
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(KipColor.verdePnl(scheme))
                    }
                    BotonKip(texto: guardando ? "Guardando…" : "Guardar", deshabilitado: guardando || cargando) { guardar() }
                    BotonBordeKip(texto: "Cerrar") { dismiss() }
                }
                .padding(20)
            }
            .background(KipColor.bg(scheme).ignoresSafeArea())
            .navigationTitle("Nota del día")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if let datos = try? await Api.journal(fecha: fecha) {
                    texto = datos.entrada?.reflexion ?? ""
                }
                cargando = false
            }
        }
    }

    private func guardar() {
        guardando = true
        Task {
            do {
                let r = try await Api.guardarJournal(fecha: fecha, reflexion: texto.isEmpty ? nil : texto)
                aviso = r.message
                guardando = false
            } catch {
                aviso = "No se pudo guardar. Inténtalo de nuevo."
                guardando = false
            }
        }
    }
}
