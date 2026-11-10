import SwiftUI
import UIKit

// Componentes compartidos de Kiptrade iOS: formato (Formato.kt de la
// Android), tarjetas, filas de trade, donas y curvas. Las reglas de
// pintado salen del mapa (§1.4 y §3.0): dinero SIEMPRE con signo y
// Locale.US; las donas muestran verde Y rojo (nada de esconder perdidas).

// MARK: - Formato

private let fmtMonedaUS: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "en_US")
    f.currencyCode = "USD"
    return f
}()

/// dinero() de la Android: null -> «—»; si no, signo SIEMPRE.
func dinero(_ valor: Double?) -> String {
    guard let valor = valor else { return "—" }
    let cuerpo = fmtMonedaUS.string(from: NSNumber(value: abs(valor))) ?? "$0.00"
    return (valor < 0 ? "-" : "+") + cuerpo
}

/// dineroSinSigno(): moneda US con su signo natural.
func dineroSinSigno(_ valor: Double?) -> String {
    guard let valor = valor else { return "—" }
    return fmtMonedaUS.string(from: NSNumber(value: valor)) ?? "$0.00"
}

/// dineroBarra de Formato.kt: sin centavos; «−$» con U+2212 si negativo.
func dineroBarraFormato(_ valor: Double) -> String {
    let entero = Int(valor) // trunca, como la Android
    let miles = milesConComas(abs(entero))
    if entero < 0 { return "\u{2212}$\(miles)" }
    return "+$\(miles)"
}

/// La dineroBarra PRIVADA del Panel Android: redondea y usa «-$» ASCII.
func dineroBarraPanel(_ valor: Double) -> String {
    let redondo = Int(valor.rounded())
    let miles = milesConComas(abs(redondo))
    return (redondo > 0 ? "+$" : "-$") + miles
}

func milesConComas(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// porcentaje(Int?): null -> «—»; si no «{n}%».
func porcentaje(_ valor: Int?) -> String {
    guard let valor = valor else { return "—" }
    return "\(valor)%"
}

/// El strike: entero sin decimales si es exacto; si no, el double crudo.
func strikeTexto(_ valor: Double) -> String {
    if valor == valor.rounded() { return String(Int(valor)) }
    return String(valor)
}

/// Los valores semilla de los campos numericos del detalle: sin ceros
/// (30.0 -> «30»), como la Android.
func numeroSemilla(_ valor: Double?) -> String {
    guard let valor = valor else { return "" }
    if valor == valor.rounded() { return String(Int(valor)) }
    return String(valor)
}

private let fmtFechaISO: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
private let fmtFechaISOsimple: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func parsearISO(_ iso: String?) -> Date? {
    guard let iso = iso, !iso.isEmpty else { return nil }
    return fmtFechaISO.date(from: iso) ?? fmtFechaISOsimple.date(from: iso)
}

private func formateador(_ patron: String) -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es")
    f.dateFormat = patron
    return f
}

/// fechaCorta: «d MMM yyyy» en español; si no parsea, los 10 primeros.
func fechaCorta(_ iso: String?) -> String {
    guard let iso = iso, !iso.isEmpty else { return "" }
    if let d = parsearISO(iso) { return formateador("d MMM yyyy").string(from: d) }
    return String(iso.prefix(10))
}

/// fechaHora: «d MMM yyyy · h:mm a».
func fechaHora(_ iso: String?) -> String {
    guard let iso = iso, !iso.isEmpty else { return "" }
    if let d = parsearISO(iso) { return formateador("d MMM yyyy · h:mm a").string(from: d) }
    return String(iso.prefix(10))
}

/// fechaPunto: los 10 primeros caracteres como fecha -> «d MMM yyyy».
func fechaPunto(_ iso: String?) -> String {
    guard let iso = iso, iso.count >= 10 else { return fechaCorta(iso) }
    let clave = String(iso.prefix(10))
    let f = DateFormatter()
    f.locale = Locale(identifier: "es")
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    if let d = f.date(from: clave) {
        let salida = DateFormatter()
        salida.locale = Locale(identifier: "es")
        salida.dateFormat = "d MMM yyyy"
        salida.timeZone = TimeZone(secondsFromGMT: 0)
        return salida.string(from: d)
    }
    return fechaCorta(iso)
}

