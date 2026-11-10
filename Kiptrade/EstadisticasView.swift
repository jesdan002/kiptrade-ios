import SwiftUI

// Estadisticas dentro del Diario (mapa §3.5): chips de rango con
// «Todo» PRIMERO y «1A», filtros sin estrategia/estado/orden y con
// busqueda, y bloques personalizables LOCALES (UserDefaults: no van
// al servidor — trampa §5.9 del mapa).

@MainActor
final class EstadisticasModel: ObservableObject {
    @Published var datos: EstadisticasDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionExpirada = false
    @Published var filtros = FiltrosDiario()

    func cargar() {
        cargando = true
        // Estadisticas NO recibe estrategia/estado/orden (mapa §2.3).
        let f = filtros
        let query: [(String, String?)] = [
            ("rango", rangoActual),
            ("ticker", f.ticker), ("tipo", f.tipo), ("emocion", f.emocion),
            ("resultado", f.resultado), ("q", f.q.isEmpty ? nil : f.q),
            ("cuenta", f.cuenta.map { "\($0)" }), ("lado", f.lado),
            ("desde", f.desde), ("hasta", f.hasta),
        ]
        Task {
            do {
                datos = try await Api.estadisticas(query: query)
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

    @Published var rangoActual: String = "at"

    func cambiarRango(_ nuevo: String) {
        rangoActual = nuevo
        cargar()
    }
}

/// El orden y las ocultas de Estadisticas viven en el telefono.
enum StatsLocal {
    static let clavesBase = ["resumen", "curva", "ticker", "estrategia", "plan", "emocion",
                             "patron", "adherencia", "semana", "dia", "hallazgos", "sesgos"]
    static var orden: [String] {
        get {
            let guardado = UserDefaults.standard.string(forKey: "kt-stats-orden") ?? ""
            var lista = guardado.split(separator: ",").map(String.init).filter { clavesBase.contains($0) }
            for clave in clavesBase where !lista.contains(clave) { lista.append(clave) }
            return lista
        }
        set { UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "kt-stats-orden") }
    }
    static var ocultas: Set<String> {
        get { Set((UserDefaults.standard.string(forKey: "kt-stats-ocultas") ?? "").split(separator: ",").map(String.init)) }
        set { UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "kt-stats-ocultas") }
    }
}

struct SeccionEstadisticas: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = EstadisticasModel()
    @State private var orden: [String] = StatsLocal.orden
    @State private var ocultas: Set<String> = StatsLocal.ocultas
    @State private var mostrarFiltros = false
    @State private var mostrarPersonalizar = false
    var alEntrarDeNuevo: () -> Void = {}

    private let titulos: [String: String] = [
        "resumen": "Resumen", "curva": "Curva de P&L acumulado", "ticker": "P&L por ticker",
        "estrategia": "P&L por estrategia", "plan": "P&L por seguimiento del plan",
        "emocion": "% de aciertos por emoción", "patron": "% de aciertos por patrón",
        "adherencia": "% de aciertos por adherencia", "semana": "% de aciertos por día de semana",
        "dia": "P&L por día", "hallazgos": "Lo que dicen tus números", "sesgos": "Sesgos de la semana",
    ]
    private let rangos: [(clave: String, etiqueta: String)] = [
        ("at", "Todo"), ("1m", "1M"), ("3m", "3M"), ("1y", "1A"),
    ]

