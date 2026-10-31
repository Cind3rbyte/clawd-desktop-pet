// Clawd Desktop Pet for macOS - a tiny pixel companion that lives above your Dock.
// Unofficial fan project, not affiliated with Anthropic.
// Build: mac/build.sh (needs the Xcode command line tools)

import Cocoa
import CryptoKit
import ServiceManagement

// Promo recording (--promo): the app plays the scenes of a video by itself, mouse pointer included.
let promoMode = CommandLine.arguments.contains("--promo")

// Moves the real mouse pointer smoothly and clicks, so a screen recording shows a hand at work.
enum Hand {
    static var pos = CGEvent(source: nil)?.location ?? CGPoint(x: 1200, y: 600)

    static func after(_ secs: Double, _ run: @escaping () -> Void) {
        // a timer in the common modes also fires while a dialog or a menu is open
        let t = Timer(timeInterval: secs, repeats: false) { _ in run() }
        RunLoop.main.add(t, forMode: .common)
    }

    static func glide(to p: CGPoint, _ secs: Double, then: (() -> Void)? = nil) {
        let from = pos, start = Date()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { tm in
            let raw = min(1, Date().timeIntervalSince(start) / secs)
            let u = raw * raw * (3 - 2 * raw)
            pos = CGPoint(x: from.x + (p.x - from.x) * u, y: from.y + (p.y - from.y) * u)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pos, mouseButton: .left)?.post(tap: .cghidEventTap)
            if raw >= 1 {
                tm.invalidate()
                then?()
            }
        }
        RunLoop.main.add(t, forMode: .common)
    }

    static func click() {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: pos, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
    }

    // Centre of a view in the coordinates the mouse uses (origin at the top left of the main screen).
    static func centre(_ v: NSView) -> CGPoint {
        guard let w = v.window else { return pos }
        let r = w.convertToScreen(v.convert(v.bounds, to: nil))
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: r.midX, y: h - r.midY)
    }
}

// MARK: - Settings

func T(_ de: String, _ en: String) -> String { return Cfg.lang == "de" ? de : en }

enum Cfg {
    static let orange = "#F26522"

    static var lang = (Locale.preferredLanguages.first ?? "en").hasPrefix("de") ? "de" : "en"
    static var size = 5
    static var talk = false
    static var firstRun = true
    static var readOnly = false

    // Progress: feeding and petting earn XP; levels unlock tricks, colours and hats
    // Pixel Roomies: three animals, each with its own XP, hunger and colour. One of them is on the screen.
    static var animal = 0              // 0 = Clawd, 1 = duck, 2 = cat
    static let animalKeys = ["clawd", "duck", "cat"]
    // theme colour for every animal and colour (menu bar icon, buttons, level bar, speech bubble rim)
    static let accentTab = [
        ["#F26522", "#E0568F", "#4A90D9", "#3FA66B", "#9B6FE8", "#1FB3AD", "#C99A10"],
        ["#D89500", "#8E96A3", "#1F7A4D", "#E0568F", "#3C7FD0", "#2E9E63", "#8A5FE0"],
        ["#6E7480", "#454550", "#E08A2E", "#9A8F80", "#8A6A55", "#9B6FE8", "#566B8C"]]
    static var xpA = [0, 0, 0]
    static var foodA = [80.0, 80.0, 80.0]   // 0 = starving, 100 = full
    static var varA = [0, 0, 0]             // chosen colour of each animal
    static var xp: Int {
        get { return xpA[animal] }
        set { xpA[animal] = newValue }
    }
    static var food: Double {
        get { return foodA[animal] }
        set { foodA[animal] = newValue }
    }
    static var color: String {
        get { return swatches(animal)[varA[animal]] }
        set { if let i = swatches(animal).firstIndex(of: newValue) { varA[animal] = i } }
    }
    static func accentHex(_ an: Int) -> String { return accentTab[an][varA[an]] }

    // Cosmetics are shared by all animals: head, face, neck and effect can be worn at the same time
    static var hat = "none", face = "none", neck = "none", fx = "none"
    static var streak = 0              // days in a row the app was started
    static var lastDay = ""
    static var trophy = false, trophyNew = false

    static let sizeVals = [3, 5, 7, 10]
    static let colVals = [orange, "#F06FA8", "#4A90D9", "#3FA66B", "#9B6FE8", "#3DD6D0", "#E8B923"]
    static let colLevel = [1, 1, 1, 2, 3, 4, 5]
    static let hatVals = ["none", "cap", "party", "phones", "tophat", "crown", "flower", "cowboy", "wizard", "chef", "pirate", "prop", "grad", "halo", "horns", "bow", "pumpkin", "santa"]
    static let faceVals = ["none", "nerd", "sun", "monocle", "stache", "patch", "cheeks"]
    static let faceLevel = [1, 2, 3, 5, 4, 3, 1]
    static let neckVals = ["none", "bowtie", "scarf", "bandana", "bell"]
    static let neckLevel = [1, 2, 3, 2, 1]
    static let fxVals = ["none", "sparkle", "hearts", "rain", "ghost", "trophy"]
    // 99 = feedback form, 98 = only in October, 97 = only in December, 96 = seven days in a row (not level rewards)
    static let byFeedback = 99, byOctober = 98, byDecember = 97, byStreak = 96
    static var thanked = false
    static var month: Int { return Calendar.current.component(.month, from: Date()) }
    static var hatLevel: [Int] {
        var n = [1, 1, 1, 2, 4, 6, byFeedback, 2, 5, 3, 3, 4, 5, 7, 6, 2, byOctober, byDecember]
        if thanked { n[6] = 1 }
        if month == 10 { n[16] = 1 }
        if month == 12 { n[17] = 1 }
        return n
    }
    static var fxLevel: [Int] { return [1, 4, 3, 5, 7, trophy ? 1 : byStreak] }
    static func needText(_ need: Int) -> String {
        return need == byFeedback ? "Feedback" : need == byOctober ? T("nur Oktober", "October only") : need == byDecember ? T("nur Dezember", "December only")
            : need == byStreak ? T("7 Tage in Folge", "7 days in a row") : "Level \(need)"
    }

    static func levelOf(_ xp: Int) -> Int { return 1 + Int((Double(xp) / 15.0).squareRoot()) }
    static var level: Int { return levelOf(xp) }
    // Cosmetics unlock with the highest level of all animals
    static var topLevel: Int { return xpA.map { levelOf($0) }.max() ?? 1 }
    static func othersTop() -> Int {
        var m = 1
        for i in 0..<xpA.count where i != animal { m = max(m, levelOf(xpA[i])) }
        return m
    }
    static func xpFor(_ level: Int) -> Int { return 15 * (level - 1) * (level - 1) }

    static func swatches(_ an: Int) -> [String] {
        if an == 0 { return colVals }
        return (an == 1 ? Roomies.duckVars : Roomies.catVars).map { $0.head ?? $0.body }
    }

    // Start of a new day: counts the days in a row; seven in a row earn the golden trophy
    static func touchDay() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let now = Date(), today = f.string(from: now)
        if lastDay == today { return }
        if let last = f.date(from: lastDay), let next = Calendar.current.date(byAdding: .day, value: 1, to: last), Calendar.current.isDate(next, inSameDayAs: now) {
            streak += 1
        } else {
            streak = 1
        }
        lastDay = today
        if streak >= 7 && !trophy {
            trophy = true
            trophyNew = true
        }
    }

    static var sizeLabels: [String] { return [T("Klein", "Small"), T("Mittel", "Medium"), T("Groß", "Large"), T("Riesig", "Huge")] }
    static var colLabels: [String] {
        if animal > 0 { return (animal == 1 ? Roomies.duckVars : Roomies.catVars).map { T($0.de, $0.en) } }
        return ["Orange", "Pink", T("Blau", "Blue"), T("Grün", "Green"), T("Lila", "Purple"), T("Türkis", "Teal"), "Gold"]
    }
    static var animalLabels: [String] { return ["Clawd", T("Ente", "Duck"), T("Katze", "Cat")] }
    static var hatLabels: [String] {
        return [T("Ohne", "None"), T("Mütze", "Beanie"), T("Partyhut", "Party hat"), T("Kopfhörer", "Headphones"), T("Zylinder", "Top hat"), T("Krone", "Crown"), T("Blume", "Flower"),
                T("Cowboyhut", "Cowboy hat"), T("Zauberhut", "Wizard hat"), T("Kochmütze", "Chef hat"), T("Piratenhut", "Pirate hat"), T("Propellermütze", "Propeller cap"), T("Doktorhut", "Graduation cap"),
                T("Heiligenschein", "Halo"), T("Teufelshörner", "Devil horns"), T("Schleife", "Bow"), T("Kürbis-Hut", "Pumpkin hat"), T("Weihnachtsmütze", "Santa hat")]
    }
    static var faceLabels: [String] { return [T("Ohne", "None"), T("Nerdbrille", "Nerd glasses"), T("Sonnenbrille", "Sunglasses"), T("Monokel", "Monocle"), T("Schnurrbart", "Moustache"), T("Augenklappe", "Eye patch"), T("Rosige Wangen", "Rosy cheeks")] }
    static var neckLabels: [String] { return [T("Ohne", "None"), T("Fliege", "Bow tie"), T("Schal", "Scarf"), T("Halstuch", "Bandana"), T("Glöckchen", "Bell collar")] }
    static var fxLabels: [String] { return [T("Ohne", "None"), T("Funkeln", "Sparkles"), T("Kleine Herzen", "Little hearts"), T("Regenwolke", "Rain cloud"), T("Mini-Geist", "Mini ghost"), T("Goldener Pokal", "Golden trophy")] }

    static func load() {
        let d = UserDefaults.standard
        if let l = d.string(forKey: "lang") {
            lang = l == "de" ? "de" : "en"
            firstRun = false
        }
        if d.object(forKey: "size") != nil { size = max(2, min(12, d.integer(forKey: "size"))) }
        talk = d.bool(forKey: "talk")
        // per-animal keys: xp / food / var for Clawd, xp_duck, xp_cat ... for the others
        if let c = d.string(forKey: "color"), let i = colVals.firstIndex(of: c) { varA[0] = i }
        for an in 0..<3 {
            let sfx = an == 0 ? "" : "_" + animalKeys[an]
            xpA[an] = max(0, d.integer(forKey: "xp" + sfx))
            if d.object(forKey: "food" + sfx) != nil { foodA[an] = max(0, min(100, d.double(forKey: "food" + sfx))) }
            if d.object(forKey: "var" + sfx) != nil { varA[an] = max(0, min(6, d.integer(forKey: "var" + sfx))) }
        }
        if let a = d.string(forKey: "animal"), let i = animalKeys.firstIndex(of: a) { animal = i }
        if let h = d.string(forKey: "hat"), hatVals.contains(h) { hat = h }
        if let f = d.string(forKey: "face"), faceVals.contains(f) { face = f }
        if let n = d.string(forKey: "neck"), neckVals.contains(n) { neck = n }
        if let x = d.string(forKey: "fx"), fxVals.contains(x) { fx = x }
        thanked = d.bool(forKey: "thanks")
        trophy = d.bool(forKey: "trophy")
        streak = max(0, d.integer(forKey: "streak"))
        lastDay = d.string(forKey: "lastday") ?? ""
        // They also get hungry while the Mac is off - but slowly, and never all the way
        let stamp = d.double(forKey: "stamp")
        if stamp > 0 {
            let hours = (Date().timeIntervalSince1970 - stamp) / 3600
            if hours > 0 {
                for i in 0..<foodA.count { foodA[i] = max(min(foodA[i], 20), foodA[i] - hours * 8) }
            }
        }
        // Seasonal and earned pieces are only worn while they are available
        if hat == "pumpkin" && month != 10 { hat = "none" }
        if hat == "santa" && month != 12 { hat = "none" }
        if hat == "flower" && !thanked { hat = "none" }
        if fx == "trophy" && !trophy { fx = "none" }
        touchDay()
    }

    static func save() {
        if readOnly { return }
        let d = UserDefaults.standard
        d.set(lang, forKey: "lang")
        d.set(size, forKey: "size")
        d.set(talk, forKey: "talk")
        d.set(animalKeys[animal], forKey: "animal")
        for an in 0..<3 {
            let sfx = an == 0 ? "" : "_" + animalKeys[an]
            d.set(xpA[an], forKey: "xp" + sfx)
            d.set(foodA[an], forKey: "food" + sfx)
            d.set(varA[an], forKey: "var" + sfx)
        }
        d.set(colVals[varA[0]], forKey: "color") // older versions read this one
        d.set(hat, forKey: "hat")
        d.set(face, forKey: "face")
        d.set(neck, forKey: "neck")
        d.set(fx, forKey: "fx")
        d.set(thanked, forKey: "thanks")
        d.set(trophy, forKey: "trophy")
        d.set(streak, forKey: "streak")
        d.set(lastDay, forKey: "lastday")
        d.set(Date().timeIntervalSince1970, forKey: "stamp")
    }

    // "Open at login" needs macOS 13 or newer.
    static var canAutoStart: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    static var autoStart: Bool {
        get {
            if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
            return false
        }
        set {
            if readOnly { return }
            if #available(macOS 13.0, *) {
                if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
            }
        }
    }
}

// MARK: - Colours

