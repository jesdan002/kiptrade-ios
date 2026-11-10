import Foundation

// Los DTO de la API v1 de Kiptrade AW, calcados de los modelos Kotlin
// (mapa-kiptrade.md §2). Reglas del porte:
// - Decodificacion TOLERANTE al estilo kotlinx (ignoreUnknownKeys +
//   coerceInputValues): un campo con default NUNCA rompe la decodificacion
//   si viene null o de otro tipo; por eso los campos con default llevan
//   decodificadores seguros.
// - [S] = el servidor manda el texto YA formateado: no reformatear.
// - Las claves se copian tal cual, incluidas las que van en ingles o
//   en camelCase.

/// Decodifica un valor o devuelve el default si falta, es null o el
/// tipo no calza (el coerceInputValues de kotlinx).
func seguro<T: Decodable>(_ c: KeyedDecodingContainer<ModeloKeys>, _ clave: ModeloKeys, _ defecto: T) -> T {
    (try? c.decodeIfPresent(T.self, forKey: clave)) ?? nil ?? defecto
}

func seguroOpt<T: Decodable>(_ c: KeyedDecodingContainer<ModeloKeys>, _ clave: ModeloKeys) -> T? {
    (try? c.decodeIfPresent(T.self, forKey: clave)) ?? nil
}

enum ModeloKeys: String, CodingKey {
    case id, name, nickname, email, avatarUrl = "avatar_url", isAdmin = "is_admin"
    case verificado, tema, timezone, barra, billing
    case trialEndsAt = "trial_ends_at", currentPeriodEnd = "current_period_end"
    case cancelAtPeriodEnd = "cancel_at_period_end", intervalo
    case token, user, message, codigo, procesando
    case modo, requiereCodigo = "requiere_codigo", diasPrueba = "dias_prueba"
    case brokerAlerta = "broker_alerta", titulo, cuenta
    case estadoUnico = "estado"
    case detalle
    case avisosBilling = "avisos_billing", tipoK = "tipo", tarjetas
    case rango, desde, hasta, resumen, donas, metricasDonas = "metricas_donas"
    case donasElegidas = "donas_elegidas", drawdown, curva, diaFecha = "date", valorPunto = "value"
    case ultimosTrades = "ultimos_trades", posicionesAbiertas = "posiciones_abiertas"
    case tieneConexionBroker = "tiene_conexion_broker", espejo
    case neto, winRate = "win_rate", profitFactor = "profit_factor", kipScore = "kip_score"
    case tradesCerradosKT = "trades_cerrados_kt", tradesMes = "trades_mes"
    case promedioGanancia = "promedio_ganancia", gananciaPromPct = "ganancia_prom_pct"
    case promedioPerdida = "promedio_perdida", promedioR = "promedio_r", mejor, peor
    case rachaGanadora = "racha_ganadora", rachaPerdedora = "racha_perdedora"
    case caidaMaxima = "caida_maxima", caidaMaximaPct = "caida_maxima_pct"
    case key, label, display, share, tono, parteVerde = "parte_verde", parteRoja = "parte_roja"
    case valorBarraKT = "valor_barra_kt"
    case clave, etiqueta
    case netoHoy = "neto_hoy", limitePerdidaDiaria = "limite_perdida_diaria"
    case consumoLimitePct = "consumo_limite_pct", senialRevanchaHoy = "senial_revancha_hoy"
    case fueraDelPlan = "fuera_del_plan", revancha, siguiendoPlan = "siguiendo_plan"
    case trades, net
    case simbolo, ticker, esOpcion = "es_opcion", strike, lado, cantidadKT = "cantidad_pata"
    case precioApertura = "precio_apertura", precioCierre = "precio_cierre"
    case ganador, pnlPct = "pnl_pct", fees, emocion
    case abiertoEn = "abierto_en", cerradoEn = "cerrado_en"
    case grupo, grupoPatas = "grupo_patas", grupoNeto = "grupo_neto"
    case cantidadResumenK = "cantidad", ganadores
    case totalK = "total"
    case tickers, cuentas, estrategiasPlan = "estrategias_plan", emociones
    case mes, anterior, siguiente, chips, cerrados
    case gananciaBruta = "ganancia_bruta", perdidaBruta = "perdida_bruta"
    case promedioGananciaPct = "promedio_ganancia_pct"
    case gainLoss, longShort, timing, bestWorst, all, won, lost, detail
    case porDia = "por_dia", mapa, limiteDiario = "limite_diario"
    case ganancia, perdida, totalTrades = "total_trades"
    case trade, opciones
    case contrato, vencimiento, bruto, rMultiple = "r_multiple", origen
    case emocionDetectada = "emocion_detectada", motivoSalida = "motivo_salida"
    case notas, checklist, estrategia, patronEntrada = "patron_entrada"
    case stopPlanificado = "stop_planificado", objetivoPlanificado = "objetivo_planificado"
    case riesgo, siguioPlan = "siguio_plan", errorPrincipal = "error_principal"
    case tieneCaptura = "tiene_captura", transcripcion, tieneAudio = "tiene_audio"
    case grupoPatasDetalle = "grupo_patas_detalle"
    case estrategias, patrones, motivosSalida = "motivos_salida", errores
    case porTicker = "por_ticker", porEstrategia = "por_estrategia", porPlan = "por_plan"
    case porEmocion = "por_emocion", graficas, hallazgos
    case sesgosSemana = "sesgos_semana", sesgosHoy = "sesgos_hoy"
    case porDiaSemana = "por_dia_semana", porPatron = "por_patron", porAdherencia = "por_adherencia"
    case puntoEquilibrio = "punto_equilibrio"
    case estadoStatus = "status", signals, textoSenal = "text", tradesToday, netToday, detectadas
    case plan, plantillas
    case checklistNucleo = "checklist_nucleo", core
    case limiteSuave = "limite_suave", limiteDuro = "limite_duro"
    case interruptorRacha = "interruptor_racha", stopPct = "stop_pct"
    case fecha, entrada, historial, tradesDia = "trades_del_dia", tradesCerradosDia = "trades_cerrados"
    case reflexion
    case hoy, semana, ultimoAnalisis = "ultimo_analisis", iaActiva = "ia_activa"
    case mapaEmociones = "mapa_emociones", contenido, fuente, creadoEn = "creado_en"
    case dias, filasKT = "filas_mapa", maxAbs = "max_abs"
    case fear, fomo, deviated, followed
    case configurado, conexiones, cuentasSueltas = "cuentas_sueltas"
    case broker, numero, moneda, ultimoSync = "ultimo_sync", esCsv = "es_csv"
    case salud, saludTexto = "salud_texto", saludDetalle = "salud_detalle"
    case url
    case columnas, filasImportar = "filas", campos, index, suggested, samples, obligatorio
    case validas, duplicadas, conError = "con_error"
    case n, resultado, importados
    case cobroActivo = "cobro_activo", exento, precio
    case trialTermina = "trial_termina", periodoTermina = "periodo_termina"
    case canceladaAlFin = "cancelada_al_fin", avisos, tieneSuscripcion = "tiene_suscripcion"
    case puedeCheckout = "puede_checkout", puedePortal = "puede_portal", puedeCancelar = "puede_cancelar"
    case city, country, accountSize = "account_size", correoVerificado = "correo_verificado"
    case correoCambio = "correo_cambio"
    case invitaciones, usada, usadaPor = "usada_por", creada
    case ok
    case sinLeer = "sin_leer", notificaciones, icono, cuerpo, fechaIso = "fecha_iso", leida
    case preferencias, canales
    case analisis
}

