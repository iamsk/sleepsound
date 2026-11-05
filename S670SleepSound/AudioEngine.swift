import Foundation
import AVFoundation

enum SoundType: String, CaseIterable, Identifiable {
    case white = "white"
    case fan = "fan"
    case rain = "rain"
    case ocean = "ocean"
    case thunder = "thunder"
    case birds = "birds"
    case fire = "fire"
    case stream = "stream"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "白噪音"
        case .fan: return "睡眠风扇"
        case .rain: return "舒缓雨声"
        case .ocean: return "潮汐海浪"
        case .thunder: return "远雷暴雨"
        case .birds: return "清晨鸟鸣"
        case .fire: return "温暖篝火"
        case .stream: return "山涧小溪"
        }
    }

    var englishTitle: String {
        switch self {
        case .white: return "White Noise"
        case .fan: return "Bedtime Fan"
        case .rain: return "Gentle Rain"
        case .ocean: return "Ocean Waves"
        case .thunder: return "Thunderstorm"
        case .birds: return "Forest Birds"
        case .fire: return "Campfire Crackle"
        case .stream: return "Running Stream"
        }
    }

    var number: String {
        switch self {
        case .white: return "01"
        case .fan: return "02"
        case .rain: return "03"
        case .ocean: return "04"
        case .thunder: return "05"
        case .birds: return "06"
        case .fire: return "07"
        case .stream: return "08"
        }
    }

    var defaultGain: Float {
        switch self {
        case .white: return 0.25
        case .fan: return 0.45
        case .rain: return 0.40
        case .ocean: return 0.45
        case .thunder: return 0.50
        case .birds: return 0.42
        case .fire: return 0.40
        case .stream: return 0.38
        }
    }
}

final class SoundEngine: ObservableObject {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private var players: [SoundType: AVAudioPlayerNode] = [:]
    private var buffers: [SoundType: AVAudioPCMBuffer] = [:]

    @Published var activeSounds: Set<SoundType> = []
    @Published var masterVolume: Float = 0.70 {
        didSet {
            engine.mainMixerNode.outputVolume = masterVolume
        }
    }

    private init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let sampleRate: Double = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        // 为每种声音独立合成真实的母带级声学 Buffer (15秒长循环，采用等功率交叠算法保证 100% 连贯无停顿)
        for sound in SoundType.allCases {
            let player = AVAudioPlayerNode()
            let buffer = synthesizeBuffer(for: sound, format: format, sampleRate: sampleRate, duration: 15.0)

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)

