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

        // 为每种声音独立合成真实的母带级声学 Buffer (10秒长循环，无缝淡入淡出消除接缝)
        for sound in SoundType.allCases {
            let player = AVAudioPlayerNode()
            let buffer = synthesizeBuffer(for: sound, format: format, sampleRate: sampleRate, duration: 10.0)

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

    // MARK: - 核心：为 8 种声音进行精确的声学生成算法
    private func synthesizeBuffer(for sound: SoundType, format: AVAudioFormat, sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        let total = Int(frameCount)
        var rawSamples = [Float](repeating: 0, count: total)

        switch sound {
        case .birds:
            // 1. 清晨鸟鸣：林间自然微风背景 + 清晰真实的调频鸟啼声 (Frequency Sweeps & Melodic Trills)
            synthesizeForestBirds(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .fire:
            // 2. 温暖篝火：温润火焰轰鸣 + 真实的木炭清脆爆裂声 (Charcoal Crackles & Pops)
            synthesizeCampfire(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .stream:
            // 3. 山涧小溪：潺潺水流基底 + 灵动气泡翻滚爆破声 (Water Bubble Bursts)
            synthesizeStream(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .thunder:
            // 4. 远雷暴雨：持续雨声背景 + 2 处深沉滚动的低频远雷回荡 (Rolling Sub-bass Thunderclaps)
            synthesizeThunderstorm(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .ocean:
            // 5. 潮汐海浪：真实 9 秒呼吸周期的潮涌、拍岸浪花与退潮沙石声 (Ocean Swells & Crashes)
            synthesizeOceanWaves(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .fan:
            // 6. 睡眠风扇：120Hz/240Hz 机械电机嗡鸣 + 4.5Hz 扇叶空气旋转扰动 (Blade Air Vortex)
            synthesizeFan(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .rain:
            // 7. 舒缓雨声：大雨倾盆背景 + 随机密集雨滴击打声 (Droplet Patter Transients)
            synthesizeRain(into: &rawSamples, sampleRate: sampleRate, total: total)

        case .white:
            // 8. 白噪音：全频谱能量完全均匀的高斯平滑白噪
            synthesizeWhiteNoise(into: &rawSamples, total: total)
        }

        // 首尾 50ms 跨周期平滑淡入淡出 (消除循环播放时的接缝咔嗒声)
        let fadeLength = Int(sampleRate * 0.05)
        for i in 0..<fadeLength {
            let factor = Float(i) / Float(fadeLength)
            rawSamples[i] *= factor
            rawSamples[total - 1 - i] *= factor
        }

        // 写入左右声道
        for i in 0..<total {
            left[i] = rawSamples[i]
            right[i] = rawSamples[i]
        }

        return buffer
    }

    // MARK: - 1. 清晨鸟鸣合成器 (真正婉转悦耳的鸟叫声)
    private func synthesizeForestBirds(into buf: inout [Float], sampleRate: Double, total: Int) {
        // (1) 森林微风沙沙树叶背景
        var leafNoise: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            leafNoise = 0.96 * leafNoise + white * 0.04
            buf[i] = leafNoise * 0.03
        }

        // (2) 鸟鸣啼叫生成函数 (利用正弦频率快速调制扫频)
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

        // (3) 在 10 秒内编排多组不同品种的自然林间鸟鸣组合 (包括单音啼、双颤音、三连啼)
        // 第一组：林间知更鸟双颤音 (t = 1.2s ~ 1.6s)
        addChirp(startSec: 1.1, durSec: 0.14, fStart: 3100, fEnd: 4200, peakAmp: 0.35)
        addChirp(startSec: 1.3, durSec: 0.18, fStart: 4200, fEnd: 3200, peakAmp: 0.40)
        addChirp(startSec: 1.55, durSec: 0.12, fStart: 3400, fEnd: 4100, peakAmp: 0.28)

        // 第二组：婉转下行林鸟 (t = 3.8s)
        addChirp(startSec: 3.8, durSec: 0.22, fStart: 3900, fEnd: 2700, peakAmp: 0.42)
        addChirp(startSec: 4.1, durSec: 0.15, fStart: 2900, fEnd: 3600, peakAmp: 0.32)

        // 第三组：清脆短促三音欢鸣 (t = 6.4s)
        addChirp(startSec: 6.4, durSec: 0.09, fStart: 4200, fEnd: 4700, peakAmp: 0.30)
        addChirp(startSec: 6.55, durSec: 0.09, fStart: 4700, fEnd: 4200, peakAmp: 0.30)
        addChirp(startSec: 6.75, durSec: 0.16, fStart: 3600, fEnd: 4400, peakAmp: 0.38)

        // 第四组：远方山雀回应 (t = 8.6s)
        addChirp(startSec: 8.6, durSec: 0.14, fStart: 3200, fEnd: 4100, peakAmp: 0.32)
        addChirp(startSec: 8.8, durSec: 0.20, fStart: 4100, fEnd: 3000, peakAmp: 0.38)
    }

    // MARK: - 2. 温暖篝火合成器 (真实木炭燃烧与清脆劈啪声)
    private func synthesizeCampfire(into buf: inout [Float], sampleRate: Double, total: Int) {
        var flameNoise: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            flameNoise = 0.985 * flameNoise + white * 0.03
            buf[i] = flameNoise * 0.18

            // 随机突发清脆木炭爆裂脉冲 (Crackles)
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

    // MARK: - 3. 山涧小溪合成器 (流水潺潺与气泡翻滚)
    private func synthesizeStream(into buf: inout [Float], sampleRate: Double, total: Int) {
        var streamBed: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            streamBed = 0.95 * streamBed + white * 0.08
            buf[i] = streamBed * 0.16

            // 水流翻卷气泡音 (Bubble pinch-off 频率快速上升)
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

    // MARK: - 4. 远雷暴雨合成器 (暴雨倾盆 + 滚滚低频闷雷)
    private func synthesizeThunderstorm(into buf: inout [Float], sampleRate: Double, total: Int) {
        // 雨声基底
        for i in 0..<total {
            buf[i] = Float.random(in: -0.09...0.09)
        }

        // 注入 2 次真实的低沉轰鸣远雷 (t = 2.0s 与 t = 6.8s)
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
        addThunder(atSec: 1.8)
        addThunder(atSec: 6.5)
    }

    // MARK: - 5. 潮汐海浪合成器 (9秒自然浪涌潮起潮落)
    private func synthesizeOceanWaves(into buf: inout [Float], sampleRate: Double, total: Int) {
        var lowFilter: Float = 0
        let wavePeriod = 8.5
        for i in 0..<total {
            let timeSec = Double(i) / sampleRate
            let waveCycle = (sin(2.0 * Double.pi * timeSec / wavePeriod) + 1.0) / 2.0 // 0.0 ~ 1.0
            let white = Float.random(in: -1...1)
            lowFilter = 0.94 * lowFilter + white * 0.06
            
            // 浪涌高潮时带碎浪花高频
            let crash = (waveCycle > 0.75) ? (white * Float(waveCycle - 0.75) * 0.25) : 0
            buf[i] = (lowFilter * Float(waveCycle * 0.5 + 0.15)) + crash
        }
    }

    // MARK: - 6. 睡眠风扇合成器 (真实电机嗡鸣 + 4.5Hz 扇叶风切律动)
    private func synthesizeFan(into buf: inout [Float], sampleRate: Double, total: Int) {
        var airNoise: Float = 0
        for i in 0..<total {
            let timeSec = Double(i) / sampleRate
            // 120Hz 电机工频谐波
            let motor = sin(2.0 * Double.pi * 120.0 * timeSec) * 0.08 + sin(2.0 * Double.pi * 240.0 * timeSec) * 0.03
            // 4.5Hz 扇叶旋转空气流动调制
            let bladeMod = 0.75 + 0.25 * sin(2.0 * Double.pi * 4.5 * timeSec)
            let white = Float.random(in: -1...1)
            airNoise = 0.97 * airNoise + white * 0.04
            buf[i] = Float(motor) + (airNoise * Float(bladeMod) * 0.35)
        }
    }

    // MARK: - 7. 舒缓雨声合成器 (致密水汽雨声 + 雨滴敲打瞬态)
    private func synthesizeRain(into buf: inout [Float], sampleRate: Double, total: Int) {
        var rainBed: Float = 0
        for i in 0..<total {
            let white = Float.random(in: -1...1)
            rainBed = 0.88 * rainBed + white * 0.12
            var sample = rainBed * 0.22
            // 细密雨滴打击微瞬态
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