// MARK: - Auth y usuario

struct BillingDto: Decodable {
    var estado: String = ""
    var trialEndsAt: String? = nil
    var currentPeriodEnd: String? = nil
    var cancelAtPeriodEnd: Bool = false
    var intervalo: String? = nil
    enum CodingKeys: String, CodingKey {
        case estado, intervalo
        case trialEndsAt = "trial_ends_at", currentPeriodEnd = "current_period_end", cancelAtPeriodEnd = "cancel_at_period_end"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estado = (try? c.decodeIfPresent(String.self, forKey: .estado)) ?? nil ?? ""
        trialEndsAt = (try? c.decodeIfPresent(String.self, forKey: .trialEndsAt)) ?? nil
        currentPeriodEnd = (try? c.decodeIfPresent(String.self, forKey: .currentPeriodEnd)) ?? nil
        cancelAtPeriodEnd = (try? c.decodeIfPresent(Bool.self, forKey: .cancelAtPeriodEnd)) ?? nil ?? false
        intervalo = (try? c.decodeIfPresent(String.self, forKey: .intervalo)) ?? nil
    }
}

struct UsuarioDto: Decodable {
    var id: Int = 0
    var name: String = ""
    var nickname: String? = nil
    var email: String = ""
    var avatarUrl: String? = nil
    var isAdmin: Bool = false
    var verificado: Bool = false
    var tema: String? = nil
    var timezone: String? = nil
    var barra: [String] = ["panel", "diario", "estadisticas", "coach", "plan"]
    var billing: BillingDto? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = seguro(c, .id, 0)
        name = seguro(c, .name, "")
        nickname = seguroOpt(c, .nickname)
        email = seguro(c, .email, "")
        avatarUrl = seguroOpt(c, .avatarUrl)
        isAdmin = seguro(c, .isAdmin, false)
        verificado = seguro(c, .verificado, false)
        tema = seguroOpt(c, .tema)
        timezone = seguroOpt(c, .timezone)
        barra = seguro(c, .barra, ["panel", "diario", "estadisticas", "coach", "plan"])
        billing = seguroOpt(c, .billing)
    }
}

struct RespuestaLogin: Decodable {
    var token: String = ""
    var user: UsuarioDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        token = seguro(c, .token, "")
        user = seguro(c, .user, UsuarioDtoVacio.hacer())
    }
}

/// Usuario vacio para defaults (nunca se pinta: el login siempre trae user).
enum UsuarioDtoVacio {
    static func hacer() -> UsuarioDto {
        try! JSONDecoder().decode(UsuarioDto.self, from: Data("{}".utf8))
    }
}

struct RespuestaUsuario: Decodable {
    var user: UsuarioDto = UsuarioDtoVacio.hacer()
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        user = seguro(c, .user, UsuarioDtoVacio.hacer())
    }
}

/// El MensajeDto de la AW: `message` es OBLIGATORIO en el contrato.
struct MensajeDto: Decodable {
    var message: String = ""
    var procesando: Bool? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        procesando = seguroOpt(c, .procesando)
    }
}

struct RegistroConfig: Decodable {
    var modo: String = "beta"
    var requiereCodigo: Bool = true
    var diasPrueba: Int = 14
    typealias Keys = ModeloKeys
    init(modo: String, requiereCodigo: Bool, diasPrueba: Int) {
        self.modo = modo; self.requiereCodigo = requiereCodigo; self.diasPrueba = diasPrueba
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        modo = seguro(c, .modo, "beta")
        requiereCodigo = seguro(c, .requiereCodigo, true)
        diasPrueba = seguro(c, .diasPrueba, 14)
    }
}

// MARK: - Panel

struct AlertaBrokerDto: Decodable {
    var titulo: String = ""
    var cuenta: String? = nil
    var estado: String? = nil
    var detalle: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        titulo = seguro(c, .titulo, "")
        cuenta = seguroOpt(c, .cuenta)
        estado = seguroOpt(c, .estadoUnico)
        detalle = seguroOpt(c, .detalle)
    }
}

struct AvisoBillingDto: Decodable {
    var tipo: String = ""
    var titulo: String = ""
    var detalle: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        tipo = seguro(c, .tipoK, "")
        titulo = seguro(c, .titulo, "")
        detalle = seguro(c, .detalle, "")
    }
}

struct ResumenDto: Decodable {
    var neto: Double? = nil
    var winRate: Int? = nil
    var profitFactor: Double? = nil
    var kipScore: Int? = nil
    var tradesCerrados: Int = 0
    var tradesMes: Int = 0
    var promedioGanancia: Double = 0
    var gananciaPromPct: Double? = nil
    var promedioPerdida: Double = 0
    var promedioR: Double? = nil
    var mejor: Double? = nil
    var peor: Double? = nil
    var rachaGanadora: Int = 0
    var rachaPerdedora: Int = 0
    var caidaMaxima: Double = 0
    var caidaMaximaPct: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        neto = seguroOpt(c, .neto)
        winRate = seguroOpt(c, .winRate)
        profitFactor = seguroOpt(c, .profitFactor)
        kipScore = seguroOpt(c, .kipScore)
        tradesCerrados = seguro(c, .tradesCerradosKT, 0)
        tradesMes = seguro(c, .tradesMes, 0)
        promedioGanancia = seguro(c, .promedioGanancia, 0)
        gananciaPromPct = seguroOpt(c, .gananciaPromPct)
        promedioPerdida = seguro(c, .promedioPerdida, 0)
        promedioR = seguroOpt(c, .promedioR)
        mejor = seguroOpt(c, .mejor)
        peor = seguroOpt(c, .peor)
        rachaGanadora = seguro(c, .rachaGanadora, 0)
        rachaPerdedora = seguro(c, .rachaPerdedora, 0)
        caidaMaxima = seguro(c, .caidaMaxima, 0)
        caidaMaximaPct = seguro(c, .caidaMaximaPct, 0)
    }
}

struct DonaDto: Decodable, Identifiable {
    var key: String = ""
    var label: String = ""
    var display: String = "" // [S] ya formateado
    var share: Double = 0
    var tono: String = "verde"
    var parteVerde: Double? = nil
    var parteRoja: Double? = nil
    var id: String { key }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        key = seguro(c, .key, "")
        label = seguro(c, .label, "")
        display = seguro(c, .display, "")
        share = seguro(c, .share, 0)
        tono = seguro(c, .tono, "verde")
        parteVerde = seguroOpt(c, .parteVerde)
        parteRoja = seguroOpt(c, .parteRoja)
    }
}