func hex(_ s: String) -> NSColor {
    var h = s
    if h.hasPrefix("#") { h.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: h).scanHexInt64(&v)
    let a: CGFloat = h.count == 8 ? CGFloat((v >> 24) & 0xFF) / 255 : 1
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

enum Ink {
    static let ink = hex("#1A1915"), white = hex("#FFFFFF"), cream = hex("#FAF9F5"), red = hex("#E5484D")
    static let yellow = hex("#F5C542"), blue = hex("#4A90D9"), grey = hex("#C9C8C2"), greyDark = hex("#8A8983")
    static let brown = hex("#8B5A2B"), brownDark = hex("#5C3A1A"), cookie = hex("#D9A55B"), gold = hex("#E8C76A")
    static let steam = hex("#BBFFFFFF"), green = hex("#3FA66B"), shine = hex("#6E6D68"), purple = hex("#9B6FE8")
    static let pink = hex("#F06FA8"), hatBlue = hex("#3B6FD4"), crownGold = hex("#F2B824"), teal = hex("#3DD6D0")
    static let palette = [red, yellow, blue, green, purple, pink, hex("#FF9F43"), hex("#3DD6D0")]
}

var isDark: Bool {
    return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

// MARK: - Pixel Roomies: the animals and the cosmetics (same pixel maps as the Windows version)

struct Pose {
    var eye = 0, frame = 0, danglePhase = 0
    var lx = 0.0, ly = 0.0, aL = 0.0, aR = 0.0, bob = 0.0, tall = 0.0
    var sit = false, cool = false, dangle = false, moving = false
    var extra: String?
}

struct Anchor {
    var top = 0.0, hw = 0.0, exL = 0.0, exR = 0.0, ey = 0.0, my = 0.0, chY = 0.0, chL = 0.0, chR = 0.0, cw = 0.0
    var ny = 0.0, nw = 0.0, bt = 0.0, bb = 0.0, armY = 0.0, armR = 0.0, armL = 0.0, fxTop = 0.0, ghostY = 0.0
    var loaf = false
}

struct Var {
    var de: String, en: String
    var body = "", dark = "", belly = "", beak = "", muzzle = ""
    var beakD: String?, feet: String?, head: String?, tail: String?, points: String?, eyeC: String?, earIn: String?
    var ring = false, stripes = false, tux = false

    init(_ de: String, _ en: String, body: String, dark: String, belly: String = "", beak: String = "", beakD: String? = nil, head: String? = nil, ring: Bool = false,
         muzzle: String = "", stripes: Bool = false, eyeC: String? = nil, earIn: String? = nil, points: String? = nil, tail: String? = nil) {
        self.de = de
        self.en = en
        self.body = body
        self.dark = dark
        self.belly = belly
        self.beak = beak
        self.beakD = beakD
        self.head = head
        self.ring = ring
        self.muzzle = muzzle
        self.stripes = stripes
        self.eyeC = eyeC
        self.earIn = earIn
        self.points = points
        self.tail = tail
    }
}

final class Roomies {
    static let eyeOpen = 0, eyeClosed = 1, eyeHappy = 2, eyeWide = 3, eyeDizzy = 4
    var ctx: CGContext!
    var ox = 0.0, oy = 0.0, S = 5.0, scale = 2.0

    static var cache: [String: NSColor] = [:]
    static let names = [
        "ink": "#1A1915", "white": "#FFFFFF", "cream": "#FAF9F5", "red": "#E5484D", "redD": "#A8262B", "yellow": "#F5C542",
        "blue": "#4A90D9", "grey": "#C9C8C2", "greyD": "#8A8983", "brown": "#8B5A2B", "brownD": "#5C3A1A", "gold": "#E8C76A",
        "green": "#3FA66B", "greenD": "#2C7A4D", "purple": "#9B6FE8", "pink": "#F06FA8", "pinkL": "#FF9DB8",
        "hatBlue": "#3B6FD4", "crownGold": "#F2B824", "crownD": "#C99410", "teal": "#3DD6D0", "orange": "#F28C28",
        "orangeD": "#C96A12", "indigo": "#3B2F8F", "indigoD": "#2A2068", "cloud": "#9AA3AE", "cloudD": "#7C8591",
        "rain": "#3F7FD0", "ghost": "#F2F6FF", "ghostD": "#C9D5F0", "stache": "#3A2412", "shine": "#6E6D68"]

    static func K(_ c: String) -> NSColor {
        if let b = cache[c] { return b }
        let b = hex(names[c] ?? c)
        cache[c] = b
        return b
    }

    func sn(_ v: Double) -> Double { return (v * scale).rounded() / scale }

    func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: String) {
        let x0 = sn(ox + x * S), y0 = sn(oy + y * S), x1 = sn(ox + (x + w) * S), y1 = sn(oy + (y + h) * S)
        if x1 <= x0 || y1 <= y0 { return }
        ctx.setFillColor(Roomies.K(c).cgColor)
        ctx.fill(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
    }

    func Rc(_ y: Double, _ w: Double, _ h: Double, _ c: String) { R(-w / 2.0, y, w, h, c) }

    func M(_ rows: [String], _ x: Double, _ y: Double, _ keys: [Character: String]) {
        for (r, row) in rows.enumerated() {
            for (q, ch) in row.enumerated() {
                if let col = keys[ch] { R(x + Double(q), y + Double(r), 1, 1, col) }
            }
        }
    }

    static let heart5 = [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."]
    static let plus5 = ["..X..", "..X..", "XXXXX", "..X..", "..X.."]
    static let plus3 = [".X.", "XXX", ".X."]
    static let ghostBmp = [".XXX.", "XXXXX", "X#X#X", "XXXXX", "XXXXX", "X.X.X"]

    // MARK: Eyes

    func eye(_ mode: Int, _ ex: Double, _ ey: Double, _ c: String) {
        switch mode {
        case Roomies.eyeOpen: R(ex, ey, 1, 2, c)
        case Roomies.eyeClosed: R(ex - 0.5, ey + 1, 2, 0.7, "ink")
        case Roomies.eyeHappy:
            R(ex - 1, ey + 1, 1, 1, "ink")
            R(ex, ey, 1, 1, "ink")
            R(ex + 1, ey + 1, 1, 1, "ink")
        case Roomies.eyeWide:
            R(ex - 0.5, ey - 0.5, 2, 2.5, "ink")
            R(ex - 0.5, ey - 0.5, 1, 1, "white")
        default:
            R(ex - 1, ey - 0.5, 1, 1, "ink")
            R(ex + 1, ey - 0.5, 1, 1, "ink")
            R(ex, ey + 0.5, 1, 1, "ink")
            R(ex - 1, ey + 1.5, 1, 1, "ink")
            R(ex + 1, ey + 1.5, 1, 1, "ink")
        }
    }

    // MARK: Animals

    func clawdAnchor(_ p: Pose) -> Anchor {
        var a = Anchor()
        let so = p.sit ? 2.0 : 0.0
        let bt = -10 - p.tall + p.bob + so
        let ey = -8 - p.tall * 0.5 + p.bob + so + p.ly
        a.top = bt
        a.hw = 7
        a.exL = -4 + p.lx
        a.exR = 3 + p.lx
        a.ey = ey
        a.my = ey + 2.7
        a.chY = ey + 2.2
        a.chL = -6.3
        a.chR = 4.3
        a.cw = 2
        a.ny = ey + 3.8
        a.nw = 14
        a.bt = bt
        a.bb = p.sit ? 0 : -2 + p.bob
        a.armY = -7 + p.bob + so
        a.armR = p.aR
        a.armL = p.aL
        a.fxTop = bt
        a.ghostY = -18
        return a
    }

    func clawd(_ p: Pose, _ body: String) -> Anchor {
        let a = clawdAnchor(p)
        let bt = a.bt, bb = a.bb, armY = a.armY
        if !p.sit {
            let legX = [-6.0, -4.0, 3.0, 5.0]
            for i in 0..<4 {
                var ln = -bb
                if p.dangle {
                    ln = (i + p.danglePhase) % 2 == 0 ? 2 : 1.2
                } else if p.moving && i % 2 == p.frame {
                    ln = 1
                }
                R(legX[i], bb, 1, ln, body)
            }
        }
        R(-7, bt, 14, bb - bt, body)
        R(-9, armY + p.aL, 2, 2, body)
        R(7, armY + p.aR, 2, 2, body)
        eye(p.eye, a.exL, a.ey, "ink")
        eye(p.eye, a.exR, a.ey, "ink")
        if p.cool {
            let gy = -8.5 + p.bob
            R(-7, gy, 14, 1, "ink"); R(-6, gy, 5, 3, "ink"); R(1, gy, 5, 3, "ink")
            R(-5, gy + 1, 1, 1, "shine"); R(2, gy + 1, 1, 1, "shine")
        }
        return a
    }

    // Shading for the duck: light from the top left, shade on the right and at the bottom, glints and a soft ground shadow
    static func mix(_ h: String, _ with: String, _ t: Double) -> String {
        let a = hex(h), b = hex(with)
        func ch(_ x: CGFloat, _ y: CGFloat) -> Int { return Int(((x + (y - x) * CGFloat(t)) * 255).rounded(.down)) }
        return String(format: "#%02X%02X%02X", ch(a.redComponent, b.redComponent), ch(a.greenComponent, b.greenComponent), ch(a.blueComponent, b.blueComponent))
    }
    static func lit(_ h: String, _ t: Double) -> String { return mix(h, "#FFFFFF", t) }
    static func shd(_ h: String, _ t: Double) -> String { return mix(h, "#000000", t) }

    func duck(_ p: Pose, _ v: Var) -> Anchor {
        let body = v.body, dk = v.dark, belly = v.belly, beak = v.beak, feet = v.feet ?? "#F28C28", head = v.head ?? body
        let bob = p.bob, so = p.sit ? 2.0 : 0.0, tall = p.tall
        let ex = p.extra
        let bt = -8 - tall + bob + so
        let bb = p.sit ? 0 : -2 + bob
        let armY = -6 + bob + so
        let beakD = v.beakD ?? beak
        let bl = Roomies.lit(body, 0.38), bs = Roomies.shd(body, 0.2), hl = Roomies.lit(head, 0.38), hs = Roomies.shd(head, 0.2)
        let dl = Roomies.lit(dk, 0.3), ds = Roomies.shd(dk, 0.25), fs = Roomies.shd(feet, 0.25), bkl = Roomies.lit(beak, 0.5), bks = Roomies.shd(beakD, 0.25)
        R(-8, -0.7, 16, 1.2, "#30000000"); R(-6, 0.3, 12, 0.6, "#22000000")   // soft shadow on the ground
        if ex == "puddle" {
            R(-9, -1, 18, 2, "rain"); R(-6, 1, 12, 1, "rain")
            R(-11, -3, 1, 1, "rain"); R(10, -4, 1, 1, "rain"); R(-9, -6, 1, 1, "rain"); R(9, -7, 1, 1, "rain")
            R(-7, -0.6, 8, 0.5, "#80FFFFFF"); R(-9, 0.8, 18, 0.7, "#40000000")
        }
        if !p.sit {
            let lx = [-4.5, 1.5]
            for i in 0..<2 {
                let x = lx[i]
                let raised = (p.moving && i == p.frame) ? 1.0 : 0.0
                var ln = -bb
                if p.dangle {
                    ln = (i + p.danglePhase) % 2 == 0 ? 2 : 1.2
                    R(x + 1, bb, 1, ln, feet); R(x, bb + ln - 0.5, 3, 1, feet)
                    R(x, bb + ln + 0.1, 3, 0.4, fs)
                } else {
                    R(x + 1, bb, 1, max(0, ln - 1 - raised), feet)
                    R(x, -1 - raised, 3, 1, feet)
                    R(x + 1.6, bb, 0.4, max(0, ln - 1 - raised), fs); R(x, -0.4 - raised, 3, 0.4, fs); R(x, -1 - raised, 1.2, 0.3, Roomies.lit(feet, 0.4))
                }
            }
        }
        R(-8, bt + 1, 2, 2, body); R(-8, bt, 1, 1, body)
        R(-4, bt, 8, 1, body)
        R(-6, bt + 1, 12, bb - bt - 2, body)
        R(-5, bb - 1, 10, 1, body)
        R(-3, bt + 3.2, 6, 2.2, belly)
        R(-8, bt, 1, 1, bl)                                    // tail tip
        R(-6, bt + 1, 1.2, max(1, (bb - bt) * 0.45), bl)       // light on the left
        R(4.8, bt + 1.5, 1.2, max(1, bb - bt - 3), bs)         // shade on the right
        R(-5, bb - 1, 10, 1, bs)                               // shade underneath
        R(-6, bb - 2, 1, 1, bs)
        R(-3, bt + 3.2, 6, 0.5, Roomies.lit(belly, 0.5))
        R(-3, bt + 4.9, 6, 0.5, Roomies.shd(belly, 0.12))
        R(-4, bt, 8, 0.9, bs)                                  // the head casts a shadow on the chest
        R(-8.5, armY + p.aL, 2.5, 3, dk)
        R(6, armY + p.aR, 2.5, 3, dk)
        R(-8.5, armY + p.aL, 2.5, 0.7, dl); R(-7.6, armY + p.aL + 1.5, 1.4, 0.4, ds); R(-8.5, armY + p.aL + 2.4, 2.5, 0.6, ds)
        R(6, armY + p.aR, 2.5, 0.7, dl); R(6.1, armY + p.aR + 1.5, 1.4, 0.4, ds); R(6, armY + p.aR + 2.4, 2.5, 0.6, ds)
        let ht = bt - 6
        R(-3, ht, 6, 1, head); R(-4, ht + 1, 8, 5, head)
        if v.ring { R(-4, ht + 6, 8, 0.8, "white") }
        R(-3, ht, 3, 0.8, hl); R(-4, ht + 1, 1.2, 2.6, hl); R(-2.6, ht + 0.8, 1.4, 0.7, hl)   // light from the top left
        R(2.8, ht + 1, 1.2, 4.6, hs); R(-4, ht + 5.1, 8, 0.9, hs)                             // shade right and under the cheeks
        R(-3.9, ht + 3.5, 1.3, 1.1, "#50FF7FA8"); R(2.6, ht + 3.5, 1.3, 1.1, "#50FF7FA8")     // blush
        let ey = ht + 2 + p.ly
        eye(p.eye, -3 + p.lx, ey, "ink")
        eye(p.eye, 2 + p.lx, ey, "ink")
        if p.eye == Roomies.eyeOpen || p.eye == Roomies.eyeWide {
            R(-2.55 + p.lx, ey + 0.15, 0.5, 0.5, "white"); R(2.45 + p.lx, ey + 0.15, 0.5, 0.5, "white")   // glint in the eyes
        }
        if ex == "quak" {
            R(-2, ht + 3.6, 4, 1, beak); R(-2, ht + 4.6, 4, 1, "redD"); R(-2.5, ht + 5.6, 5, 1.2, beak)
            R(-2, ht + 3.6, 4, 0.35, bkl); R(-2.5, ht + 6.5, 5, 0.3, bks)
        } else {
            R(-2, ht + 3.6, 4, 1, beak); R(-3, ht + 4.6, 6, 1.4, beakD)
            R(-1.5, ht + 3.6, 3, 0.35, bkl); R(-3, ht + 4.6, 6, 0.4, Roomies.shd(beak, 0.12))
            R(-3, ht + 5.7, 6, 0.3, bks)
            R(-1, ht + 3.95, 0.5, 0.5, bks); R(0.5, ht + 3.95, 0.5, 0.5, bks)
        }
        if p.cool {
            let gy = ey - 0.5
            R(-4.5, gy, 9, 1, "ink"); R(-4, gy, 3.5, 2.5, "ink"); R(0.5, gy, 3.5, 2.5, "ink")
            R(-3, gy + 1, 1, 1, "greyD"); R(1.5, gy + 1, 1, 1, "greyD")
        }
        var a = Anchor()
        a.top = ht
        a.hw = 4
        a.exL = -3 + p.lx
        a.exR = 2 + p.lx
        a.ey = ey
        a.my = ht + 3.0
        a.chY = ht + 3.6
        a.chL = -4.2
        a.chR = 3.0
        a.cw = 1.2
        a.ny = bt - 0.8
        a.nw = 9
        a.bt = bt
        a.bb = bb
        a.armY = armY
        a.armR = p.aR
        a.armL = p.aL
        a.fxTop = ht
        a.ghostY = -18
        return a
    }

    func cat(_ p: Pose, _ v: Var) -> Anchor {
        let body = v.body, dk = v.dark, mz = v.muzzle, tailc = v.tail ?? v.body, pts = v.points, pw = v.points ?? v.body
        let bob = p.bob, tall = p.tall
        var so = p.sit ? 2.0 : 0.0
        let ex = p.extra
        if ex == "hunt" { so = 3 }
        let ecol = v.eyeC ?? "ink"
        var a = Anchor()
        if ex == "loaf" {
            R(8, -5, 2, 1.5, pts ?? tailc)
            R(-7, -6, 14, 6, body); R(-8, -5, 16, 5, body); R(-6, -7, 12, 1, body)
            R(-7, -1.5, 14, 1.5, v.stripes ? dk : body)
            if v.stripes { for q in [-5.0, -1.0, 3.0] { R(q, -7, 1, 1.5, dk) } }
            let lh = -9.0
            R(-5, lh, 10, 5, body)
            R(-5, lh - 2, 2, 2, pw); R(-5, lh - 1, 3, 1, pw); R(-4.5, lh - 1, 1, 1, "pinkL")
            R(3, lh - 2, 2, 2, pw); R(2, lh - 1, 3, 1, pw); R(3.5, lh - 1, 1, 1, "pinkL")
            R(-3.5, lh + 2.4, 2, 0.6, "ink"); R(1.5, lh + 2.4, 2, 0.6, "ink")
            R(-0.5, lh + 3.2, 1, 1, "pinkL")
            R(-5, -2, 3, 2, pw); R(2, -2, 3, 2, pw)
            a.top = lh
            a.hw = 5
            a.exL = -3.5
            a.exR = 2.5
            a.ey = lh + 1.6
            a.my = lh + 3.6
            a.chY = lh + 3
            a.chL = -5
            a.chR = 3.2
            a.cw = 2
            a.ny = lh + 5
            a.nw = 10
            a.bt = -6
            a.bb = 0
            a.armY = -4
            a.fxTop = lh - 2
            a.ghostY = -18
            a.loaf = true
            return a
        }
        let bt = -9 - tall + bob + so
        let bb = p.sit ? 0 : -2 + bob
        let armY = -6.5 + bob + so
        let ht = bt - 6
        let wag = ex == "purr" ? 1.0 : 0.0
        let ty = bt + 2
        R(5, bb - 1.5, 3, 1.5, tailc)
        R(7, ty, 1.5, bb - ty - 0.5, tailc)
        R(7 + wag, ty - 1.5, 1.5, 1.5, pts ?? dk)
        if !p.sit {
            let lx = [-4.0, 2.0]
            for i in 0..<2 {
                var ln = -bb
                if p.dangle {
                    ln = (i + p.danglePhase) % 2 == 0 ? 2 : 1.2
                } else if p.moving && i == p.frame {
                    ln = 1
                }
                R(lx[i], bb, 2, ln, pw)
            }
        }
        R(-5, bt, 10, bb - bt, body)
        if v.stripes { for q in [-3.0, -0.5, 2.0] { R(q, bt, 1, 2, dk) } }
        if v.tux { R(-2, bt + 1, 4, bb - bt - 1, "white") }
        R(-7, armY + p.aL, 2.2, 2.5, pw)
        R(4.8, armY + p.aR, 2.2, 2.5, pw)
        R(-6, ht, 12, 6, body)
        for left in [true, false] {
            R(left ? -6 : 4, ht - 2, 2, 1, pw)
            R(left ? -6 : 3, ht - 1, 3, 1, pw)
            R(left ? -4.8 : 3.8, ht - 1, 1, 1, v.earIn ?? "pinkL")
        }
        if v.stripes { R(-0.5, ht, 1, 1.6, dk); R(-2.5, ht, 0.8, 1.2, dk); R(1.7, ht, 0.8, 1.2, dk) }
        if let pt = pts { R(-3.5, ht + 2, 7, 4, pt) }
        R(-2.5, ht + 3.5, 5, 2.5, mz)
        let ey = ht + 2 + p.ly
        eye(p.eye, -4 + p.lx, ey, ecol)
        eye(p.eye, 3 + p.lx, ey, ecol)
        R(-0.5, ht + 3.4, 1, 1, pts == nil ? "pinkL" : "ink")
        R(-1, ht + 4.4, 0.8, 0.6, "ink"); R(0.2, ht + 4.4, 0.8, 0.6, "ink")
        for wx in [-9.0, 6.0] {
            R(wx, ht + 3.4, 3, 0.4, "white"); R(wx, ht + 4.4, 3, 0.4, "white")
        }
        if p.cool {
            let gy = ey - 0.5
            R(-6, gy, 12, 1, "ink"); R(-5.5, gy, 4.5, 2.6, "ink"); R(1, gy, 4.5, 2.6, "ink")
            R(-4.5, gy + 1, 1, 1, "greyD"); R(2, gy + 1, 1, 1, "greyD")
        }
        a.top = ht
        a.hw = 6
        a.exL = -4 + p.lx
        a.exR = 3 + p.lx
        a.ey = ey
        a.my = ht + 4.6
        a.chY = ht + 3.8
        a.chL = -5.6
        a.chR = 3.6
        a.cw = 2
        a.ny = bt - 0.5
        a.nw = 10
        a.bt = bt
        a.bb = bb
        a.armY = armY
        a.armR = p.aR
        a.armL = p.aL
        a.fxTop = ht - 2
        a.ghostY = -19
        return a
    }

    // Extras that belong to one animal only (drawn on top of the body, before the cosmetics)
    func extras(_ extra: String?, _ a: Anchor) {
        guard let extra = extra else { return }
        switch extra {
        case "scratch":
            R(10, -22, 2, 24, "greyD"); R(10, -22, 0.6, 24, "grey")
            for dy in [-12.0, -10.8, -9.6] { R(9.2, dy, 0.5, 2, "brownD") }
        case "groom":
            R(5.2, a.ey + 2.6, 1.4, 1.2, "pinkL")
        case "purr":
            for i in 0..<2 {
                R(-12, a.ey + 1.5 + Double(i) * 2, 3, 0.6, "white")
                R(9, a.ey + 1.5 + Double(i) * 2, 3, 0.6, "white")
            }
        case "hunt":
            R(9, -3, 4, 2, "greyD"); R(12.5, -3.4, 1.2, 1.2, "greyD"); R(8, -2.4, 1, 0.5, "pinkL")
            R(11.5, -2.4, 0.6, 0.6, "ink")
            M(Roomies.plus3, 14, -6, ["X": "white"])
        case "run":
            for i in 0..<3 {
                let d = Double(i)
                R(-15 + d, -8 + d * 2.4, 4 - d, 0.5, "white")
            }
        default: break
        }
    }

    func footprint(_ x: Double, _ y: Double) {
        R(x - 1, y, 2.6, 0.6, "orangeD"); R(x - 0.4, y - 0.6, 0.5, 0.6, "orangeD")
        R(x + 0.5, y - 0.6, 0.5, 0.6, "orangeD"); R(x + 1.4, y - 0.6, 0.5, 0.6, "orangeD")
    }

    // MARK: Cosmetics

    func sw(_ n: Double, _ a: Anchor) -> Double { return max(1, (n * 2 * a.hw / 14.0).rounded()) }

    func hat(_ k: String, _ a: Anchor) {
        let t = a.top, W = 2 * a.hw
        switch k {
        case "cap":
            Rc(t - 5, 2, 1, "white"); Rc(t - 4, sw(6, a), 1, "hatBlue"); Rc(t - 3, sw(10, a), 1, "hatBlue")
            Rc(t - 2, sw(12, a), 1, "hatBlue"); Rc(t - 1, sw(13, a) + 0.5, 1.2, "white")
        case "party":
            let pw = [1.0, 1, 2, 3, 4, 5, 6]
            let pc = ["yellow", "pink", "blue", "pink", "blue", "pink", "blue"]
            let mx = W >= 12 ? 6.0 : 5.0
            for i in 0..<7 { Rc(t - 7 + Double(i), min(pw[i], mx), 1, pc[i]) }
        case "phones":
            Rc(t - 1.6, W - 0.5, 1.1, "ink")
            R(-a.hw - 1, t - 1, 1.5, 1.6, "ink"); R(a.hw - 0.5, t - 1, 1.5, 1.6, "ink")
            R(-a.hw - 1.6, t + 0.5, 1.6, 2.5, "ink"); R(a.hw, t + 0.5, 1.6, 2.5, "ink")
            R(-a.hw - 1.6, t + 1, 0.6, 1.5, "teal"); R(a.hw + 1, t + 1, 0.6, 1.5, "teal")
        case "tophat":
            Rc(t - 6, sw(7, a), 5, "ink"); Rc(t - 2.2, sw(7, a), 1.2, "red"); Rc(t - 1, sw(11, a) + 1, 1, "ink")
        case "crown":
            let w = sw(9, a)
            R(-w / 2, t - 4, 1.5, 2, "crownGold"); R(-0.75, t - 4.6, 1.5, 2.6, "crownGold"); R(w / 2 - 1.5, t - 4, 1.5, 2, "crownGold")
            Rc(t - 2, w, 2, "crownGold"); R(-0.5, t - 1.5, 1, 1, "red")
            if w >= 6 { R(-w / 2 + 1.2, t - 1.5, 1, 1, "blue"); R(w / 2 - 2.2, t - 1.5, 1, 1, "blue") }
        case "flower":
            R(-0.5, t - 3, 1, 3, "green"); R(0.5, t - 2, 1.5, 1, "green")
            Rc(t - 5, 3, 1, "pink"); R(-0.5, t - 6, 1, 3, "pink"); R(-0.5, t - 5, 1, 1, "yellow")
        case "cowboy":
            let bw = W + 4
            Rc(t - 1, bw, 1.2, "brown"); R(-bw / 2, t - 2, 1.6, 1, "brown"); R(bw / 2 - 1.6, t - 2, 1.6, 1, "brown")
            Rc(t - 4, sw(7, a), 3, "brown"); Rc(t - 5, sw(4, a), 1, "brown"); Rc(t - 2, sw(7, a), 0.8, "brownD")
            R(-0.5, t - 4, 1, 1, "brownD")
        case "wizard":
            let ww = [1.0, 2, 3, 3, 4, 5, 6]
            for i in 0..<7 { Rc(t - 10 + Double(i), min(ww[i], max(2, sw(6, a))), 1, "indigo") }
            R(1, t - 11, 1.5, 1, "indigo")
            Rc(t - 2.3, max(sw(8, a), 5), 1.2, "indigoD"); Rc(t - 1.3, sw(12, a) + 1, 1.3, "indigo")
            R(-0.5, t - 7, 1, 1, "yellow"); R(1.2, t - 5, 1, 1, "yellow"); R(-1.8, t - 4.6, 0.8, 0.8, "yellow")
        case "chef":
            Rc(t - 8, sw(6, a), 1, "white"); Rc(t - 7, sw(9, a), 2, "white"); Rc(t - 5, sw(11, a), 1, "white")
            Rc(t - 4, sw(8, a), 3, "white"); Rc(t - 1.5, sw(9, a), 0.8, "grey")
            R(-1.4, t - 3.8, 0.5, 2, "grey"); R(0.9, t - 3.8, 0.5, 2, "grey")
        case "pirate":
            Rc(t - 4, sw(5, a), 1, "ink"); Rc(t - 3, sw(9, a), 1, "ink"); Rc(t - 2, sw(13, a), 2, "ink")
            R(-sw(13, a) / 2 - 1, t - 3, 1.5, 1.2, "ink"); R(sw(13, a) / 2 - 0.5, t - 3, 1.5, 1.2, "ink")
            Rc(t - 3.4, 2, 1.4, "white"); Rc(t - 1.6, 4, 0.5, "white")
        case "prop":
            Rc(t - 3, sw(5, a), 1, "red"); Rc(t - 2, sw(9, a), 1, "yellow"); Rc(t - 1, sw(12, a), 1, "hatBlue")
            R(-0.25, t - 5, 0.5, 2, "greyD"); Rc(t - 5.7, sw(10, a), 0.7, "grey")
            R(-sw(10, a) / 2, t - 5.7, 1.2, 0.7, "red"); R(sw(10, a) / 2 - 1.2, t - 5.7, 1.2, 0.7, "green")
        case "grad":
            Rc(t - 3, sw(13, a), 1, "ink"); Rc(t - 4, sw(7, a), 1, "ink"); Rc(t - 2, sw(8, a), 2, "ink")
            R(-0.5, t - 3.6, 1, 0.6, "gold")
            let cx = sw(13, a) / 2 - 1.5
            R(cx, t - 3, 0.6, 3, "gold"); R(cx - 0.2, t, 1, 1, "gold")
        case "halo":
            let wb = max(3, sw(6, a))
            Rc(t - 6, wb, 1, "crownGold"); Rc(t - 4, wb, 1, "crownGold")
            R(-wb / 2 - 1, t - 5, 1, 1, "crownGold"); R(wb / 2, t - 5, 1, 1, "crownGold")
        case "horns":
            for sg in [-1.0, 1.0] {
                let x = sg < 0 ? (-a.hw + 0.5) : (a.hw - 1.5)
                R(x, t - 1, 1.5, 1, "red")
                R(x - 0.3 * sg, t - 2, 1.5, 1, "red")
                R(x - 0.8 * sg, t - 3, 1, 1, "redD")
            }
        case "bow":
            let x = max(2.5, a.hw * 0.45)
            R(x - 3, t - 3, 2, 3, "pink"); R(x + 1, t - 3, 2, 3, "pink"); R(x - 1, t - 2.2, 2, 2, "pinkL")
            R(x - 0.5, t - 1.7, 1, 1, "pink")
        case "pumpkin":
            Rc(t - 5, sw(8, a), 1, "orange"); Rc(t - 4, sw(11, a), 3, "orange"); Rc(t - 1, sw(9, a), 1, "orangeD")
            R(-0.5, t - 6.5, 1.5, 2, "green")
            R(-sw(11, a) / 2 + 1.6, t - 4, 0.8, 3, "orangeD"); R(sw(11, a) / 2 - 2.4, t - 4, 0.8, 3, "orangeD")
            R(-1.8, t - 3.3, 1, 1, "ink"); R(0.8, t - 3.3, 1, 1, "ink"); Rc(t - 1.8, 2.6, 0.7, "ink")
        case "santa":
            Rc(t - 1.2, sw(13, a), 1.6, "white")
            Rc(t - 2.8, sw(11, a), 1.6, "red"); Rc(t - 3.8, sw(9, a), 1, "red"); Rc(t - 4.8, sw(7, a), 1, "red")
            R(0.5, t - 5.8, 3, 1, "red"); R(2.5, t - 5, 2, 1, "red"); R(3.8, t - 4.6, 2, 2, "white")
        default: break
        }
    }

    func face(_ k: String, _ a: Anchor) {
        let cl = a.exL + 0.5, cr = a.exR + 0.5, ey = a.ey, gap = cr - cl
        let lw = min(4, (gap - 1).rounded(.down))
        switch k {
        case "nerd":
            for cx in [cl, cr] {
                let x = cx - lw / 2.0
                R(x, ey - 1, lw, 0.8, "ink"); R(x, ey + 2.2, lw, 0.8, "ink")
                R(x, ey - 1, 0.8, 4, "ink"); R(x + lw - 0.8, ey - 1, 0.8, 4, "ink")
                R(x + 1.2, ey - 0.2, 0.7, 0.7, "white")
            }
            R(cl + lw / 2.0, ey + 0.3, gap - lw, 0.8, "ink")
            R(cl - lw / 2.0 - 1.2, ey, 1.2, 0.7, "ink"); R(cr + lw / 2.0, ey, 1.2, 0.7, "ink")
        case "sun":
            let wl = lw + 1
            for cx in [cl, cr] { R(cx - wl / 2.0, ey - 0.3, wl, 2.8, "ink") }
            R(cl - wl / 2.0, ey - 0.8, gap + wl, 1, "ink")
            R(cl - wl / 2.0 + 0.8, ey + 0.6, 1, 1, "white"); R(cr - wl / 2.0 + 0.8, ey + 0.6, 1, 1, "white")
        case "monocle":
            let x = cr - 2
            R(x, ey - 1, 4, 0.8, "crownGold"); R(x, ey + 2.2, 4, 0.8, "crownGold")
            R(x, ey - 1, 0.8, 4, "crownGold"); R(x + 3.2, ey - 1, 0.8, 4, "crownGold")
            R(x + 1.2, ey - 0.2, 0.7, 0.7, "white")
            R(cr + 1.6, ey + 3, 0.5, 4.5, "crownGold"); R(cr + 1.6, ey + 7, 1, 1, "crownGold")
        case "stache":
            let y = a.my
            Rc(y, 2.4, 1, "stache"); R(-4, y + 0.6, 3, 1, "stache"); R(1, y + 0.6, 3, 1, "stache")
            R(-4.8, y, 1, 1, "stache"); R(3.8, y, 1, 1, "stache")
        case "patch":
            R(cl - 2, ey - 1, 4, 4, "ink")
            R(-a.hw, ey - 1.2, a.hw + cl - 2, 0.7, "ink")
            R(cl + 1.4, ey - 2.5, 0.7, 2, "ink"); R(cl + 2, ey - 3.3, 4, 0.7, "ink")
        case "cheeks":
            R(a.chL, a.chY, a.cw, 1, "pinkL"); R(a.chR, a.chY, a.cw, 1, "pinkL")
        default: break
        }
    }

    func neck(_ k: String, _ a: Anchor) {
        let y = a.ny, nw = a.nw
        switch k {
        case "bowtie":
            R(-3.2, y, 2.6, 2, "red"); R(0.6, y, 2.6, 2, "red"); R(-0.7, y + 0.3, 1.4, 1.4, "redD")
        case "scarf":
            Rc(y, nw, 1.6, "red")
            for i in 0..<Int(nw / 3) { R(-nw / 2 + 1 + Double(i) * 3, y, 0.7, 1.6, "white") }
            let x = nw / 2 - 3
            R(x, y + 1.6, 2, 3.5, "red"); R(x, y + 3, 2, 0.7, "white")
        case "bandana":
            for i in 0..<4 { Rc(y + Double(i), max(1, nw - 2 * Double(i)), 1, "blue") }
            R(-1.5, y + 0.2, 0.7, 0.7, "white"); R(1.4, y + 0.5, 0.7, 0.7, "white"); R(-0.2, y + 1.5, 0.7, 0.7, "white")
        case "bell":
            Rc(y, nw - 1, 1, "red")
            R(-1, y + 1, 2, 2, "crownGold"); R(-0.3, y + 2.2, 0.6, 0.5, "ink"); R(-1, y + 1, 0.7, 0.7, "white")
        default: break
        }
    }

    func fx(_ k: String, _ a: Anchor) {
        let t = a.fxTop, h = a.hw
        switch k {
        case "sparkle":
            M(Roomies.plus5, -h - 5, t + 1, ["X": "yellow"]); R(-h - 3.5, t + 2.5, 2, 2, "white")
            M(Roomies.plus3, h + 3, t - 3, ["X": "white"]); M(Roomies.plus3, h + 2, -5, ["X": "yellow"])
            M(Roomies.plus3, -h - 3, -4, ["X": "white"])
        case "hearts":
            M(Roomies.heart5, -3, t - 8, ["X": "red"]); M(Roomies.heart5, h + 1, t - 3, ["X": "pink"])
            M(Roomies.heart5, -h - 5, t - 2, ["X": "pinkL"])
        case "rain":
            let y = t - 11
            R(-6, y + 2, 12, 2, "cloud"); R(-4, y, 4, 2, "cloud"); R(0, y + 0.8, 4, 1.2, "cloud"); R(-5, y + 3.2, 10, 1, "cloudD")
            let xs = [-4.0, -1, 2, 5], ds = [0.0, 2, 1, 3]
            for i in 0..<4 { R(xs[i], y + 5 + ds[i], 0.6, 1.6, "rain") }
            let xs2 = [-5.5, -2.5, 1, 4], ds2 = [4.0, 6, 5, 7]
            for i in 0..<4 { R(xs2[i], y + 5 + ds2[i], 0.6, 1.6, "rain") }
        case "ghost":
            let gx = -h - 8, gy = a.ghostY
            M(Roomies.ghostBmp, gx, gy, ["X": "ghost", "#": "ink"])
            R(gx, gy + 5, 1, 1, "ghostD"); R(gx + 4, gy + 4, 1, 1, "ghostD")
            R(gx + 1, gy + 3.2, 3, 0.8, "ghostD")
        case "trophy":
            let x = h + 1.6, y = -13.0
            R(x, y, 4, 3, "crownGold"); R(x - 1, y + 0.5, 1, 1.6, "crownD"); R(x + 4, y + 0.5, 1, 1.6, "crownD")
            R(x + 0.6, y + 0.6, 0.8, 1.2, "white")
            R(x + 1.2, y + 3, 1.6, 2, "crownD"); R(x + 0.3, y + 5, 3.4, 1, "crownGold"); R(x, y + 6, 4, 1, "crownD")
        default: break
        }
    }

    // MARK: The animals and their colours

    static let duckVars = [
        Var("Gelb", "Yellow", body: "#F5C542", dark: "#D9A520", belly: "#FBE08A", beak: "#F28C28", beakD: "#D9731A"),
        Var("Weiß", "White", body: "#F4F2EA", dark: "#CFCBC0", belly: "#FFFFFF", beak: "#F28C28", beakD: "#D9731A"),
        Var("Stockente", "Mallard", body: "#8B6B4A", dark: "#6B4F34", belly: "#C9B79C", beak: "#E8C230", beakD: "#CFA920", head: "#1F7A4D", ring: true),
        Var("Rosa", "Pink", body: "#F6A6C1", dark: "#E27FA3", belly: "#FFD3E1", beak: "#F28C28", beakD: "#D9731A"),
        Var("Blau", "Blue", body: "#6FB1E8", dark: "#4A90D9", belly: "#A9D3F5", beak: "#F5C542", beakD: "#D9A520"),
        Var("Grün", "Green", body: "#7ED6A4", dark: "#3FA66B", belly: "#BDEBD1", beak: "#F28C28", beakD: "#D9731A"),
        Var("Lila", "Purple", body: "#B79BF0", dark: "#9B6FE8", belly: "#D9C9F8", beak: "#F5C542", beakD: "#D9A520")]

    static let catVars = [
        Var("Grau", "Grey", body: "#9AA0AB", dark: "#6E7480", muzzle: "#D7DAE0", stripes: true),
        Var("Schwarz", "Black", body: "#34343C", dark: "#1F1F25", muzzle: "#55555F", eyeC: "#F5E04A", earIn: "#7A5568"),
        Var("Orange", "Orange", body: "#F0A04B", dark: "#C97A24", muzzle: "#FBD9A6", stripes: true),
        Var("Weiß", "White", body: "#F4F2EA", dark: "#CFCBC0", muzzle: "#FFFFFF"),
        Var("Siamese", "Siamese", body: "#F3E2C7", dark: "#6B4A35", muzzle: "#FBF1DE", eyeC: "#3B8FD6", points: "#6B4A35", tail: "#F3E2C7"),
        Var("Lila", "Purple", body: "#B79BF0", dark: "#9B6FE8", muzzle: "#E1D5FA"),
        Var("Blau", "Blue", body: "#7C93B5", dark: "#566B8C", muzzle: "#C3CFE0")]

    // One whole animal with its cosmetics. animal: 0 Clawd, 1 duck, 2 cat. The caller has already moved ox / oy for sway and lift.
    func animal(_ animal: Int, _ variant: Int, _ p: Pose, _ head: String, _ faceK: String, _ neckK: String) {
        let a: Anchor
        if animal == 1 {
            a = duck(p, Roomies.duckVars[variant])
        } else if animal == 2 {
            a = cat(p, Roomies.catVars[variant])
        } else {
            a = clawd(p, Cfg.colVals[variant])
        }
        extras(p.extra, a)
        if faceK != "none" { face(faceK, a) }
        if neckK != "none" { neck(neckK, a) }
        if head != "none" { hat(head, a) }
    }
}

// MARK: - Duck footprints and the quote window

// Duck footprints stay where she walked: a click-through overlay over the whole screen (the pet window itself is only a few cells wide)
final class TrackView: NSView {
    weak var pet: Pet?
    let rm = Roomies()
    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext, let prints = pet?.prints else { return }
        c.setShouldAntialias(false)
        rm.ctx = c
        rm.scale = Double(window?.backingScaleFactor ?? 2)
        for p in prints {
            c.saveGState()
            c.setAlpha(CGFloat(min(1, p.life / 4.0) * 0.85))
            c.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
            c.rotate(by: CGFloat(p.heading * .pi / 180))
            rm.S = p.size
            rm.ox = 0
            rm.oy = 0
            rm.footprint(0, -1.2)
            c.restoreGState()
        }
    }
}

// x, y on the screen, seconds left, cell size, heading in degrees
struct FootPrint {
    var x = 0.0, y = 0.0, life = 0.0, size = 0.0, heading = 0.0
}

// A borderless window that floats above other apps but below the pet and never takes the focus.
func overlayPanel(_ rect: NSRect) -> NSPanel {
    let w = PetPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    w.isOpaque = false
    w.backgroundColor = .clear
    w.hasShadow = false
    w.level = .floating
    w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    w.hidesOnDeactivate = false
    w.isReleasedWhenClosed = false
    return w
}

// The little text window the duck drags onto the screen with a quote in it
final class QuoteView: NSView {
    let quote: NSAttributedString, who: NSAttributedString, title: NSAttributedString, close: NSAttributedString
    var onClick: (() -> Void)?
    override var isFlipped: Bool { return true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }

    init(_ quoteText: String, _ whoText: String) {
        let dark = isDark
        let text = dark ? NSColor.white : Ink.ink
        let right = NSMutableParagraphStyle()
        right.alignment = .right
        quote = NSAttributedString(string: quoteText, attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: text])
        who = NSAttributedString(string: whoText, attributes: [
            .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 12), toHaveTrait: .italicFontMask),
            .foregroundColor: text.withAlphaComponent(0.7), .paragraphStyle: right])
        title = NSAttributedString(string: T("ente.txt – TextEdit", "duck.txt - TextEdit"), attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: Ink.ink])
        close = NSAttributedString(string: "x", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: Ink.ink])
        super.init(frame: NSRect(x: 0, y: 0, width: QuoteWindow.W, height: 100))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var quoteH: CGFloat {
        return quote.boundingRect(with: NSSize(width: QuoteWindow.W - 32, height: 2000), options: [.usesLineFragmentOrigin]).height.rounded(.up)
    }
    var whoH: CGFloat { return who.boundingRect(with: NSSize(width: QuoteWindow.W - 32, height: 200), options: [.usesLineFragmentOrigin]).height.rounded(.up) }
    var fullH: CGFloat { return 22 + 12 + quoteH + 6 + whoH + 12 }

    override func draw(_ dirtyRect: NSRect) {
        let frame = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
        hex(isDark ? "#2B2B2F" : "#FFFDF3").setFill()
        frame.fill()
        NSGraphicsContext.saveGraphicsState()
        frame.addClip()
        hex("#F5C542").setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 22).fill()
        NSGraphicsContext.restoreGraphicsState()
        Ink.ink.setStroke()
        frame.lineWidth = 2
        frame.stroke()
        title.draw(at: NSPoint(x: 10, y: 4))
        close.draw(at: NSPoint(x: bounds.width - 18, y: 4))
        quote.draw(with: NSRect(x: 16, y: 34, width: bounds.width - 32, height: quoteH), options: [.usesLineFragmentOrigin])
        who.draw(with: NSRect(x: 16, y: 34 + quoteH + 6, width: bounds.width - 32, height: whoH), options: [.usesLineFragmentOrigin])
    }

    override func mouseUp(with event: NSEvent) { onClick?() }
}

