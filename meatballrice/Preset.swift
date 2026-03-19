import Foundation

struct Preset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let duration: TimeInterval

    var minutes: Int { Int(duration / 60) }

    static let defaults: [Preset] = [
        Preset(name: "Work", duration: 25 * 60),
        Preset(name: "Short Break", duration: 5 * 60),
        Preset(name: "Long Break", duration: 15 * 60),
    ]
}