struct MetricaDonaDto: Decodable {
    var clave: String = ""
    var etiqueta: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        clave = seguro(c, .clave, "")
        etiqueta = seguro(c, .etiqueta, "")
    }
}

struct PuntoCurvaDto: Decodable {
    var date: String = "" // [S] crudo: se pinta tal cual
    var value: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        date = seguro(c, .diaFecha, "")
        value = seguro(c, .valorPunto, 0)
    }
}

struct SesgoSemanaDto: Decodable {
    var trades: Int = 0
    var net: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        trades = seguro(c, .trades, 0)
        net = seguro(c, .net, 0)
    }
    init(trades: Int, net: Double) { self.trades = trades; self.net = net }
}

struct EspejoDto: Decodable {
    var estado: String = "verde"
    var netoHoy: Double = 0
    var limitePerdidaDiaria: Double? = nil
    var consumoLimitePct: Int? = nil
    var senialRevanchaHoy: String? = nil
    var fueraDelPlan: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var revancha: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var siguiendoPlan: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        estado = seguro(c, .estadoStatus, "verde")
        netoHoy = seguro(c, .netoHoy, 0)
        limitePerdidaDiaria = seguroOpt(c, .limitePerdidaDiaria)
        consumoLimitePct = seguroOpt(c, .consumoLimitePct)
        senialRevanchaHoy = seguroOpt(c, .senialRevanchaHoy)
        fueraDelPlan = seguro(c, .fueraDelPlan, SesgoSemanaDto(trades: 0, net: 0))
        revancha = seguro(c, .revancha, SesgoSemanaDto(trades: 0, net: 0))
        siguiendoPlan = seguro(c, .siguiendoPlan, SesgoSemanaDto(trades: 0, net: 0))
    }
}

struct PanelDto: Decodable {
    var brokerAlerta: AlertaBrokerDto? = nil
    var avisosBilling: [AvisoBillingDto] = []
    var tarjetas: [String] = ["grafica", "donas", "espejo", "ultimos", "semana", "caida", "posiciones"]
    var barra: [String] = ["panel", "diario", "estadisticas", "coach", "plan"]
    var rango: String = "at"
    var desde: String? = nil
    var hasta: String? = nil
    var resumen: ResumenDto
    var donas: [DonaDto] = []
    var metricasDonas: [MetricaDonaDto] = []
    var donasElegidas: [String] = []
    var drawdown: [PuntoCurvaDto] = []
    var curva: [PuntoCurvaDto] = []
    var ultimosTrades: [TradeDto] = []
    var posicionesAbiertas: [TradeDto] = []
    var tieneConexionBroker: Bool = false
    var verificado: Bool = false
    var espejo: EspejoDto? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        brokerAlerta = seguroOpt(c, .brokerAlerta)
        avisosBilling = seguro(c, .avisosBilling, [])
        tarjetas = seguro(c, .tarjetas, ["grafica", "donas", "espejo", "ultimos", "semana", "caida", "posiciones"])
        barra = seguro(c, .barra, ["panel", "diario", "estadisticas", "coach", "plan"])
        rango = seguro(c, .rango, "at")
        desde = seguroOpt(c, .desde)
        hasta = seguroOpt(c, .hasta)
        resumen = try c.decode(ResumenDto.self, forKey: .resumen)
        donas = seguro(c, .donas, [])
        metricasDonas = seguro(c, .metricasDonas, [])
        donasElegidas = seguro(c, .donasElegidas, [])
        drawdown = seguro(c, .drawdown, [])
        curva = seguro(c, .curva, [])
        ultimosTrades = seguro(c, .ultimosTrades, [])
        posicionesAbiertas = seguro(c, .posicionesAbiertas, [])
        tieneConexionBroker = seguro(c, .tieneConexionBroker, false)
        verificado = seguro(c, .verificado, false)
        espejo = seguroOpt(c, .espejo)
    }
}

// MARK: - Trades y Diario

struct TradeDto: Decodable, Identifiable {
    var id: Int = 0
    var simbolo: String = ""
    var ticker: String = ""
    var tipo: String = ""
    var esOpcion: Bool = false
    var strike: Double? = nil
    var lado: String? = nil
    var cantidad: Int = 0
    var precioApertura: Double? = nil
    var precioCierre: Double? = nil
    var neto: Double? = nil
    var ganador: Bool? = nil
    var pnlPct: Double? = nil
    var fees: Double? = nil
    var estado: String = ""
    var emocion: String? = nil
    var abiertoEn: String? = nil
    var cerradoEn: String? = nil
    var grupo: String? = nil
    var grupoPatas: Int = 0
    var grupoNeto: Double? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = seguro(c, .id, 0)
        simbolo = seguro(c, .simbolo, "")
        ticker = seguro(c, .ticker, "")
        tipo = seguro(c, .tipoK, "")
        esOpcion = seguro(c, .esOpcion, false)
        strike = seguroOpt(c, .strike)
        lado = seguroOpt(c, .lado)
        cantidad = seguro(c, .cantidadKT, 0)
        precioApertura = seguroOpt(c, .precioApertura)
        precioCierre = seguroOpt(c, .precioCierre)
        neto = seguroOpt(c, .neto)
        ganador = seguroOpt(c, .ganador)
        pnlPct = seguroOpt(c, .pnlPct)
        fees = seguroOpt(c, .fees)
        estado = seguro(c, .estadoUnico, "")
        emocion = seguroOpt(c, .emocion)
        abiertoEn = seguroOpt(c, .abiertoEn)
        cerradoEn = seguroOpt(c, .cerradoEn)
        grupo = seguroOpt(c, .grupo)
        grupoPatas = seguro(c, .grupoPatas, 0)
        grupoNeto = seguroOpt(c, .grupoNeto)
    }
}

struct ResumenDiarioDto: Decodable {
    var neto: Double = 0
    var cantidad: Int = 0
    var ganadores: Int = 0
    var total: Int = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        neto = seguro(c, .neto, 0)
        cantidad = seguro(c, .cantidadResumenK, 0)
        ganadores = seguro(c, .ganadores, 0)
        total = seguro(c, .totalK, 0)
    }
}

struct CuentaDto: Decodable, Identifiable {
    var id: Int = 0
    var nombre: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = seguro(c, .id, 0)
        nombre = seguro(c, .name, "")
    }
}

struct DiarioDto: Decodable {
    var trades: [TradeDto] = []
    var resumen: ResumenDiarioDto
    var tickers: [String] = []
    var cuentas: [CuentaDto] = []
    var estrategiasPlan: [String] = []
    var emociones: [String] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        trades = seguro(c, .trades, [])
        resumen = seguro(c, .resumen, ResumenDiarioVacio.hacer())
        tickers = seguro(c, .tickers, [])
        cuentas = seguro(c, .cuentas, [])
        estrategiasPlan = seguro(c, .estrategiasPlan, [])
        emociones = seguro(c, .emociones, [])
    }

    /// Adaptador para el dialogo de filtros de Estadisticas: sus
    /// listas (tickers/cuentas/emociones) salen del DTO de estadisticas.
    init(desdeStats datos: EstadisticasDto) {
        trades = []
        resumen = ResumenDiarioVacio.hacer()
        tickers = datos.tickers
        cuentas = datos.cuentas
        estrategiasPlan = []
        emociones = datos.emociones
    }
}