final class QuoteWindow {
    static let W = 270.0
    let panel: NSPanel
    var life: Timer?
    var closing = false

    var height: Double { return Double(panel.frame.height) }

    init(_ quote: String, _ who: String) {
        let view = QuoteView(Cfg.lang == "de" ? "„" + quote + "“" : "“" + quote + "”", "— " + who)
        let h = view.fullH
        view.setFrameSize(NSSize(width: QuoteWindow.W, height: Double(h)))
        panel = overlayPanel(NSRect(x: -5000, y: -5000, width: QuoteWindow.W, height: Double(h)))
        panel.contentView = view
        view.onClick = { [weak self] in self?.fade() }
        wait(30)   // if the duck never gets to drop it
    }

    func wait(_ secs: Double) {
        life?.invalidate()
        let t = Timer(timeInterval: secs, repeats: false) { [self] _ in fade() }
        RunLoop.main.add(t, forMode: .common)
        life = t
    }

    func show() { panel.orderFrontRegardless() }

    // top-left corner on the screen, the way the pet counts
    func move(_ left: Double, _ top: Double, _ screenH: Double) {
        panel.setFrameOrigin(NSPoint(x: left, y: screenH - top - height))
    }

    // The duck let go: it stays a while, then goes away
    func drop() { wait(14) }

    func fade() {
        if closing { return }
        closing = true
        life?.invalidate()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            panel.animator().alphaValue = 0
        }, completionHandler: { [self] in panel.close() })
    }
}

// A small animated animal for the welcome window (pixel art drawn with the same code as the pet itself).
final class PetPreview: NSView {
    var animal = 0, variant = 0
    var dress = false        // wear the cosmetics that are set
    var hover = false        // happy eyes
    var walk = false         // walk on the spot
    let cell: Double, w: Double, h: Double
    let rm = Roomies()
    var timer: Timer?
    var anim = 0.0

    override var isFlipped: Bool { return true }
    override var intrinsicContentSize: NSSize { return NSSize(width: w, height: h) }