            player.volume = 0
            players[sound] = player
            buffers[sound] = buffer
        }

        engine.mainMixerNode.outputVolume = masterVolume

        do {
            try engine.start()
            for (sound, player) in players {
                if let buf = buffers[sound] {
                    player.play()
                    player.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
                }
            }
        } catch {
            print("AudioEngine start error: \(error)")
        }
    }

    // MARK: - 核心：等功率交叠无缝循环合成器 (Equal-Power Overlap-Add Crossfade)
    /// 彻底解决循环接缝处的停顿、断音与音量下潜，同时原生支持加载真实录音文件
    private func synthesizeBuffer(for sound: SoundType, format: AVAudioFormat, sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        // 0. 优先检测工程 Bundle 中是否已拖入真实录音文件 (如 fan.wav / fan.m4a / fan.mp3)
        let extensions = ["wav", "m4a", "mp3", "caf"]
        for ext in extensions {
            if let fileURL = Bundle.main.url(forResource: sound.rawValue, withExtension: ext) ??
                             Bundle.main.url(forResource: sound.title, withExtension: ext) {
                if let audioFile = try? AVAudioFile(forReading: fileURL),
                   let fileBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) {
                    do {
                        try audioFile.read(into: fileBuffer)
                        return fileBuffer
                    } catch {
                        print("Error reading audio file: \(error)")
                    }
                }
            }
        }

        let totalFrames = Int(sampleRate * duration)
        let crossfadeFrames = Int(sampleRate * 0.6) // 600ms 黄金平滑交叠区
        let extendedFrames = totalFrames + crossfadeFrames

        var extendedSamples = [Float](repeating: 0, count: extendedFrames)

        // 1. 生成扩展长度的原生声学生成数据
        switch sound {
        case .birds:
            synthesizeForestBirds(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .fire:
            synthesizeCampfire(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .stream:
            synthesizeStream(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .thunder:
            synthesizeThunderstorm(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .ocean:
            synthesizeOceanWaves(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .fan:
            synthesizeFan(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .rain:
            synthesizeRain(into: &extendedSamples, sampleRate: sampleRate, total: extendedFrames)
        case .white:
            synthesizeWhiteNoise(into: &extendedSamples, total: extendedFrames)
        }

        // 2. 将尾部多出的 crossfadeFrames 通过【等功率三角函数权重】无缝融入头部
        // 公式：sin^2(θ) + cos^2(θ) = 1.0 (总声能恒定，绝不出现音量下沉或空白停顿)
        var finalSamples = [Float](repeating: 0, count: totalFrames)

        for i in 0..<crossfadeFrames {
            let t = Float(i) / Float(crossfadeFrames)
            let wHead = sin(t * Float.pi * 0.5) // 0 -> 1
            let wTail = cos(t * Float.pi * 0.5) // 1 -> 0
            finalSamples[i] = extendedSamples[i] * wHead + extendedSamples[totalFrames + i] * wTail
        }

        for i in crossfadeFrames..<totalFrames {
            finalSamples[i] = extendedSamples[i]
        }

        // 3. 构建 AVAudioPCMBuffer 并输出至左右声道
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        for i in 0..<totalFrames {
            left[i] = finalSamples[i]
            right[i] = finalSamples[i]
        }

        return buffer
    }

    // MARK: - 1. 清晨鸟鸣合成器 (真实自然调频鸟啼)
    private func synthesizeForestBirds(into buf: inout [Float], sampleRate: Double, total: Int) {
        // 森林微风背景 (恒定流动)
        var leafNoise: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            leafNoise = 0.96 * leafNoise + white * 0.04
            buf[i] = leafNoise * 0.035
        }

        func addChirp(startSec: Double, durSec: Double, fStart: Float, fEnd: Float, peakAmp: Float) {
            let startIdx = Int(startSec * sampleRate)
            let count = Int(durSec * sampleRate)
            for j in 0..<count {
                let idx = startIdx + j
                guard idx < total else { break }
                let t = Float(j) / Float(count)
                let env = sin(t * Float.pi) * peakAmp
                let currentFreq = fStart + (fEnd - fStart) * t
                let phase = 2.0 * Float.pi * (fStart * (Float(j) / Float(sampleRate)) + 0.5 * (fEnd - fStart) * t * (Float(j) / Float(sampleRate)))
                buf[idx] += sin(phase) * env
            }
        }

        // 15 秒内编排 4 组自然鸟啼序列 (结尾预留充足微风余量，避开接缝)
        // 第 1 组 (t = 1.2s)
        addChirp(startSec: 1.2, durSec: 0.14, fStart: 3100, fEnd: 4200, peakAmp: 0.35)
        addChirp(startSec: 1.4, durSec: 0.18, fStart: 4200, fEnd: 3200, peakAmp: 0.40)
        addChirp(startSec: 1.65, durSec: 0.12, fStart: 3400, fEnd: 4100, peakAmp: 0.28)

        // 第 2 组 (t = 4.5s)
        addChirp(startSec: 4.5, durSec: 0.22, fStart: 3900, fEnd: 2700, peakAmp: 0.42)
        addChirp(startSec: 4.8, durSec: 0.15, fStart: 2900, fEnd: 3600, peakAmp: 0.32)

        // 第 3 组 (t = 8.2s)
        addChirp(startSec: 8.2, durSec: 0.09, fStart: 4200, fEnd: 4700, peakAmp: 0.30)
        addChirp(startSec: 8.35, durSec: 0.09, fStart: 4700, fEnd: 4200, peakAmp: 0.30)
        addChirp(startSec: 8.55, durSec: 0.16, fStart: 3600, fEnd: 4400, peakAmp: 0.38)

        // 第 4 组 (t = 11.5s)
        addChirp(startSec: 11.5, durSec: 0.14, fStart: 3200, fEnd: 4100, peakAmp: 0.32)
        addChirp(startSec: 11.7, durSec: 0.20, fStart: 4100, fEnd: 3000, peakAmp: 0.38)
    }

    // MARK: - 2. 温暖篝火合成器 (连续火焰气流 + 随机木炭清脆爆破)
    private func synthesizeCampfire(into buf: inout [Float], sampleRate: Double, total: Int) {
        var flameNoise: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            flameNoise = 0.985 * flameNoise + white * 0.03
            buf[i] = flameNoise * 0.18

            // 随机木炭清脆爆裂声
            if Float.random(in: 0...1) < 0.0007 {
                let popLen = Int(Float.random(in: 0.004...0.015) * Float(sampleRate))
                let popAmp = Float.random(in: 0.35...0.75)
                let freq = Float.random(in: 1400...3600)
                for j in 0..<popLen {
                    let idx = i + j
                    guard idx < total else { break }
                    let t = Float(j) / Float(popLen)
                    let decay = exp(-t * 6.0)
                    let snap = sin(2.0 * Float.pi * freq * (Float(j) / Float(sampleRate))) * popAmp * decay
                    buf[idx] += snap
                }
            }
        }
    }

    // MARK: - 3. 山涧小溪合成器 (流水潺潺 + 翻卷气泡音)
    private func synthesizeStream(into buf: inout [Float], sampleRate: Double, total: Int) {
        var streamBed: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            streamBed = 0.95 * streamBed + white * 0.08
            buf[i] = streamBed * 0.16

            if Float.random(in: 0...1) < 0.0012 {
                let bubbleLen = Int(Float.random(in: 0.01...0.025) * Float(sampleRate))
                let f0 = Float.random(in: 700...1500)
                let amp = Float.random(in: 0.15...0.30)
                for j in 0..<bubbleLen {
                    let idx = i + j
                    guard idx < total else { break }
                    let t = Float(j) / Float(bubbleLen)
                    let curF = f0 * (1.0 + t * 0.7)
                    let env = sin(t * Float.pi)
                    let sample = sin(2.0 * Float.pi * curF * (Float(j) / Float(sampleRate))) * amp * env
                    buf[idx] += sample
                }
            }
        }
    }

    // MARK: - 4. 远雷暴雨合成器 (暴雨基底 + 55Hz 低频闷雷)
    private func synthesizeThunderstorm(into buf: inout [Float], sampleRate: Double, total: Int) {
        // 持续雨声基底
        for i in 0..<total {
            buf[i] = Float.random(in: -0.09...0.09)
        }

        func addThunder(atSec: Double) {
            let startIdx = Int(atSec * sampleRate)
            let thunderLen = Int(3.2 * sampleRate)
            for j in 0..<thunderLen {
                let idx = startIdx + j
                guard idx < total else { break }
                let t = Float(j) / Float(thunderLen)
                let env = exp(-t * 2.2) * sin(t * Float.pi * 0.75)
                let rumbleFreq: Float = 55.0 + Float.random(in: -8...8)
                let sample = sin(2.0 * Float.pi * rumbleFreq * (Float(j) / Float(sampleRate))) * env * 0.65
                buf[idx] += sample
            }
        }

        // 在 15 秒内分布 3 次自然远雷
        addThunder(atSec: 2.2)
        addThunder(atSec: 7.0)
        addThunder(atSec: 11.8)
    }

    // MARK: - 5. 潮汐海浪合成器 (周期完全整除，相位 100% 连贯)
    private func synthesizeOceanWaves(into buf: inout [Float], sampleRate: Double, total: Int) {
        var lowFilter: Float = 0
        // 5.0 秒为一个潮涌周期，15.0 秒刚好整除为 3 个完整周期，循环边界相位 100% 连续无突变
        let wavePeriod = 5.0
        for i in 0..<total {
            let timeSec = Double(i) / sampleRate
            let waveCycle = (sin(2.0 * Double.pi * timeSec / wavePeriod) + 1.0) / 2.0
            let white = Float.random(in: -1...1)
            lowFilter = 0.94 * lowFilter + white * 0.06
            
            let crash = (waveCycle > 0.78) ? (white * Float(waveCycle - 0.78) * 0.28) : 0
            buf[i] = (lowFilter * Float(waveCycle * 0.5 + 0.15)) + crash
        }
    }

    // MARK: - 6. 睡眠风扇合成器 (真实物理机身气流与亥姆霍兹共振，彻底剔除正弦波电流音)
    private func synthesizeFan(into buf: inout [Float], sampleRate: Double, total: Int) {
        // 彻底删除 60Hz/120Hz 纯正弦波（消灭手机扬声器振膜失真引起的“电视电流/嗡鸣杂音”）
        // 采用双极点布朗空气涡流 + 240Hz 声学机壳亥姆霍兹共振腔体滤波 (Helmholtz Resonant Cavity)
        var b0: Float = 0
        var b1: Float = 0

        let f0: Double = 240.0
        let q: Double = 0.85
        let w0 = 2.0 * Double.pi * f0 / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let b_0 = alpha
        let b_1 = 0.0
        let b_2 = -alpha
        let a_0 = 1.0 + alpha
        let a_1 = -2.0 * cos(w0)
        let a_2 = 1.0 - alpha

        let nb0 = Float(b_0 / a_0)
        let nb1 = Float(b_1 / a_0)
        let nb2 = Float(b_2 / a_0)
        let na1 = Float(a_1 / a_0)
        let na2 = Float(a_2 / a_0)

        var x1: Float = 0
        var x2: Float = 0
        var y1: Float = 0
        var y2: Float = 0

        for i in 0..<total {
            let timeSec = Double(i) / sampleRate
            let white = Float.random(in: -1...1)

            // 真实空气流动与摩擦 (平滑布朗/粉红气流，杜绝任何人工合成电子音)
            b0 = 0.982 * b0 + white * 0.025
            b1 = 0.950 * b1 + b0 * 0.050
            let airBase = b0 * 0.65 + b1 * 0.35

            // 物理腔体共鸣滤波 (模拟真实风扇外壳出风口的深沉风道声)
            let y = nb0 * airBase + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2
            x2 = x1
            x1 = airBase
            y2 = y1
            y1 = y

            // 0.85Hz 舒缓自然的扇叶气流慢速起伏
            let sweep = 0.88 + 0.12 * Float(sin(2.0 * Double.pi * 0.85 * timeSec))

            // 混合输出真实风扇深沉平稳的风道气流声 (零电流音，只有纯净温润的风声)
            buf[i] = (airBase * 0.72 + y * 0.85) * sweep * 0.44
        }
    }

    // MARK: - 7. 舒缓雨声合成器 (致密水汽雨声 + 密集微雨滴瞬态)
    private func synthesizeRain(into buf: inout [Float], sampleRate: Double, total: Int) {
        var rainBed: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            rainBed = 0.88 * rainBed + white * 0.12
            var sample = rainBed * 0.22
            if Float.random(in: 0...1) < 0.003 {
                sample += Float.random(in: -0.18...0.18)
            }
            buf[i] = sample
        }
    }

    // MARK: - 8. 纯净平直白噪音合成器
    private func synthesizeWhiteNoise(into buf: inout [Float], total: Int) {
        for i in 0..<total {
            buf[i] = Float.random(in: -0.22...0.22)
        }
    }

    // 切换声音播放状态
    func toggleSound(_ sound: SoundType) {
        if activeSounds.contains(sound) {
            activeSounds.remove(sound)
            players[sound]?.volume = 0
        } else {
            activeSounds.insert(sound)
            players[sound]?.volume = sound.defaultGain
        }
    }

    func isSoundActive(_ sound: SoundType) -> Bool {
        activeSounds.contains(sound)
    }
}