enum ResumenDiarioVacio {
    static func hacer() -> ResumenDiarioDto {
        try! JSONDecoder().decode(ResumenDiarioDto.self, from: Data("{}".utf8))
    }
}

struct ChipTickerDto: Decodable {
    var ticker: String = ""
    var trades: Int = 0
    var net: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        ticker = seguro(c, .ticker, "")
        trades = seguro(c, .trades, 0)
        net = seguro(c, .net, 0)
    }
}

struct FilaDetalleDto: Decodable {
    var label: String = ""
    var all: String? = nil // [S]
    var won: String? = nil // [S]
    var lost: String? = nil // [S]
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        label = seguro(c, .label, "")
        all = seguroOpt(c, .all)
        won = seguroOpt(c, .won)
        lost = seguroOpt(c, .lost)
    }
}

/// bestWorst trae OBJETOS {ticker, detail}, no textos (trampa §5.1).
struct MejorPeorDto: Decodable {
    var ticker: String = ""
    var detail: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        ticker = seguro(c, .ticker, "")
        detail = seguro(c, .detalle, "")
    }
}

struct FilaMejorPeorDto: Decodable {
    var label: String = ""
    var won: MejorPeorDto? = nil
    var lost: MejorPeorDto? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        label = seguro(c, .label, "")
        won = seguroOpt(c, .won)
        lost = seguroOpt(c, .lost)
    }
}

struct DetalleMesDto: Decodable {
    var gainLoss: FilaDetalleDto
    var longShort: FilaDetalleDto
    var timing: FilaDetalleDto
    var bestWorst: FilaMejorPeorDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        gainLoss = seguro(c, .gainLoss, FilaDetalleVacio.hacer())
        longShort = seguro(c, .longShort, FilaDetalleVacio.hacer())
        timing = seguro(c, .timing, FilaDetalleVacio.hacer())
        bestWorst = seguro(c, .bestWorst, FilaMejorPeorVacio.hacer())
    }
}

enum FilaDetalleVacio {
    static func hacer() -> FilaDetalleDto { try! JSONDecoder().decode(FilaDetalleDto.self, from: Data("{}".utf8)) }
}
enum FilaMejorPeorVacio {
    static func hacer() -> FilaMejorPeorDto { try! JSONDecoder().decode(FilaMejorPeorDto.self, from: Data("{}".utf8)) }
}

struct ResumenMensualDto: Decodable {
    var neto: Double? = nil
    var gananciaBruta: Double? = nil
    var perdidaBruta: Double? = nil
    var ganadores: Int? = nil
    var promedioGananciaPct: Double? = nil
    var winRate: Int? = nil
    var profitFactor: Double? = nil
    var promedioR: Double? = nil
    var promedioGanancia: Double? = nil
    var promedioPerdida: Double? = nil
    var mejor: Double? = nil
    var peor: Double? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        neto = seguroOpt(c, .neto)
        gananciaBruta = seguroOpt(c, .gananciaBruta)
        perdidaBruta = seguroOpt(c, .perdidaBruta)
        ganadores = seguroOpt(c, .ganadores)
        promedioGananciaPct = seguroOpt(c, .promedioGananciaPct)
        winRate = seguroOpt(c, .winRate)
        profitFactor = seguroOpt(c, .profitFactor)
        promedioR = seguroOpt(c, .promedioR)
        promedioGanancia = seguroOpt(c, .promedioGanancia)
        promedioPerdida = seguroOpt(c, .promedioPerdida)
        mejor = seguroOpt(c, .mejor)
        peor = seguroOpt(c, .peor)
    }
}

struct MensualDto: Decodable {
    var mes: String = ""
    var anterior: String = ""
    var siguiente: String = ""
    var ticker: String? = nil
    var chips: [ChipTickerDto] = []
    var curva: [PuntoCurvaDto] = []
    var neto: Double = 0
    var cantidad: Int = 0
    var cerrados: Int = 0
    var winRate: Int? = nil
    var resumen: ResumenMensualDto
    var detalle: DetalleMesDto
    var donas: [DonaDto] = []
    var trades: [TradeDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        mes = seguro(c, .mes, "")
        anterior = seguro(c, .anterior, "")
        siguiente = seguro(c, .siguiente, "")
        ticker = seguroOpt(c, .ticker)
        chips = seguro(c, .chips, [])
        curva = seguro(c, .curva, [])
        neto = seguro(c, .neto, 0)
        cantidad = seguro(c, .cantidadResumenK, 0)
        cerrados = seguro(c, .cerrados, 0)
        winRate = seguroOpt(c, .winRate)
        resumen = seguro(c, .resumen, ResumenMensualVacio.hacer())
        detalle = seguro(c, .detalle, DetalleMesVacio.hacer())
        donas = seguro(c, .donas, [])
        trades = seguro(c, .trades, [])
    }
}

enum ResumenMensualVacio {
    static func hacer() -> ResumenMensualDto { try! JSONDecoder().decode(ResumenMensualDto.self, from: Data("{}".utf8)) }
}
enum DetalleMesVacio {
    static func hacer() -> DetalleMesDto { try! JSONDecoder().decode(DetalleMesDto.self, from: Data("{}".utf8)) }
}

struct DiaCalendarioDto: Decodable {
    var net: Double = 0
    var trades: Int = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        net = seguro(c, .net, 0)
        trades = seguro(c, .trades, 0)
    }
}

struct DiaMapaDto: Decodable {
    var fecha: String = ""
    var neto: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        fecha = seguro(c, .fecha, "")
        neto = seguro(c, .neto, 0)
    }
}

struct CalendarioDto: Decodable {
    var mes: String = ""
    var anterior: String = ""
    var siguiente: String = ""
    var porDia: [String: DiaCalendarioDto] = [:]
    var mapa: [DiaMapaDto] = []
    var limiteDiario: Double? = nil
    var ganancia: Double = 0
    var perdida: Double = 0 // POSITIVA: la UI pinta dinero(-perdida)
    var neto: Double = 0
    var totalTrades: Int = 0
    var trades: [TradeDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        mes = seguro(c, .mes, "")
        anterior = seguro(c, .anterior, "")
        siguiente = seguro(c, .siguiente, "")
        porDia = seguro(c, .porDia, [:])
        mapa = seguro(c, .mapa, [])
        limiteDiario = seguroOpt(c, .limiteDiario)
        ganancia = seguro(c, .ganancia, 0)
        perdida = seguro(c, .perdida, 0)
        neto = seguro(c, .neto, 0)
        totalTrades = seguro(c, .totalTrades, 0)
        trades = seguro(c, .trades, [])
    }
}

// MARK: - Detalle del trade