    init(_ animal: Int, _ cell: Double, _ w: Double, _ h: Double) {
        self.animal = animal
        self.cell = cell
        self.w = w
        self.h = h
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: h))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidMoveToWindow() {
        timer?.invalidate()
        timer = nil
        if window == nil { return }
        let t = Timer(timeInterval: 0.11, repeats: true) { [weak self] _ in
            self?.anim += 0.11
            self?.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    override func hitTest(_ point: NSPoint) -> NSView? { return nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        let dpi = Double(window?.backingScaleFactor ?? 2)
        c.setShouldAntialias(false)
        rm.ctx = c
        rm.scale = dpi
        rm.S = max(1, (cell * dpi).rounded()) / dpi
        rm.ox = (w / 2 * dpi).rounded() / dpi
        rm.oy = h - 3 * rm.S
        var p = Pose()
        let fr = Int(anim * 5) % 2
        p.eye = hover ? Roomies.eyeHappy : (anim.truncatingRemainder(dividingBy: 3.3) > 3.15 ? Roomies.eyeClosed : Roomies.eyeOpen)
        p.moving = walk
        p.frame = fr
        p.bob = walk ? (fr == 0 ? 0 : -0.6) : sin(anim * 2.2) * 0.25
        if hover { p.aR = -3 + Double(Int(anim * 6) % 2) }
        rm.animal(animal, max(0, min(6, variant)), p, dress ? Cfg.hat : "none", dress ? Cfg.face : "none", dress ? Cfg.neck : "none")
    }
}

// One of the three cards of the welcome window: a moving animal and its name, one click picks it.
final class AnimalCard: NSView {
    let preview: PetPreview
    let name = NSTextField(labelWithString: "")
    let accent: NSColor
    var over = false
    var onPick: (() -> Void)?

    override var isFlipped: Bool { return true }
    override var intrinsicContentSize: NSSize { return NSSize(width: 100, height: 112) }

    init(_ animal: Int) {
        preview = PetPreview(animal, 3, 90, 66)
        accent = hex(Cfg.accentHex(animal))
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 112))
        preview.walk = true
        preview.setFrameOrigin(NSPoint(x: 5, y: 10))
        addSubview(preview)
        name.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        name.alignment = .center
        name.frame = NSRect(x: 0, y: 82, width: 100, height: 20)
        addSubview(name)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // the card itself takes the click, not the label on it
    override func hitTest(_ point: NSPoint) -> NSView? { return frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        let r = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        r.fill()
        if over {
            accent.setStroke()
            r.lineWidth = 2
            r.stroke()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        over = true
        preview.hover = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        over = false
        preview.hover = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) { onPick?() }
}

// MARK: - The pet

struct Particle {
    var kind = 0
    var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, life = 0.0, max = 0.0, size = 0.0
    var text = ""
    var color = NSColor.white
}

// Another app's window, used as a platform to stand on.
struct Plat {
    var id = 0
    var l = 0.0, t = 0.0, r = 0.0, b = 0.0
    var stand = false
}

final class Pet: NSView {
    // Canvas size in cells (one cell = one "pixel" of Clawd)
    static let CW = 48.0, CH = 36.0
    let pText = 0, pHeart = 1, pSteam = 2, pCrumb = 3
    let eyeOpen = 0, eyeClosed = 1, eyeHappy = 2, eyeWide = 3, eyeDizzy = 4

    static let heart = [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
    static let balloon = ["..XXXX..", ".XXXXXX.", "XXoXXXXX", "XXoXXXXX", "XXXXXXXX", "XXXXXXXX", ".XXXXXX.", "..XXXX..", "...XX..."]
    static let cookieBmp = [".XX.", "XdXX", "XXdX", ".XX."]

    // Speech bubble lines: [German, English]
    static let petLines = [
        ["Hihi!", "Das kitzelt!", "Mehr davon!", "Du bist nett!", "Schnurr...", "Nochmal!", "Hach, schön."],
        ["Hehe!", "That tickles!", "More, please!", "You're nice!", "Purr...", "Again!", "Ahh, lovely."]]
    static let idleLines = [
        ["Was machst du da?", "Schöner Desktop!", "Ich bin Clawd!", "Zeit für eine Pause?", "Trink mal Wasser!", "Du schaffst das!", "Mir ist langweilig...", "Psst... Speichern nicht vergessen!", "Klick mich mal an!"],
        ["What are you up to?", "Nice desktop!", "I'm Clawd!", "Time for a break?", "Drink some water!", "You've got this!", "I'm bored...", "Psst... don't forget to save!", "Click me!"]]
    static let ideaLines = [
        ["Idee!", "Heureka!", "Was wäre, wenn...", "42!", "Ich hab's!"],
        ["Idea!", "Eureka!", "What if...", "42!", "Got it!"]]
    static let codeLines = [
        ["Nur noch ein Bug...", "Kompiliert!", "Läuft bei mir.", "git push --force?", "Wer hat das geschrieben? ...Ich."],
        ["Just one more bug...", "It compiles!", "Works on my machine.", "git push --force?", "Who wrote this? ...Me."]]
    static let dragLines = [
        ["Huch!", "Hey, lass mich runter!", "Wohin geht's?", "Ich kann fliegen!"],
        ["Whoa!", "Hey, put me down!", "Where are we going?", "I can fly!"]]
    static let codeBits = ["{ }", "</>", "01", "fn", "==", "//", "[ ]", ";"]

    static let actNames = ["walk", "run", "sleep", "code", "coffee", "read", "dance", "jump", "flip", "wave", "think", "cool", "climb", "juggle", "balloon", "stretch", "chase", "quak", "puddle", "purr", "groom", "scratch", "quote"]
    static let actWeights = [30, 0, 6, 0, 6, 6, 5, 3, 0, 4, 0, 4, 0, 0, 0, 4, 0, 5, 3, 3, 5, 3, 3]
    static let actLabelsEn = ["Walk", "Zoom", "Sleep", "Code", "Drink coffee", "Read", "Dance", "Hop", "Flip", "Wave", "Think", "Be cool", "Climb the wall", "Juggle", "Balloon ride", "Stretch", "Chase the mouse", "Quack", "Splash in a puddle", "Purr", "Wash up", "Scratch the edge", "Bring a quote"]
    static let actLabelsDe = ["Spazieren", "Flitzen", "Schlafen", "Programmieren", "Kaffee trinken", "Lesen", "Tanzen", "Hüpfen", "Salto", "Winken", "Nachdenken", "Cool sein", "Wand hochklettern", "Jonglieren", "Ballonfahrt", "Strecken", "Maus jagen", "Quaken", "In der Pfütze planschen", "Schnurren", "Putzen", "An der Kante kratzen", "Zitat bringen"]
    static let demoScript = ["wave", "walk", "code", "coffee", "read", "dance", "jump", "flip", "cool", "juggle", "pet", "eat", "stretch", "sleep", "chase", "climb", "balloon"]
    static let busy = ["drag", "fall", "dizzy", "pet", "purr", "eat", "jump", "flip", "climb", "balloon", "chase", "scratch"]

    static func actLevel(_ name: String) -> Int {
        return name == "flip" ? 2 : name == "juggle" ? 3 : name == "balloon" ? 4 : name == "climb" ? 5 : name == "puddle" ? 2 : name == "scratch" ? 3 : 1
    }

    // Some activities belong to one animal only
    static func actFor(_ n: String) -> Bool {
        if n == "quak" || n == "puddle" || n == "quote" { return Cfg.animal == 1 }
        if n == "purr" || n == "groom" || n == "scratch" { return Cfg.animal == 2 }
        return true
    }

    static let nameDe = ["Clawd", "die Ente", "die Katze"], nameEn = ["Clawd", "the duck", "the cat"]
    func nm(_ text: String) -> String { return text.replacingOccurrences(of: "Clawd", with: (Cfg.lang == "de" ? Pet.nameDe : Pet.nameEn)[Cfg.animal]) }

    static let petLinesDuck = [
        ["Quak!", "Das kitzelt!", "Mehr davon!", "Du bist nett!", "Nochmal!", "Hach, schön."],
        ["Quack!", "That tickles!", "More, please!", "You're nice!", "Again!", "Ahh, lovely."]]
    static let petLinesCat = [
        ["Prrr...", "Mehr davon!", "Du bist nett!", "Miau!", "Nochmal!", "Hach, schön."],
        ["Purr...", "More, please!", "You're nice!", "Meow!", "Again!", "Ahh, lovely."]]
    static let duckLines = [
        ["Quak!", "Quak quak!", "Wer hat Brot?", "Heute schon geplanscht?", "Quak... Pause?"],
        ["Quack!", "Quack quack!", "Anyone got bread?", "Had a splash today?", "Quack... break time?"]]
    static let catLines = [
        ["Miau!", "Wo ist mein Futter?", "Ich war schon immer hier.", "*streckt sich*", "Prrr..."],
        ["Meow!", "Where's my food?", "I was here first.", "*stretches*", "Purr..."]]
    static let quotes = [
        ["Fantasie ist wichtiger als Wissen.", "Imagination is more important than knowledge.", "Albert Einstein"],
        ["Ich denke, also bin ich.", "I think, therefore I am.", "René Descartes"],
        ["Das Einzige, was wir zu fürchten haben, ist die Furcht selbst.", "The only thing we have to fear is fear itself.", "Franklin D. Roosevelt"],
        ["Ein kleiner Schritt für einen Menschen, ein riesiger Sprung für die Menschheit.", "That's one small step for man, one giant leap for mankind.", "Neil Armstrong"],
        ["Ich habe einen Traum.", "I have a dream.", "Martin Luther King Jr."],
        ["Bleib hungrig, bleib verrückt.", "Stay hungry, stay foolish.", "Steve Jobs"],
        ["Der Mensch ist, was er isst.", "Man is what he eats.", "Ludwig Feuerbach"],
        ["Ich bin ein Berliner.", "Ich bin ein Berliner.", "John F. Kennedy"],
        ["Es ist nicht genug zu wissen, man muss auch anwenden.", "Knowing is not enough; we must apply.", "Johann Wolfgang von Goethe"],
        ["Ich weiß, dass ich nichts weiß.", "I know that I know nothing.", "Sokrates"],
        ["Im Leben gibt es nichts zu fürchten, es gibt nur zu verstehen.", "Nothing in life is to be feared, it is only to be understood.", "Marie Curie"]]

    var parts: [Particle] = []
    var S = 5.0
    var scale = 2.0          // device pixels per point
    var screenH = 900.0      // height of the main screen, to convert from Cocoa's bottom-left origin
    var workL = 0.0, workT = 0.0, workR = 1440.0, workB = 900.0

    // State
    var st = "idle", lastAct = ""
    var t = 0.0, dur = 0.0, anim = 0.0, x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, tx = 0.0, ty = 0.0, rot = 0.0
    var climbTop = 0.0, spawnT = 0.0, hopT = 0.0, blinkT = 2.0, maxImpact = 0.0
    var phase = 0, hops = 0, side = 0, dir = 1
    var air = false, moving = false
    var curX = 0.0, curY = 0.0
    var winLeft = 0.0, ox = 0.0, oy = 0.0
    var last = CACurrentMediaTime()
    var bodyColor = hex(Cfg.orange)

    // Reacting to the user
    var keyCount: UInt32 = 0
    var typingT = 99.0, tapT = 0.0
    var tapArm = 0
    var typed = false, wasAway = false

    // Other windows as platforms
    var plats: [Plat] = []
    var perch = 0            // window he is standing on (0 = the Dock / bottom of the screen)
    var scanT = 0.0
    let myPid = Int(ProcessInfo.processInfo.processIdentifier)

    // Hunger, level
    var beat = 0.0
    var musicDance = false
    var petXpT = 0.0, saveT = 60.0, hungerNag = 20.0, hungerShow = 0.0

    // Pixel Roomies
    let rm = Roomies()
    var prints: [FootPrint] = []   // duck footprints
    var quakT = 0.0, printT = 0.0, topCells = 10.0, jumpY = 0.0, lastPx = 0.0, lastPy = 0.0, trackT = 0.0
    var printFoot = 0, sdir = 1, qdir = 1
    var track: NSPanel?
    var quoteWin: QuoteWindow?
    var onTheme: (() -> Void)?
    var scripted = false   // CLAWD_ACTS decides what happens

    // Demo modes and admin
    var demo = false
    var demoIdx = 0
    var adminOn = false, featDemo = false, fdMusic = false
    var fdStep = 0, fdXp = 0
    var fdT = 0.0, fdFood = 0.0
    var fdHat = "none"

    // Mouse
    var pressed = false, dragging = false, menuOpen = false
    var pressX = 0.0, pressY = 0.0, grabX = 0.0, grabY = 0.0, thvx = 0.0, thvy = 0.0

    // Speech bubble
    var bubbleText = ""
    var bubbleT = 0.0, bubbleAge = 0.0

    var logPath: String?
    var logT = 0.0
    var onMenu: ((NSEvent) -> Void)?

    // Self-test for the automatic build: the app plays with itself while a video is recorded
    var selfTest = false, gotRealMouse = false
    var stStep = 0, typeTick = 0
    var stT = 2.5, dragU = -1.0, typeSim = 0.0
    var fakeCur: (x: Double, y: Double)?
    var dragFrom = (x: 0.0, y: 0.0)
    var onAutoMenu: (() -> Void)?

    // Promo recording: the scenes of the video in a fixed order
    var promo = false
    var prStep = 0
    var prT = 1.0
    var onPromoMenu: (() -> Void)?

    override var isFlipped: Bool { return true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }

    var W: Double { return Pet.CW * S }
    var H: Double { return Pet.CH * S }

    // MARK: Start

    func start() {
        readScreen()
        applyScale()
        applyColor()
        x = workL + (workR - workL) / 2
        y = max(workT + 14 * S, workB - 150 * S)
        keyCount = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
        set("fall")
        air = true
        let hr = Calendar.current.component(.hour, from: Date())
        say(hr < 5 ? T("Noch wach?", "Still up?") : hr < 11 ? T("Guten Morgen!", "Good morning!") : hr < 18 ? nm(T("Hallo! Ich bin Clawd.", "Hi! I'm Clawd.")) : T("Guten Abend!", "Good evening!"), 4)
        place()
    }

    func readScreen() {
        guard let scr = NSScreen.screens.first else { return }
        screenH = Double(scr.frame.height)
        let v = scr.visibleFrame
        workL = Double(v.minX)
        workR = Double(v.maxX)
        workT = screenH - Double(v.maxY)
        workB = screenH - Double(v.minY)
        scale = Double(scr.backingScaleFactor)
    }

    func applyScale() {
        S = Double(Cfg.size)
        window?.setContentSize(NSSize(width: W, height: H))
        setFrameSize(NSSize(width: W, height: H))
    }

    func applyColor() {
        bodyColor = hex(Cfg.color)
        onTheme?()
    }

    func log(_ text: String) {
        guard let p = logPath else { return }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.S"
        let line = f.string(from: Date()) + " " + text + "\n"
        if let h = FileHandle(forWritingAtPath: p) {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8)!)
            h.closeFile()
        } else {
            try? line.write(toFile: p, atomically: true, encoding: .utf8)
        }
    }

    // MARK: Mouse

    func readCursor() {
        if let f = fakeCur {
            curX = f.x
            curY = f.y
            return
        }
        let m = NSEvent.mouseLocation
        curX = Double(m.x)
        curY = screenH - Double(m.y)
    }

    override func mouseDown(with e: NSEvent) {
        gotRealMouse = true
        if e.clickCount == 2 {
            if !air && (y >= ground - 1 || free()) { set(Cfg.level >= Pet.actLevel("flip") || demo ? "flip" : "jump") }
            return
        }
        press()
    }

    func press() {
        readCursor()
        pressed = true
        pressX = curX
        pressY = curY
        grabX = x - curX
        grabY = y - curY
        thvx = 0
        thvy = 0
    }

    override func mouseUp(with e: NSEvent) { release() }

    func release() {
        if !pressed { return }
        pressed = false
        if dragging {
            dragging = false
            set("fall")
            air = true
            let lim = 500 * S
            vx = max(-lim, min(lim, thvx))
            vy = max(-lim, min(lim, thvy))
            if abs(vx) + abs(vy) > 150 * S { say(T("Huiii!", "Wheee!"), 1.5) }
        } else if st == "sleep" {
            set("idle")
            say(T("Hm? Bin wach!", "Huh? I'm awake!"), 2.5)
        } else {
            petIt()
        }
    }

    override func rightMouseDown(with e: NSEvent) { onMenu?(e) }

    func petIt() {
        set(Cfg.animal == 2 ? "purr" : "pet")
        for _ in 0..<4 {
            spawn(pHeart, -6 + R() * 12, -(topCells + 1) - R() * 3, (R() - 0.5) * 3, -5 - R() * 3, 1.3 + R() * 0.5, "", 0, pal())
        }
        if Cfg.animal == 1 && R() < 0.5 { quak() }
        say(pick(Cfg.animal == 1 ? Pet.petLinesDuck : Cfg.animal == 2 ? Pet.petLinesCat : Pet.petLines), 2)
        if petXpT <= 0 {
            petXpT = 8
            addXp(1)
        }
    }

    func feed() {
        if dragging { return }
        hungerShow = 0
        if Cfg.food >= 85 {
            say(T("Ich bin pappsatt!", "I'm stuffed!"), 2.5)
            return
        }
        set("eat")
        Cfg.food = min(100, Cfg.food + 35)
        addXp(5)
    }

    func addXp(_ n: Int) {
        if demo || featDemo { return }
        let before = Cfg.level
        Cfg.xp += n
        spawn(pText, 0, -(rise() + 2), 0, -4, 1.5, "+\(n) XP", 2.3, Ink.yellow)
        if Cfg.level > before { levelUp() }
        Cfg.save()
    }

    func levelUp() {
        confetti()
        announce(levelText(Cfg.level), 5)
    }

    func confetti() {
        for _ in 0..<26 {
            spawn(pCrumb, -10 + R() * 20, -12 - R() * 8, (R() - 0.5) * 22, -6 - R() * 12, 1.2 + R() * 0.8, "", 0, pal())
        }
    }

    // "Level 3!" plus what that level unlocks.
    func levelText(_ lv: Int) -> String {
        var news: [String] = []
        let al = Cfg.lang == "de" ? Pet.actLabelsDe : Pet.actLabelsEn
        for i in 0..<Pet.actNames.count where Pet.actLevel(Pet.actNames[i]) == lv && Pet.actFor(Pet.actNames[i]) { news.append(al[i]) }
        for i in 0..<Cfg.colLevel.count where Cfg.colLevel[i] == lv { news.append(Cfg.colLabels[i]) }
        // cosmetics unlock with the highest level of all animals, so they only count when this one is the new top
        if lv > Cfg.othersTop() {
            let hn = Cfg.hatLevel, fxn = Cfg.fxLevel
            for i in 0..<hn.count where hn[i] == lv { news.append(Cfg.hatLabels[i]) }
            for i in 0..<Cfg.faceLevel.count where Cfg.faceLevel[i] == lv { news.append(Cfg.faceLabels[i]) }
            for i in 0..<Cfg.neckLevel.count where Cfg.neckLevel[i] == lv { news.append(Cfg.neckLabels[i]) }
            for i in 0..<fxn.count where fxn[i] == lv { news.append(Cfg.fxLabels[i]) }
        }
        var text = "Level \(lv)!"
        if !news.isEmpty { text += "\n" + T("Neu: ", "New: ") + news.joined(separator: ", ") }
        return text
    }

    var hatH: Double {
        switch Cfg.hat {
        case "cap": return 5
        case "party": return 7
        case "phones": return 2
        case "tophat": return 6
        case "crown": return 5
        case "flower": return 6
        case "cowboy": return 5
        case "wizard": return 11
        case "chef": return 8
        case "pirate": return 4
        case "prop": return 6
        case "grad": return 4
        case "halo": return 6
        case "horns": return 3
        case "bow": return 3
        case "pumpkin": return 7
        case "santa": return 6
        default: return 0
        }
    }

    // How far above his feet a speech bubble sits (head, hat and a rain cloud)
    func rise() -> Double { return topCells + 3 + max(hatH, Cfg.fx == "rain" ? 11 : 0) }

    // The duck walks all over the screen, not only along the Dock (like Desktop Goose)
    func free() -> Bool { return Cfg.animal == 1 && st != "fall" && st != "drag" }

    func freeY() -> Double { return workT + 24 * S + R() * max(0, workB - workT - 24 * S) }

    func moveTo2(_ px: Double, _ py: Double, _ speed: Double, _ dt: Double) -> Bool {
        let dx = px - x, dy = py - y, d = (dx * dx + dy * dy).squareRoot()
        if d <= speed * dt {
            x = px
            y = py
            return true
        }
        if abs(dx) > 0.5 { dir = dx > 0 ? 1 : -1 }
        x += dx / d * speed * dt
        y += dy / d * speed * dt
        moving = true
        return false
    }

    func quak() {
        quakT = 0.8
        spawn(pText, 9, -(rise() - 1), 2, -3, 1.4, "Quak!", 2.6, hex("#E08A1E"))
    }

    func updatePrints(_ dt: Double) {
        quakT -= dt
        for i in stride(from: prints.count - 1, through: 0, by: -1) {
            prints[i].life -= dt
            if prints[i].life <= 0 { prints.remove(at: i) }
        }
        var hx = x - lastPx, hy = y - lastPy
        lastPx = x
        lastPy = y
        trackT -= dt
        if Cfg.animal != 1 {
            prints.removeAll()
        } else if moving && !air && !dragging {
            printT -= dt
            if printT <= 0 {
                printT = 0.32
                printFoot = 1 - printFoot
                var len = (hx * hx + hy * hy).squareRoot()
                if len < 0.01 {
                    hx = Double(dir)
                    hy = 0
                    len = 1
                }
                hx /= len
                hy /= len
                let foot = (printFoot == 0 ? -1.0 : 1.0) * 2.5 * S
                // toes point the way she walks, left and right foot alternate
                prints.append(FootPrint(x: x - hy * foot, y: y + hx * foot, life: 12, size: S, heading: atan2(hy, hx) * 180 / .pi + 90))
                trackT = 0
            }
        }
        if !prints.isEmpty {
            if track == nil, let scr = NSScreen.screens.first {
                let w = overlayPanel(scr.frame)
                w.ignoresMouseEvents = true
                let v = TrackView(frame: NSRect(origin: .zero, size: scr.frame.size))
                v.pet = self
                w.contentView = v
                track = w
            }
            if let w = track {
                if !w.isVisible { w.orderFrontRegardless() }
                // a whole-screen window: a few redraws a second are enough for the slow fade
                if trackT <= 0 {
                    trackT = 0.15
                    w.contentView?.needsDisplay = true
                }
            }
        } else if let w = track, w.isVisible {
            w.orderOut(nil)
        }
    }

    func switchAnimal(_ an: Int) {
        if an == Cfg.animal { return }
        Cfg.save()
        Cfg.animal = an
        applyColor()
        parts.removeAll()
        prints.removeAll()
        quakT = 0
        hungerShow = 0
        hungerNag = 20
        bubbleT = 0
        Cfg.save()
        if !air { set("wave") }
        say(nm(T("Hallo! Ich bin Clawd.", "Hi! I'm Clawd.")), 3.5)
    }

    func trophyEarned() {
        Cfg.trophyNew = false
        confetti()
        announce(T("7 Tage in Folge! Neu: Goldener Pokal", "7 days in a row! New: Golden trophy"), 5)
    }

    func doAct(_ name: String) {
        if dragging { return }
        set(name)
    }

    // MARK: Admin area

    func setXp(_ xp: Int) {
        endFeatureDemo()
        let before = Cfg.level
        Cfg.xp = max(0, xp)
        Cfg.save()
        if Cfg.level > before { levelUp() }
    }

    func setFood(_ food: Double) {
        endFeatureDemo()
        Cfg.food = food
        hungerNag = 0 // if he is hungry now, he says so right away
        Cfg.save()
    }

    // Shows the newer features one after the other: outfits, hunger, feeding, level-up,
    // dancing, landing on a window. Works on copies - XP, hunger and outfit are restored afterwards.
    func startFeatureDemo() {
        if featDemo || dragging { return }
        featDemo = true
        fdStep = 0
        fdT = 0.8
        fdMusic = false
        fdXp = Cfg.xp
        fdFood = Cfg.food
        fdHat = Cfg.hat
        Cfg.hat = "none"
        hungerShow = 0
        bubbleT = 0
        set("wave")
        dur = 99
    }

    func endFeatureDemo() {
        if !featDemo { return }
        featDemo = false
        fdMusic = false
        Cfg.xp = fdXp
        Cfg.food = fdFood
        Cfg.hat = fdHat
    }

    func featureDemo(_ dt: Double) {
        if dragging { return }
        fdT -= dt
        if fdT > 0 { return }
        let step = fdStep
        fdStep += 1
        if step < 5 {
            // try on every outfit
            Cfg.hat = Cfg.hatVals[step + 1]
            for _ in 0..<8 {
                spawn(pCrumb, -8 + R() * 16, -13 - R() * 5, (R() - 0.5) * 12, -3 - R() * 6, 0.7, "", 0, pal())
            }
            t = 0
            fdT = 1.4
        } else if step == 5 {
            // hungry: the cookie bubble
            Cfg.hat = "none"
            Cfg.food = 12
            set("idle")
            dur = 99
            hungerShow = 3.2
            bubbleAge = 0
            fdT = 3.2
        } else if step == 6 {
            hungerShow = 0
            set("eat")
            Cfg.food = 60
            spawn(pText, 0, -(rise() + 2), 0, -4, 1.5, "+5 XP", 2.3, Ink.yellow)
            fdT = 3.8
        } else if step == 7 {
            confetti()
            announce(levelText(Cfg.level + 1), 4)
            set("jump")
            fdT = 4.4
        } else if step == 8 {
            // headphones on, bounce to a made-up beat
            bubbleT = 0
            Cfg.hat = "phones"
            set("dance")
            musicDance = true
            fdMusic = true
            dur = 99
            fdT = 6
        } else if step == 9 {
            // drop onto the frontmost window that has room
            fdMusic = false
            Cfg.hat = "none"
            var found = false
            for i in 0..<plats.count where !found {
                let p = plats[i]
                let cx = max(workL + 12 * S, min(workR - 12 * S, (p.l + p.r) / 2))
                if !p.stand || cx < p.l + 8 * S || cx > p.r - 8 * S || covered(i, cx, p.t) { continue }
                found = true
                perch = 0
                x = cx
                y = max(workT + 13 * S, p.t - 45 * S)
                vx = 0
                vy = 0
                set("fall")
                air = true
            }
            if found {
                fdT = 3.5
            } else {
                set("idle")
                dur = 99
                announce(T("Für den Fenster-Teil bitte ein Fenster öffnen.", "Open a window for the window part."), 3.5)
                fdStep = 11
                fdT = 3.5
            }
        } else if step == 10 {
            // run off the nearer edge and fall down
            for p in plats where p.id == perch {
                set("run")
                tx = max(workL + 12 * S, min(workR - 12 * S, x - p.l < p.r - x ? p.l - 10 * S : p.r + 10 * S))
                break
            }
            fdT = 6
        } else {
            endFeatureDemo()
            if !air { set("idle") }
        }
    }

    // MARK: Self-test

    // Sends a real mouse click through the system, the way a hand on the mouse would.
    func postClick(_ px: Double, _ py: Double) {
        let pt = CGPoint(x: px, y: py)
        let src = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: pt, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
    }

    func selfTestTick(_ dt: Double) {
        if dragU >= 0 {
            // being carried up and to the side, then let go while still moving
            dragU += dt / 1.1
            let u = min(1, dragU)
            fakeCur = (dragFrom.x + 420 * u * u, dragFrom.y - 380 * u)
            if dragU >= 1 {
                dragU = -1
                readCursor()
                release()
                fakeCur = nil
                log("selftest: let go - thrown with vx=\(Int(vx)) vy=\(Int(vy))")
            }
            return
        }
        if typeSim > 0 { typeSim -= dt }
        stT -= dt
        if stT > 0 || air { return }
        let step = stStep
        stStep += 1
        switch step {
        case 0:
            log("selftest: sending a real mouse click to his body")
            gotRealMouse = false
            postClick(x, y - 6 * S)
            stT = 1.2
        case 1:
            if gotRealMouse {
                log("selftest: the real click arrived - petting works with the mouse")
            } else {
                log("selftest: real clicks cannot be sent on this machine - calling the click handler directly")
                petIt()
            }
            stT = 2.6
        case 2:
            log("selftest: double-click -> flip")
            set("flip")
            stT = 1.2
        case 3:
            log("selftest: picking him up and throwing him")
            fakeCur = (x, y - 6 * S)
            press()
            dragFrom = (x, y - 6 * S)
            dragU = 0
            stT = 1.8
        case 4:
            log("selftest: opening the right-click menu")
            onAutoMenu?()
            stT = 4.2
        case 5:
            log("selftest: typing -> he types along")
            typeSim = 3.6
            stT = 6.5
        case 6:
            log("selftest: crown on, dancing")
            Cfg.hat = "crown"
            set("dance")
            stT = 5
        case 7:
            log("selftest: walking")
            Cfg.hat = "cap"
            set("walk")
            stT = 5
        case 8:
            Cfg.hat = "phones"
            set("wave")
            stT = 3
        default:
            log("selftest: done")
            selfTest = false
        }
    }

    // MARK: Promo recording

    func crumbs() {
        for _ in 0..<8 {
            spawn(pCrumb, -8 + R() * 16, -13 - R() * 5, (R() - 0.5) * 12, -3 - R() * 6, 0.7, "", 0, pal())
        }
    }

    func promoTick(_ dt: Double) {
        if typeSim > 0 { typeSim -= dt }
        if air || st == "walk" || st == "run" { return }
        prT -= dt
        if prT > 0 { return }
        let step = prStep
        prStep += 1
        let mid = workL + (workR - workL) / 2
        log("promo: scene \(step)")
        switch step {
        case 0:
            set("wave")
            prT = 3.2
        case 1:
            // a stroll along the Dock
            set("walk")
            tx = workL + (workR - workL) * 0.22
            prT = 0.7
        case 2:
            set("walk")
            tx = workL + (workR - workL) * 0.6
            prT = 0.9
        case 3:
            // drop onto the frontmost window that has room
            for i in 0..<plats.count {
                let p = plats[i]
                let cx = max(workL + 12 * S, min(workR - 12 * S, (p.l + p.r) / 2))
                if !p.stand || cx < p.l + 8 * S || cx > p.r - 8 * S || covered(i, cx, p.t) { continue }
                perch = 0
                x = cx
                y = max(workT + 13 * S, p.t - 45 * S)
                vx = 0
                vy = 0
                set("fall")
                air = true
                break
            }
            prT = 1.6
        case 4:
            set("walk")
            prT = 0.6
        case 5:
            // run off the nearer edge and fall down
            for p in plats where p.id == perch {
                set("run")
                tx = max(workL + 12 * S, min(workR - 12 * S, x - p.l < p.r - x ? p.l - 10 * S : p.r + 10 * S))
                break
            }
            prT = 2.8
        case 6:
            set("walk")
            tx = mid
            prT = 0.8
        case 7:
            set("idle")
            dur = 99
            typeSim = 5
            prT = 7.2
        case 8:
            set("idle")
            dur = 99
            onPromoMenu?()
            prT = 3.2
        case 9, 10, 11, 12, 13:
            Cfg.hat = Cfg.hatVals[step - 8]
            crumbs()
            set("idle")
            dur = 99
            prT = 1.15
        case 14:
            Cfg.hat = "none"
            feed()
            prT = 4.2
        case 15:
            Cfg.xp = Cfg.xpFor(Cfg.level + 1)
            levelUp()
            set("jump")
            prT = 4.4
        case 16:
            bubbleT = 0
            Cfg.hat = "crown"
            crumbs()
            set("dance")
            dur = 99
            prT = 5
        case 17:
            set("wave")
            prT = 4
        default:
            log("promo: done")
            set("idle")
            dur = 99
            promo = false
        }
    }

    // MARK: Logic

    func R() -> Double { return Double.random(in: 0..<1) }
    func pick(_ a: [String]) -> String { return a[Int.random(in: 0..<a.count)] }
    func pick(_ a: [[String]]) -> String { return pick(a[Cfg.lang == "de" ? 0 : 1]) }
    func pickIdle() -> String {
        if Cfg.animal == 1 && R() < 0.5 { return pick(Pet.duckLines) }
        if Cfg.animal == 2 && R() < 0.5 { return pick(Pet.catLines) }
        return nm(pick(Pet.idleLines))
    }
    func pal() -> NSColor { return Ink.palette[Int.random(in: 0..<Ink.palette.count)] }
    func snap(_ v: Double) -> Double { return (v * scale).rounded() / scale }

    func randX() -> Double {
        var lo = workL + 12 * S, hi = workR - 12 * S
        for p in plats where p.id == perch {
            // now and then he strolls off the edge and drops down
            if R() < 0.2 { return max(lo, min(hi, R() < 0.5 ? p.l - 10 * S : p.r + 10 * S)) }
            lo = max(lo, p.l + 8 * S)
            hi = min(hi, p.r - 8 * S)
            break
        }
        return hi > lo ? lo + R() * (hi - lo) : x
    }

    func say(_ text: String, _ secs: Double) {
        if !Cfg.talk { return }
        announce(text, secs)
    }

    // Like say, but also shown when speech bubbles are switched off (level-ups).
    func announce(_ text: String, _ secs: Double) {
        bubbleText = text
        bubbleT = secs
        bubbleAge = 0
    }

    func spawn(_ kind: Int, _ px: Double, _ py: Double, _ pvx: Double, _ pvy: Double, _ life: Double, _ text: String, _ size: Double, _ color: NSColor) {
        var p = Particle()
        p.kind = kind
        p.x = px
        p.y = py
        p.vx = pvx
        p.vy = pvy
        p.life = life
        p.max = life
        p.text = text
        p.size = size
        p.color = color
        parts.append(p)
    }

    func every(_ interval: Double, _ dt: Double) -> Bool {
        spawnT -= dt
        if spawnT > 0 { return false }
        spawnT = interval
        return true
    }

    func launch(_ cells: Double) {
        if !air { jumpY = y }
        vy = -(2 * 260 * S * cells * S).squareRoot()
        air = true
    }

    func moveTo(_ target: Double, _ speed: Double, _ dt: Double) -> Bool {
        let d = target - x
        if abs(d) <= speed * dt {
            x = target
            return true
        }
        dir = d > 0 ? 1 : -1
        x += Double(dir) * speed * dt
        moving = true
        return false
    }

    func set(_ s: String) {
        st = s
        t = 0
        phase = 0
        rot = 0
        spawnT = 0
        hopT = 0
        musicDance = false
        side = x < workL + (workR - workL) / 2 ? -1 : 1
        switch s {
        case "idle":
            dur = 4 + R() * 8
            if R() < 0.12 && bubbleT <= 0 { say(pickIdle(), 3.5) }
        case "walk", "run":
            tx = randX()
            if Cfg.animal == 1 {
                tx = workL + 10 * S + R() * max(0, workR - workL - 20 * S)
                ty = freeY()
                perch = 0
            }
        case "quote":
            // out of the screen edge with a text window in the beak
            qdir = R() < 0.5 ? 1 : -1
            tx = qdir > 0 ? workL + 6 * S : workR - 6 * S
            ty = freeY()
            perch = 0
            dur = 99
            let q = Pet.quotes[Int.random(in: 0..<Pet.quotes.count)]
            quoteWin = QuoteWindow(Cfg.lang == "de" ? q[0] : q[1], q[2])
        case "sleep": dur = 14 + R() * 14
        case "code":
            dur = 10 + R() * 10
            typed = false
            if R() < 0.6 { say(pick(Pet.codeLines), 3) }
        case "coffee": dur = 8 + R() * 5
        case "read": dur = 10 + R() * 6
        case "dance": dur = 6 + R() * 4
        case "jump":
            hops = 3
            launch(12)
        case "flip":
            launch(18)
            say(T("Hepp!", "Hup!"), 1.2)
        case "wave":
            dur = 3
            say(T("Hallo!", "Hello!"), 2.5)
        case "think":
            dur = 6
            say(". . .", 3.2)
        case "cool":
            dur = 8
            say(T("Läuft.", "Smooth."), 2.5)
        case "juggle": dur = 8
        case "balloon": dur = 4 + R() * 3
        case "stretch":
            dur = 2.5
            say(T("*gähn*", "*yawn*"), 2)
        case "chase": dur = 9
        case "quak":
            dur = 1.9
            quak()
        case "puddle":
            dur = 6 + R() * 3
            say(T("Plansch!", "Splash!"), 2)
        case "purr":
            dur = 3.5
            say(T("Prrr...", "Purr..."), 2.5)
        case "groom": dur = 5 + R() * 2
        case "scratch":
            // walks to the nearer edge of the window he stands on (or of the screen) and sharpens his claws there
            var eL = workL, eR = workR
            for p in plats where p.id == perch {
                eL = p.l
                eR = p.r
                break
            }
            sdir = x - eL < eR - x ? -1 : 1
            if R() < 0.3 { sdir = -sdir }
            tx = sdir > 0 ? eR - 10 * S : eL + 10 * S
            tx = max(workL + 7 * S, min(workR - 7 * S, tx))
            dur = 99
        case "eat": dur = 3.6
        case "pet": dur = 1.5
        case "drag": say(pick(Pet.dragLines), 2)
        case "fall": maxImpact = 0
        case "dizzy": dur = 2.5
        default: break
        }
        // keep the show moving: short pauses, nothing longer than 5 seconds
        if demo { dur = s == "idle" ? 1.2 : min(dur, 5) }
    }

    func weight(_ i: Int, _ night: Bool) -> Int {
        let n = Pet.actNames[i]
        if !Pet.actFor(n) { return 0 }
        var w = Pet.actWeights[i]
        if n == "chase" && Cfg.animal > 0 { w = 3 }   // duck and cat run after the mouse pointer by themselves now and then
        if n == "sleep" && Cfg.animal == 2 { w = 14 } // cats sleep a lot
        return n == "sleep" && night ? w * 5 : w
    }

    func pickActivity() {
        let hr = Calendar.current.component(.hour, from: Date())
        let night = hr >= 23 || hr < 6
        var total = 0
        for i in 0..<Pet.actNames.count where Pet.actNames[i] != lastAct { total += weight(i, night) }
        if total <= 0 { return }
        var r = Int.random(in: 0..<total)
        for i in 0..<Pet.actNames.count where Pet.actNames[i] != lastAct {
            r -= weight(i, night)
            if r < 0 {
                lastAct = Pet.actNames[i]
                set(Pet.actNames[i])
                return
            }
        }
    }

    func nextDemo() {
        let a = Pet.demoScript[demoIdx % Pet.demoScript.count]
        demoIdx += 1
        if a == "pet" { petIt() } else { set(a) }
    }

    // Called 60 times a second; draws at 30 when nothing fast is going on.
    func tick() {
        let now = CACurrentMediaTime()
        let fast = dragging || pressed || air
        let want = fast ? 1.0 / 60 : st == "sleep" ? 1.0 / 20 : 1.0 / 30
        if now - last < want - 0.004 { return }
        let dt = min(0.1, now - last)
        last = now
        readScreen()
        readCursor()
        anim += dt
        if bubbleT > 0 { bubbleT -= dt }
        bubbleAge += dt
        blinkT -= dt
        if blinkT < -0.13 { blinkT = 1.5 + R() * 4 }
        logT -= dt
        if logT <= 0 && logPath != nil {
            logT = 1
            log((featDemo ? "demo\(fdStep) " : "") + "animal=\(Cfg.animal) hat=\(Cfg.hat) \(st) x=\(Int(x)) y=\(Int(y)) air=\(air) windows=\(plats.count) level=\(Cfg.level) food=\(Int(Cfg.food))")
        }
        readInput(dt)
        updateNeeds(dt)
        beat = featDemo && fdMusic ? 0.12 + 0.2 * abs(sin(anim * 3.5)) : 0
        scanT -= dt
        if scanT <= 0 {
            scanT = air || dragging ? 0.08 : 0.25
            scanWindows()
        }
        if featDemo && !menuOpen { featureDemo(dt) }
        if selfTest && !menuOpen { selfTestTick(dt) }
        if promo && !menuOpen { promoTick(dt) }
        if !menuOpen { updatePet(dt) }
        updatePrints(dt)
        updateParticles(dt)
        place()
        needsDisplay = true
    }

    func calm() -> Bool {
        return !air && !dragging && !pressed && (y >= ground - 0.5 || free()) && !Pet.busy.contains(st)
    }

    // Hunger grows slowly while the app runs; when it gets bad he asks for food.
    func updateNeeds(_ dt: Double) {
        petXpT -= dt
        hungerShow -= dt
        if demo || featDemo { return }
        Cfg.food = max(0, Cfg.food - dt * 100 / 9000) // full -> empty in about 2.5 hours
        saveT -= dt
        if saveT <= 0 {
            saveT = 60
            Cfg.touchDay()
            if Cfg.trophyNew { trophyEarned() }
            Cfg.save()
        }
        if Cfg.food >= 30 {
            hungerNag = 5
            return
        }
        hungerNag -= dt
        if hungerNag > 0 || bubbleT > 0 || dragging || air || st == "sleep" || st == "eat" { return }
        hungerNag = Cfg.food < 10 ? 25 : 60
        hungerShow = 5
        bubbleAge = 0
        say(T("Ich hab Hunger!", "I'm hungry!"), 4)
    }

    func secondsSince(_ type: CGEventType) -> Double {
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
    }

    // Only counts THAT keys are being pressed - never which ones. Nothing is stored or sent.
    func readInput(_ dt: Double) {
        let n = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
        var hits = n &- keyCount
        keyCount = n
        if typeSim > 0 && Int(anim * 9) != typeTick {
            typeTick = Int(anim * 9)
            hits = 1
        }
        if demo || featDemo { return } // the script decides, not the keyboard
        typingT += dt
        tapT -= dt
        let idle = min(secondsSince(.keyDown), secondsSince(.mouseMoved), secondsSince(.leftMouseDown), secondsSince(.scrollWheel))
        let isCalm = calm()

        if hits > 0 && hits < 50 {
            typingT = 0
            tapT = 0.12
            tapArm = 1 - tapArm
            if st != "code" && isCalm { set("code") }
            if st == "code" {
                typed = true
                spawn(pText, -5 + R() * 10, -7, (R() - 0.5) * 3, -5, 1.2, pick(Pet.codeBits), 2.2, pal())
            }
        }
        // Nobody there -> fall asleep; back again -> wake up and wave
        let away = idle > 120 && !selfTest && !promo && !scripted
        if away && isCalm && st != "sleep" { set("sleep") }
        if wasAway && !away && st == "sleep" { set("wave") }
        wasAway = away
    }

    // MARK: Other windows as platforms

    // Collects the visible app windows, front to back.
    func scanWindows() {
        plats.removeAll(keepingCapacity: true)
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return }
        for w in list {
            // layer 0 = ordinary app windows (the Dock, menu bar and overlays live on other layers)
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let pid = w[kCGWindowOwnerPID as String] as? Int, pid == myPid { continue }
            if let alpha = w[kCGWindowAlpha as String] as? Double, alpha < 0.05 { continue }
            guard let b = w[kCGWindowBounds as String] as? [String: Any],
                  let bx = b["X"] as? Double, let by = b["Y"] as? Double,
                  let bw = b["Width"] as? Double, let bh = b["Height"] as? Double else { continue }
            if bw < 2 || bh < 2 { continue }
            var p = Plat()
            p.id = w[kCGWindowNumber as String] as? Int ?? 0
            p.l = bx
            p.t = by
            p.r = bx + bw
            p.b = by + bh
            // good to stand on: a window with room above it for Clawd
            p.stand = bw >= 30 * S && p.t - 13 * S >= workT && p.t <= workB - 6 * S
            plats.append(p)
        }
    }

    // Is the spot (px, top edge) of window number i hidden behind a window in front of it?
    func covered(_ i: Int, _ px: Double, _ py: Double) -> Bool {
        for j in 0..<i {
            let q = plats[j]
            if px >= q.l && px <= q.r && py + 1 >= q.t && py + 1 <= q.b { return true }
        }
        return false
    }

    // What he is standing on right now: a window's top edge or the bottom of the work area.
    var ground: Double {
        if perch != 0 {
            for p in plats where p.id == perch { return p.t }
        }
        return workB
    }

    func perchOk() -> Bool {
        for i in 0..<plats.count where plats[i].id == perch {
            let p = plats[i]
            return p.stand && abs(p.t - y) < 1.5 && x >= p.l + S && x <= p.r - S && !covered(i, x, p.t)
        }
        return false
    }

    // First surface he hits while dropping from y0 to y1.
    func findSurface(_ px: Double, _ y0: Double, _ y1: Double) -> (top: Double, id: Int)? {
        var top = Double.greatestFiniteMagnitude
        var id = 0
        if y1 >= workB { top = workB }
        for i in 0..<plats.count {
            let p = plats[i]
            if !p.stand || p.t < y0 - 0.5 || p.t > y1 || p.t >= top { continue }
            if px < p.l + 2 * S || px > p.r - 2 * S || covered(i, px, p.t) { continue }
            top = p.t
            id = p.id
        }
        return top == Double.greatestFiniteMagnitude ? nil : (top, id)
    }

    func place() {
        winLeft = snap(x - W / 2)
        let top = snap(y - (Pet.CH - 1) * S)
        window?.setFrameOrigin(NSPoint(x: winLeft, y: screenH - top - H))
    }

    func updateParticles(_ dt: Double) {
        var i = parts.count - 1
        while i >= 0 {
            parts[i].life -= dt
            if parts[i].life <= 0 {
                parts.remove(at: i)
            } else {
                if parts[i].kind == pCrumb { parts[i].vy += 30 * dt }
                parts[i].x += parts[i].vx * dt
                parts[i].y += parts[i].vy * dt
            }
            i -= 1
        }
    }

    func physics(_ dt: Double) {
        let y0 = y
        vy += 260 * S * dt
        x += vx * dt
        y += vy * dt
        let minX = workL + 9 * S, maxX = workR - 9 * S
        if x < minX {
            x = minX
            vx = -vx * 0.6
        }
        if x > maxX {
            x = maxX
            vx = -vx * 0.6
        }
        if y < workT + 12 * S {
            y = workT + 12 * S
            vy = abs(vy) * 0.5
        }
        if vy < 0 { return } // still on the way up

        var hit = (top: jumpY, id: perch)
        if Cfg.animal == 1 && (st == "jump" || st == "flip") {
            // the free duck lands where she took off
            if y < jumpY { return }
        } else {
            guard let found = findSurface(x, y0, y) else { return }
            hit = found
        }
        y = hit.top
        if st == "fall" && vy > 60 * S {
            if vy > maxImpact { maxImpact = vy }
            vy = -vy * 0.4
            vx *= 0.7
            return
        }
        perch = hit.id
        log("landed on " + (hit.id == 0 ? "ground" : "window \(hit.id)") + " at y=\(Int(y))")
        vx = 0
        vy = 0
        air = false
        if st == "jump" {
            hops -= 1
            if hops > 0 { launch(12) } else { set("idle") }
        } else if st == "flip" {
            set("idle")
        } else if st == "fall" {
            if maxImpact > 300 * S {
                set("dizzy")
                say(T("Mir ist schwindelig...", "I'm dizzy..."), 2.5)
            } else {
                set("idle")
            }
        }
    }

    func updatePet(_ dt: Double) {
        t += dt
        moving = false

        if pressed && !dragging {
            let dx = curX - pressX, dy = curY - pressY
            if dx * dx + dy * dy > 25 {
                dragging = true
                air = false
                perch = 0
                set("drag")
            }
        }
        if dragging {
            let nx = curX + grabX, ny = curY + grabY
            if dt > 0 {
                thvx = thvx * 0.6 + (nx - x) / dt * 0.4
                thvy = thvy * 0.6 + (ny - y) / dt * 0.4
            }
            x = max(workL + 9 * S, min(workR - 9 * S, nx))
            y = max(workT + 12 * S, min(workB, ny))
            return
        }

        let floating = st == "climb" || st == "balloon" || free()
        if free() { perch = 0 }
        // The window under him was moved, closed or covered: down he goes
        if perch != 0 && !air && !perchOk() {
            perch = 0
            log("lost the window under him")
            if !floating {
                set("fall")
                air = true
            }
        }
        let gnd = ground
        if !air && !floating && y < gnd - 0.5 { air = true }
        if air { physics(dt) }

        switch st {
        case "idle":
            if t > dur && !air {
                if featDemo {
                } else if demo {
                    nextDemo()
                } else {
                    pickActivity()
                }
            }
        case "walk":
            if (Cfg.animal == 1 ? moveTo2(tx, ty, 16 * S, dt) : moveTo(tx, 12 * S, dt)) { set("idle") }
        case "run":
            if (Cfg.animal == 1 ? moveTo2(tx, ty, 45 * S, dt) : moveTo(tx, 45 * S, dt)) { set("idle") }
        case "quote":
            if phase == 0 {
                if moveTo2(tx, ty, 30 * S, dt) {
                    // turn round and pull the window onto the screen
                    phase = 1
                    dir = qdir
                    let lo = qdir > 0 ? workL + QuoteWindow.W + 12 * S : workL + 6 * S
                    let hi = qdir > 0 ? workR - 6 * S : workR - QuoteWindow.W - 12 * S
                    tx = hi > lo ? lo + R() * (hi - lo) : (workL + workR) / 2
                    ty = freeY()
                    quoteWin?.show()
                }
            } else if phase == 1 {
                let there = moveTo2(tx, ty, 14 * S, dt)
                if let q = quoteWin {
                    q.move(qdir > 0 ? x - 7 * S - QuoteWindow.W : x + 7 * S, y - max(40, q.height) * 0.8, screenH)
                }
                if there {
                    phase = 2
                    t = 0
                    quoteWin?.drop()
                    quoteWin = nil
                    quak()
                    say(T("Für dich!", "For you!"), 2.5)
                }
            } else if t > 3.5 {
                set("idle")
            }
        case "sleep":
            if every(1.3, dt) { spawn(pText, 6, -9, 2.2, -3.5, 2.4, "z", 2.2, pal()) }
            if t > dur && !wasAway {
                set("idle")
                say(T("Gut geschlafen!", "Slept well!"), 2.5)
            }
        case "code":
            if typed {
                if typingT > 2.5 { set("idle") }
            } else {
                if every(0.7, dt) { spawn(pText, -5 + R() * 10, -7, (R() - 0.5) * 2, -4, 1.8, pick(Pet.codeBits), 2.2, pal()) }
                if t > dur { set("idle") }
            }
        case "coffee":
            if t.truncatingRemainder(dividingBy: 4) < 3 && every(0.5, dt) {
                spawn(pSteam, 10.5 + R() * 1.5, -10, R() - 0.5, -2.5, 1.2, "", 0, Ink.steam)
            }
            if t > dur {
                set("idle")
                say(T("Ahh, Kaffee.", "Ahh, coffee."), 2)
            }
        case "dance":
            if every(0.55, dt) { spawn(pText, -9 + R() * 18, -11, (R() - 0.5) * 3, -4, 1.6, R() < 0.5 ? "♪" : "♫", 3, pal()) }
            if R() < 0.15 { spawn(pCrumb, -14 + R() * 28, -22, (R() - 0.5) * 4, 2, 1.4, "", 0, pal()) }
            if t > dur { set("idle") }
        case "flip":
            let total = 2 * (2 * 260 * S * 18 * S).squareRoot() / (260 * S)
            rot = 360 * min(1, t / total) * Double(dir)
        case "think":
            if phase == 0 && t > 3.5 {
                phase = 1
                say(pick(Pet.ideaLines), 2.3)
            }
            if t > dur { set("idle") }
        case "climb":
            if phase == 0 {
                if moveTo(side < 0 ? workL + 6 * S : workR - 6 * S, 14 * S, dt) {
                    phase = 1
                    climbTop = gnd - (workB - workT) * (0.3 + R() * 0.4)
                }
            } else if phase == 1 {
                rot = side < 0 ? 90 : -90
                moving = true
                y -= 9 * S * dt
                if y <= climbTop {
                    phase = 2
                    t = 0
                }
            } else {
                rot = side < 0 ? 90 : -90
                if t > 2.5 {
                    let sd = side
                    set("fall")
                    air = true
                    vx = -Double(sd) * 25 * S
                    vy = -20 * S
                    say(T("Huiii!", "Wheee!"), 1.5)
                }
            }
        case "chase":
            let target = max(workL + 9 * S, min(workR - 9 * S, curX))
            hopT -= dt
            let ty2 = max(workT + 24 * S, min(workB, curY + 6 * S))
            if Cfg.animal == 1 {
                if abs(target - x) > 12 * S || abs(ty2 - y) > 12 * S { _ = moveTo2(target, ty2, 40 * S, dt) }
            } else if abs(target - x) > 12 * S {
                _ = moveTo(target, (Cfg.animal == 2 ? 26 : 40) * S, dt)
            } else if !air && hopT <= 0 {
                launch(Cfg.animal == 2 ? 7 : 4)
                hopT = Cfg.animal == 2 ? 1.6 : 0.9
            }
            if t > dur && !air {
                set("idle")
                say(T("Hab dich!", "Gotcha!"), 2)
            }
        case "balloon":
            y -= 12 * S * dt
            x += sin(t * 1.3) * 8 * S * dt
            if t > dur || y < workT + 45 * S {
                for _ in 0..<9 { spawn(pCrumb, 8, -20, (R() - 0.5) * 30, -R() * 14, 0.8, "", 0, Ink.red) }
                set("fall")
                air = true
                say(T("Peng!", "Pop!"), 1.5)
            }
        case "stretch":
            if t > dur { set(R() < 0.5 && !demo ? "sleep" : "idle") }
        case "eat":
            if every(0.9, dt) && t > 0.5 {
                for _ in 0..<4 { spawn(pCrumb, 10, -9, (R() - 0.5) * 8, -R() * 5, 0.7, "", 0, Ink.cookie) }
            }
            if t > dur {
                set("idle")
                say(T("Lecker!", "Yummy!"), 2)
            }
        case "quak":
            if phase == 0 && t > 0.9 {
                phase = 1
                quak()
            }
            if t > dur { set("idle") }
        case "puddle":
            if every(0.3, dt) {
                for _ in 0..<2 { spawn(pCrumb, -8 + R() * 16, -2, (R() - 0.5) * 8, -4 - R() * 5, 0.8, "", 0, Roomies.K("rain")) }
            }
            if t > dur {
                set("idle")
                say(T("Herrlich nass!", "Lovely and wet!"), 2)
            }
        case "purr":
            if every(0.7, dt) { spawn(pHeart, -5 + R() * 10, -(topCells - 2), (R() - 0.5) * 3, -5, 1.3, "", 0, pal()) }
            if t > dur { set("idle") }
        case "groom":
            if t > dur {
                set("idle")
                say(T("Alles sauber.", "All clean."), 2)
            }
        case "scratch":
            if phase == 0 {
                if moveTo(tx, 20 * S, dt) {
                    phase = 1
                    t = 0
                    dur = 4 + R() * 2
                    say(T("Meins!", "Mine!"), 1.5)
                }
            } else {
                if every(0.22, dt) { spawn(pCrumb, Double(sdir) * 10, -9 + R() * 3, Double(sdir) * (2 + R() * 3), -2 - R() * 3, 0.5, "", 0, Ink.greyDark) }
                if t > dur { set("idle") }
            }
        case "read", "wave", "cool", "juggle", "pet", "dizzy":
            if t > dur { set("idle") }
        default: break
        }

        x = max(workL + 6 * S, min(workR - 6 * S, x))
        if free() {
            y = max(workT + 20 * S, min(workB, y))
        } else if !air && st != "climb" && st != "balloon" && y > gnd {
            y = gnd
        }
    }

    // MARK: Drawing

    var ctx: CGContext!

    func C(_ color: NSColor, _ cx: Double, _ cy: Double, _ w: Double, _ h: Double) {
        let x0 = snap(ox + cx * S), y0 = snap(oy + cy * S), x1 = snap(ox + (cx + w) * S), y1 = snap(oy + (cy + h) * S)
        if x1 <= x0 || y1 <= y0 { return }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
    }

    func bmp(_ rows: [String], _ cx: Double, _ cy: Double, _ u: Double, _ main: NSColor, _ alt: NSColor, _ maxCols: Int) {
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where c < maxCols && ch != "." {
                C(ch == "X" ? main : alt, cx + Double(c) * u, cy + Double(r) * u, u, u)
            }
        }
    }

    func txt(_ s: String, _ cx: Double, _ cy: Double, _ sizeCells: Double, _ color: NSColor) {
        let size = CGFloat(max(7, sizeCells * S))
        let font = NSFont(name: "Menlo-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = s as NSString
        let sz = str.size(withAttributes: attrs)
        ctx.setShouldAntialias(true)
        str.draw(at: NSPoint(x: ox + cx * S - Double(sz.width) / 2, y: oy + cy * S - Double(sz.height) / 2), withAttributes: attrs)
        ctx.setShouldAntialias(false)
    }

    // ex = left edge of the 1-cell-wide eye
    func eye(_ mode: Int, _ ex: Double, _ ey: Double) {
        let k = Ink.ink
        switch mode {
        case eyeOpen: C(k, ex, ey, 1, 2)
        case eyeClosed: C(k, ex - 0.5, ey + 1, 2, 0.7)
        case eyeHappy:
            C(k, ex - 1, ey + 1, 1, 1)
            C(k, ex, ey, 1, 1)
            C(k, ex + 1, ey + 1, 1, 1)
        case eyeWide:
            C(k, ex - 0.5, ey - 0.5, 2, 2.5)
            C(Ink.white, ex - 0.5, ey - 0.5, 1, 1)
        default:
            C(k, ex - 1, ey - 0.5, 1, 1)
            C(k, ex + 1, ey - 0.5, 1, 1)
            C(k, ex, ey + 0.5, 1, 1)
            C(k, ex - 1, ey + 1.5, 1, 1)
            C(k, ex + 1, ey + 1.5, 1, 1)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        if let w = window { scale = Double(w.backingScaleFactor) }
        render(c)
    }

    // Draws Clawd, his props, particles and the bubble into a top-left-origin context.
    func render(_ c: CGContext) {
        ctx = c
        ctx.setShouldAntialias(false)

        var sway = 0.0, lift = 0.0, bob = 0.0, aL = 0.0, aR = 0.0, tall = 0.0
        var eyeMode = eyeOpen, lx = 0.0, ly = 0.0
        var sit = false, dangle = false, glasses = false, mir = false
        var extra: String?
        let an = Cfg.animal
        let fastLegs = st == "run" || st == "chase"
        let frame = Int(anim * (fastLegs ? 12 : 6)) % 2
        let beatStep = Int(anim * 6) % 2

        if abs(curX - x) > 8 * S { lx = curX > x ? 1 : -1 }
        if curY < y - 30 * S { ly = -1 }
        bob = moving ? (frame == 0 ? 0 : -0.6) : sin(anim * 2.2) * 0.25
        if air {
            bob = 0
            if vy < 0 {
                aL = -2
                aR = -2
            }
        }

        switch st {
        case "sleep":
            sit = true
            eyeMode = eyeClosed
            lx = 0
            ly = 0
            bob = (sin(anim * 1.3) + 1) * 0.3
        case "code":
            lx = 0
            ly = 1
            if !typed {
                aL = Double(Int(anim * 9) % 2)
                aR = 1 - aL
            } else if tapT > 0 {
                if tapArm == 0 { aL = 1 } else { aR = 1 }
            }
        case "coffee":
            if t.truncatingRemainder(dividingBy: 4) >= 3 {
                aR = -2
                eyeMode = eyeClosed
            }
        case "read":
            ly = 1
            lx = Double(Int(anim * 1.5) % 3 - 1)
            aL = 2
            aR = 2
        case "dance":
            // in the feature demo the bounce follows a beat
            lift = -abs(sin(anim * 6)) * 1.5 * (musicDance ? 0.45 + min(1.2, beat * 4) : 1)
            sway = sin(anim * 3) * 1.5
            if sin(anim * 3) > 0 { aL = -3 } else { aR = -3 }
            eyeMode = eyeHappy
            lx = 0
            ly = 0
        case "jump", "flip":
            eyeMode = eyeHappy
            lx = 0
            ly = 0
        case "wave":
            aR = -3 + Double(beatStep)
            eyeMode = eyeHappy
            lx = 0
            ly = 0
        case "think":
            if phase == 0 {
                lx = 1
                ly = -1
                aR = -1
            } else {
                eyeMode = eyeHappy
                lx = 0
                ly = 0
                aL = -2
                aR = -2
            }
        case "cool":
            glasses = true
            lx = 0
            ly = 0
        case "climb":
            if phase > 0 {
                lx = 0
                ly = phase == 2 ? 1 : -1
            }
        case "juggle":
            lx = 0
            ly = -1
            aL = -Double(beatStep)
            aR = -Double(1 - beatStep)
        case "balloon":
            aR = -3
            ly = -1
            lx = 0
            dangle = true
            bob = 0
        case "stretch":
            aL = -3
            aR = -3
            eyeMode = eyeClosed
            tall = 1
            bob = 0
        case "eat":
            aR = -2
            if t.truncatingRemainder(dividingBy: 0.9) < 0.3 { eyeMode = eyeHappy }
            lx = 0
            ly = 0
        case "pet":
            eyeMode = eyeHappy
            lx = 0
            ly = 0
            lift = -abs(sin(t * 10)) * 1.0
        case "drag":
            eyeMode = eyeWide
            lx = 0
            ly = 0
            dangle = true
            aL = -2
            aR = -2
            bob = 0
        case "fall":
            eyeMode = eyeWide
            lx = 0
            ly = 0
            aL = -2
            aR = -2
        case "dizzy":
            eyeMode = eyeDizzy
            lx = 0
            ly = 0
            sway = sin(anim * 5) * 0.8
        case "chase":
            if !moving { eyeMode = eyeHappy }
        default: break
        }
        if blinkT < 0 && eyeMode == eyeOpen { eyeMode = eyeClosed }

        // What only the duck or only the cat does
        if an == 1 {
            let dash = (st == "chase" || st == "run") && moving
            if st == "quak" {
                eyeMode = eyeOpen
                aL = Double(-Int(anim * 10) % 2)
                aR = aL
            }
            if st == "puddle" {
                extra = "puddle"
                eyeMode = eyeHappy
                aL = -2
                aR = -2
                lift = -0.5
                lx = 0
                ly = 0
            }
            if dash {
                extra = "run"
                aL = -2
                aR = -2
                lx = 1
                ly = 0
                lift = -0.4
                mir = dir < 0
            }
            if (quakT > 0 || st == "quak") && extra == nil { extra = "quak" }
        } else if an == 2 {
            if st == "sleep" {
                extra = "loaf"
            } else if st == "purr" {
                extra = "purr"
                eyeMode = eyeHappy
                sit = true
                lx = 0
                ly = 0
            } else if st == "groom" {
                extra = "groom"
                eyeMode = eyeClosed
                sit = true
                aR = -5 + Double(Int(anim * 5) % 2)
                lx = 0
                ly = 0
            } else if st == "scratch" && phase == 1 {
                extra = "scratch"
                eyeMode = eyeClosed
                aR = -4 + Double(Int(anim * 8) % 2) * 1.5
                lx = 0
                ly = 0
                mir = sdir < 0
            } else if st == "chase" && !air {
                extra = "hunt"
                eyeMode = eyeWide
                lx = 1
                ly = 1
                mir = dir < 0
            }
        }

        let baseX = W / 2, baseY = (Pet.CH - 1) * S
        ox = baseX + sway * S
        oy = baseY + lift * S
        let so = sit ? 2.0 : 0.0
        let bodyTop = -10 - tall + bob + so
        let bodyBot = sit ? 0 : -2 + bob
        var armY = -7 + bob + so

        rm.ctx = ctx
        rm.S = S
        rm.scale = scale
        var pz = Pose()
        pz.eye = eyeMode
        pz.lx = lx
        pz.ly = ly
        pz.aL = aL
        pz.aR = aR
        pz.bob = bob
        pz.tall = tall
        pz.sit = sit
        pz.cool = glasses
        pz.dangle = dangle
        pz.moving = moving && !air
        pz.frame = frame
        pz.danglePhase = Int(anim * 10)
        pz.extra = extra
        let anc: Anchor

        ctx.saveGState()
        if rot != 0 {
            ctx.translateBy(x: ox, y: oy - 6 * S)
            ctx.rotate(by: rot * .pi / 180)
            ctx.translateBy(x: -ox, y: -(oy - 6 * S))
        }
        if mir {
            ctx.translateBy(x: ox, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -ox, y: 0)
        }

        if st == "balloon" {
            C(Ink.cream, 7.85, -16, 0.3, 6 + bob)
            bmp(Pet.balloon, 4, -25, 1, Ink.red, Ink.white, 99)
        }

        rm.ox = ox
        rm.oy = oy
        if an == 0 {
            if !sit {
                let legX = [-6.0, -4.0, 3.0, 5.0]
                for i in 0..<4 {
                    var len = -bodyBot
                    if dangle {
                        len = (i + Int(anim * 10)) % 2 == 0 ? 2 : 1.2
                    } else if air {
                        len = 2
                    } else if moving && i % 2 == frame {
                        len = 1
                    }
                    C(bodyColor, legX[i], bodyBot, 1, len)
                }
            }
            C(bodyColor, -7, bodyTop, 14, bodyBot - bodyTop)
            C(bodyColor, -9, armY + aL, 2, 2)
            C(bodyColor, 7, armY + aR, 2, 2)

            let eyeY = -8 - tall * 0.5 + bob + so + ly
            eye(eyeMode, -4 + lx, eyeY)
            eye(eyeMode, 3 + lx, eyeY)

            if glasses {
                let gy = -8.5 + bob
                C(Ink.ink, -7, gy, 14, 1)
                C(Ink.ink, -6, gy, 5, 3)
                C(Ink.ink, 1, gy, 5, 3)
                C(Ink.shine, -5, gy + 1, 1, 1)
                C(Ink.shine, 2, gy + 1, 1, 1)
            }
            anc = rm.clawdAnchor(pz)
        } else {
            anc = an == 1 ? rm.duck(pz, Roomies.duckVars[Cfg.varA[1]]) : rm.cat(pz, Roomies.catVars[Cfg.varA[2]])
            rm.extras(extra, anc)
            armY = anc.armY
        }
        if Cfg.face != "none" { rm.face(Cfg.face, anc) }
        if Cfg.neck != "none" { rm.neck(Cfg.neck, anc) }
        if Cfg.hat != "none" { rm.hat(Cfg.hat, anc) }
        topCells = -anc.fxTop

        switch st {
        case "code":
            C(Ink.grey, -5, -5, 10, 4)
            C(Ink.palette[Int(anim * 3) % Ink.palette.count], -1, -4, 2, 2)
            C(Ink.greyDark, -6, -1, 12, 1)
        case "read":
            C(Ink.brown, -6, -5, 12, 4)
            C(Ink.brownDark, -0.5, -5, 1, 4)
            C(Ink.gold, -4.5, -4, 3, 1)
            C(Ink.gold, 1.5, -4, 3, 1)
        case "coffee":
            let cy = armY + aR - 2.5
            C(Ink.white, 9.5, cy, 3, 3)
            C(Ink.white, 12.5, cy + 1, 1, 1)
            C(Ink.brownDark, 9.5, cy, 3, 0.6)
        case "eat":
            bmp(Pet.cookieBmp, 9, armY + aR - 3.5, 1, Ink.cookie, Ink.brownDark, 4 - min(3, Int(t / 0.9)))
        case "juggle":
            let cols = [Ink.red, Ink.yellow, Ink.blue]
            for i in 0..<3 {
                let p = anim * 1.2 + Double(i) / 3.0
                let f = p - p.rounded(.down)
                let ltr = Int(p.rounded(.down)) % 2 == 0
                let bx = ltr ? -8 + 16 * f : 8 - 16 * f
                let by = -10 - 12 * 4 * f * (1 - f)
                C(cols[i], bx - 1, by - 1, 2, 2)
            }
        default: break
        }

        if Cfg.fx != "none" { rm.fx(Cfg.fx, anc) }
        ctx.restoreGState()

        // Overlays (neither rotated nor swayed with the body)
        ox = baseX
        oy = baseY

        if st == "dizzy" {
            for i in 0..<3 {
                let a = anim * 4 + Double(i) * 2.094
                let sx = 7 * cos(a), sy = -12.5 + 1.5 * sin(a)
                C(Ink.yellow, sx - 0.5, sy - 1.5, 1, 3)
                C(Ink.yellow, sx - 1.5, sy - 0.5, 3, 1)
            }
        }

        for p in parts {
            ctx.saveGState()
            ctx.setAlpha(CGFloat(min(1, p.life / (p.max * 0.4))))
            switch p.kind {
            case pText: txt(p.text, p.x, p.y, p.size * (1 + (1 - p.life / p.max) * 0.5), p.color)
            case pHeart: bmp(Pet.heart, p.x - 1.75, p.y - 1.5, 0.5, p.color, p.color, 99)
            default: C(p.color, p.x, p.y, 0.7, 0.7)
            }
            ctx.restoreGState()
        }

        ctx.setShouldAntialias(true)
        if bubbleT > 0 && !bubbleText.isEmpty { drawBubble() } else { drawHunger() }
        ctx.setShouldAntialias(false)
    }

    func spring() -> Double {
        let k = min(1, bubbleAge / 0.3) - 1
        return 0.6 + 0.4 * (1 + 2.0 * k * k * k + 1.0 * k * k)
    }

    // Glass-style speech bubble: pops in with a little bounce, fades out.
    func drawBubble() {
        let dark = isDark
        let fontSize = CGFloat(max(12, 2.5 * S))
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: dark ? NSColor.white : Ink.ink,
            .paragraphStyle: style]
        let str = NSAttributedString(string: bubbleText, attributes: attrs)
        let maxW = 34 * S
        let tb = str.boundingRect(with: NSSize(width: maxW, height: 2000), options: [.usesLineFragmentOrigin])
        let tw = Double(tb.width.rounded(.up)), th = Double(tb.height.rounded(.up))
        let padX = max(11, 2.2 * S), padY = max(6, 1.2 * S)
        let bw = tw + 2 * padX, bh = th + 2 * padY
        let mid = W / 2
        let tail = max(5, 1.1 * S)

        // clamp to the screen first, then to the window
        var bx = max(workL + bw / 2 + 6, min(workR - bw / 2 - 6, winLeft + mid)) - winLeft
        bx = max(bw / 2 + 6, min(W - bw / 2 - 6, bx))
        let by = (Pet.CH - 1) * S - rise() * S - tail - 0.6 * S
        let r = CGRect(x: bx - bw / 2, y: by - bh, width: bw, height: bh)
        let rad = min(bh / 2, 15)
        let tailX = max(Double(r.minX) + rad + tail, min(Double(r.maxX) - rad - tail, mid))
        let s = spring()
        let alpha = min(1, bubbleAge / 0.1) * min(1, bubbleT / 0.25)

        ctx.saveGState()
        ctx.setAlpha(CGFloat(alpha))
        ctx.translateBy(x: tailX, y: by + tail)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -tailX, y: -(by + tail))

        let path = CGMutablePath()
        path.addRoundedRect(in: r, cornerWidth: rad, cornerHeight: rad)
        path.move(to: CGPoint(x: tailX - tail, y: by - 1))
        path.addLine(to: CGPoint(x: tailX, y: by + tail))
        path.addLine(to: CGPoint(x: tailX + tail, y: by - 1))
        path.closeSubpath()

        let fill = dark ? hex("#EB26262A") : hex("#F5FFFFFF")
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.addPath(path)
        ctx.setFillColor(fill.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        let rim = CGMutablePath()
        rim.addRoundedRect(in: r.insetBy(dx: 0.5, dy: 0.5), cornerWidth: rad - 0.5, cornerHeight: rad - 0.5)
        ctx.addPath(rim)
        ctx.setStrokeColor(hex(Cfg.accentHex(Cfg.animal)).cgColor)
        ctx.setLineWidth(1.4)
        ctx.strokePath()

        str.draw(with: NSRect(x: bx - maxW / 2, y: Double(r.minY) + padY, width: maxW, height: th), options: [.usesLineFragmentOrigin])
        ctx.restoreGState()
    }

    // "I'm hungry": a small thought bubble with a cookie in it. Shown even when speech bubbles are off.
    func drawHunger() {
        if hungerShow <= 0 { return }
        let dark = isDark
        let fill = dark ? hex("#EB26262A") : hex("#F5FFFFFF")
        let mid = W / 2, r = max(14, 3.3 * S)
        let feet = (Pet.CH - 1) * S - rise() * S
        let cy = feet - r - 2.2 * S
        let s = spring()
        let alpha = min(1, bubbleAge / 0.1) * min(1, hungerShow / 0.25)

        ctx.saveGState()
        ctx.setAlpha(CGFloat(alpha))
        ctx.translateBy(x: mid, y: feet)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -mid, y: -feet)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.setFillColor(fill.cgColor)
        ctx.fillEllipse(in: CGRect(x: mid - r, y: cy - r, width: 2 * r, height: 2 * r))
        ctx.restoreGState()
        ctx.setStrokeColor(hex(Cfg.accentHex(Cfg.animal)).cgColor)
        ctx.setLineWidth(1.4)
        ctx.strokeEllipse(in: CGRect(x: mid - r, y: cy - r, width: 2 * r, height: 2 * r))
        ctx.setFillColor(fill.cgColor)
        ctx.fillEllipse(in: CGRect(x: mid - 0.5 * r - 0.5 * S, y: feet - 1.1 * S, width: S, height: S))
        ctx.fillEllipse(in: CGRect(x: mid - 0.3 * r - 0.8 * S, y: feet - 2.5 * S, width: 1.6 * S, height: 1.6 * S))

        ctx.setShouldAntialias(false)
        let u = (r * 0.3).rounded()
        for (row, line) in Pet.cookieBmp.enumerated() {
            for (col, ch) in line.enumerated() where ch != "." {
                ctx.setFillColor((ch == "X" ? Ink.cookie : Ink.brownDark).cgColor)
                ctx.fill(CGRect(x: (mid - 2 * u).rounded() + Double(col) * u, y: (cy - 2 * u).rounded() + Double(row) * u, width: u, height: u))
            }
        }
        ctx.setShouldAntialias(true)
        ctx.restoreGState()
    }
}

