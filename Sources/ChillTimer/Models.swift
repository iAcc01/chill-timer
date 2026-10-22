import Foundation

/// 一个微动作（拉伸 / 远眺 / 呼吸）。
/// 约定：文案里写明的秒数之和必须等于 duration；
/// flexible = 文案以「直到倒计时结束」收尾，可吸收凑整后的剩余秒数而不与文案矛盾。
struct StretchAction: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let target: String
    let duration: Int          // 秒
    let symbol: String         // SF Symbol（参考图缺失时兜底）
    let isEyeCare: Bool
    let requiresStanding: Bool
    let flexible: Bool
    let steps: [String]

    func withDuration(_ seconds: Int) -> StretchAction {
        StretchAction(id: id, name: name, target: target, duration: seconds, symbol: symbol,
                      isEyeCare: isEyeCare, requiresStanding: requiresStanding,
                      flexible: flexible, steps: steps)
    }
}

enum StretchLibrary {

    static let all: [StretchAction] = [
        StretchAction(
            id: "stand_walk", name: "起身走动", target: "全身 · 血液循环", duration: 45,
            symbol: "figure.walk", isEyeCare: false, requiresStanding: true, flexible: true,
            steps: [
                "站起来，离开椅子",
                "在工位附近慢走，双臂自然摆动",
                "放松肩膀，方便的话去接杯水",
                "持续走动，直到倒计时结束"
            ]),
        StretchAction(
            id: "neck_side", name: "颈部侧屈", target: "颈部 · 肩颈", duration: 30,
            symbol: "figure.stand", isEyeCare: false, requiresStanding: false, flexible: false,
            steps: [
                "坐直或站直，肩膀下沉",
                "头缓慢向右倾，右耳找右肩",
                "保持 15 秒，感受左侧拉伸",
                "回正后换左侧，再保持 15 秒"
            ]),
        StretchAction(
            id: "neck_turn", name: "颈部回旋", target: "颈部", duration: 30,
            symbol: "arrow.clockwise", isEyeCare: false, requiresStanding: false, flexible: false,
            steps: [
                "下巴微收，头部保持中立",
                "头缓慢向右转，看向右后方，保持 15 秒",
                "缓慢回正后向左转，再保持 15 秒",
                "全程不要仰头"
            ]),
        StretchAction(
            id: "shoulder_roll", name: "肩部绕环", target: "肩颈", duration: 30,
            symbol: "arrow.clockwise", isEyeCare: false, requiresStanding: false, flexible: false,
            steps: [
                "双肩向上提，尽量靠近耳朵",
                "向后、向下画圈落下",
                "向后绕 8 圈，约 15 秒",
                "再向前绕 8 圈，约 15 秒"
            ]),
        StretchAction(
            id: "chest_open", name: "扩胸展背", target: "胸背", duration: 40,
            symbol: "lungs.fill", isEyeCare: false, requiresStanding: true, flexible: false,
            steps: [
                "站起，双手在背后交握",
                "挺胸，双手向后上方缓慢抬起",
                "保持 20 秒，胸口有张开感",
                "松开抖肩，再做一次，保持 20 秒"
            ]),
        StretchAction(
            id: "forward_fold", name: "站立体前屈", target: "腰背 · 腿后侧", duration: 40,
            symbol: "figure.stand", isEyeCare: false, requiresStanding: true, flexible: false,
            steps: [
                "站起，双脚与肩同宽",
                "呼气，上半身缓慢向前折叠，膝盖可微弯",
                "双手自然下垂，保持 30 秒",
                "最后 10 秒，缓慢逐节起身"
            ]),
        StretchAction(
            id: "side_reach", name: "站起侧伸展", target: "侧腰 · 脊柱", duration: 40,
            symbol: "figure.stand", isEyeCare: false, requiresStanding: true, flexible: false,
            steps: [
                "站起，双手在头顶交握",
                "身体缓慢向右侧弯，保持 20 秒",
                "回正后向左侧弯，再保持 20 秒",
                "全程骨盆保持中立"
            ]),
        StretchAction(
            id: "wrist_stretch", name: "手腕伸展", target: "手腕 · 前臂", duration: 40,
            symbol: "hand.raised.fill", isEyeCare: false, requiresStanding: false, flexible: false,
            steps: [
                "右臂前伸掌心朝下，左手轻压手背，保持 10 秒",
                "翻转掌心朝上，左手下压手指，保持 10 秒",
                "换左臂，掌心朝下保持 10 秒",
                "翻转掌心朝上，再保持 10 秒"
            ]),
        StretchAction(
            id: "hand_open", name: "手指张握", target: "手部", duration: 20,
            symbol: "hand.raised.fill", isEyeCare: false, requiresStanding: false, flexible: true,
            steps: [
                "双手用力张开，手指尽量分开",
                "保持 2 秒",
                "缓缓握拳，不要太用力",
                "张握交替，直到倒计时结束"
            ]),
        StretchAction(
            id: "eye_20", name: "20-20-20 远眺", target: "眼睛", duration: 20,
            symbol: "eye.fill", isEyeCare: true, requiresStanding: false, flexible: true,
            steps: [
                "看向约 6 米外的物体，最好是窗外最远处",
                "全程不要看屏幕",
                "多眨几次眼，让眼球湿润",
                "至少看 20 秒，直到倒计时结束"
            ]),
        StretchAction(
            id: "eye_roll", name: "眼球放松", target: "眼睛", duration: 30,
            symbol: "eye.fill", isEyeCare: true, requiresStanding: false, flexible: true,
            steps: [
                "闭眼，眼球顺时针缓慢转 3 圈，约 10 秒",
                "再逆时针转 3 圈，约 10 秒",
                "用力闭眼 3 秒后睁开",
                "看向窗外最远处，直到倒计时结束"
            ]),
        StretchAction(
            id: "breathe", name: "腹式深呼吸", target: "呼吸 · 放松", duration: 36,
            symbol: "wind", isEyeCare: false, requiresStanding: false, flexible: true,
            steps: [
                "坐直或站直，一只手放在腹部",
                "鼻吸 4 秒，感受腹部鼓起",
                "屏息 2 秒，再用嘴呼气 6 秒",
                "按这个节奏重复，直到倒计时结束"
            ])
    ]