/// fechaPuntoLarga: «EEEE d 'de' MMMM» con inicial mayuscula.
func fechaPuntoLarga(_ iso: String?) -> String {
    guard let iso = iso, iso.count >= 10 else { return "" }
    let clave = String(iso.prefix(10))
    let f = DateFormatter()
    f.locale = Locale(identifier: "es")
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    guard let d = f.date(from: clave) else { return "" }
    let salida = DateFormatter()
    salida.locale = Locale(identifier: "es")
    salida.dateFormat = "EEEE d 'de' MMMM"
    salida.timeZone = TimeZone(secondsFromGMT: 0)
    let texto = salida.string(from: d)
    return texto.prefix(1).uppercased() + texto.dropFirst()
}

/// La clave «yyyy-MM-dd» de hoy en la zona del telefono.
func claveFechaHoy() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

/// Suma dias a una clave «yyyy-MM-dd».
func claveFecha(_ clave: String, masDias delta: Int) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    guard let d = f.date(from: clave) else { return clave }
    let nueva = Calendar(identifier: .gregorian).date(byAdding: .day, value: delta, to: d) ?? d
    return f.string(from: nueva)
}

// MARK: - Tarjetas y titulos

struct KipCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// El titulo estandar de tarjeta de la app.
struct TituloTarjeta: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    var body: some View {
        Text(texto)
            .font(.manrope(16, weight: .bold))
            .foregroundStyle(KipColor.text(scheme))
    }
}