// MARK: - Off-screen pictures (app icon, pose sheet for the README and for testing)

func makeBitmap(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    let c = g.cgContext
    // top-left origin, like the flipped pet view
    c.translateBy(x: 0, y: CGFloat(h))
    c.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: true)
    draw(c)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePng(_ rep: NSBitmapImageRep, _ path: String) {
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

func drawLogo(_ c: CGContext, _ color: NSColor, _ x0: Double, _ y0: Double, _ cell: Double) {
    func cellRect(_ col: NSColor, _ cx: Double, _ cy: Double, _ w: Double, _ h: Double) {
        c.setFillColor(col.cgColor)
        c.fill(CGRect(x: x0 + cx * cell, y: y0 + cy * cell, width: w * cell, height: h * cell))
    }
    c.setShouldAntialias(false)
    cellRect(color, 2, 0, 14, 8)
    cellRect(color, 0, 3, 18, 2)
    for lx in [3.0, 5.0, 12.0, 14.0] { cellRect(color, lx, 8, 1, 2) }
    cellRect(Ink.ink, 5, 2, 1, 2)
    cellRect(Ink.ink, 12, 2, 1, 2)
    c.setShouldAntialias(true)
}

func renderIcon(_ path: String) {
    let rep = makeBitmap(1024, 1024) { c in
        let r = CGRect(x: 100, y: 100, width: 824, height: 824)
        let bg = CGMutablePath()
        bg.addRoundedRect(in: r, cornerWidth: 185, cornerHeight: 185)
        c.addPath(bg)
        c.setFillColor(hex("#FAF9F5").cgColor)
        c.fillPath()
        drawLogo(c, hex(Cfg.orange), 512 - 9 * 34, 512 - 5 * 34, 34)
    }
    writePng(rep, path)
}

// --sheet file [clawd|duck|cat] [poses|colors|cos]
func renderSheet(_ path: String, _ animal: String, _ mode: String) {
    Cfg.readOnly = true
    Cfg.animal = max(0, Cfg.animalKeys.firstIndex(of: animal) ?? 0)
    // each tile: state, colour, head, face, neck, effect
    var tiles: [[String]] = []
    if mode == "colors" {
        for v in 0..<7 { tiles.append(["idle", String(v), "none", "none", "none", "none"]) }
    } else if mode == "cos" {
        for h in Cfg.hatVals where h != "none" { tiles.append(["idle", "0", h, "none", "none", "none"]) }
        for f in Cfg.faceVals where f != "none" { tiles.append(["idle", "0", "none", f, "none", "none"]) }
        for n in Cfg.neckVals where n != "none" { tiles.append(["idle", "0", "none", "none", n, "none"]) }
        for x in Cfg.fxVals where x != "none" { tiles.append(["idle", "0", "none", "none", "none", x]) }
        tiles.append(["idle", "0", "wizard", "nerd", "bowtie", "sparkle"])
    } else {
        var states = ["idle", "walk", "sleep", "code", "coffee", "read", "dance", "wave", "cool", "juggle", "balloon", "stretch", "eat", "pet", "drag", "dizzy"]
        if Cfg.animal == 1 { states += ["quak", "puddle", "run"] }
        if Cfg.animal == 2 { states += ["purr", "groom", "scratch", "chase"] }
        for s in states {
            let hat: String = s == "idle" ? "crown" : s == "walk" ? "cap" : s == "dance" ? "phones" : s == "wave" ? "party" : s == "cool" ? "tophat" : "none"
            tiles.append([s, "0", hat, "none", "none", "none"])
        }
    }
    let cols = min(6, tiles.count), rows = (tiles.count + cols - 1) / cols
    let pet = Pet(frame: NSRect(x: 0, y: 0, width: 240, height: 180))
    pet.S = 5
    pet.scale = 1
    let tw = Int(pet.W), th = Int(pet.H)
    Cfg.talk = true
    let rep = makeBitmap(cols * tw, rows * th) { c in
        c.setFillColor(hex("#243447").cgColor)
        c.fill(CGRect(x: 0, y: 0, width: cols * tw, height: rows * th))
        for (i, tl) in tiles.enumerated() {
            let s = tl[0]
            pet.parts.removeAll()
            pet.st = s
            pet.t = 3.1
            pet.anim = 1.3
            pet.phase = s == "scratch" ? 1 : 0
            pet.rot = 0
            pet.blinkT = 1
            pet.quakT = 0
            pet.sdir = 1
            pet.dir = 1
            pet.moving = s == "walk" || s == "run" || s == "chase"
            pet.bubbleT = 0
            pet.hungerShow = 0
            pet.x = 500
            pet.y = 500
            pet.curX = s == "chase" ? 560 : 500
            pet.curY = 500
            pet.winLeft = 500 - pet.W / 2
            pet.workL = 0
            pet.workR = 1000
            pet.workT = 0
            pet.workB = 1000
            if s == "sleep" { pet.spawn(pet.pText, 8, -12, 0, 0, 2, "z", 2.6, Ink.cream) }
            if s == "pet" || s == "purr" {
                pet.spawn(pet.pHeart, -4, -13, 0, 0, 2, "", 0, Ink.red)
                pet.spawn(pet.pHeart, 4, -15, 0, 0, 2, "", 0, Ink.red)
            }
            if s == "quak" { pet.spawn(pet.pText, 9, -16, 0, 0, 2, "Quak!", 2.6, hex("#E08A1E")) }
            if s == "code" {
                pet.typed = true
                pet.tapT = 0.1
                pet.spawn(pet.pText, -3, -13, 0, 0, 2, "{ }", 2.2, Ink.green)
                pet.spawn(pet.pText, 5, -16, 0, 0, 2, "</>", 2.2, Ink.yellow)
            }
            if s == "dance" {
                pet.spawn(pet.pText, -9, -15, 0, 0, 2, "♪", 3, Ink.pink)
                pet.spawn(pet.pText, 8, -17, 0, 0, 2, "♫", 3, Ink.blue)
            }
            if s == "idle" && mode == "poses" {
                pet.bubbleText = pet.nm("Hi! I'm Clawd.")
                pet.bubbleT = 3
                pet.bubbleAge = 1
            }
            if s == "stretch" {
                pet.hungerShow = 3
                pet.bubbleAge = 1
            }
            Cfg.varA[Cfg.animal] = Int(tl[1]) ?? 0
            Cfg.hat = tl[2]
            Cfg.face = tl[3]
            Cfg.neck = tl[4]
            Cfg.fx = tl[5]
            pet.applyColor()
            c.saveGState()
            c.translateBy(x: CGFloat((i % cols) * tw), y: CGFloat((i / cols) * th))
            pet.render(c)
            c.restoreGState()
        }
    }
    writePng(rep, path)
}

// MARK: - Menus

// Menu entry that runs a closure.
final class Item: NSMenuItem {
    var run: (() -> Void)?

    convenience init(_ title: String, checked: Bool = false, enabled: Bool = true, _ run: (() -> Void)? = nil) {
        self.init(title: title, action: nil, keyEquivalent: "")
        self.run = run
        if run != nil {
            target = self
            action = #selector(fire)
        }
        state = checked ? .on : .off
        isEnabled = enabled
    }

    @objc func fire() { run?() }
}

// Top of the menu: level, XP and how hungry he is.
final class StatusView: NSView {
    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        let lv = Cfg.level, lo = Cfg.xpFor(lv), hi = Cfg.xpFor(lv + 1)
        let left: CGFloat = 21, width = bounds.width - 42
        let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: NSColor.labelColor]
        let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        ("Level \(lv)" as NSString).draw(at: NSPoint(x: left, y: 6), withAttributes: title)
        let xpText = "\(Cfg.xp - lo) / \(hi - lo) XP" as NSString
        xpText.draw(at: NSPoint(x: left + width - xpText.size(withAttributes: small).width, y: 9), withAttributes: small)
        bar(NSRect(x: left, y: 28, width: width, height: 5), CGFloat(Cfg.xp - lo) / CGFloat(max(1, hi - lo)), hex(Cfg.accentHex(Cfg.animal)))
        let mood = Cfg.food < 10 ? T("Sehr hungrig", "Starving") : Cfg.food < 30 ? T("Hungrig", "Hungry") : Cfg.food < 85 ? T("Zufrieden", "Content") : T("Satt", "Full")
        (mood as NSString).draw(at: NSPoint(x: left, y: 39), withAttributes: small)
        bar(NSRect(x: left, y: 57, width: width, height: 5), CGFloat(Cfg.food / 100), Cfg.food < 30 ? Ink.red : Ink.green)
    }

    func bar(_ r: NSRect, _ frac: CGFloat, _ color: NSColor) {
        NSColor.tertiaryLabelColor.setFill()
        NSBezierPath(roundedRect: r, xRadius: 2.5, yRadius: 2.5).fill()
        if frac <= 0 { return }
        color.setFill()
        var f = r
        f.size.width = max(5, r.width * min(1, frac))
        NSBezierPath(roundedRect: f, xRadius: 2.5, yRadius: 2.5).fill()
    }
}