    /// 按休息时长拼一组动作，总时长**严格等于** target：
    /// 起身类排最前，用眼类收尾；动作不够时循环补充；凑不整的剩余秒数并入 flexible 动作。
    static func buildSequence(
        duration target: Int,
        includeStanding: Bool = true,
        includeEyeCare: Bool = true
    ) -> [StretchAction] {
        let total = max(30, target)
        var remaining = total
        var picked: [StretchAction] = []

        // 收尾的用眼动作先预留时长
        let eye = includeEyeCare
            ? all.filter { $0.isEyeCare && $0.duration <= total }.shuffled().first
            : nil
        let reserve = eye?.duration ?? 0

        let pool = all.filter { !$0.isEyeCare }

        // 起身优先：久坐最需要的就是先站起来
        if includeStanding,
           let standing = pool.shuffled().first(where: { $0.requiresStanding && $0.duration <= remaining - reserve }) {
            picked.append(standing)
            remaining -= standing.duration
        }

        // 循环填充：一轮用完再洗牌下一轮，避免同一动作连做两次
        var queue = pool.filter { $0.id != picked.first?.id }.shuffled()
        for _ in 0..<200 {
            let budget = remaining - reserve
            var index = queue.firstIndex { $0.duration <= budget }
            if index == nil {
                queue = pool.shuffled()
                index = queue.firstIndex { $0.duration <= budget && $0.id != picked.last?.id }
            }
            guard let found = index else { break }
            let action = queue.remove(at: found)
            picked.append(action)
            remaining -= action.duration
        }

        if let eye {
            picked.append(eye)
            remaining -= eye.duration
        }

        if picked.isEmpty {
            return [all[0].withDuration(total)]
        }

        // 剩余秒数并入 flexible 动作（文案是「直到倒计时结束」，加长不矛盾）；
        // 序列里没有 flexible 时，用腹式深呼吸接住，绝不拉长写死秒数的动作
        if remaining > 0 {
            if let index = picked.lastIndex(where: { $0.flexible }) {
                picked[index] = picked[index].withDuration(picked[index].duration + remaining)
            } else if let breathe = all.first(where: { $0.id == "breathe" }) {
                if remaining >= 12 {
                    picked.append(breathe.withDuration(remaining))
                } else {
                    let index = picked.count - 1
                    picked[index] = breathe.withDuration(picked[index].duration + remaining)
                }
            }
        }

        return picked
    }
}