struct PataGrupoDto: Decodable, Identifiable {
    var id: Int = 0
    var contrato: String? = nil
    var tipo: String? = nil
    var strike: Double? = nil
    var lado: String? = nil
    var cantidad: Int = 0
    var neto: Double? = nil
    var estado: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = seguro(c, .id, 0)
        contrato = seguroOpt(c, .contrato)
        tipo = seguroOpt(c, .tipoK)
        strike = seguroOpt(c, .strike)
        lado = seguroOpt(c, .lado)
        cantidad = seguro(c, .cantidadKT, 0)
        neto = seguroOpt(c, .neto)
        estado = seguroOpt(c, .estadoUnico)
    }
}

struct TradeDetalleDto: Decodable {
    var base: TradeDto
    var contrato: String? = nil
    var vencimiento: String? = nil // crudo: se pinta tal cual
    var bruto: Double? = nil
    var rMultiple: Double? = nil
    var cuenta: String? = nil
    var origen: String? = nil
    var emocionDetectada: String? = nil
    var motivoSalida: String? = nil
    var notas: String? = nil
    var checklist: [String: Bool] = [:]
    var estrategia: String? = nil
    var patronEntrada: String? = nil
    var stopPlanificado: Double? = nil
    var objetivoPlanificado: Double? = nil
    var riesgo: Double? = nil
    var siguioPlan: Bool? = nil
    var errorPrincipal: String? = nil
    var tieneCaptura: Bool = false
    var transcripcion: String? = nil
    var tieneAudio: Bool = false
    var grupoPatasDetalle: [PataGrupoDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        base = try TradeDto(from: decoder)
        let c = try decoder.container(keyedBy: Keys.self)
        contrato = seguroOpt(c, .contrato)
        vencimiento = seguroOpt(c, .vencimiento)
        bruto = seguroOpt(c, .bruto)
        rMultiple = seguroOpt(c, .rMultiple)
        cuenta = seguroOpt(c, .cuenta)
        origen = seguroOpt(c, .origen)
        emocionDetectada = seguroOpt(c, .emocionDetectada)
        motivoSalida = seguroOpt(c, .motivoSalida)
        notas = seguroOpt(c, .notas)
        checklist = seguro(c, .checklist, [:])
        estrategia = seguroOpt(c, .estrategia)
        patronEntrada = seguroOpt(c, .patronEntrada)
        stopPlanificado = seguroOpt(c, .stopPlanificado)
        objetivoPlanificado = seguroOpt(c, .objetivoPlanificado)
        riesgo = seguroOpt(c, .riesgo)
        siguioPlan = seguroOpt(c, .siguioPlan)
        errorPrincipal = seguroOpt(c, .errorPrincipal)
        tieneCaptura = seguro(c, .tieneCaptura, false)
        transcripcion = seguroOpt(c, .transcripcion)
        tieneAudio = seguro(c, .tieneAudio, false)
        grupoPatasDetalle = seguro(c, .grupoPatasDetalle, [])
    }
}

struct ChecklistItemDto: Decodable, Identifiable {
    var key: String = ""
    var label: String = ""
    var id: String { key }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        key = seguro(c, .key, "")
        label = seguro(c, .label, "")
    }
}

struct OpcionesTradeDto: Decodable {
    var emociones: [String] = []
    var estrategias: [String] = []
    var patrones: [String] = []
    var motivosSalida: [String] = []
    var errores: [String] = []
    var checklist: [ChecklistItemDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        emociones = seguro(c, .emociones, [])
        estrategias = seguro(c, .estrategias, [])
        patrones = seguro(c, .patrones, [])
        motivosSalida = seguro(c, .motivosSalida, [])
        errores = seguro(c, .errores, [])
        checklist = seguro(c, .checklist, [])
    }
}

struct RespuestaTradeDetalle: Decodable {
    var trade: TradeDetalleDto
    var opciones: OpcionesTradeDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        trade = try c.decode(TradeDetalleDto.self, forKey: .trade)
        opciones = seguro(c, .opciones, OpcionesTradeVacio.hacer())
    }
}

enum OpcionesTradeVacio {
    static func hacer() -> OpcionesTradeDto { try! JSONDecoder().decode(OpcionesTradeDto.self, from: Data("{}".utf8)) }
}

// MARK: - Estadisticas

struct ResumenStatsDto: Decodable {
    var cantidad: Int = 0
    var neto: Double = 0
    var winRate: Int? = nil
    var profitFactor: Double? = nil
    var promedioR: Double? = nil
    var promedioGanancia: Double = 0
    var promedioPerdida: Double = 0
    var mejor: Double? = nil
    var peor: Double? = nil
    var rachaGanadora: Int = 0
    var rachaPerdedora: Int = 0
    var puntoEquilibrio: Int? = nil // existe; la UI no lo pinta
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        cantidad = seguro(c, .cantidadResumenK, 0)
        neto = seguro(c, .neto, 0)
        winRate = seguroOpt(c, .winRate)
        profitFactor = seguroOpt(c, .profitFactor)
        promedioR = seguroOpt(c, .promedioR)
        promedioGanancia = seguro(c, .promedioGanancia, 0)
        promedioPerdida = seguro(c, .promedioPerdida, 0)
        mejor = seguroOpt(c, .mejor)
        peor = seguroOpt(c, .peor)
        rachaGanadora = seguro(c, .rachaGanadora, 0)
        rachaPerdedora = seguro(c, .rachaPerdedora, 0)
        puntoEquilibrio = seguroOpt(c, .puntoEquilibrio)
    }
}

struct GrupoStatsDto: Decodable {
    var ticker: String? = nil
    var estrategia: String? = nil
    var etiqueta: String? = nil
    var trades: Int = 0
    var net: Double = 0
    var winRate: Int = 0
    var nombreVisible: String { ticker ?? estrategia ?? etiqueta ?? "—" }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        ticker = seguroOpt(c, .ticker)
        estrategia = seguroOpt(c, .estrategia)
        etiqueta = seguroOpt(c, .etiqueta)
        trades = seguro(c, .trades, 0)
        net = seguro(c, .net, 0)
        winRate = seguro(c, .winRate, 0)
    }
}

struct EmocionStatsDto: Decodable {
    var emocion: String = ""
    var trades: Int = 0
    var net: Double = 0
    var winRate: Int = 0
    var detectadas: Int = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        emocion = seguro(c, .emocion, "")
        trades = seguro(c, .trades, 0)
        net = seguro(c, .net, 0)
        winRate = seguro(c, .winRate, 0)
        detectadas = seguro(c, .detectadas, 0)
    }
}

struct BarraDto: Decodable {
    var label: String = ""
    var value: Double = 0
    var display: String = "" // [S]
    var detalle: String = "" // [S]
    init(label: String, value: Double, display: String, detalle: String) {
        self.label = label; self.value = value; self.display = display; self.detalle = detalle
    }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        label = seguro(c, .label, "")
        value = seguro(c, .valorPunto, 0)
        display = seguro(c, .display, "")
        detalle = seguro(c, .detalle, "")
    }
}