// SHA-256 of the admin password. The password itself is not in the code.
let adminHash = "def311f008e18477bb13f6bf75a15739b90be4fa579c06815193d56ab08e6cd0"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panel: NSPanel!
    var pet: Pet!
    var statusItem: NSStatusItem!
    var timer: Timer?
    let args = CommandLine.arguments

    func applicationDidFinishLaunching(_ notification: Notification) {
        Cfg.load()
        // for the automatic build: pick the animal without touching the settings
        if let i = args.firstIndex(of: "--animal"), i + 1 < args.count, let an = Cfg.animalKeys.firstIndex(of: args[i + 1]) {
            Cfg.readOnly = true
            Cfg.animal = an
        }
        let logging = args.contains("--log")
        if logging { Cfg.readOnly = true }
        if args.contains("--selftest") {
            // big, talkative and with everything unlocked, so the video shows as much as possible
            Cfg.readOnly = true
            Cfg.size = 10
            Cfg.xp = 9999
            Cfg.talk = true
            Cfg.lang = "en"
        }
        if promoMode {
            // a fresh, hungry Clawd one step below the crown
            Cfg.readOnly = true
            Cfg.size = 10
            Cfg.xp = Cfg.xpFor(5)
            Cfg.animal = 0
            Cfg.food = 40
            Cfg.hat = "none"
            Cfg.face = "none"
            Cfg.neck = "none"
            Cfg.fx = "none"
            Cfg.color = Cfg.orange
            Cfg.talk = true
            Cfg.lang = "en"
        }
        if (Cfg.firstRun || args.contains("--setup") || promoMode) && !args.contains("--skip-setup") && (!logging || promoMode) {
            let w = SetupWindow(welcome: !promoMode)
            // for the automatic build: a card is picked after a moment, so both steps can be photographed
            if let i = args.firstIndex(of: "--setup-pick"), i + 1 < args.count, let an = Cfg.animalKeys.firstIndex(of: args[i + 1]) {
                Hand.after(3) { w.pick(an) }
            }
            w.runModal()
        }

        pet = Pet(frame: NSRect(x: 0, y: 0, width: 240, height: 180))
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 180), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar            // always on top, above ordinary windows
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = pet

        pet.demo = args.contains("--demo")
        if let i = args.firstIndex(of: "--log"), i + 1 < args.count { pet.logPath = args[i + 1] }
        pet.onMenu = { [weak self] e in self?.showMenu(e) }
        pet.selfTest = args.contains("--selftest")
        pet.promo = promoMode
        pet.onPromoMenu = { [weak self] in
            DispatchQueue.main.async { self?.promoMenu() }
        }
        pet.onAutoMenu = { [weak self] in
            // not from inside the frame timer, or the animation would stand still while the menu is open
            DispatchQueue.main.async { self?.autoMenu() }
        }
        pet.start()
        panel.orderFrontRegardless()
        if args.contains("--featdemo") {
            DispatcherQueueHelper.after(3) { [weak self] in self?.pet.startFeatureDemo() }
        }

        buildStatusItem()
        pet.onTheme = { [weak self] in self?.refreshIcon() }
        if Cfg.trophyNew {
            Cfg.trophyNew = false
            Cfg.save()
        }

        if pet.logPath != nil, let list = ProcessInfo.processInfo.environment["CLAWD_ACTS"] {
            // developer helper: run the named activities one after the other, CLAWD_ACT_SECS seconds each (default 6)
            let acts = list.components(separatedBy: ",")
            let secs = Double(ProcessInfo.processInfo.environment["CLAWD_ACT_SECS"] ?? "") ?? 6
            var ai = 0
            pet.scripted = true
            let next: () -> Void = { [weak self] in
                guard let p = self?.pet else { return }
                let a = acts[ai % acts.count]
                ai += 1
                p.log("activity " + a)
                p.set(a)
            }
            Hand.after(2, next)
            Hand.after(2) {
                let at = Timer(timeInterval: secs, repeats: true) { _ in next() }
                RunLoop.main.add(at, forMode: .common)
            }
        }

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.pet.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func applicationWillTerminate(_ notification: Notification) {
        pet?.endFeatureDemo()
        Cfg.save()
    }

    // MARK: Right-click menu (built fresh every time, so it is always up to date)

    func showMenu(_ e: NSEvent) {
        let m = buildMenu()
        m.delegate = self
        NSMenu.popUpContextMenu(m, with: e, for: pet)
    }

    // Self-test: opens the right-click menu next to him and closes it again after a moment.
    func autoMenu() {
        let m = buildMenu()
        m.delegate = self
        let t = Timer(timeInterval: 3, repeats: false) { _ in m.cancelTracking() }
        RunLoop.main.add(t, forMode: .common)
        m.popUp(positioning: nil, at: NSPoint(x: pet.W / 2 + 9 * pet.S, y: pet.H - 14 * pet.S), in: pet)
        pet.log("selftest: the menu was open and closed again")
    }

    // Promo recording: the pointer comes over, the menu opens, the pointer wanders to "Feed" and "Outfit".
    func promoMenu() {
        let at = NSPoint(x: pet.W / 2 + 4 * pet.S, y: pet.H - 8 * pet.S)
        let s = panel.convertPoint(toScreen: pet.convert(at, to: nil))
        let h = NSScreen.screens.first?.frame.height ?? 0
        let p = CGPoint(x: s.x, y: h - s.y)
        Hand.glide(to: p, 0.8) { [weak self] in
            Hand.after(0.3) {
                guard let me = self else { return }
                let m = me.buildMenu()
                m.delegate = me
                // the rows are found from the status block at the top, wherever the system puts the menu
                func row(_ below: CGFloat) -> CGPoint {
                    guard let v = m.items.first?.view, v.window != nil else { return Hand.pos }
                    let c = Hand.centre(v)
                    return CGPoint(x: c.x - 30, y: c.y + v.bounds.height / 2 + below)
                }
                Hand.after(1.0) { Hand.glide(to: row(44), 0.5) }
                Hand.after(2.3) { Hand.glide(to: row(121), 0.45) }
                Hand.after(5.0) { m.cancelTracking() }
                m.popUp(positioning: nil, at: at, in: me.pet)
                me.pet.log("promo: the menu was open and closed again")
                Hand.after(0.2) { Hand.glide(to: CGPoint(x: 1905, y: 1070), 0.8) }
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) { pet.menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { pet.menuOpen = false }

    // Submenu where exactly one entry is ticked. Entries above the current level are shown locked.
    func choice(_ title: String, _ labels: [String], _ selected: Int, _ need: [Int]?, top: Bool = false, _ pick: @escaping (Int) -> Void) -> NSMenuItem {
        let parent = Item(title)
        let sub = NSMenu()
        sub.autoenablesItems = false
        for (i, label) in labels.enumerated() {
            let locked = need != nil && need![i] > (top ? Cfg.topLevel : Cfg.level) && !pet.demo && i != selected
            sub.addItem(Item(locked ? label + "  ·  " + Cfg.needText(need![i]) : label, checked: i == selected, enabled: !locked) {
                pick(i)
                Cfg.save()
            })
        }
        parent.submenu = sub
        return parent
    }

    func buildMenu() -> NSMenu {
        let p = pet!
        let m = NSMenu()
        m.autoenablesItems = false

        let status = NSMenuItem()
        status.view = StatusView(frame: NSRect(x: 0, y: 0, width: 240, height: 70))
        m.addItem(status)
        m.addItem(.separator())
        m.addItem(Item(T("Streicheln", "Pet")) { p.petIt() })
        m.addItem(Item(T("Füttern", "Feed")) { p.feed() })
        m.addItem(Item(T("Komm her!", "Come here!")) { p.doAct("chase") })
        m.addItem(.separator())

        let acts = Item(T("Aktivität", "Activity"))
        let actMenu = NSMenu()
        actMenu.autoenablesItems = false
        let labels = Cfg.lang == "de" ? Pet.actLabelsDe : Pet.actLabelsEn
        for (i, name) in Pet.actNames.enumerated() where Pet.actFor(name) {
            let need = Pet.actLevel(name)
            let locked = need > Cfg.level && !p.demo
            actMenu.addItem(Item(locked ? labels[i] + "  ·  Level \(need)" : labels[i], enabled: !locked) { p.doAct(name) })
        }
        acts.submenu = actMenu
        m.addItem(acts)

        m.addItem(choice(T("Tier", "Animal"), Cfg.animalLabels, Cfg.animal, nil) { i in p.switchAnimal(i) })
        let outfit = Item(T("Outfit", "Outfit"))
        let outfitMenu = NSMenu()
        outfitMenu.autoenablesItems = false
        outfitMenu.addItem(choice(T("Kopf", "Head"), Cfg.hatLabels, Cfg.hatVals.firstIndex(of: Cfg.hat) ?? 0, Cfg.hatLevel, top: true) { i in Cfg.hat = Cfg.hatVals[i] })
        outfitMenu.addItem(choice(T("Gesicht", "Face"), Cfg.faceLabels, Cfg.faceVals.firstIndex(of: Cfg.face) ?? 0, Cfg.faceLevel, top: true) { i in Cfg.face = Cfg.faceVals[i] })
        outfitMenu.addItem(choice(T("Hals", "Neck"), Cfg.neckLabels, Cfg.neckVals.firstIndex(of: Cfg.neck) ?? 0, Cfg.neckLevel, top: true) { i in Cfg.neck = Cfg.neckVals[i] })
        outfitMenu.addItem(choice(T("Effekt", "Effect"), Cfg.fxLabels, Cfg.fxVals.firstIndex(of: Cfg.fx) ?? 0, Cfg.fxLevel, top: true) { i in Cfg.fx = Cfg.fxVals[i] })
        outfit.submenu = outfitMenu
        m.addItem(outfit)
        m.addItem(choice(T("Farbe", "Color"), Cfg.colLabels, Cfg.varA[Cfg.animal], Cfg.colLevel) { i in
            Cfg.varA[Cfg.animal] = i
            p.applyColor()
        })
        m.addItem(choice(T("Größe", "Size"), Cfg.sizeLabels, Cfg.sizeVals.firstIndex(of: Cfg.size) ?? -1, nil) { i in
            Cfg.size = Cfg.sizeVals[i]
            p.applyScale()
        })
        m.addItem(choice(T("Sprache", "Language"), ["Deutsch", "English"], Cfg.lang == "de" ? 0 : 1, nil) { i in
            Cfg.lang = i == 0 ? "de" : "en"
            p.bubbleT = 0
        })
        m.addItem(.separator())

        m.addItem(Item(T("Sprechblasen", "Speech bubbles"), checked: Cfg.talk) {
            Cfg.talk.toggle()
            if !Cfg.talk { p.bubbleT = 0 }
            Cfg.save()
        })
        if Cfg.canAutoStart {
            m.addItem(Item(T("Bei der Anmeldung starten", "Open at login"), checked: Cfg.autoStart) { Cfg.autoStart = !Cfg.autoStart })
        }
        m.addItem(Item(T("Einstellungen…", "Settings…")) { [weak self] in self?.openSetup() })
        m.addItem(Item(T("Demo-Modus", "Demo mode"), checked: p.demo) {
            p.demo.toggle()
            p.demoIdx = 0
            if p.demo && !p.dragging { p.set("idle") }
        })
        m.addItem(Item(T("Feedback senden…", "Send feedback…")) {
            // opens the feedback form in the browser; the app itself sends nothing
            let v = ProcessInfo.processInfo.operatingSystemVersion
            let os = "macOS%20\(v.majorVersion).\(v.minorVersion)"
            if let url = URL(string: "https://tally.so/r/2EqDqb?version=1.4&os=" + os) { NSWorkspace.shared.open(url) }
            // a little thank-you: the flower outfit
            if !Cfg.thanked {
                Cfg.thanked = true
                Cfg.hat = "flower"
                Cfg.save()
                p.confetti()
                p.announce(T("Danke! Neues Outfit: Blume", "Thank you! New outfit: Flower"), 5)
            }
        })

        if promoMode {
            // nothing for the video
        } else if !p.adminOn {
            m.addItem(Item("Admin…") { [weak self] in self?.askAdmin() })
        } else {
            let ad = Item("Admin")
            let am = NSMenu()
            am.addItem(Item(T("Funktions-Demo starten", "Run feature demo")) { p.startFeatureDemo() })
            am.addItem(.separator())
            am.addItem(Item("XP +5") { p.setXp(Cfg.xp + 5) })
            am.addItem(Item("XP +25") { p.setXp(Cfg.xp + 25) })
            am.addItem(Item("Level +1") { p.setXp(Cfg.xpFor(Cfg.level + 1)) })
            am.addItem(Item(T("XP auf 0", "Reset XP")) { p.setXp(0) })
            am.addItem(.separator())
            am.addItem(Item(T("Hunger: satt", "Hunger: full")) { p.setFood(100) })
            am.addItem(Item(T("Hunger: hungrig", "Hunger: hungry")) { p.setFood(25) })
            am.addItem(Item(T("Hunger: sehr hungrig", "Hunger: starving")) { p.setFood(5) })
            am.addItem(.separator())
            am.addItem(Item(T("Admin sperren", "Lock admin")) { p.adminOn = false })
            ad.submenu = am
            m.addItem(ad)
        }
        m.addItem(.separator())
        m.addItem(Item(T("Beenden", "Quit")) { NSApp.terminate(nil) })
        return m
    }

    func openSetup() {
        SetupWindow(welcome: false).runModal()
        pet.applyScale()
        pet.applyColor()
        if !Cfg.talk { pet.bubbleT = 0 }
    }

    func askAdmin() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = T("Admin-Bereich", "Admin area")
        alert.informativeText = T("Passwort eingeben", "Enter the password")
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: T("Abbrechen", "Cancel"))
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 230, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() != .alertFirstButtonReturn { return }
        let digest = SHA256.hash(data: Data(field.stringValue.utf8))
        let hexString = digest.map { String(format: "%02x", $0) }.joined()
        if hexString == adminHash {
            pet.adminOn = true
        } else {
            NSSound.beep()
        }
    }

    // MARK: Menu bar icon

    // the icon takes the theme colour of the animal
    func refreshIcon() {
        let color = hex(Cfg.accentHex(Cfg.animal))
        statusItem?.button?.image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            drawLogo(c, color, 0, 4, 1)
            return true
        }
    }

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        refreshIcon()
        let m = NSMenu()
        m.addItem(Item(T("Zeigen / Verstecken", "Show / Hide")) { [weak self] in
            guard let s = self else { return }
            if s.panel.isVisible { s.panel.orderOut(nil) } else { s.panel.orderFrontRegardless() }
        })
        m.addItem(Item(T("Zurück in die Mitte", "Back to the centre")) { [weak self] in
            guard let s = self, let p = s.pet else { return }
            s.panel.orderFrontRegardless()
            p.x = p.workL + (p.workR - p.workL) / 2
            p.y = max(p.workT + 14 * p.S, p.workB - 150 * p.S)
            p.perch = 0
            p.set("fall")
            p.air = true
        })
        m.addItem(.separator())
        m.addItem(Item(T("Beenden", "Quit")) { NSApp.terminate(nil) })
        statusItem.menu = m
    }
}

