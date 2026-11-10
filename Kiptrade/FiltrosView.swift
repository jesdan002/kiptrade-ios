import SwiftUI

// El dialogo de Filtros (Filtros.kt de la Android): selectores con las
// opciones exactas, fechas con selector, y los botones «Limpiar» /
// «Aplicar filtros» siempre visibles. En Diario se usa completo; en
// Estadisticas sin estrategia/estado/orden y con busqueda q.

struct OpcionFiltro: Identifiable {
    let etiqueta: String
    let valor: String?
    var id: String { etiqueta }
}

let opcionesTipo: [OpcionFiltro] = [
    OpcionFiltro(etiqueta: "Todos", valor: nil), OpcionFiltro(etiqueta: "Calls", valor: "call"),
    OpcionFiltro(etiqueta: "Puts", valor: "put"), OpcionFiltro(etiqueta: "Acciones", valor: "acciones"),
]
let opcionesEstado: [OpcionFiltro] = [
    OpcionFiltro(etiqueta: "Todos", valor: nil), OpcionFiltro(etiqueta: "Abiertas", valor: "open"),
    OpcionFiltro(etiqueta: "Cerradas", valor: "closed"),
]
let opcionesResultado: [OpcionFiltro] = [
    OpcionFiltro(etiqueta: "Todos", valor: nil), OpcionFiltro(etiqueta: "Ganadores", valor: "ganador"),
    OpcionFiltro(etiqueta: "Perdedores", valor: "perdedor"),
]
let opcionesLado: [OpcionFiltro] = [
    OpcionFiltro(etiqueta: "Todos", valor: nil), OpcionFiltro(etiqueta: "Largo", valor: "long"),
    OpcionFiltro(etiqueta: "Corto", valor: "short"),
]
let opcionesOrden: [OpcionFiltro] = [
    OpcionFiltro(etiqueta: "Más recientes", valor: "recientes"), OpcionFiltro(etiqueta: "Más antiguos", valor: "antiguos"),
    OpcionFiltro(etiqueta: "Mayor ganancia", valor: "ganancia"), OpcionFiltro(etiqueta: "Mayor pérdida", valor: "perdida"),
]

struct FiltrosView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var f: FiltrosDiario
    let datos: DiarioDto
    var conEstrategia: Bool = true
    var conEstado: Bool = true
    var conOrden: Bool = true
    var conBusqueda: Bool = false
    var alAplicar: (FiltrosDiario) -> Void = { _ in }

    init(filtros: FiltrosDiario, datos: DiarioDto, conEstrategia: Bool = true, conEstado: Bool = true,
         conOrden: Bool = true, conBusqueda: Bool = false, alAplicar: @escaping (FiltrosDiario) -> Void) {
        _f = State(initialValue: filtros)
        self.datos = datos
        self.conEstrategia = conEstrategia
        self.conEstado = conEstado
        self.conOrden = conOrden
        self.conBusqueda = conBusqueda
        self.alAplicar = alAplicar
    }

    var body: some View {
        NavigationStack {
            Form {
                if conBusqueda {
                    Section("Buscar") {
                        TextField("Buscar", text: $f.q)
                            .font(.manrope(15))
                    }
                }
                selector("Ticker", opciones: [OpcionFiltro(etiqueta: "Todos", valor: nil)] + datos.tickers.map { OpcionFiltro(etiqueta: $0, valor: $0) }, valor: $f.ticker)
                selector("Tipo", opciones: opcionesTipo, valor: $f.tipo)
                if conEstrategia {
                    selector("Estrategia", opciones: [OpcionFiltro(etiqueta: "Todas", valor: nil)] + datos.estrategiasPlan.map { OpcionFiltro(etiqueta: $0, valor: $0) }, valor: $f.estrategia)
                }
                if conEstado {
                    selector("Estado", opciones: opcionesEstado, valor: $f.estado)
                }
                selectorCuenta()
                selector("Emoción", opciones: [OpcionFiltro(etiqueta: "Todas", valor: nil)] + datos.emociones.map { OpcionFiltro(etiqueta: $0, valor: $0) }, valor: $f.emocion)
                selector("Resultado", opciones: opcionesResultado, valor: $f.resultado)
                selector("Lado", opciones: opcionesLado, valor: $f.lado)
                if conOrden {
                    SelectorOrden(orden: $f.orden)
                }
                Section("Fechas") {
                    SelectorFecha(titulo: "Desde", clave: $f.desde)
                    SelectorFecha(titulo: "Hasta", clave: $f.hasta)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 12) {
                        BotonBordeKip(texto: "Limpiar") {
                            let limpia = FiltrosDiario()
                            alAplicar(limpia)
                            dismiss()
                        }
                        BotonKip(texto: "Aplicar filtros") {
                            alAplicar(f)
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func selector(_ titulo: String, opciones: [OpcionFiltro], valor: Binding<String?>) -> some View {
        Section(titulo) {
            Picker(titulo, selection: Binding(
                get: { opciones.first { $0.valor == valor.wrappedValue }?.etiqueta ?? opciones.first?.etiqueta ?? "" },
                set: { etiqueta in valor.wrappedValue = opciones.first { $0.etiqueta == etiqueta }?.valor }
            )) {
                ForEach(opciones) { opcion in
                    Text(opcion.etiqueta).tag(opcion.etiqueta)
                }
            }
            .pickerStyle(.menu)
            .font(.manrope(15))
        }
    }

    private func selectorCuenta() -> some View {
        Section("Cuenta") {
            Picker("Cuenta", selection: Binding(
                get: { f.cuenta },
                set: { f.cuenta = $0 }
            )) {
                Text("Todas").tag(nil as Int?)
                ForEach(datos.cuentas) { cuenta in
                    Text(cuenta.nombre).tag(cuenta.id as Int?)
                }
            }
            .pickerStyle(.menu)
            .font(.manrope(15))
        }
    }
}

private struct SelectorOrden: View {
    @Binding var orden: String
    var body: some View {
        Section("Orden") {
            Picker("Orden", selection: $orden) {
                ForEach(opcionesOrden) { opcion in
                    Text(opcion.etiqueta).tag(opcion.valor ?? "recientes")
                }
            }
            .pickerStyle(.menu)
            .font(.manrope(15))
        }
    }
}

/// Fecha opcional: sin fecha, o el calendario con «Quitar».
struct SelectorFecha: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    @Binding var clave: String?

    private var fechaBinding: Binding<Date> {
        Binding(
            get: {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.timeZone = TimeZone(secondsFromGMT: 0)
                return f.date(from: clave ?? claveFechaHoy()) ?? Date()
            },
            set: { nueva in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                clave = f.string(from: nueva)
            }
        )
    }

    var body: some View {
        HStack {
            Text(titulo)
                .font(.manrope(15))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
            if let clave = clave {
                DatePicker("", selection: fechaBinding, displayedComponents: .date)
                    .labelsHidden()
                Button("Quitar") { self.clave = nil }
                    .font(.manrope(13, weight: .bold))
                    .foregroundStyle(KipColor.error(scheme))
            } else {
                Text("Sin fecha")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Button("Elegir") { clave = claveFechaHoy() }
                    .font(.manrope(13, weight: .bold))
                    .foregroundStyle(KipColor.accent)
            }
        }
    }
}