struct GraficasDto: Decodable {
    var porDia: [BarraDto] = []
    var porAdherencia: [BarraDto] = []
    var porEmocion: [BarraDto] = []
    var porPatron: [BarraDto] = []
    var porTicker: [BarraDto] = []
    var porDiaSemana: [BarraDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        porDia = seguro(c, .porDia, [])
        porAdherencia = seguro(c, .porAdherencia, [])
        porEmocion = seguro(c, .porEmocion, [])
        porPatron = seguro(c, .porPatron, [])
        porTicker = seguro(c, .porTicker, [])
        porDiaSemana = seguro(c, .porDiaSemana, [])
    }
}

struct SesgoDto: Decodable {
    var label: String = ""
    var trades: Int = 0
    var net: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        label = seguro(c, .label, "")
        trades = seguro(c, .trades, 0)
        net = seguro(c, .net, 0)
    }
}

struct SenalDto: Decodable {
    var type: String = ""
    var text: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        type = seguro(c, .tipoK, "")
        text = seguro(c, .textoSenal, "")
    }
}

/// OJO: tradesToday / netToday llegan en camelCase en el JSON.
struct SesgosHoyDto: Decodable {
    var status: String = "verde"
    var signals: [SenalDto] = []
    var tradesToday: Int = 0
    var netToday: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        status = seguro(c, .estadoStatus, "verde")
        signals = seguro(c, .signals, [])
        tradesToday = seguro(c, .tradesToday, 0)
        netToday = seguro(c, .netToday, 0)
    }
}

struct EstadisticasDto: Decodable {
    var rango: String = "at"
    var resumen: ResumenStatsDto
    var kipScore: Int? = nil
    var curva: [PuntoCurvaDto] = []
    var detalle: DetalleMesDto
    var porTicker: [GrupoStatsDto] = []
    var porEstrategia: [GrupoStatsDto] = []
    var porPlan: [GrupoStatsDto] = []
    var porEmocion: [EmocionStatsDto] = []
    var graficas: GraficasDto
    var hallazgos: [String] = [] // [S]
    var sesgosSemana: [SesgoDto] = []
    var sesgosHoy: SesgosHoyDto
    var tickers: [String] = []
    var cuentas: [CuentaDto] = []
    var emociones: [String] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        rango = seguro(c, .rango, "at")
        resumen = seguro(c, .resumen, ResumenStatsVacio.hacer())
        kipScore = seguroOpt(c, .kipScore)
        curva = seguro(c, .curva, [])
        detalle = seguro(c, .detalle, DetalleMesVacio.hacer())
        porTicker = seguro(c, .porTicker, [])
        porEstrategia = seguro(c, .porEstrategia, [])
        porPlan = seguro(c, .porPlan, [])
        porEmocion = seguro(c, .porEmocion, [])
        graficas = seguro(c, .graficas, GraficasVacio.hacer())
        hallazgos = seguro(c, .hallazgos, [])
        sesgosSemana = seguro(c, .sesgosSemana, [])
        sesgosHoy = seguro(c, .sesgosHoy, SesgosHoyVacio.hacer())
        tickers = seguro(c, .tickers, [])
        cuentas = seguro(c, .cuentas, [])
        emociones = seguro(c, .emociones, [])
    }
}

enum ResumenStatsVacio {
    static func hacer() -> ResumenStatsDto { try! JSONDecoder().decode(ResumenStatsDto.self, from: Data("{}".utf8)) }
}
enum GraficasVacio {
    static func hacer() -> GraficasDto { try! JSONDecoder().decode(GraficasDto.self, from: Data("{}".utf8)) }
}
enum SesgosHoyVacio {
    static func hacer() -> SesgosHoyDto { try! JSONDecoder().decode(SesgosHoyDto.self, from: Data("{}".utf8)) }
}

// MARK: - Plan, Journal, Coach

struct ChecklistPlanDto: Decodable, Identifiable {
    var key: String = ""
    var label: String = ""
    var core: Bool = false
    var id: String { key.isEmpty ? label : key }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        key = seguro(c, .key, "")
        label = seguro(c, .label, "")
        core = seguro(c, .core, false)
    }
    init(key: String, label: String, core: Bool) { self.key = key; self.label = label; self.core = core }
}

struct PlanDto: Decodable {
    var estrategias: [String] = []
    var patrones: [String] = []
    var motivosSalida: [String] = []
    var errores: [String] = []
    var checklist: [ChecklistPlanDto] = []
    var checklistNucleo: [String] = []
    var limiteSuave: Int = 3
    var limiteDuro: Int = 5
    var interruptorRacha: Int = 3
    var stopPct: Double? = 30.0
    var limitePerdidaDiaria: Double? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        estrategias = seguro(c, .estrategias, [])
        patrones = seguro(c, .patrones, [])
        motivosSalida = seguro(c, .motivosSalida, [])
        errores = seguro(c, .errores, [])
        checklist = seguro(c, .checklist, [])
        checklistNucleo = seguro(c, .checklistNucleo, [])
        limiteSuave = seguro(c, .limiteSuave, 3)
        limiteDuro = seguro(c, .limiteDuro, 5)
        interruptorRacha = seguro(c, .interruptorRacha, 3)
        stopPct = seguroOpt(c, .stopPct) ?? 30.0
        limitePerdidaDiaria = seguroOpt(c, .limitePerdidaDiaria)
    }
}

struct PlantillaDto: Decodable, Identifiable {
    var clave: String = ""
    var nombre: String = ""
    var id: String { clave }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        clave = seguro(c, .clave, "")
        nombre = seguro(c, .name, "")
    }
}

struct RespuestaPlan: Decodable {
    var plan: PlanDto
    var plantillas: [PlantillaDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        plan = seguro(c, .plan, PlanVacio.hacer())
        plantillas = seguro(c, .plantillas, [])
    }
}

enum PlanVacio {
    static func hacer() -> PlanDto { try! JSONDecoder().decode(PlanDto.self, from: Data("{}".utf8)) }
}

struct RespuestaPlanGuardado: Decodable {
    var message: String = ""
    var plan: PlanDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        plan = seguro(c, .plan, PlanVacio.hacer())
    }
}

struct JournalEntradaDto: Decodable {
    var fecha: String = ""
    var reflexion: String? = nil
    var transcripcion: String? = nil
    var emocionDetectada: String? = nil
    var tieneAudio: Bool = false
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        fecha = seguro(c, .fecha, "")
        reflexion = seguroOpt(c, .reflexion)
        transcripcion = seguroOpt(c, .transcripcion)
        emocionDetectada = seguroOpt(c, .emocionDetectada)
        tieneAudio = seguro(c, .tieneAudio, false)
    }
}

struct JournalDto: Decodable {
    var fecha: String = ""
    var entrada: JournalEntradaDto? = nil
    var historial: [JournalEntradaDto] = []
    var tradesDelDia: [TradeDto] = []
    var tradesCerrados: [TradeDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        fecha = seguro(c, .fecha, "")
        entrada = seguroOpt(c, .entrada)
        historial = seguro(c, .historial, [])
        tradesDelDia = seguro(c, .tradesDia, [])
        tradesCerrados = seguro(c, .tradesCerradosDia, [])
    }
}