enum DispatcherQueueHelper {
    static func after(_ secs: Double, _ run: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + secs, execute: run)
    }
}

// The pet's window never takes keyboard focus away from the app you are working in.
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}

// MARK: - Welcome / settings window

final class Swatch: NSView {
    var color = NSColor.orange
    var selected = false
    var locked = false
    var onPick: (() -> Void)?

    override var intrinsicContentSize: NSSize { return NSSize(width: 34, height: 34) }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 3, dy: 3)
        color.withAlphaComponent(locked ? 0.25 : 1).setFill()
        NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill()
        if selected {
            NSColor.labelColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.25, dy: 1.25), xRadius: 10, yRadius: 10)
            ring.lineWidth = 2.5
            ring.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        if !locked { onPick?() }
    }
}

final class SetupWindow: NSObject, NSWindowDelegate {
    let win: NSWindow
    let glass = NSVisualEffectView()
    let welcome: Bool
    var settingsBuilt = false
    var variant = Cfg.varA[Cfg.animal]

    // Step 1 of the welcome window: three cards with a moving animal, one click picks it.
    let chooser = NSStackView()
    let cHead = NSTextField(wrappingLabelWithString: ""), cSub = NSTextField(wrappingLabelWithString: "")
    let cLangLabel = NSTextField(labelWithString: "")
    let cLang = NSSegmentedControl(labels: ["Deutsch", "English"], trackingMode: .selectOne, target: nil, action: nil)
    var cards: [AnimalCard] = []

