import SwiftUI

// El Panel de Kiptrade iOS: el MISMO Panel de la app Android, bloque
// por bloque (mapa §3.4): encabezado, alerta de broker, avisos de
// billing, heroe «Resultado neto», y las tarjetas en el orden que
// manda el servidor (panel.tarjetas), con la fila mini inyectada tras
// las donas. La tarjeta «Última semana» sale de GET diario/calendario.

@MainActor
final class PanelModel: ObservableObject {
    @Published var panel: PanelDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var sinLeer = 0
    @Published var semanaDias: [(clave: String, neto: Double)] = []

    func cargar(rangoCambio: Bool = false) {
        if cargando { return }
        cargando = true
        Task {
            do {
                let actual = panel
                let datos = try await Api.panel(rango: rangoCambio ? (actual?.rango ?? "at") : (actual?.rango ?? "at"),
                                                desde: actual?.desde, hasta: actual?.hasta)
                panel = datos
                errorTexto = nil
                sesionExpirada = false
                cargando = false
                await cargarSemana()
                await cargarBadge()
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla {
                    sesionExpirada = true
                    Sesion.cerrar()
                } else if panel == nil {
                    errorTexto = falla.errorDescription
                }
            } catch {
                cargando = false
                if panel == nil { errorTexto = "Algo salió mal. Inténtalo de nuevo." }
            }
        }
    }

    func cambiarRango(_ rango: String, desde: String? = nil, hasta: String? = nil) {
        guard var actual = panel else { return }
        actual.rango = rango
        actual.desde = desde
        actual.hasta = hasta
        panel = actual
        // Recarga con el rango nuevo
        cargando = true
        Task {
            do {
                let datos = try await Api.panel(rango: rango, desde: desde, hasta: hasta)
                panel = datos
                cargando = false
                await cargarSemana()
            } catch let falla as ApiError {
                cargando = false
                if case .sesionExpirada = falla { sesionExpirada = true; Sesion.cerrar() }
            } catch {
                cargando = false
            }
        }
    }

    private func cargarSemana() async {
        // Hoy y 6 atras, desde el calendario del mes actual (y el
        // anterior si hoy cae en la primera semana).
        let hoy = claveFechaHoy()
        var claves: [String] = []
        for i in stride(from: 6, through: 0, by: -1) { claves.append(claveFecha(hoy, masDias: -i)) }
        var porDia: [String: DiaCalendarioDto] = [:]
        let mesActual = String(hoy.prefix(7))
        if let cal = try? await Api.calendario(mes: mesActual) {
            porDia.merge(cal.porDia) { a, _ in a }
        }
        if let dia = Int(hoy.suffix(2)), dia <= 7 {
            let mesAnterior = String(claveFecha(hoy, masDias: -7).prefix(7))
            if let cal = try? await Api.calendario(mes: mesAnterior) {
                porDia.merge(cal.porDia) { a, _ in a }
            }
        }
        semanaDias = claves.map { (clave: $0, neto: porDia[$0]?.net ?? 0) }
    }

    private func cargarBadge() async {
        if let n = try? await Api.notificaciones() {
            sinLeer = n.sinLeer
        }
    }
}

/// Las claves canonicas de destino, con su etiqueta e icono.
enum Destino {
    static let etiquetas: [String: String] = [
        "panel": "Panel", "diario": "Diario", "estadisticas": "Estadísticas",
        "coach": "KipCoach", "plan": "Mi plan", "mas": "Más",
    ]
    static let iconos: [String: String] = [
        "panel": "house.fill", "diario": "book.fill", "estadisticas": "chart.bar.fill",
        "coach": "person.fill.checkmark", "plan": "list.clipboard.fill", "mas": "ellipsis.circle.fill",
    ]
    static let canonico = ["diario", "estadisticas", "coach", "plan"]

    /// Los 4 laterales: la preferencia de la cuenta sin panel/mas,
    /// sin duplicados, completada con el orden canonico.
    static func laterales(desde barra: [String]) -> [String] {
        var resultado: [String] = []
        for clave in barra where clave != "panel" && clave != "mas" && canonico.contains(clave) && !resultado.contains(clave) {
            resultado.append(clave)
        }
        for clave in canonico where !resultado.contains(clave) && resultado.count < 4 {
            resultado.append(clave)
        }
        return Array(resultado.prefix(4))
    }
}