struct RespuestaJournalGuardado: Decodable {
    var message: String = ""
    var entrada: JournalEntradaDto? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        entrada = seguroOpt(c, .entrada)
    }
}

/// La semana del coach llega con claves EN INGLES.
struct SemanaCoachDto: Decodable {
    var revenge: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var fear: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var fomo: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var deviated: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var followed: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    var total: SesgoSemanaDto = SesgoSemanaDto(trades: 0, net: 0)
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        revenge = seguro(c, .revancha, SesgoSemanaDto(trades: 0, net: 0))
        fear = seguro(c, .fear, SesgoSemanaDto(trades: 0, net: 0))
        fomo = seguro(c, .fomo, SesgoSemanaDto(trades: 0, net: 0))
        deviated = seguro(c, .deviated, SesgoSemanaDto(trades: 0, net: 0))
        followed = seguro(c, .followed, SesgoSemanaDto(trades: 0, net: 0))
        total = seguro(c, .totalK, SesgoSemanaDto(trades: 0, net: 0))
    }
}

struct AnalisisDto: Decodable {
    var contenido: String = ""
    var fuente: String = "rules"
    var creadoEn: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        contenido = seguro(c, .contenido, "")
        fuente = seguro(c, .fuente, "rules")
        creadoEn = seguroOpt(c, .creadoEn)
    }
}

struct MapaEmocionesDto: Decodable {
    var dias: [String] = []
    var filas: [String: [String: Double?]] = [:]
    var maxAbs: Double = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        dias = seguro(c, .dias, [])
        filas = seguro(c, .filasKT, [:])
        maxAbs = seguro(c, .maxAbs, 0)
    }
}

struct CoachDto: Decodable {
    var hoy: SesgosHoyDto
    var semana: SemanaCoachDto
    var ultimoAnalisis: AnalisisDto? = nil
    var historial: [AnalisisDto] = []
    var iaActiva: Bool = false
    var mapaEmociones: MapaEmocionesDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        hoy = seguro(c, .hoy, SesgosHoyVacio.hacer())
        semana = seguro(c, .semana, SemanaCoachVacio.hacer())
        ultimoAnalisis = seguroOpt(c, .ultimoAnalisis)
        historial = seguro(c, .historial, [])
        iaActiva = seguro(c, .iaActiva, false)
        mapaEmociones = seguro(c, .mapaEmociones, MapaEmocionesVacio.hacer())
    }
}

enum SemanaCoachVacio {
    static func hacer() -> SemanaCoachDto { try! JSONDecoder().decode(SemanaCoachDto.self, from: Data("{}".utf8)) }
}
enum MapaEmocionesVacio {
    static func hacer() -> MapaEmocionesDto { try! JSONDecoder().decode(MapaEmocionesDto.self, from: Data("{}".utf8)) }
}

struct RespuestaAnalisis: Decodable {
    var message: String = ""
    var analisis: AnalisisDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        analisis = seguro(c, .analisis, AnalisisVacio.hacer())
    }
}

enum AnalisisVacio {
    static func hacer() -> AnalisisDto { try! JSONDecoder().decode(AnalisisDto.self, from: Data("{}".utf8)) }
}

// MARK: - Broker, importar, membresia

struct CuentaBrokerDto: Decodable, Identifiable {
    var id: Int = 0
    var nombre: String? = nil
    var numero: String? = nil // solo la cola: se pinta «••••{numero}»
    var broker: String? = nil
    var moneda: String? = nil
    var ultimoSync: String? = nil
    var esCsv: Bool = false
    var salud: String? = nil
    var saludTexto: String? = nil
    var saludDetalle: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = seguro(c, .id, 0)
        nombre = seguroOpt(c, .name)
        numero = seguroOpt(c, .numero)
        broker = seguroOpt(c, .broker)
        moneda = seguroOpt(c, .moneda)
        ultimoSync = seguroOpt(c, .ultimoSync)
        esCsv = seguro(c, .esCsv, false)
        salud = seguroOpt(c, .salud)
        saludTexto = seguroOpt(c, .saludTexto)
        saludDetalle = seguroOpt(c, .saludDetalle)
    }
}

struct ConexionDto: Decodable, Identifiable {
    var id: Int = 0
    var broker: String? = nil
    var estado: String = "active"
    var cuentas: [CuentaBrokerDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = seguro(c, .id, 0)
        broker = seguroOpt(c, .broker)
        estado = seguro(c, .estadoUnico, "active")
        cuentas = seguro(c, .cuentas, [])
    }
}

struct BrokerDto: Decodable {
    var configurado: Bool = false
    var verificado: Bool = false
    var conexiones: [ConexionDto] = []
    var cuentasSueltas: [CuentaBrokerDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        configurado = seguro(c, .configurado, false)
        verificado = seguro(c, .verificado, false)
        conexiones = seguro(c, .conexiones, [])
        cuentasSueltas = seguro(c, .cuentasSueltas, [])
    }
}

/// Sobre dual de broker/membresia: url O message (nunca asumir URL).
struct EnlaceDto: Decodable {
    var url: String? = nil
    var message: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        url = seguroOpt(c, .url)
        message = seguroOpt(c, .message)
    }
}

struct ColumnaCsvDto: Decodable {
    var index: Int = 0
    var name: String = ""
    var suggested: String? = nil
    var samples: [String] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        index = seguro(c, .index, 0)
        name = seguro(c, .name, "")
        suggested = seguroOpt(c, .suggested)
        samples = seguro(c, .samples, [])
    }
}

struct CampoCsvDto: Decodable, Identifiable {
    var clave: String = ""
    var etiqueta: String = ""
    var obligatorio: Bool = false
    var id: String { clave }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        clave = seguro(c, .clave, "")
        etiqueta = seguro(c, .etiqueta, "")
        obligatorio = seguro(c, .obligatorio, false)
    }
}

struct ImportarSubidaDto: Decodable {
    var token: String = ""
    var columnas: [ColumnaCsvDto] = []
    var filas: Int = 0
    var campos: [CampoCsvDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        token = seguro(c, .token, "")
        columnas = seguro(c, .columnas, [])
        filas = seguro(c, .filasImportar, 0)
        campos = seguro(c, .campos, [])
    }
}

struct FilaPreviaDto: Decodable {
    var n: Int = 0
    var status: String = ""
    var detail: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        n = seguro(c, .n, 0)
        status = seguro(c, .estadoUnico, "")
        detail = seguro(c, .detail, "")
    }
}

struct VistaPreviaDto: Decodable {
    var filas: [FilaPreviaDto] = []
    var validas: Int = 0
    var duplicadas: Int = 0
    var conError: Int = 0
    var total: Int = 0
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        filas = seguro(c, .filasImportar, [])
        validas = seguro(c, .validas, 0)
        duplicadas = seguro(c, .duplicadas, 0)
        conError = seguro(c, .conError, 0)
        total = seguro(c, .totalK, 0)
    }
}