    // Step 2 (or the whole settings dialog): language, size, colour and the switches.
    let settings = NSStackView()
    let logo = PetPreview(Cfg.animal, 4, 150, 84)
    let head = NSTextField(labelWithString: "")
    let sub = NSTextField(wrappingLabelWithString: "")
    let lLang = NSTextField(labelWithString: ""), lSize = NSTextField(labelWithString: ""), lColor = NSTextField(labelWithString: "")
    let langSeg = NSSegmentedControl(labels: ["Deutsch", "English"], trackingMode: .selectOne, target: nil, action: nil)
    let sizeSeg = NSSegmentedControl(labels: ["", "", "", ""], trackingMode: .selectOne, target: nil, action: nil)
    let row = NSStackView()
    let talk = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let auto = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let ok = NSButton(title: "", target: nil, action: nil)
    let hint = NSTextField(wrappingLabelWithString: "")
    let back = NSButton(title: "", target: nil, action: nil)
    var swatches: [Swatch] = []

    init(welcome: Bool) {
        self.welcome = welcome
        win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 560), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        win.title = "Pixel Roomies"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.delegate = self

        // frosted glass behind everything
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        win.contentView = glass
        glass.widthAnchor.constraint(equalToConstant: 380).isActive = true

        buildChooser()
        buildSettings()
        retext()
        if welcome {
            show(chooser)
        } else {
            settingsBuilt = true
            buildSwatches()
            show(settings)
        }
    }

    func buildChooser() {
        cHead.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        cHead.alignment = .center
        cHead.preferredMaxLayoutWidth = 320
        cSub.textColor = .secondaryLabelColor
        cSub.alignment = .center
        cSub.preferredMaxLayoutWidth = 320
        cLangLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        cLang.selectedSegment = Cfg.lang == "de" ? 0 : 1
        cLang.target = self
        cLang.action = #selector(langChanged(_:))
        cLang.segmentDistribution = .fillEqually

        let cardRow = NSStackView()
        cardRow.orientation = .horizontal
        cardRow.spacing = 10
        for i in 0..<3 {
            let card = AnimalCard(i)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.onPick = { [weak self] in self?.pick(i) }
            NSLayoutConstraint.activate([card.widthAnchor.constraint(equalToConstant: 100), card.heightAnchor.constraint(equalToConstant: 112)])
            cards.append(card)
            cardRow.addArrangedSubview(card)
        }

        for v in [cHead, cSub, cardRow, cLangLabel, cLang] as [NSView] { chooser.addArrangedSubview(v) }
        chooser.orientation = .vertical
        chooser.alignment = .leading
        chooser.spacing = 8
        chooser.edgeInsets = NSEdgeInsets(top: 44, left: 30, bottom: 26, right: 30)
        chooser.setCustomSpacing(4, after: cHead)
        chooser.setCustomSpacing(20, after: cSub)
        chooser.setCustomSpacing(18, after: cardRow)
        chooser.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cHead.widthAnchor.constraint(equalToConstant: 320),
            cSub.widthAnchor.constraint(equalToConstant: 320),
            cLang.widthAnchor.constraint(equalToConstant: 320)
        ])
    }

    func buildSettings() {
        head.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        head.alignment = .center
        sub.textColor = .secondaryLabelColor
        sub.alignment = .center
        sub.preferredMaxLayoutWidth = 320
        for l in [lLang, lSize, lColor] { l.font = NSFont.systemFont(ofSize: 13, weight: .semibold) }
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.preferredMaxLayoutWidth = 320

        langSeg.selectedSegment = Cfg.lang == "de" ? 0 : 1
        langSeg.target = self
        langSeg.action = #selector(langChanged(_:))
        langSeg.segmentDistribution = .fillEqually
        sizeSeg.selectedSegment = max(0, Cfg.sizeVals.firstIndex(of: Cfg.size) ?? 1)
        sizeSeg.segmentDistribution = .fillEqually

        row.orientation = .horizontal
        row.spacing = 7

        talk.state = Cfg.talk ? .on : .off
        auto.state = Cfg.autoStart ? .on : .off
        auto.isHidden = !Cfg.canAutoStart

        ok.bezelStyle = .rounded
        ok.controlSize = .large
        ok.keyEquivalent = "\r"
        ok.target = self
        ok.action = #selector(done)

        back.isBordered = false
        back.target = self
        back.action = #selector(goBack)
        back.isHidden = !welcome

        // the stack lines everything up on the left; the animal gets a full-width box to sit centred in
        let logoBox = NSView()
        logo.dress = true
        logo.variant = variant
        logo.translatesAutoresizingMaskIntoConstraints = false
        logoBox.addSubview(logo)

        for v in [logoBox, head, sub, lLang, langSeg, lSize, sizeSeg, lColor, row, talk, auto, ok, hint, back] as [NSView] { settings.addArrangedSubview(v) }
        settings.orientation = .vertical
        settings.alignment = .leading
        settings.spacing = 8
        settings.edgeInsets = NSEdgeInsets(top: 44, left: 30, bottom: 26, right: 30)
        settings.setCustomSpacing(14, after: logoBox)
        settings.setCustomSpacing(4, after: head)
        settings.setCustomSpacing(20, after: sub)
        settings.setCustomSpacing(16, after: langSeg)
        settings.setCustomSpacing(16, after: sizeSeg)
        settings.setCustomSpacing(20, after: row)
        settings.setCustomSpacing(22, after: auto)
        settings.setCustomSpacing(8, after: talk)
        settings.setCustomSpacing(10, after: ok)
        settings.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoBox.widthAnchor.constraint(equalToConstant: 320),
            logoBox.heightAnchor.constraint(equalToConstant: 84),
            logo.centerXAnchor.constraint(equalTo: logoBox.centerXAnchor),
            logo.topAnchor.constraint(equalTo: logoBox.topAnchor),
            head.widthAnchor.constraint(equalToConstant: 320),
            sub.widthAnchor.constraint(equalToConstant: 320),
            langSeg.widthAnchor.constraint(equalToConstant: 320),
            sizeSeg.widthAnchor.constraint(equalToConstant: 320),
            ok.widthAnchor.constraint(equalToConstant: 320),
            hint.widthAnchor.constraint(equalToConstant: 320),
            back.widthAnchor.constraint(equalToConstant: 320)
        ])
    }

    // The colours of the chosen animal
    func buildSwatches() {
        for v in row.arrangedSubviews {
            row.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        swatches.removeAll()
        for (i, v) in Cfg.swatches(Cfg.animal).enumerated() {
            let s = Swatch()
            s.color = hex(v)
            s.locked = Cfg.colLevel[i] > Cfg.level && i != variant
            s.toolTip = s.locked ? "Level \(Cfg.colLevel[i])" : nil
            s.onPick = { [weak self] in
                guard let me = self else { return }
                me.variant = i
                Cfg.varA[Cfg.animal] = i
                me.mark()
            }
            swatches.append(s)
            row.addArrangedSubview(s)
        }
        mark()
    }

    func show(_ stack: NSStackView) {
        chooser.removeFromSuperview()
        settings.removeFromSuperview()
        glass.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            stack.topAnchor.constraint(equalTo: glass.topAnchor),
            stack.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])
        glass.layoutSubtreeIfNeeded()
        win.setContentSize(NSSize(width: 380, height: stack.fittingSize.height))
        centre()
    }

    // A card was clicked: on to the settings for this animal.
    func pick(_ an: Int) {
        Cfg.animal = an
        variant = Cfg.varA[an]
        logo.animal = an
        settingsBuilt = true
        retext()
        buildSwatches()
        show(settings)
    }

    // remember what was set so far, then go back to the animal cards
    @objc func goBack() {
        Cfg.varA[Cfg.animal] = variant
        settingsBuilt = false
        show(chooser)
    }

    @objc func langChanged(_ sender: NSSegmentedControl) {
        Cfg.lang = sender.selectedSegment == 0 ? "de" : "en"
        cLang.selectedSegment = sender.selectedSegment
        langSeg.selectedSegment = sender.selectedSegment
        retext()
    }

    func retext() {
        cHead.stringValue = T("Willkommen bei Pixel Roomies!", "Welcome to Pixel Roomies!")
        cSub.stringValue = T("Wer soll bei dir einziehen? Später kannst du jederzeit wechseln.", "Who should move in with you? You can switch any time.")
        cLangLabel.stringValue = T("Sprache", "Language")
        for (i, l) in Cfg.animalLabels.enumerated() where i < cards.count { cards[i].name.stringValue = l }
        let an = Cfg.animal
        head.stringValue = an == 0 ? T("Hallo, ich bin Clawd!", "Hi, I'm Clawd!") : an == 1 ? T("Hallo, ich bin die Ente!", "Hi, I'm the duck!") : T("Hallo, ich bin die Katze!", "Hi, I'm the cat!")
        sub.stringValue = T("Dein kleiner Mitbewohner für den Desktop. Wie hättest du mich gern?", "Your little desktop companion. How would you like me?")
        lLang.stringValue = T("Sprache", "Language")
        lSize.stringValue = T("Größe", "Size")
        lColor.stringValue = T("Farbe", "Color")
        for (i, l) in Cfg.sizeLabels.enumerated() { sizeSeg.setLabel(l, forSegment: i) }
        talk.title = T("Sprechblasen anzeigen", "Show speech bubbles")
        auto.title = T("Bei der Anmeldung starten", "Open at login")
        ok.title = T("Los geht's!", "Let's go!")
        hint.stringValue = T("Alles lässt sich später per Rechtsklick auf mich ändern.", "You can change everything later by right-clicking me.")
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        back.attributedTitle = NSAttributedString(string: T("Anderes Tier wählen", "Pick a different animal"), attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue, .paragraphStyle: centred])
    }

    // Highlight the chosen swatch, redraw the little animal in that colour and give the button the theme colour.
    func mark() {
        for (i, s) in swatches.enumerated() {
            s.selected = i == variant
            s.needsDisplay = true
        }
        logo.variant = variant
        logo.needsDisplay = true
        ok.bezelColor = hex(Cfg.accentHex(Cfg.animal))
    }

    @objc func done() { win.close() }

    func windowWillClose(_ notification: Notification) {
        if settingsBuilt {
            Cfg.size = Cfg.sizeVals[max(0, min(Cfg.sizeVals.count - 1, sizeSeg.selectedSegment))]
            Cfg.varA[Cfg.animal] = variant
            Cfg.talk = talk.state == .on
        }
        Cfg.save()
        if settingsBuilt && Cfg.canAutoStart && (auto.state == .on) != Cfg.autoStart { Cfg.autoStart = auto.state == .on }
        NSApp.stopModal()
    }

    // always centred on the main screen
    func centre() {
        if let scr = NSScreen.screens.first {
            win.layoutIfNeeded()
            let v = scr.visibleFrame, s = win.frame.size
            win.setFrameOrigin(NSPoint(x: v.midX - s.width / 2, y: v.midY - s.height / 2))
        }
    }

    func runModal() {
        centre()
        win.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            win.animator().alphaValue = 1
        }
        if promoMode { promoPlay() }
        NSApp.runModal(for: win)
    }

    // Promo recording: the pointer tries two colours, goes back to orange and presses the button.
    // If a click does not get through, the choice is made directly, so the recording never hangs.
    func promoPlay() {
        var at = 1.8
        for i in [4, 5, 0] {
            Hand.after(at) { [weak self] in
                guard let me = self else { return }
                Hand.glide(to: Hand.centre(me.swatches[i]), 0.55) {
                    Hand.click()
                    Hand.after(0.25) {
                        if me.variant != i {
                            me.variant = i
                            Cfg.varA[Cfg.animal] = i
                            me.mark()
                        }
                    }
                }
            }
            at += 1.35
        }
        Hand.after(at + 0.2) { [weak self] in
            guard let me = self else { return }
            Hand.glide(to: Hand.centre(me.ok), 0.6) {
                Hand.click()
                Hand.after(0.4) {
                    if me.win.isVisible { me.done() }
                    Hand.after(0.3) { Hand.glide(to: CGPoint(x: 1905, y: 1070), 0.9) }
                }
            }
        }
    }
}

// MARK: - Entry point

let cli = CommandLine.arguments
if let i = cli.firstIndex(of: "--wallpaper"), i + 1 < cli.count {
    // used by the automatic build before it records a video
    for scr in NSScreen.screens {
        do {
            try NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: cli[i + 1]), for: scr, options: [:])
            print("wallpaper set: \(cli[i + 1])")
        } catch {
            print("wallpaper failed: \(error)")
        }
    }
    exit(0)
}
if let i = cli.firstIndex(of: "--icon"), i + 1 < cli.count {
    renderIcon(cli[i + 1])
    exit(0)
}
if let i = cli.firstIndex(of: "--sheet"), i + 1 < cli.count {
    _ = NSApplication.shared
    renderSheet(cli[i + 1], i + 2 < cli.count ? cli[i + 2] : "clawd", i + 3 < cli.count ? cli[i + 3] : "poses")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
