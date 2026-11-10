import Foundation
import AVFoundation

/// La grabadora de notas de voz: M4A/AAC 64 kbps a 44.1 kHz, el mismo
/// formato que la Android; el archivo viaja declarado como audio/mp4.
@MainActor
final class GrabadoraVoz: NSObject, ObservableObject {
    @Published var grabando = false
    @Published var sinPermiso = false
    private var grabadora: AVAudioRecorder?
    private var archivo: URL?

    func alternar(alTerminar: @escaping (Data?) -> Void) {
        if grabando {
            detener()
            if let archivo = archivo, let datos = try? Data(contentsOf: archivo) {
                alTerminar(datos)
            } else {
                alTerminar(nil)
            }
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] concedido in
            Task { @MainActor in
                guard let self = self else { return }
                if !concedido {
                    self.sinPermiso = true
                    return
                }
                self.empezar()
            }
        }
    }

    private func empezar() {
        do {
            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.playAndRecord, mode: .default)
            try sesion.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("nota-\(UUID().uuidString).m4a")
            let ajustes: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64000,
            ]
            grabadora = try AVAudioRecorder(url: url, settings: ajustes)
            archivo = url
            grabadora?.record()
            grabando = true
        } catch {
            grabando = false
        }
    }

    func detener() {
        grabadora?.stop()
        grabadora = nil
        grabando = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