/// Mensaje de error de carga con su boton «Reintentar».
struct ErrorCarga: View {
    @Environment(\.colorScheme) private var scheme
    let mensaje: String
    var reintentar: () -> Void = {}
    var body: some View {
        VStack(spacing: 10) {
            Text(mensaje)
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .multilineTextAlignment(.center)
            Button("Reintentar") { reintentar() }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }
}

/// La vista compartida de sesion expirada (cada pantalla pone su cola).
struct VistaSesionExpirada: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    var alEntrar: () -> Void = {}
    var body: some View {
        VStack(spacing: 14) {
            Text(texto)
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .multilineTextAlignment(.center)
            Button { alEntrar() } label: {
                Text("Iniciar sesión")
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.onAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(degradadoMarca)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
    }
}

// MARK: - Campos y botones

/// Campo de texto de la familia: etiqueta SOBRE el campo, borde de la
/// tarjeta, ojito opcional en contrasenas.
struct CampoKip: View {
    @Environment(\.colorScheme) private var scheme
    let etiqueta: String
    @Binding var texto: String
    var esContrasena: Bool = false
    var teclado: UIKeyboardType = .default
    var autocapitalizacion: TextInputAutocapitalization = .sentences
    var multilinea: Bool = false
    var lineasMinimas: Int = 4
    var placeholder: String = ""
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(etiqueta)
                .font(.manrope(13, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            HStack(spacing: 6) {
                Group {
                    if multilinea {
                        TextField(placeholder, text: $texto, axis: .vertical)
                            .lineLimit(lineasMinimas...(lineasMinimas + 6))
                    } else if esContrasena && !visible {
                        SecureField(placeholder, text: $texto)
                    } else {
                        TextField(placeholder, text: $texto)
                    }
                }
                .font(.manrope(16))
                .foregroundStyle(KipColor.text(scheme))
                .keyboardType(teclado)
                .textInputAutocapitalization(autocapitalizacion)
                .autocorrectionDisabled(teclado == .emailAddress)
                if esContrasena {
                    Button { visible.toggle() } label: {
                        Image(systemName: visible ? "eye.slash" : "eye")
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(visible ? "Ocultar" : "Ver")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Boton primario de la familia: pastilla con el degradado de marca.
struct BotonKip: View {
    let texto: String
    var deshabilitado: Bool = false
    var accion: () -> Void = {}
    var body: some View {
        Button { accion() } label: {
            Text(texto)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(degradadoMarca)
                .clipShape(Capsule())
                .opacity(deshabilitado ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(deshabilitado)
    }
}

/// Boton con borde (outlined) de la familia.
struct BotonBordeKip: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    var deshabilitado: Bool = false
    var accion: () -> Void = {}
    var body: some View {
        Button { accion() } label: {
            Text(texto)
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: 1))
                .opacity(deshabilitado ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(deshabilitado)
    }
}

/// Interruptor de la familia en los colores de la marca (nada de
/// colores por defecto del sistema).
struct KipInterruptor: View {
    @Binding var prendido: Bool
    var alCambiar: (Bool) -> Void = { _ in }
    var body: some View {
        Toggle("", isOn: Binding(get: { prendido }, set: { nuevo in
            prendido = nuevo
            alCambiar(nuevo)
        }))
        .labelsHidden()
        .tint(KipColor.accent)
    }
}

// MARK: - Donas

/// La regla de color de una dona del servidor (esRojaLaDona de la
/// Android): roja si tono == "rojo", o si es una metrica de perdida y
/// el display empieza con «-», o si el profit factor parseado es < 1.
/// Las donas muestran verde Y rojo: nada de esconder las perdidas.
func esRojaLaDona(_ dona: DonaDto) -> Bool {
    if dona.tono == "rojo" { return true }
    if ["max_dd", "max_dd_pct", "profit", "ganancia_prom"].contains(dona.key) {
        if dona.display.hasPrefix("-") || dona.display.hasPrefix("\u{2212}") { return true }
    }
    if dona.key == "profit_factor" {
        let numero = dona.display.replacingOccurrences(of: "[^0-9.\\-]", with: "", options: .regularExpression)
        if let v = Double(numero), v < 1.0 { return true }
    }
    return false
}

/// El anillo de una dona: fondo #35485A fijo; si vienen las dos partes,
/// el anillo se cierra verde + rojo = 360 grados.
struct DonaAnillo: View {
    @Environment(\.colorScheme) private var scheme
    let dona: DonaDto
    var tamano: CGFloat = 120

    var body: some View {
        let roja = esRojaLaDona(dona)
        let colorPrincipal = roja ? KipColor.rojoPnl(scheme) : KipColor.verdePnl(scheme)
        ZStack {
            Circle()
                .stroke(Color(hex: 0x35485A), lineWidth: 12)
            if let verde = dona.parteVerde, let rojaParte = dona.parteRoja, (verde + rojaParte) > 0 {
                let fraccion = verde / (verde + rojaParte)
                Circle()
                    .trim(from: 0, to: CGFloat(fraccion))
                    .stroke(KipColor.verdePnl(scheme), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: CGFloat(fraccion), to: 1)
                    .stroke(KipColor.rojoPnl(scheme), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(dona.share, 0), 1)))
                    .stroke(colorPrincipal, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            Text(dona.display)
                .font(.manrope(17, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
        }
        .frame(width: tamano, height: tamano)
    }
}

// MARK: - Fila de trade

/// El detalle corto de un trade (FilaTrade de la Android): opcion ->
/// «{tipo} {strike} · ×{n} contrato(s)»; accion -> «Acción · ×{n} acciones».
func detalleTradeCorto(_ t: TradeDto) -> String {
    var texto: String
    if t.esOpcion {
        var partes = t.tipo
        if let strike = t.strike { partes += " " + strikeTexto(strike) }
        texto = partes + " · ×\(t.cantidad) contrato" + (t.cantidad == 1 ? "" : "s")
    } else {
        texto = "Acción · ×\(t.cantidad) acciones"
    }
    let fecha = t.cerradoEn ?? t.abiertoEn
    if let fecha = fecha, !fecha.isEmpty { texto += " · " + fechaCorta(fecha) }
    return texto
}

/// La fila de un trade: logo FMP 38, ticker, detalle, y a la derecha
/// la pastilla Win/Loss con el neto, o «Abierta».
struct FilaTrade: View {
    @Environment(\.colorScheme) private var scheme
    let trade: TradeDto
    var body: some View {
        HStack(spacing: 12) {
            LogoTicker(ticker: trade.ticker)
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.ticker)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(detalleTradeCorto(trade))
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .lineLimit(2)
            }
            Spacer()
            if trade.estado == "closed", let ganador = trade.ganador {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ganador ? "Win" : "Loss")
                            .font(.manrope(11, weight: .heavy))
                            .foregroundStyle(Color(hex: 0x12181F))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(ganador ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                            .clipShape(Capsule())
                        Text(dinero(trade.neto))
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle((trade.neto ?? 0) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme))
                    }
                    if let pct = trade.pnlPct {
                        Text(String(format: "%+.2f%%", pct))
                            .font(.manrope(12))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
            } else {
                Text("Abierta")
                    .font(.manrope(14, weight: .semibold))
                    .foregroundStyle(KipColor.verdePnl(scheme))
            }
        }
        .padding(.vertical, 10)
    }
}

/// El logo de un ticker desde FMP (sin token), con la inicial de
/// respaldo si la imagen no llega.
struct LogoTicker: View {
    @Environment(\.colorScheme) private var scheme
    let ticker: String
    @State private var imagen: UIImage? = nil
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(KipColor.elevated(scheme))
            if let imagen = imagen {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Text(String(ticker.prefix(1)))
                    .font(.manrope(16, weight: .heavy))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task {
            guard imagen == nil, !ticker.isEmpty,
                  let url = URL(string: "https://financialmodelingprep.com/image-stock/\(ticker).png") else { return }
            if let (datos, respuesta) = try? await URLSession.shared.data(from: url),
               let http = respuesta as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let img = UIImage(data: datos) {
                imagen = img
            }
        }
    }
}

/// La foto remota que pide Bearer SOLO si el host es app.kiptrade.net
/// (avatar y captura; los logos FMP van sin token).
struct ImagenConToken: View {
    let urlTexto: String?
    @State private var imagen: UIImage? = nil
    var body: some View {
        Group {
            if let imagen = imagen {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: urlTexto) {
            imagen = nil
            guard let urlTexto = urlTexto, let url = URL(string: urlTexto) else { return }
            var req = URLRequest(url: url)
            if url.host == "app.kiptrade.net", let token = Sesion.token {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            if let (datos, respuesta) = try? await URLSession.shared.data(for: req),
               let http = respuesta as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                imagen = UIImage(data: datos)
            }
        }
    }
}

/// El avatar redondo: foto con Bearer, o el circulo de marca con la inicial.
struct AvatarKip: View {
    let urlTexto: String?
    let nombre: String
    var tamano: CGFloat = 48
    var body: some View {
        ZStack {
            if let urlTexto = urlTexto, !urlTexto.isEmpty {
                ImagenConToken(urlTexto: urlTexto)
            } else {
                Circle().fill(degradadoMarca)
                Text(String((nombre.isEmpty ? "?" : nombre).prefix(1)).uppercased())
                    .font(.manrope(tamano * 0.42, weight: .heavy))
                    .foregroundStyle(KipColor.onAccent)
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(Circle())
    }
}

// MARK: - Curvas

/// Una curva de capital suave (Bezier) explorable con el dedo: el
/// tooltip muestra la fecha ([S] cruda del servidor) y el valor.
/// Bicolor opcional: se parte en el cruce del cero (verde arriba,
/// rojo abajo) y marca el punto final.
struct CurvaCapital: View {
    @Environment(\.colorScheme) private var scheme
    let puntos: [PuntoCurvaDto]
    var bicolor: Bool = false
    var altura: CGFloat = 180
    @State private var indiceTocado: Int? = nil

    var body: some View {
        let valores = puntos.map { $0.value }
        let maximo = max(valores.max() ?? 0, 0.0001)
        let minimo = min(valores.min() ?? 0, -0.0001)
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Canvas { contexto, tamano in
                    func punto(_ i: Int) -> CGPoint {
                        let x = puntos.count > 1 ? tamano.width * CGFloat(i) / CGFloat(puntos.count - 1) : 0
                        let rango = maximo - minimo
                        let y = tamano.height - CGFloat((valores[i] - minimo) / rango) * (tamano.height - 12) - 6
                        return CGPoint(x: x, y: y)
                    }
                    func trazo(_ desde: Int, _ hasta: Int) -> Path {
                        var p = Path()
                        guard hasta > desde else { return p }
                        p.move(to: punto(desde))
                        for i in (desde + 1)...hasta {
                            let anterior = punto(i - 1)
                            let actual = punto(i)
                            let medio = CGPoint(x: (anterior.x + actual.x) / 2, y: (anterior.y + actual.y) / 2)
                            p.addQuadCurve(to: medio, control: anterior)
                            if i == hasta { p.addLine(to: actual) }
                        }
                        return p
                    }
                    // Linea cero si la curva la cruza
                    if minimo < 0 && maximo > 0 {
                        let rango = maximo - minimo
                        let yCero = tamano.height - CGFloat((0 - minimo) / rango) * (tamano.height - 12) - 6
                        var cero = Path()
                        cero.move(to: CGPoint(x: 0, y: yCero))
                        cero.addLine(to: CGPoint(x: tamano.width, y: yCero))
                        contexto.stroke(cero, with: .color(Color(hex: 0x35485A)), lineWidth: 1)
                    }
                    if bicolor {
                        var inicioSegmento = 0
                        for i in 1..<puntos.count {
                            let cambia = (valores[i - 1] < 0) != (valores[i] < 0)
                            if cambia || i == puntos.count - 1 {
                                let fin = i == puntos.count - 1 ? i : i - 1
                                let color = valores[inicioSegmento] >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)
                                contexto.stroke(trazo(inicioSegmento, max(fin, inicioSegmento + 1)), with: .color(color), lineWidth: 2)
                                inicioSegmento = i - 1
                            }
                        }
                        if let ultimo = (0..<puntos.count).last {
                            let p = punto(ultimo)
                            contexto.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)),
                                          with: .color(valores[ultimo] >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)))
                        }
                    } else {
                        contexto.stroke(trazo(0, puntos.count - 1), with: .color(KipColor.verdePnl(scheme)), lineWidth: 2)
                    }
                    if let tocado = indiceTocado, tocado < puntos.count {
                        let p = punto(tocado)
                        var guia = Path()
                        guia.move(to: CGPoint(x: p.x, y: 0))
                        guia.addLine(to: CGPoint(x: p.x, y: tamano.height))
                        contexto.stroke(guia, with: .color(KipColor.textSecondary(scheme).opacity(0.5)), lineWidth: 1)
                        contexto.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(KipColor.accent))
                    }
                }
                .frame(height: altura)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesto in
                            indiceTocado = indiceCercano(x: gesto.location.x)
                        }
                        .onEnded { _ in indiceTocado = nil }
                )
                if let tocado = indiceTocado, tocado < puntos.count {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(puntos[tocado].date)
                            .font(.manrope(11, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Text(dinero(puntos[tocado].value))
                            .font(.manrope(13, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(KipColor.elevated(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .offset(x: 8, y: 4)
                }
            }
            HStack {
                Text(puntos.first?.date ?? "")
                Spacer()
                Text(puntos.last?.date ?? "")
            }
            .font(.manrope(11))
            .foregroundStyle(KipColor.textSecondary(scheme))
        }
    }

    private func indiceCercano(x: CGFloat) -> Int {
        // El ancho real llega del gesto via el frame del Canvas; se
        // estima con el ancho de pantalla menos los paddings usuales.
        let ancho = UIScreen.main.bounds.width - 64
        guard puntos.count > 1, ancho > 0 else { return 0 }
        let fraccion = min(max(x / ancho, 0), 1)
        return Int((fraccion * CGFloat(puntos.count - 1)).rounded())
    }
}

/// La curva del mes con ejes (Mensual): dinero(max)/dinero(min) a la
/// izquierda y «#1»/«#{n}» abajo; el color por el signo del ultimo valor.
struct CurvaConEjes: View {
    @Environment(\.colorScheme) private var scheme
    let puntos: [PuntoCurvaDto]
    var body: some View {
        let valores = puntos.map { $0.value }
        let maximo = valores.max() ?? 0
        let minimo = valores.min() ?? 0
        HStack(alignment: .top, spacing: 8) {
            VStack {
                Text(dinero(maximo))
                Spacer()
                Text(dinero(minimo))
            }
            .font(.manrope(11, weight: .semibold))
            .foregroundStyle(KipColor.textSecondary(scheme))
            .frame(height: 170)
            VStack(spacing: 4) {
                CurvaCapitalSimple(puntos: puntos, altura: 170)
                HStack {
                    Text("#1")
                    Spacer()
                    Text("#\(puntos.count)")
                }
                .font(.manrope(11))
                .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }
}

struct CurvaCapitalSimple: View {
    @Environment(\.colorScheme) private var scheme
    let puntos: [PuntoCurvaDto]
    var altura: CGFloat = 170
    var body: some View {
        let valores = puntos.map { $0.value }
        let maximo = max(valores.max() ?? 0, 0.0001)
        let minimo = min(valores.min() ?? 0, -0.0001)
        let color = (valores.last ?? 0) >= 0 ? KipColor.verdePnl(scheme) : KipColor.rojoPnl(scheme)
        Canvas { contexto, tamano in
            func punto(_ i: Int) -> CGPoint {
                let x = puntos.count > 1 ? tamano.width * CGFloat(i) / CGFloat(puntos.count - 1) : 0
                let rango = maximo - minimo
                let y = tamano.height - CGFloat((valores[i] - minimo) / rango) * (tamano.height - 8) - 4
                return CGPoint(x: x, y: y)
            }
            var p = Path()
            if !puntos.isEmpty {
                p.move(to: punto(0))
                for i in 1..<puntos.count {
                    let anterior = punto(i - 1)
                    let actual = punto(i)
                    let medio = CGPoint(x: (anterior.x + actual.x) / 2, y: (anterior.y + actual.y) / 2)
                    p.addQuadCurve(to: medio, control: anterior)
                    if i == puntos.count - 1 { p.addLine(to: actual) }
                }
            }
            contexto.stroke(p, with: .color(color), lineWidth: 2)
        }
        .frame(height: altura)
    }
}

// MARK: - Barras de estadisticas

/// Una columna de BarrasStats: alto 140 x fraccion (min. 3), degradado
/// vertical claro->base, el display [S] encima y el label debajo.
struct ColumnaBarra: View {
    @Environment(\.colorScheme) private var scheme
    let barra: BarraDto
    let fraccion: CGFloat
    let esDebil: Bool
    var mostrarDetalle: Bool = true
    var body: some View {
        let negativa = barra.value < 0 || esDebil
        let base = negativa ? KipColor.rojoPnl(scheme) : KipColor.verdePnl(scheme)
        VStack(spacing: 4) {
            Text(barra.display)
                .font(.manrope(11, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [base.opacity(0.45), base], startPoint: .top, endPoint: .bottom))
                .frame(width: 32, height: max(140 * fraccion, 3))
            Text(barra.label)
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .lineLimit(1)
            if mostrarDetalle && !barra.detalle.isEmpty {
                Text(barra.detalle)
                    .font(.manrope(10))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .lineLimit(1)
            }
        }
        .frame(width: 62)
    }
}

/// La tarjeta de barras: si son mas de 4, la fila se desplaza.
struct BarrasStats: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    let barras: [BarraDto]
    var porValorAbsoluto: Bool = false
    var mostrarDetalle: Bool = true
    var debilPorLabel: Bool = false
    @State private var elegida: Int? = nil

    var body: some View {
        let referencia = porValorAbsoluto ? (barras.map { abs($0.value) }.max() ?? 0) : (barras.map { $0.value }.max() ?? 0)
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                TituloTarjeta(texto: titulo)
                if barras.isEmpty {
                    Text("Sin datos en este rango.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(Array(barras.enumerated()), id: \.offset) { indice, barra in
                                Button {
                                    elegida = elegida == indice ? nil : indice
                                } label: {
                                    ColumnaBarra(barra: barra,
                                                 fraccion: referencia > 0 ? CGFloat(abs(barra.value) / referencia) : 0,
                                                 esDebil: debilPorLabel && barra.label.lowercased().contains("bajo"),
                                                 mostrarDetalle: mostrarDetalle)
                                    .opacity(elegida == nil || elegida == indice ? 1 : 0.55)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let elegida = elegida, elegida < barras.count {
                        let barra = barras[elegida]
                        Text("\(tituloFicha(barra)) · \(barra.display)")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                }
            }
        }
    }

    private func tituloFicha(_ barra: BarraDto) -> String {
        // Si el detalle parsea como fecha, va la fecha larga; si no, el label.
        if barra.detalle.count >= 10, fechaPuntoLarga(String(barra.detalle.prefix(10))) != "" {
            let clave = String(barra.detalle.prefix(10))
            if clave.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil {
                return fechaPuntoLarga(clave)
            }
        }
        return barra.label
    }
}

// MARK: - Pastillas de seccion

/// Las pastillas de seccion (Diario, Notificaciones): la activa con
/// fondo Accent y texto OnAccent; la etiqueta se auto-encoge.
struct PastillasSeccion: View {
    @Environment(\.colorScheme) private var scheme
    let opciones: [String]
    @Binding var elegida: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(opciones.enumerated()), id: \.offset) { indice, opcion in
                Button { elegida = indice } label: {
                    Text(opcion)
                        .font(.manrope(14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(elegida == indice ? KipColor.onAccent : KipColor.textSecondary(scheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(elegida == indice ? KipColor.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}
