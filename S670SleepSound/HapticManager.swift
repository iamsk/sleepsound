import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let rigidFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    private init() {
        impactFeedback.prepare()
        selectionFeedback.prepare()
        rigidFeedback.prepare()
    }
    
    /// 按键下压确信震动
    func playClick() {
        impactFeedback.impactOccurred()
    }
    
    /// 旋钮转动阻尼跳格微震动
    func playTick() {
        selectionFeedback.selectionChanged()
    }
    
    /// 模式切换双段式硬朗震动
    func playToggle() {
        rigidFeedback.impactOccurred()
    }
}