struct PanelView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = PanelModel()
    @State private var editorTarjetas = false
    @State private var editorDonas = false
    var alAbrirMenu: () -> Void = {}
    var alAbrirNotificaciones: () -> Void = {}
    var alAbrirTrade: (Int) -> Void = { _ in }
    var alVerTodos: () -> Void = {}
    var alEntrarDeNuevo: () -> Void = {}

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para ver tu panel.", alEntrar: alEntrarDeNuevo)
            } else if let panel = modelo.panel {
                ScrollView {
                    VStack(spacing: 14) {
                        encabezado(panel)
                        if let alerta = panel.brokerAlerta {
                            tarjetaAlertaBroker(alerta)
                        }
                        ForEach(Array(panel.avisosBilling.enumerated()), id: \.offset) { _, aviso in
                            tarjetaAvisoBilling(aviso)
                        }
                        heroe(panel)
                        ForEach(panel.tarjetas, id: \.self) { clave in
                            tarjeta(clave, panel: panel)
                            if clave == "donas" {
                                filaMini(panel)
                            }
                        }
                        BotonBordeKip(texto: "Personalizar mi panel") { editorTarjetas = true }
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 110)
                }
                .refreshable { modelo.cargar() }
            } else if modelo.cargando {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = modelo.errorTexto {
                ErrorCarga(mensaje: error) { modelo.cargar() }
            } else {
                ErrorCarga(mensaje: "No se pudo cargar tu panel.") { modelo.cargar() }
            }
        }
        .background(KipColor.bg(scheme).ignoresSafeArea())
        .onAppear { if modelo.panel == nil { modelo.cargar() } }
        .sheet(isPresented: $editorTarjetas) {
            if let panel = modelo.panel {
                EditorTarjetasView(panel: panel) { modelo.cargar() }
            }
        }
        .sheet(isPresented: $editorDonas) {
            if let panel = modelo.panel {
                EditorDonasView(panel: panel) { modelo.cargar() }
            }
        }
    }

    // MARK: - Encabezado

    private func encabezado(_ panel: PanelDto) -> some View {
        let local = Sesion.usuarioLocal
        let nombre = local?.apodo ?? local?.nombre ?? "Trader"
        let verificado = panel.verificado || (local?.verificado ?? false)
        return HStack(spacing: 12) {
            AvatarKip(urlTexto: local?.avatarUrl, nombre: nombre, tamano: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text(nombre)
                    .font(.manrope(17, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(1)
                if verificado {
                    Text("✓ Verificado")
                        .font(.manrope(12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x5EC96E))
                }
            }
            Spacer()
            Button { alAbrirNotificaciones() } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(KipColor.text(scheme))
                    if modelo.sinLeer > 0 {
                        Text(modelo.sinLeer > 99 ? "99" : "\(modelo.sinLeer)")
                            .font(.manrope(10, weight: .heavy))
                            .foregroundStyle(KipColor.onAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(KipColor.accent)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -7)
                    }
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            Button { alAbrirMenu() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
        }
    }

    private func tarjetaAlertaBroker(_ alerta: AlertaBrokerDto) -> some View {
        let esFallo = alerta.estado == "fallo" || alerta.estado == "reconectar"
        return KipCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(alerta.cuenta.map { "\(alerta.titulo) · \($0)" } ?? alerta.titulo)
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(esFallo ? KipColor.rojoPnl(scheme) : KipColor.ambarPnl(scheme))
                if let detalle = alerta.detalle, !detalle.isEmpty {
                    Text(detalle)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                }
                Text("Revísalo en Más → Conectar broker.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private func tarjetaAvisoBilling(_ aviso: AvisoBillingDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(aviso.titulo)
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.ambarPnl(scheme))
                Text(aviso.detalle)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.text(scheme))
            }
        }
    }

    // MARK: - Heroe

    private func captionRango(_ panel: PanelDto) -> String {
        switch panel.rango {
        case "1m": return "Último mes"
        case "3m": return "Últimos 3 meses"
        case "1y": return "Último año"
        default:
            if panel.desde != nil || panel.hasta != nil { return "Personalizado" }
            return "Todo el tiempo"
        }
    }

    private func heroe(_ panel: PanelDto) -> some View {
        let r = panel.resumen
        return KipCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("RESULTADO NETO")
                        .font(.manrope(11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Text(dinero(r.neto))
                        .font(.manrope(28, weight: .heavy))
                        .foregroundStyle(r.neto == nil ? KipColor.text(scheme) : ((r.neto ?? 0) >= 0 ? Color(hex: 0x5EC96E) : Color(hex: 0xE57373)))
                    Text("\(captionRango(panel)) · \(r.tradesCerrados) trades cerrados · aciertos \(porcentaje(r.winRate))")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    if r.tradesCerrados > 0 {
                        Text(panel.tieneConexionBroker
                             ? "Tus números vienen directo de tu broker, sin editar."
                             : "Tus números salen de los archivos que importaste, tal cual los subiste.")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x5EC96E))
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(r.kipScore.map { "\($0)" } ?? "—")
                        .font(.manrope(36, weight: .heavy))
                        .foregroundStyle(KipColor.accent)
                    Text("KIP SCORE")
                        .font(.manrope(11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
        }
    }

    private func filaMini(_ panel: PanelDto) -> some View {
        let r = panel.resumen
        return HStack(spacing: 10) {
            miniTarjeta(titulo: "Ganancia", valor: dinero(r.neto), color: (r.neto ?? 0) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
            miniTarjeta(titulo: "Aciertos", valor: porcentaje(r.winRate), color: KipColor.text(scheme))
            miniTarjeta(titulo: "Ganancia prom. %", valor: r.gananciaPromPct.map { String(format: "%+.2f%%", $0) } ?? "—", color: KipColor.text(scheme))
        }
    }

    private func miniTarjeta(titulo: String, valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .lineLimit(1)
            Text(valor)
                .font(.manrope(15, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KipColor.elevated(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Tarjetas en el orden del servidor

    @ViewBuilder
    private func tarjeta(_ clave: String, panel: PanelDto) -> some View {
        switch clave {
        case "grafica":
            tarjetaGrafica(panel)
        case "donas":
            if !panel.donas.isEmpty { tarjetaDonas(panel) }
        case "espejo":
            if let espejo = panel.espejo { tarjetaEspejo(espejo) }
        case "ultimos":
            tarjetaUltimos(panel)
        case "semana":
            if !modelo.semanaDias.isEmpty { tarjetaSemana() }
        case "caida":
            if panel.drawdown.count >= 2 { tarjetaCaida(panel) }
        case "posiciones":
            if !panel.posicionesAbiertas.isEmpty { tarjetaPosiciones(panel) }
        default:
            EmptyView()
        }
    }

    private func tarjetaGrafica(_ panel: PanelDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                if panel.curva.count >= 2 {
                    CurvaCapital(puntos: panel.curva, bicolor: true, altura: 190)
                } else {
                    Text("Sin trades cerrados en este rango")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                }
                PastillasRango(rango: panel.rango) { nuevo in
                    modelo.cambiarRango(nuevo)
                }
            }
        }
    }

    private func tarjetaDonas(_ panel: PanelDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TituloTarjeta(texto: "Tus métricas")
                    Spacer()
                    Button { editorDonas = true } label: {
                        Text("Personalizar")
                            .font(.manrope(13, weight: .bold))
                            .foregroundStyle(KipColor.accent)
                    }
                    .buttonStyle(.plain)
                }
                TabView {
                    ForEach(panel.donas) { dona in
                        VStack(spacing: 8) {
                            DonaAnillo(dona: dona, tamano: 128)
                            Text(dona.label)
                                .font(.manrope(13, weight: .semibold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        .padding(.bottom, 26)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 205)
            }
        }
    }

    private func tarjetaEspejo(_ espejo: EspejoDto) -> some View {
        let colorEstado: Color = espejo.estado == "rojo" ? KipColor.rojoPnl(scheme)
            : (espejo.estado == "ambar" ? Color(hex: 0xEAB308) : KipColor.verdePnl(scheme))
        let textoEstado = espejo.estado == "rojo" ? "Circuit breaker activo"
            : (espejo.estado == "ambar" ? "Atención hoy" : "Día limpio")
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TituloTarjeta(texto: "Espejo del desquite")
                    Spacer()
                    Circle().fill(colorEstado).frame(width: 10, height: 10)
                    Text(textoEstado)
                        .font(.manrope(13, weight: .bold))
                        .foregroundStyle(colorEstado)
                }
                if let limite = espejo.limitePerdidaDiaria {
                    Text("Neto de hoy: \(dinero(espejo.netoHoy)) · Tu límite de pérdida diaria: \u{2212}\(dineroSinSigno(limite))")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    if let consumo = espejo.consumoLimitePct {
                        let fraccion = CGFloat(min(max(consumo, 0), 100)) / 100
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(KipColor.elevated(scheme))
                                Capsule().fill(colorEstado).frame(width: geo.size.width * fraccion)
                            }
                        }
                        .frame(height: 8)
                        Text("Has usado el \(consumo)% de tu límite de hoy.")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                } else {
                    Text("Neto de hoy: \(dinero(espejo.netoHoy)). Tu plan no tiene límite de pérdida diaria; ponlo en Mi plan para verlo aquí contra tu día.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                }
                if let senial = espejo.senialRevanchaHoy, !senial.isEmpty {
                    Text(senial)
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                Divider()
                filaEspejo(etiqueta: "Fuera de tu plan (7 días)", sesgo: espejo.fueraDelPlan)
                filaEspejo(etiqueta: "Emoción de revancha", sesgo: espejo.revancha)
                filaEspejo(etiqueta: "Siguiendo tu plan", sesgo: espejo.siguiendoPlan)
                Text("Esto es tu propio espejo: tus números contra el plan que tú declaraste. Kiptrade no te dice cómo operar.")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private func filaEspejo(etiqueta: String, sesgo: SesgoSemanaDto) -> some View {
        HStack {
            Text(etiqueta.uppercased())
                .font(.manrope(11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(KipColor.textSecondary(scheme))
            Spacer()
            Text("\(sesgo.trades) trades")
                .font(.manrope(13))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(dinero(sesgo.net))
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(sesgo.net >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
        }
    }

    private func tarjetaUltimos(_ panel: PanelDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TituloTarjeta(texto: "Últimos trades")
                    Spacer()
                    Button { alVerTodos() } label: {
                        Text("Ver todos")
                            .font(.manrope(13, weight: .bold))
                            .foregroundStyle(KipColor.onAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(KipColor.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if panel.ultimosTrades.isEmpty {
                    Text("Sin trades cerrados en este rango.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(panel.ultimosTrades.enumerated()), id: \.offset) { indice, trade in
                        Button { alAbrirTrade(trade.id) } label: {
                            FilaTrade(trade: trade)
                        }
                        .buttonStyle(.plain)
                        if indice < panel.ultimosTrades.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func tarjetaSemana() -> some View {
        let dias = modelo.semanaDias
        let maximo = max(dias.map { abs($0.neto) }.max() ?? 0, 0.0001)
        let letras = ["L", "M", "X", "J", "V", "S", "D"]
        return KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: "Última semana")
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(dias.enumerated()), id: \.offset) { _, dia in
                        let letra = letraDia(dia.clave, letras: letras)
                        VStack(spacing: 5) {
                            Text(dia.neto == 0 ? "—" : dineroBarraPanel(dia.neto))
                                .font(.manrope(10, weight: .bold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(dia.neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                                .frame(height: max(56 * CGFloat(abs(dia.neto) / maximo), dia.neto == 0 ? 3 : 5))
                            Text(letra)
                                .font(.manrope(11, weight: .bold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func letraDia(_ clave: String, letras: [String]) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        guard let d = f.date(from: clave) else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let semana = cal.component(.weekday, from: d) // 1=domingo
        let indice = (semana + 5) % 7 // lunes = 0
        return letras[indice]
    }

    private func tarjetaCaida(_ panel: PanelDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                TituloTarjeta(texto: "Caída desde el máximo")
                Text("Peor caída: \(dinero(panel.resumen.caidaMaxima)) (\(String(format: "%.1f", panel.resumen.caidaMaximaPct))%)")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                CurvaCapital(puntos: panel.drawdown, bicolor: false, altura: 130)
            }
        }
    }

    private func tarjetaPosiciones(_ panel: PanelDto) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 4) {
                TituloTarjeta(texto: "Posiciones abiertas")
                ForEach(Array(panel.posicionesAbiertas.enumerated()), id: \.offset) { indice, trade in
                    Button { alAbrirTrade(trade.id) } label: {
                        FilaTrade(trade: trade)
                    }
                    .buttonStyle(.plain)
                    if indice < panel.posicionesAbiertas.count - 1 { Divider() }
                }
            }
        }
    }
}

/// Las pastillas de rango del Panel: 1M / 3M / 1Y / AT + personalizado.
struct PastillasRango: View {
    @Environment(\.colorScheme) private var scheme
    let rango: String
    var alCambiar: (String) -> Void = { _ in }
    private let opciones: [(clave: String, etiqueta: String)] = [
        ("1m", "1M"), ("3m", "3M"), ("1y", "1Y"), ("at", "AT"),
    ]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(opciones, id: \.clave) { opcion in
                Button { alCambiar(opcion.clave) } label: {
                    Text(opcion.etiqueta)
                        .font(.manrope(13, weight: .bold))
                        .foregroundStyle(rango == opcion.clave ? KipColor.onAccent : KipColor.textSecondary(scheme))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(rango == opcion.clave ? KipColor.accent : KipColor.elevated(scheme))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("Rango personalizado en la web por ahora")
                .font(.manrope(11))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .lineLimit(1)
        }
    }
}

// MARK: - Editores del Panel

struct EditorTarjetasView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let panel: PanelDto
    var alGuardar: () -> Void = {}
    /// Las tarjetas encendidas, EN ORDEN: es lo que viaja al servidor.
    @State private var activas: [String] = []
    @State private var guardando = false
    @State private var errorTexto: String? = nil

    private let catalogo: [(clave: String, etiqueta: String)] = [
        ("grafica", "Gráfica"), ("donas", "Tus métricas"), ("espejo", "Espejo del desquite"),
        ("ultimos", "Últimos trades"), ("semana", "Última semana"), ("caida", "Caída desde el máximo"),
        ("posiciones", "Posiciones abiertas"),
    ]

    private func etiqueta(_ clave: String) -> String {
        catalogo.first { $0.clave == clave }?.etiqueta ?? clave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(activas, id: \.self) { clave in
                        HStack {
                            Text(etiqueta(clave))
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            Button { apagar(clave) } label: {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { desde, hasta in
                        activas.move(fromOffsets: desde, toOffset: hasta)
                    }
                } header: {
                    Text("Apaga las que no uses y muévelas arrastrando. Se guarda en tu cuenta.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .textCase(nil)
                }
                let apagadas = catalogo.map { $0.clave }.filter { !activas.contains($0) }
                if !apagadas.isEmpty {
                    Section("Apagadas") {
                        ForEach(apagadas, id: \.self) { clave in
                            HStack {
                                Text(etiqueta(clave))
                                    .font(.manrope(15))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                Spacer()
                                Button { encender(clave) } label: {
                                    Image(systemName: "eye")
                                        .foregroundStyle(KipColor.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if let error = errorTexto {
                    Text(error)
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.error(scheme))
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Personaliza tu panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(guardando ? "Guardando…" : "Guardar") { guardar() }
                        .disabled(guardando)
                }
            }
            .onAppear {
                activas = panel.tarjetas.filter { catalogo.map { $0.clave }.contains($0) }
            }
        }
    }

    private func apagar(_ clave: String) {
        activas.removeAll { $0 == clave }
    }

    private func encender(_ clave: String) {
        if !activas.contains(clave) { activas.append(clave) }
    }

    private func guardar() {
        guardando = true
        errorTexto = nil
        let ordenFinal = activas
        Task {
            do {
                _ = try await Api.guardarTarjetas(ordenFinal)
                guardando = false
                alGuardar()
                dismiss()
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

struct EditorDonasView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let panel: PanelDto
    var alGuardar: () -> Void = {}
    @State private var elegidas: [String] = ["", "", "", ""]
    @State private var guardando = false
    @State private var errorTexto: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<4, id: \.self) { i in
                        Picker("Dona \(i + 1)", selection: $elegidas[i]) {
                            Text("Sin elegir").tag("")
                            ForEach(panel.metricasDonas, id: \.clave) { metrica in
                                Text(metrica.etiqueta).tag(metrica.clave)
                            }
                        }
                        .font(.manrope(15))
                    }
                } header: {
                    Text("Elige las 4 métricas que quieres ver en el Panel, sin repetir.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .textCase(nil)
                }
                if let error = errorTexto {
                    Text(error)
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(KipColor.error(scheme))
                }
            }
            .navigationTitle("Personaliza tus donas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(guardando ? "Guardando…" : "Guardar") { guardar() }
                        .disabled(guardando)
                }
            }
            .onAppear {
                var base = panel.donasElegidas
                while base.count < 4 { base.append("") }
                elegidas = Array(base.prefix(4))
            }
        }
    }

    private func guardar() {
        let limpias = elegidas.filter { !$0.isEmpty }
        if Set(limpias).count != limpias.count || limpias.count != 4 {
            errorTexto = "Las 4 métricas deben ser distintas."
            return
        }
        guardando = true
        errorTexto = nil
        Task {
            do {
                _ = try await Api.guardarDonas(limpias)
                guardando = false
                alGuardar()
                dismiss()
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