    var body: some View {
        Group {
            if modelo.sesionExpirada {
                VistaSesionExpirada(texto: "Tu sesión expiró. Vuelve a iniciar sesión para seguir.", alEntrar: alEntrarDeNuevo)
            } else if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            ForEach(rangos, id: \.clave) { opcion in
                                let activo = modelo.rangoActual == opcion.clave
                                Button { modelo.cambiarRango(opcion.clave) } label: {
                                    Text(opcion.etiqueta)
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
                            Button { mostrarFiltros = true } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 21))
                                    .foregroundStyle(KipColor.text(scheme))
                            }
                            .buttonStyle(.plain)
                            Button { mostrarPersonalizar = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 20))
                                    .foregroundStyle(KipColor.text(scheme))
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(orden.filter { !ocultas.contains($0) }, id: \.self) { clave in
                            bloque(clave, datos: datos)
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
                ErrorCarga(mensaje: modelo.errorTexto ?? "No se pudieron cargar tus estadísticas.") { modelo.cargar() }
            }
        }
        .onAppear { if modelo.datos == nil { modelo.cargar() } }
        .sheet(isPresented: $mostrarFiltros) {
            if let datos = modelo.datos {
                // Los filtros de Estadisticas toman sus listas del propio
                // DTO de estadisticas; se adaptan a la forma de Diario.
                let adaptado = DiarioDto(desdeStats: datos)
                FiltrosView(filtros: modelo.filtros, datos: adaptado,
                            conEstrategia: false, conEstado: false, conOrden: false, conBusqueda: true) { nuevos in
                    modelo.filtros = nuevos
                    modelo.cargar()
                }
            }
        }
        .sheet(isPresented: $mostrarPersonalizar) {
            PersonalizarStatsView(orden: $orden, ocultas: $ocultas, titulos: titulos)
        }
        .onChange(of: orden) { _, nuevo in StatsLocal.orden = nuevo }
        .onChange(of: ocultas) { _, nuevo in StatsLocal.ocultas = nuevo }
    }

    // MARK: - Bloques

    @ViewBuilder
    private func bloque(_ clave: String, datos: EstadisticasDto) -> some View {
        switch clave {
        case "resumen":
            bloqueResumen(datos)
        case "curva":
            if datos.curva.count >= 2 {
                KipCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TituloTarjeta(texto: titulos[clave] ?? clave)
                        CurvaCapital(puntos: datos.curva, bicolor: true, altura: 170)
                    }
                }
            }
        case "ticker":
            if !datos.porTicker.isEmpty {
                BarrasStats(titulo: titulos[clave] ?? clave, barras: barrasDeGrupos(datos.porTicker))
            }
        case "estrategia":
            if !datos.porEstrategia.isEmpty {
                BarrasStats(titulo: titulos[clave] ?? clave, barras: barrasDeGrupos(datos.porEstrategia))
            }
        case "plan":
            if !datos.porPlan.isEmpty {
                BarrasStats(titulo: titulos[clave] ?? clave, barras: barrasDeGrupos(datos.porPlan))
            }
        case "emocion":
            BarrasStats(titulo: titulos[clave] ?? clave, barras: datos.graficas.porEmocion, debilPorLabel: true)
        case "patron":
            BarrasStats(titulo: titulos[clave] ?? clave, barras: datos.graficas.porPatron)
        case "adherencia":
            BarrasStats(titulo: titulos[clave] ?? clave, barras: datos.graficas.porAdherencia)
        case "semana":
            BarrasStats(titulo: titulos[clave] ?? clave, barras: datos.graficas.porDiaSemana)
        case "dia":
            BarrasStats(titulo: titulos[clave] ?? clave, barras: barrasDiaSinFinde(datos.graficas.porDia), mostrarDetalle: false)
        case "hallazgos":
            if !datos.hallazgos.isEmpty {
                KipCard {
                    VStack(alignment: .leading, spacing: 7) {
                        TituloTarjeta(texto: titulos[clave] ?? clave)
                        ForEach(Array(datos.hallazgos.enumerated()), id: \.offset) { _, hallazgo in
                            Text("• \(hallazgo)")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.text(scheme))
                        }
                    }
                }
            }
        case "sesgos":
            if !datos.sesgosSemana.isEmpty {
                KipCard {
                    VStack(alignment: .leading, spacing: 9) {
                        TituloTarjeta(texto: titulos[clave] ?? clave)
                        ForEach(Array(datos.sesgosSemana.enumerated()), id: \.offset) { _, sesgo in
                            HStack {
                                Text(sesgo.label)
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                Text("\(sesgo.trades)")
                                    .font(.manrope(12, weight: .bold))
                                    .foregroundStyle(KipColor.onAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(KipColor.accent)
                                    .clipShape(Capsule())
                                Text(dinero(sesgo.net))
                                    .font(.manrope(14, weight: .bold))
                                    .foregroundStyle(sesgo.net >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                                    .frame(width: 86, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private func bloqueResumen(_ datos: EstadisticasDto) -> some View {
        let r = datos.resumen
        let tarjetas: [(titulo: String, valor: String, color: Color)] = [
            ("Neto", dinero(r.neto), r.neto >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)),
            ("Trades", "\(r.cantidad)", KipColor.text(scheme)),
            ("Aciertos", r.winRate.map { "\($0)%" } ?? "—", KipColor.text(scheme)),
            ("Profit factor", r.profitFactor.map { String(format: "%.2f", $0) } ?? "—", KipColor.text(scheme)),
            ("KipScore", datos.kipScore.map { "\($0)" } ?? "—", KipColor.verdePnl(scheme)),
            ("Prom. R", r.promedioR.map { String(format: "%.2f", $0) } ?? "—", KipColor.text(scheme)),
            ("Prom. ganancia", dinero(r.promedioGanancia), KipColor.verdePnl(scheme)),
            ("Prom. pérdida", dinero(r.promedioPerdida), KipColor.rojoPnl(scheme)),
            ("Mejor trade", dinero(r.mejor), KipColor.verdePnl(scheme)),
            ("Peor trade", dinero(r.peor), KipColor.rojoPnl(scheme)),
            ("Racha ganadora", "\(r.rachaGanadora)", KipColor.text(scheme)),
            ("Racha perdedora", "\(r.rachaPerdedora)", KipColor.text(scheme)),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            TituloTarjeta(texto: "Resumen")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(tarjetas.enumerated()), id: \.offset) { _, tarjeta in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tarjeta.titulo)
                            .font(.manrope(11, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Text(tarjeta.valor)
                            .font(.manrope(17, weight: .heavy))
                            .foregroundStyle(tarjeta.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(KipColor.card(scheme))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(KipColor.border(scheme), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    /// Las barras de estrategia/plan se CONSTRUYEN desde los grupos.
    private func barrasDeGrupos(_ grupos: [GrupoStatsDto]) -> [BarraDto] {
        grupos.map { grupo in
            BarraDto(label: grupo.nombreVisible, value: grupo.net,
                     display: dinero(grupo.net),
                     detalle: "\(grupo.trades) trades · \(grupo.winRate)% aciertos")
        }
    }

    /// dia: se filtran sabado y domingo usando el detalle como fecha ISO.
    private func barrasDiaSinFinde(_ barras: [BarraDto]) -> [BarraDto] {
        barras.filter { barra in
            guard barra.detalle.count >= 10 else { return true }
            let clave = String(barra.detalle.prefix(10))
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(secondsFromGMT: 0)
            guard let d = f.date(from: clave) else { return true }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            let semana = cal.component(.weekday, from: d)
            return semana != 1 && semana != 7
        }
    }
}

/// El dialogo «Personalizar tarjetas» de Estadisticas.
struct PersonalizarStatsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Binding var orden: [String]
    @Binding var ocultas: Set<String>
    let titulos: [String: String]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orden, id: \.self) { clave in
                        HStack {
                            Text(titulos[clave] ?? clave)
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !ocultas.contains(clave) },
                                set: { prendida in
                                    if prendida { ocultas.remove(clave) } else { ocultas.insert(clave) }
                                }
                            ))
                            .labelsHidden()
                            .tint(KipColor.accent)
                        }
                    }
                    .onMove { desde, hasta in
                        orden.move(fromOffsets: desde, toOffset: hasta)
                    }
                } header: {
                    Text("Muévelas arrastrando desde los puntos y apaga las que no uses. Se guarda en tu teléfono.")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Personalizar tarjetas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Restablecer") {
                        orden = StatsLocal.clavesBase
                        ocultas = []
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
