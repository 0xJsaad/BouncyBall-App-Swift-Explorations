// Shapes-Mac

#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
#elseif os(macOS)
import Cocoa
typealias PlatformColor = NSColor
#else
#error("Only iOS and macOS are supported.")
#endif


public struct Color {
    enum ModelDescriptor {
    case rgb
    case hsb
    case gray
    case wrapped
    }
    
    enum Model: Equatable, Hashable {
        case rgb(red: Double, green: Double, blue: Double, alpha: Double?)
        case hsb(hue: Double, saturation: Double, brightness: Double, alpha: Double?)
        case gray(gray: Double, alpha: Double?)
        case wrapped(color: PlatformColor)
        
        var platformColor: PlatformColor {
            switch self {
            case .rgb(let r, let g, let b, let a):
                return PlatformColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a ?? 1))
            case .hsb(let h, let s, let b, let a):
                return PlatformColor(hue: CGFloat(h), saturation: CGFloat(s), brightness: CGFloat(b), alpha: CGFloat(a ?? 1))
            case .gray(let g, let a):
                return PlatformColor(white: CGFloat(g), alpha: CGFloat(a ?? 1))
            case .wrapped(let w):
                return w
            }
        }
        
        var cgColor: CGColor {
            return platformColor.cgColor
        }
        
        func to(_ other: ModelDescriptor) -> Model {
            switch (other, self) {
            case (.rgb, .rgb),
                 (.hsb, .hsb),
                 (.gray, .gray),
                 (.wrapped, .wrapped):
                return self
            case (.rgb, _):
                var (r, g, b, a) = (CGFloat(), CGFloat(), CGFloat(), CGFloat())
                platformColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                return .rgb(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
            case (.hsb, _):
                var (h, s, b, a) = (CGFloat(), CGFloat(), CGFloat(), CGFloat())
                platformColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                return .hsb(hue: Double(h), saturation: Double(s), brightness: Double(b), alpha: Double(a))
            case (.gray, _):
                var (g, a) = (CGFloat(), CGFloat())
                platformColor.getWhite(&g, alpha: &a)
                return .gray(gray: Double(g), alpha: Double(a))
            case (.wrapped, _):
                return .wrapped(color: platformColor)
            }
        }
    }
    
    var model: Model
    
    init(red: Double, green: Double, blue: Double, alpha: Double?) {
        model = .rgb(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    init(hue: Double, saturation: Double, brightness: Double, alpha: Double?) {
        model = .hsb(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    
    init(white: Double, alpha: Double?) {
        model = .gray(gray: white, alpha: alpha)
    }
    
    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        model = .rgb(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    public init(hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        model = .hsb(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    
    public init(white: Double, alpha: Double) {
        model = .gray(gray: white, alpha: alpha)
    }

    public init(red: Double, green: Double, blue: Double) {
        self.init(red: red, green: green, blue: blue, alpha: nil)
    }
    
    public init(hue: Double, saturation: Double, brightness: Double) {
        self.init(hue: hue, saturation: saturation, brightness: brightness, alpha: nil)
    }
    
    public init(white: Double) {
        self.init(white: white, alpha: nil)
    }

    init(wrapped: PlatformColor) {
        model = .wrapped(color: wrapped)
    }
    
    var cgColor: CGColor {
        return model.cgColor
    }
    
    var platformColor: PlatformColor {
        return model.platformColor
    }
    
    public var red: Double {
        get {
            if case let Model.rgb(r, _, _, _) = model.to(.rgb) {
                return r
            } else {
                return 0
            }
        }
        set {
            if case let Model.rgb(_, g, b, a) = model.to(.rgb) {
                model = .rgb(red: newValue, green: g, blue: b, alpha: a)
            }
        }
    }
    
    public var green: Double {
        get {
            if case let Model.rgb(_, g, _, _) = model.to(.rgb) {
                return g
            } else {
                return 0
            }
        }
        set {
            if case let Model.rgb(r, _, b, a) = model.to(.rgb) {
                model = .rgb(red: r, green: newValue, blue: b, alpha: a)
            }
        }
    }
    
    public var blue: Double {
        get {
            if case let Model.rgb(_, _, b, _) = model.to(.rgb) {
                return b
            } else {
                return 0
            }
        }
        set {
            if case let Model.rgb(r, g, _, a) = model.to(.rgb) {
                model = .rgb(red: r, green: g, blue: newValue, alpha: a)
            }
        }
    }
    
    public var hue: Double {
        get {
            if case let Model.hsb(h, _, _, _) = model.to(.hsb) {
                return h
            } else {
                return 0
            }
        }
        set {
            if case let Model.hsb(_, s, b, a) = model.to(.hsb) {
                model = .hsb(hue: newValue, saturation: s, brightness: b, alpha: a)
            }
        }
    }
    
    public var saturation: Double {
        get {
            if case let Model.hsb(_, s, _, _) = model.to(.hsb) {
                return s
            } else {
                return 0
            }
        }
        set {
            if case let Model.hsb(h, _, b, a) = model.to(.hsb) {
                model = .hsb(hue: h, saturation: newValue, brightness: b, alpha: a)
            }
        }
    }
    
    public var brightness: Double {
        get {
            if case let Model.hsb(_, _, b, _) = model.to(.hsb) {
                return b
            } else {
                return 0
            }
        }
        set {
            if case let Model.hsb(h, s, _, a) = model.to(.hsb) {
                model = .hsb(hue: h, saturation: s, brightness: newValue, alpha: a)
            }
        }
    }
    
    public var white: Double {
        get {
            if case let Model.gray(g, _) = model.to(.gray) {
                return g
            } else {
                return 0
            }
        }
        set {
            if case let Model.gray(_, a) = model.to(.gray) {
                model = .gray(gray: newValue, alpha: a)
            }
        }
    }
    
    public var alpha: Double {
        get {
            switch model {
            case .rgb(_, _, _, let a):
                return a ?? 1
            case .hsb(_, _, _, let a):
                return a ?? 1
            case .gray(_, let a):
                return a ?? 1
            case .wrapped:
                if case let Model.rgb(_, _, _, a) = model.to(.rgb) {
                    return a ?? 1
                } else {
                    return 1
                }
            }
        }
        set {
            switch model {
            case .rgb(let r, let g, let b, _):
                model = .rgb(red: r, green: g, blue: b, alpha: newValue)
            case .hsb(let h, let s, let b, _):
                model = .hsb(hue: h, saturation: s, brightness: b, alpha: newValue)
            case .gray(let g, _):
                model = .gray(gray: g, alpha: newValue)
            case .wrapped(let platformColor):
                model = .wrapped(color: platformColor.withAlphaComponent(CGFloat(newValue)))
            }
        }
    }
    
    public static let black = Color(wrapped: .black)
    public static let blue = Color(wrapped: .blue)
    public static let brown = Color(wrapped: .brown)
    public static let cyan = Color(wrapped: .cyan)
    public static let darkGray = Color(wrapped: .darkGray)
    public static let gray = Color(wrapped: .gray)
    public static let green = Color(wrapped: .green)
    public static let lightGray = Color(wrapped: .lightGray)
    public static let magenta = Color(wrapped: .magenta)
    public static let orange = Color(wrapped: .orange)
    public static let purple = Color(wrapped: .purple)
    public static let red = Color(wrapped: .red)
    public static let white = Color(wrapped: .white)
    public static let yellow = Color(wrapped: .yellow)
    public static let clear = Color(wrapped: .clear)

}

extension Color: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        return ()
    }
}

extension Color: Equatable {
    public static func == (lhs: Color, rhs: Color) -> Bool {
        return lhs.model.to(.rgb) == rhs.model.to(.rgb)
    }
}

extension Color: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(model.to(.rgb))
    }
}