struct ResultadoImportarDto: Decodable {
    var importados: Int = 0
    var duplicados: Int = 0
    var errores: [String] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        importados = seguro(c, .importados, 0)
        duplicados = seguro(c, .duplicadas, 0)
        errores = seguro(c, .errores, [])
    }
}

struct RespuestaImportarResultado: Decodable {
    var message: String = ""
    var resultado: ResultadoImportarDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        resultado = seguro(c, .resultado, ResultadoImportarVacio.hacer())
    }
}

enum ResultadoImportarVacio {
    static func hacer() -> ResultadoImportarDto { try! JSONDecoder().decode(ResultadoImportarDto.self, from: Data("{}".utf8)) }
}

struct MembresiaDto: Decodable {
    var modo: String = "beta"
    var cobroActivo: Bool = false
    var estado: String = "founder"
    var exento: Bool = false
    var precio: String = "$14.99/mes" // [S]
    var trialTermina: String? = nil
    var periodoTermina: String? = nil
    var intervalo: String? = nil
    var canceladaAlFin: Bool = false
    var avisos: [AvisoBillingDto] = []
    var tieneSuscripcion: Bool = false
    var puedeCheckout: Bool = false
    var puedePortal: Bool = false
    var puedeCancelar: Bool = false
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        modo = seguro(c, .modo, "beta")
        cobroActivo = seguro(c, .cobroActivo, false)
        estado = seguro(c, .estadoUnico, "founder")
        exento = seguro(c, .exento, false)
        precio = seguro(c, .precio, "$14.99/mes")
        trialTermina = seguroOpt(c, .trialTermina)
        periodoTermina = seguroOpt(c, .periodoTermina)
        intervalo = seguroOpt(c, .intervalo)
        canceladaAlFin = seguro(c, .canceladaAlFin, false)
        avisos = seguro(c, .avisos, [])
        tieneSuscripcion = seguro(c, .tieneSuscripcion, false)
        puedeCheckout = seguro(c, .puedeCheckout, false)
        puedePortal = seguro(c, .puedePortal, false)
        puedeCancelar = seguro(c, .puedeCancelar, false)
    }
}

// MARK: - Ajustes e invitaciones

/// El usuario de Ajustes: id Int64 (distinto del UsuarioDto).
struct UsuarioAjustesDto: Decodable {
    var id: Int64 = 0
    var name: String = ""
    var nickname: String? = nil
    var email: String = ""
    var avatarUrl: String? = nil
    var isAdmin: Bool = false
    var verificado: Bool = false
    var tema: String? = nil
    var timezone: String? = nil
    var city: String? = nil
    var country: String? = nil
    var accountSize: Double? = nil
    var correoVerificado: Bool = true
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let idInt: Int = seguro(c, .id, 0)
        id = Int64(idInt)
        name = seguro(c, .name, "")
        nickname = seguroOpt(c, .nickname)
        email = seguro(c, .email, "")
        avatarUrl = seguroOpt(c, .avatarUrl)
        isAdmin = seguro(c, .isAdmin, false)
        verificado = seguro(c, .verificado, false)
        tema = seguroOpt(c, .tema)
        timezone = seguroOpt(c, .timezone)
        city = seguroOpt(c, .city)
        country = seguroOpt(c, .country)
        accountSize = seguroOpt(c, .accountSize)
        correoVerificado = seguro(c, .correoVerificado, true)
    }
}

struct RespuestaAjustes: Decodable {
    var user: UsuarioAjustesDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        user = seguro(c, .user, UsuarioAjustesVacio.hacer())
    }
}

enum UsuarioAjustesVacio {
    static func hacer() -> UsuarioAjustesDto { try! JSONDecoder().decode(UsuarioAjustesDto.self, from: Data("{}".utf8)) }
}

struct RespuestaPerfil: Decodable {
    var message: String = ""
    var correoCambio: Bool = false
    var user: UsuarioDto
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        correoCambio = seguro(c, .correoCambio, false)
        user = seguro(c, .user, UsuarioDtoVacio.hacer())
    }
}

struct RespuestaFoto: Decodable {
    var message: String = ""
    var avatarUrl: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        avatarUrl = seguroOpt(c, .avatarUrl)
    }
}

struct InvitacionDto: Decodable, Identifiable {
    var id: Int64 = 0
    var codigo: String = ""
    var email: String? = nil
    var usada: Bool = false
    var usadaPor: String? = nil
    var creada: String? = nil
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let idInt: Int = seguro(c, .id, 0)
        id = Int64(idInt)
        codigo = seguro(c, .codigo, "")
        email = seguroOpt(c, .email)
        usada = seguro(c, .usada, false)
        usadaPor = seguroOpt(c, .usadaPor)
        creada = seguroOpt(c, .creada)
    }
}

struct RespuestaInvitaciones: Decodable {
    var invitaciones: [InvitacionDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        invitaciones = seguro(c, .invitaciones, [])
    }
}

struct RespuestaCodigoInvitacion: Decodable {
    var message: String = ""
    var codigo: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        message = seguro(c, .message, "")
        codigo = seguro(c, .codigo, "")
    }
}

struct RespuestaMejora: Decodable {
    var ok: Bool = false
    var message: String = ""
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        ok = seguro(c, .ok, false)
        message = seguro(c, .message, "")
    }
}

// MARK: - Notificaciones

/// La notificacion: id Int64; `fecha` llega [S] ya formateada.
struct NotificacionDto: Decodable, Identifiable {
    var id: Int64 = 0
    var tipo: String = ""
    var icono: String = "campana"
    var titulo: String = ""
    var cuerpo: String = ""
    var fecha: String = ""
    var fechaIso: String = ""
    var leida: Bool = false
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let idInt: Int = seguro(c, .id, 0)
        id = Int64(idInt)
        tipo = seguro(c, .tipoK, "")
        icono = seguro(c, .icono, "campana")
        titulo = seguro(c, .titulo, "")
        cuerpo = seguro(c, .cuerpo, "")
        fecha = seguro(c, .fecha, "")
        fechaIso = seguro(c, .fechaIso, "")
        leida = seguro(c, .leida, false)
    }
}

struct NotificacionesDto: Decodable {
    var sinLeer: Int = 0
    var notificaciones: [NotificacionDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        sinLeer = seguro(c, .sinLeer, 0)
        notificaciones = seguro(c, .notificaciones, [])
    }
}

struct RespuestaOk: Decodable {
    var ok: Bool = false
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        ok = seguro(c, .ok, false)
    }
}

struct CanalNotifDto: Decodable, Identifiable {
    var clave: String = ""
    var titulo: String = ""
    var detalle: String = ""
    var id: String { clave }
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        clave = seguro(c, .clave, "")
        titulo = seguro(c, .titulo, "")
        detalle = seguro(c, .detalle, "")
    }
}

struct PreferenciasNotifDto: Decodable {
    var preferencias: [String: Bool] = [:]
    var canales: [CanalNotifDto] = []
    typealias Keys = ModeloKeys
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        preferencias = seguro(c, .preferencias, [:])
        canales = seguro(c, .canales, [])
    }
}
