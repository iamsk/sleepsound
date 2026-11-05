import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SoundEngine.shared
    @State private var isDarkMode: Bool = true
    @State private var currentTime: String = "00:00"
    @State private var selectedTimer: Int = 0 // 0 = continuous
    @State private var lightMode: Int = 2 // 0=关闭, 1=琥珀夕阳, 2=660nm暖红
    @State private var isBreathing: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            // 计算精准绕过灵动岛/前置摄像头的左右对称安全留白
            let horizontalMargin = max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing, 54)
            let verticalMargin = max(geo.safeAreaInsets.top, geo.safeAreaInsets.bottom, 16)

            ZStack(alignment: .top) {
                // 100% 满屏拟物背景材质
                Rectangle()
                    .fill(isDarkMode ? AnyShapeStyle(darkChassisGradient) : AnyShapeStyle(whiteChassisGradient))
                    .ignoresSafeArea(.all)

                // 顶部漫射柔光光晕 (床头氛围夜灯)
                if lightMode != 0 {
                    ambientGlowOverlay
                        .frame(height: 130)
                        .ignoresSafeArea(.all, edges: .top)
                        .transition(.opacity)
                }

                // 主机控制台机身内部排版 (去除底部注解行，四周自适应安全留白)
                VStack(spacing: 14) {
                    // 第 1 层：顶部排头 (时钟 + 床头夜灯 + 定时器与主题)
                    headerSection
                        .frame(height: 52)

                    // 第 2 层：独立大尺寸主音量金属控制台
                    volumeSection
                        .frame(height: 46)

                    // 第 3 层：核心 8 颗大尺寸实体彩色琴键 (纵向自适应撑满整个下半屏)
                    soundPadsGrid
                        .frame(maxHeight: .infinity)
                }
                // 四周留白：精准避开灵动岛摄像头，同时实现左右完全对称与居中
                .padding(.horizontal, horizontalMargin)
                .padding(.vertical, verticalMargin)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.all)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onReceive(timer) { _ in
            updateClock()
        }
        .onAppear {
            updateClock()
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    // MARK: - 顶部大范围漫射氛围夜灯光晕
    private var ambientGlowOverlay: some View {
        LinearGradient(
            colors: [
                activeLightColor.opacity(isBreathing ? 0.75 : 0.45),
                activeLightColor.opacity(isBreathing ? 0.35 : 0.18),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 10)
        .blendMode(.plusLighter)
        .animation(.easeInOut(duration: 0.3), value: lightMode)
    }

    private var activeLightColor: Color {
        switch lightMode {
        case 1: return Color(hex: "FF9F43") // 琥珀夕阳暖光 (伴睡夜灯)
        case 2: return Color(hex: "FF3B30") // 660nm 纯红光 (促进褪黑素分泌)
        default: return Color.clear
        }
    }

    private var activeLightTitle: String {
        switch lightMode {
        case 1: return "夕阳琥珀"
        case 2: return "660nm暖红"
        default: return "夜灯已关"
        }
    }

    // MARK: - 第 1 层：排头控制栏 (时钟 + 夜灯 + 定时器 + 主题)
    private var headerSection: some View {
        HStack(spacing: 16) {
            // 左侧：时钟与运行状态
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("TIME")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Text(currentTime)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "FF9F43"))
                    .shadow(color: Color(hex: "FF9F43").opacity(0.4), radius: 6)

                Text(engine.activeSounds.isEmpty ? "STANDBY" : "\(engine.activeSounds.count) ON")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(engine.activeSounds.isEmpty ? Color.white.opacity(0.06) : Color(hex: "FF9F43").opacity(0.2))
                    .foregroundColor(engine.activeSounds.isEmpty ? .gray : Color(hex: "FF9F43"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(hex: "101114"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            Spacer()

            // 中间：床头夜灯快捷切换按键
            Button(action: {
                lightMode = (lightMode + 1) % 3
                HapticManager.shared.playToggle()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: lightMode == 0 ? "lightbulb" : "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(lightMode == 0 ? .gray : activeLightColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("BEDSIDE LIGHT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text(activeLightTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(lightMode == 0 ? .gray : activeLightColor)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(isDarkMode ? Color(hex: "18191E") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(lightMode == 0 ? (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06)) : activeLightColor.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: lightMode == 0 ? Color.clear : activeLightColor.opacity(0.3), radius: 6)
            }

            Spacer()

            // 右侧：定时器与主题切换
            HStack(spacing: 8) {
                // 定时器 4 档极简键
                HStack(spacing: 2) {
                    ForEach([15, 30, 60, 0], id: \.self) { mins in
                        Button(action: {
                            selectedTimer = mins
                            HapticManager.shared.playClick()
                        }) {
                            Text(mins == 0 ? "∞" : "\(mins)m")
                                .font(.system(size: 11, weight: selectedTimer == mins ? .bold : .regular, design: .monospaced))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(selectedTimer == mins ? (isDarkMode ? Color(hex: "2D3038") : Color.white) : Color.clear)
                                .foregroundColor(selectedTimer == mins ? Color(hex: "FF9F43") : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(3)
                .background(isDarkMode ? Color.black.opacity(0.35) : Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 黑白主题切换
                Button(action: {
                    isDarkMode.toggle()
                    HapticManager.shared.playToggle()
                }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(isDarkMode ? Color(hex: "18191E") : Color.white)
                        .foregroundColor(isDarkMode ? Color(hex: "FF9F43") : Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.1), radius: 2)
                }
            }
        }
    }

    // MARK: - 第 2 层：独立大尺寸主音量控制台 (宽屏滑道 + 步进微调)
    private var volumeSection: some View {
        HStack(spacing: 12) {
            // 标签
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text("MASTER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .frame(width: 72, alignment: .leading)

            // 音量减按键
            Button(action: {
                engine.masterVolume = max(0, engine.masterVolume - 0.05)
                HapticManager.shared.playClick()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 34, height: 32)
                    .background(isDarkMode ? Color(hex: "1F2126") : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 大号平滑金属滑杆 (支持横屏大范围触控与拖动)
            GeometryReader { sliderGeo in
                ZStack(alignment: .leading) {
                    // 底轨
                    Capsule()
                        .fill(isDarkMode ? Color(hex: "101114") : Color.black.opacity(0.08))
                        .frame(height: 12)
                        .overlay(
                            Capsule().stroke(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
                        )

                    // 进度条
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF9F43").opacity(0.6), Color(hex: "FF9F43")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, sliderGeo.size.width * CGFloat(engine.masterVolume)), height: 12)
                        .shadow(color: Color(hex: "FF9F43").opacity(0.4), radius: 5)

                    // 大尺寸金属滑块手柄 (Thumb)
                    Circle()
                        .fill(isDarkMode ? Color(hex: "E4E4EB") : Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.black.opacity(0.4), radius: 3, y: 1)
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.15), lineWidth: 1)
                        )
                        .offset(x: max(0, min(sliderGeo.size.width - 24, sliderGeo.size.width * CGFloat(engine.masterVolume) - 12)))
                }
                .frame(height: 32)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = Float(value.location.x / sliderGeo.size.width)
                            let clamped = max(0.0, min(1.0, progress))
                            if abs(clamped - engine.masterVolume) > 0.06 {
                                HapticManager.shared.playTick()
                            }
                            engine.masterVolume = clamped
                        }
                )
            }
            .frame(height: 32)

            // 音量加按键
            Button(action: {
                engine.masterVolume = min(1.0, engine.masterVolume + 0.05)
                HapticManager.shared.playClick()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 34, height: 32)
                    .background(isDarkMode ? Color(hex: "1F2126") : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 百分比数值
            Text("\(Int(engine.masterVolume * 100))%")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "FF9F43"))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isDarkMode ? Color.black.opacity(0.25) : Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 第 3 层：8 颗大尺寸彩色琴键矩阵 (去除底标后，撑满下半屏)
    private var soundPadsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(SoundType.allCases) { sound in
                SoundPadView(
                    sound: sound,
                    isActive: engine.isSoundActive(sound),
                    isDarkMode: isDarkMode
                ) {
                    engine.toggleSound(sound)
                    HapticManager.shared.playClick()
                }
            }
        }
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
    }

    // 渐变背景
    private var darkChassisGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "222429"), Color(hex: "151619"), Color(hex: "0B0C0E")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var whiteChassisGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "FFFFFF"), Color(hex: "F4F4F7"), Color(hex: "E6E6ED")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 大尺寸彩色琴键单个视图 (高度自适应撑满)
struct SoundPadView: View {
    let sound: SoundType
    let isActive: Bool
    let isDarkMode: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .shadow(color: isActive ? Color.white : Color.clear, radius: 4)

                    Spacer()

                    Text(sound.number)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.45))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text(sound.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textColor)
                    Text(sound.englishTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textColor.opacity(0.75))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
                    .shadow(color: isActive ? shadowColor.opacity(0.4) : Color.black.opacity(0.12), radius: isActive ? 8 : 4, y: isActive ? 1 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .offset(y: isActive ? 2 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isDarkMode {
            return isActive ? activeDarkColor : normalDarkColor
        } else {
            return isActive ? activeWhiteColor : normalWhiteColor
        }
    }

    private var textColor: Color {
        isDarkMode ? .white : activeWhiteTextColor
    }

    private var borderColor: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        normalWhiteColor
    }

    // 颜色配置
    private var normalDarkColor: Color {
        switch sound {
        case .white: return Color(hex: "292A30")
        case .fan: return Color(hex: "132A29")
        case .rain: return Color(hex: "142740")
        case .ocean: return Color(hex: "0E2B30")
        case .thunder: return Color(hex: "251B3D")
        case .birds: return Color(hex: "1A2A15")
        case .fire: return Color(hex: "381D11")
        case .stream: return Color(hex: "0F2B36")
        }
    }

    private var activeDarkColor: Color {
        switch sound {
        case .white: return Color(hex: "3A3D45")
        case .fan: return Color(hex: "1F4D4A")
        case .rain: return Color(hex: "224570")
        case .ocean: return Color(hex: "194C54")
        case .thunder: return Color(hex: "42306A")
        case .birds: return Color(hex: "2F4D25")
        case .fire: return Color(hex: "61311C")
        case .stream: return Color(hex: "184B5E")
        }
    }

    private var normalWhiteColor: Color {
        switch sound {
        case .white: return Color(hex: "F1F2F6")
        case .fan: return Color(hex: "E6F9F4")
        case .rain: return Color(hex: "E8F2FE")
        case .ocean: return Color(hex: "E3F8F7")
        case .thunder: return Color(hex: "F2EFFD")
        case .birds: return Color(hex: "F3FADC")
        case .fire: return Color(hex: "FFF1E6")
        case .stream: return Color(hex: "E4F6FD")
        }
    }

    private var activeWhiteColor: Color {
        switch sound {
        case .white: return Color(hex: "D8DAE2")
        case .fan: return Color(hex: "B7EFDF")
        case .rain: return Color(hex: "BBD9FA")
        case .ocean: return Color(hex: "B5EBE6")
        case .thunder: return Color(hex: "D5CAFA")
        case .birds: return Color(hex: "DAF09A")
        case .fire: return Color(hex: "FED0AB")
        case .stream: return Color(hex: "BBE4F7")
        }
    }

    private var activeWhiteTextColor: Color {
        switch sound {
        case .white: return Color(hex: "334155")
        case .fan: return Color(hex: "0F766E")
        case .rain: return Color(hex: "1D4ED8")
        case .ocean: return Color(hex: "0F766E")
        case .thunder: return Color(hex: "6D28D9")
        case .birds: return Color(hex: "4D7C0F")
        case .fire: return Color(hex: "C2410C")
        case .stream: return Color(hex: "0369A1")
        }
    }
}

// 辅助 HEX 颜色初始化
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
