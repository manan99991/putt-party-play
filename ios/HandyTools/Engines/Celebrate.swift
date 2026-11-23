import AVFoundation
import CoreImage
import UIKit
import Vision

/// Celebrate — any video (or photo) dressed up for a celebration: snow and fairy lights for Christmas, fireworks for
/// New Year, diyas for Diwali, colour bursts for Holi, lanterns for Lunar New Year, falling leaves for Thanksgiving —
/// festivals from every part of the world, or any celebration the person types (matched in many languages; anything
/// unknown gets a palette and confetti built from their own words and emoji). Plus their own words, placed where
/// they won't cover faces, which they can drag anywhere.
///
/// Every decoration is drawn on the phone, frame by frame, as a pure function of time — so the live preview and the
/// saved video are identical, scrubbing works, and nothing needs downloading. The video keeps its sound.
enum Celebrate {

    // MARK: - Themes

    enum Layer: Equatable {
        case snow
        case confetti([UInt32])
        case sparkles([UInt32])
        case lights([UInt32])          // a string of twinkling bulbs across the top
        case fireworks([UInt32])
        case fall([String])            // emoji drifting down: leaves, petals, shamrocks
        case rise([String])            // emoji floating up: balloons, hearts, lanterns
        case fly([String])             // emoji crossing the sky: bats, kites
        case corners([String])         // emoji tucked into the corners, gently bobbing
        case diyas                     // a row of flickering oil lamps along the bottom
        case powder([UInt32])          // Holi colour bursts
        case bubbles
        case stars                     // a twinkling night sky across the top
        case glow(UInt32)              // a soft coloured glow around the edges
        case bokeh([UInt32])           // big soft out-of-focus lights drifting, like a lens at a party
        case embers(UInt32)            // glowing sparks rising and flickering (diyas, bonfires, fireplaces)
        case rays(UInt32)              // slow beams of warm light falling from the top corner
        case sleigh                    // Santa's sleigh and reindeer crossing the sky with a trail of gold

        /// Light adds onto the video (it brightens what's under it, like real light); the rest sits on top.
        var isLight: Bool {
            switch self {
            case .glow, .rays, .stars, .bokeh, .fireworks, .sparkles, .embers: return true
            default: return false
            }
        }

        /// Back to front.
        var depth: Int {
            switch self {
            case .glow: return 0
            case .rays: return 1
            case .stars: return 2
            case .bokeh: return 3
            case .powder: return 4
            case .fireworks: return 5
            case .sparkles: return 6
            case .lights: return 7
            case .sleigh: return 8
            case .fly: return 9
            case .rise: return 10
            case .fall: return 11
            case .bubbles: return 12
            case .snow: return 13
            case .embers: return 14
            case .confetti: return 15
            case .diyas: return 16
            case .corners: return 17
            }
        }
    }

    struct Theme: Identifiable, Equatable {
        let id: String
        let name: String
        let emoji: String
        var greeting: String
        /// Months it usually falls in (1–12); empty = any day (birthdays, weddings).
        let months: [Int]
        /// Other names for it, in many languages — what someone might type.
        let keywords: [String]
        let palette: [UInt32]
        let layers: [Layer]
        /// Made from the person's own words rather than picked from the list.
        var custom = false
        /// The colour grade that tells this celebration's story (a VideoFX look id), and its light.
        var look: String? = nil
        var light: String? = nil
    }

    static let gold: UInt32 = 0xFFD54A, red: UInt32 = 0xE53935, green: UInt32 = 0x2E7D32, white: UInt32 = 0xFFFFFF
    static let silver: UInt32 = 0xCFD8DC, blue: UInt32 = 0x1E88E5, orange: UInt32 = 0xFB8C00, pink: UInt32 = 0xF06292
    static let purple: UInt32 = 0x8E24AA, teal: UInt32 = 0x00ACC1, yellow: UInt32 = 0xFDD835, leaf: UInt32 = 0x43A047
    static let rainbow: [UInt32] = [0xE53935, 0xFB8C00, 0xFDD835, 0x43A047, 0x1E88E5, 0x8E24AA]
    static let pastels: [UInt32] = [0xF8BBD0, 0xB3E5FC, 0xC8E6C9, 0xFFF9C4, 0xE1BEE7]

    static let themes: [Theme] = [
        Theme(id: "christmas", name: "Christmas", emoji: "🎄", greeting: "Merry Christmas", months: [12],
              keywords: ["christmas", "xmas", "x-mas", "navidad", "feliz navidad", "noel", "joyeux noel", "weihnachten", "natale", "natal", "kerstmis", "jul", "god jul", "рождество", "クリスマス", "圣诞", "聖誕", "크리스마스", "क्रिसमस", "santa"],
              palette: [red, green, gold], layers: [.glow(0xC62828), .bokeh([gold, red, 0x66BB6A, 0xFFF3D6]), .lights([red, green, gold, blue]), .sleigh, .snow, .sparkles([gold, white]), .corners(["🎄", "🎁", "⭐", "🔔"])], look: "xmas", light: "glow"),
        Theme(id: "newyear", name: "New Year", emoji: "🎆", greeting: "Happy New Year", months: [12, 1],
              keywords: ["new year", "new years", "nye", "ano nuevo", "feliz ano nuevo", "ano novo", "nouvel an", "bonne annee", "neujahr", "silvester", "capodanno", "hogmanay", "countdown", "新年", "신년", "새해", "नया साल", "नव वर्ष", "с новым годом"],
              palette: [gold, silver, white], layers: [.bokeh([gold, silver, 0xFFF3D6]), .fireworks([gold, white, pink, teal]), .sparkles([gold, white]), .confetti([gold, silver, white])], look: "festive", light: "glow"),
        Theme(id: "hanukkah", name: "Hanukkah", emoji: "🕎", greeting: "Happy Hanukkah", months: [11, 12],
              keywords: ["hanukkah", "chanukah", "hanukah", "chanukkah", "חנוכה", "menorah", "dreidel"],
              palette: [blue, silver, white], layers: [.glow(0x1565C0), .bokeh([blue, silver, white]), .sparkles([blue, silver, white]), .snow, .corners(["🕎", "✡️"])], look: "frost", light: "glow"),
        Theme(id: "kwanzaa", name: "Kwanzaa", emoji: "🕯️", greeting: "Happy Kwanzaa", months: [12, 1],
              keywords: ["kwanzaa", "habari gani"],
              palette: [red, 0x212121, green], layers: [.rays(gold), .bokeh([red, leaf, gold]), .lights([red, 0x424242, leaf]), .embers(gold), .corners(["🕯️"])], look: "harvest", light: "glow"),
        Theme(id: "diwali", name: "Diwali", emoji: "🪔", greeting: "Happy Diwali", months: [10, 11],
              keywords: ["diwali", "deepavali", "dipawali", "divali", "दिवाली", "दीपावली", "தீபாவளி", "దీపావళి", "ದೀಪಾವಳಿ", "দীপাবলি", "દિવાળી", "deepotsav", "lakshmi puja", "laxmi puja", "dhanteras", "festival of lights"],
              palette: [gold, orange, pink], layers: [.glow(orange), .bokeh([gold, orange, 0xFFE082]), .fireworks([gold, orange, pink, white]), .sparkles([gold, orange]), .embers(0xFFB74D), .diyas], look: "diwali", light: "glow"),
        Theme(id: "holi", name: "Holi", emoji: "🎨", greeting: "Happy Holi", months: [3],
              keywords: ["holi", "होली", "હોળી", "festival of colours", "festival of colors", "rangwali", "dhuleti", "dhulandi", "phagwah", "rang"],
              palette: [pink, yellow, leaf, blue, purple, orange], layers: [.powder([pink, yellow, leaf, blue, purple, orange]), .confetti([pink, yellow, leaf, blue])], look: "vivid"),
        Theme(id: "navratri", name: "Navratri", emoji: "💃", greeting: "Happy Navratri", months: [9, 10],
              keywords: ["navratri", "navaratri", "नवरात्रि", "નવરાત્રી", "garba", "dandiya", "dussehra", "dasara", "vijayadashami", "दशहरा"],
              palette: [orange, pink, gold, leaf], layers: [.bokeh([orange, pink, gold]), .sparkles([orange, pink, gold, leaf]), .confetti([orange, pink, gold, leaf, purple]), .corners(["🪔", "🌺"])], look: "festive", light: "glow"),
        Theme(id: "durgapuja", name: "Durga Puja", emoji: "🌺", greeting: "Shubho Durga Puja", months: [9, 10],
              keywords: ["durga puja", "pujo", "durgotsav", "দুর্গাপূজা", "শারদীয়া"],
              palette: [red, gold], layers: [.glow(red), .bokeh([red, gold]), .fall(["🌺"]), .sparkles([red, gold]), .embers(gold), .diyas], look: "diwali", light: "glow"),
        Theme(id: "ganesh", name: "Ganesh Chaturthi", emoji: "🐘", greeting: "Ganpati Bappa Morya", months: [8, 9],
              keywords: ["ganesh", "ganpati", "ganesha", "ganapati", "गणेश", "गणपति", "chaturthi", "vinayaka", "bappa"],
              palette: [orange, gold, red], layers: [.glow(orange), .fall(["🌺", "🌼"]), .sparkles([gold, orange])]),
        Theme(id: "janmashtami", name: "Janmashtami", emoji: "🦚", greeting: "Happy Janmashtami", months: [8, 9],
              keywords: ["janmashtami", "krishna", "gokulashtami", "जन्माष्टमी", "dahi handi"],
              palette: [blue, gold, leaf], layers: [.fall(["🦚"]), .sparkles([blue, gold]), .corners(["🪈", "🧈"])]),
        Theme(id: "rakhi", name: "Raksha Bandhan", emoji: "🎁", greeting: "Happy Raksha Bandhan", months: [8],
              keywords: ["rakhi", "raksha bandhan", "rakshabandhan", "रक्षाबंधन", "राखी"],
              palette: [orange, gold, pink], layers: [.sparkles([gold, orange, pink]), .fall(["🌸", "✨"]), .corners(["🎁", "💛"])]),
        Theme(id: "onam", name: "Onam", emoji: "🌼", greeting: "Happy Onam", months: [8, 9],
              keywords: ["onam", "ഓണം", "pookalam", "thiruvonam"],
              palette: [yellow, orange, gold], layers: [.fall(["🌼", "🌸", "🏵️"]), .sparkles([gold, orange]), .corners(["🛶"])]),
        Theme(id: "pongal", name: "Pongal · Sankranti", emoji: "🪁", greeting: "Happy Pongal", months: [1],
              keywords: ["pongal", "sankranti", "makar sankranti", "uttarayan", "lohri", "bihu", "kite festival", "पतंग", "पोंगल", "மகர", "பொங்கல்", "ઉત્તરાયણ"],
              palette: [orange, gold, leaf], layers: [.fly(["🪁", "🪁"]), .sparkles([gold, orange]), .corners(["🌾", "☀️"])]),
        Theme(id: "baisakhi", name: "Baisakhi", emoji: "🌾", greeting: "Happy Baisakhi", months: [4],
              keywords: ["baisakhi", "vaisakhi", "ਵਿਸਾਖੀ", "बैसाखी"],
              palette: [orange, gold, leaf], layers: [.fall(["🌾"]), .confetti([orange, gold, leaf]), .sparkles([gold])]),
        Theme(id: "gurpurab", name: "Gurpurab", emoji: "🪔", greeting: "Happy Gurpurab", months: [11],
              keywords: ["gurpurab", "guru nanak jayanti", "prakash purab", "ਗੁਰਪੁਰਬ"],
              palette: [gold, orange], layers: [.glow(orange), .bokeh([gold, orange]), .sparkles([gold, orange]), .embers(0xFFB74D), .diyas], look: "diwali", light: "glow"),
        Theme(id: "eid", name: "Eid", emoji: "🌙", greeting: "Eid Mubarak", months: [3, 4, 5, 6],
              keywords: ["eid", "eid mubarak", "eid al fitr", "eid ul fitr", "eid al adha", "eid ul adha", "bakrid", "bakra eid", "عيد", "عيد مبارك", "bayram", "hari raya", "lebaran", "عید"],
              palette: [gold, white, 0x00897B], layers: [.glow(0x00695C), .stars, .bokeh([gold, white]), .sparkles([gold, white]), .corners(["🌙", "⭐"])], look: "lunar", light: "glow"),
        Theme(id: "ramadan", name: "Ramadan", emoji: "🕌", greeting: "Ramadan Kareem", months: [2, 3],
              keywords: ["ramadan", "ramzan", "ramazan", "رمضان", "iftar", "ramadan kareem", "ramadan mubarak", "suhoor"],
              palette: [gold, 0x3949AB], layers: [.glow(0x283593), .stars, .bokeh([gold]), .sparkles([gold]), .corners(["🌙", "🕌"])], look: "frost", light: "glow"),
        Theme(id: "lunarnewyear", name: "Lunar New Year", emoji: "🧧", greeting: "Happy Lunar New Year", months: [1, 2],
              keywords: ["lunar new year", "chinese new year", "spring festival", "春节", "春節", "新年快乐", "新年快樂", "过年", "tet", "tết", "seollal", "설날", "cny", "gong xi fa cai", "kung hei fat choi"],
              palette: [red, gold], layers: [.bokeh([red, gold]), .rise(["🏮"]), .fireworks([red, gold]), .confetti([red, gold]), .corners(["🧧", "🐉"])], look: "lunar", light: "glow"),
        Theme(id: "midautumn", name: "Mid-Autumn Festival", emoji: "🥮", greeting: "Happy Mid-Autumn Festival", months: [9, 10],
              keywords: ["mid autumn", "mid-autumn", "moon festival", "mooncake", "中秋", "中秋节", "中秋節", "trung thu"],
              palette: [gold, orange], layers: [.glow(gold), .stars, .bokeh([gold, orange]), .rise(["🏮"]), .corners(["🥮", "🌕"])], look: "harvest", light: "glow"),
        Theme(id: "chuseok", name: "Chuseok", emoji: "🌕", greeting: "Happy Chuseok", months: [9, 10],
              keywords: ["chuseok", "추석", "hangawi", "한가위"],
              palette: [gold, orange], layers: [.stars, .fall(["🍂"]), .corners(["🌕"])]),
        Theme(id: "hanami", name: "Cherry blossom", emoji: "🌸", greeting: "Spring is here", months: [3, 4],
              keywords: ["hanami", "sakura", "cherry blossom", "花見", "桜", "spring"],
              palette: [pink, 0xF8BBD0], layers: [.glow(0xF48FB1), .bokeh([0xF8BBD0, white]), .fall(["🌸", "🌸", "💮"])], look: "spring", light: "glow"),
        Theme(id: "nowruz", name: "Nowruz", emoji: "🌷", greeting: "Happy Nowruz", months: [3],
              keywords: ["nowruz", "norooz", "navroz", "nauryz", "persian new year", "نوروز"],
              palette: [leaf, gold], layers: [.fall(["🌸", "🌷"]), .sparkles([leaf, gold]), .corners(["🌱"])]),
        Theme(id: "songkran", name: "Songkran", emoji: "💦", greeting: "Happy Songkran", months: [4],
              keywords: ["songkran", "thai new year", "water festival", "สงกรานต์", "thingyan"],
              palette: [teal, blue], layers: [.bubbles, .fall(["💦"]), .sparkles([teal, blue])]),
        Theme(id: "loikrathong", name: "Loi Krathong", emoji: "🪷", greeting: "Happy Loi Krathong", months: [11],
              keywords: ["loi krathong", "yi peng", "ลอยกระทง", "lantern festival"],
              palette: [gold, orange], layers: [.glow(orange), .stars, .bokeh([gold, orange]), .rise(["🏮"]), .embers(gold), .corners(["🪷"])], look: "diwali", light: "glow"),
        Theme(id: "vesak", name: "Vesak", emoji: "🪷", greeting: "Happy Vesak", months: [5],
              keywords: ["vesak", "wesak", "buddha purnima", "buddha day", "buddha jayanti"],
              palette: [gold, pink], layers: [.glow(gold), .rise(["🏮"]), .fall(["🪷"])]),
        Theme(id: "roshhashanah", name: "Rosh Hashanah", emoji: "🍎", greeting: "Shana Tova", months: [9, 10],
              keywords: ["rosh hashanah", "rosh hashana", "jewish new year", "shana tova", "ראש השנה"],
              palette: [gold, red], layers: [.glow(gold), .sparkles([gold, silver]), .corners(["🍎", "🍯"])]),
        Theme(id: "passover", name: "Passover", emoji: "🍷", greeting: "Chag Pesach Sameach", months: [3, 4],
              keywords: ["passover", "pesach", "פסח", "seder"],
              palette: [blue, silver, gold], layers: [.sparkles([blue, silver, gold]), .corners(["🍷", "✡️"])]),
        Theme(id: "easter", name: "Easter", emoji: "🐣", greeting: "Happy Easter", months: [3, 4],
              keywords: ["easter", "pascua", "paques", "ostern", "pasqua", "pascoa", "pasen", "resurrection"],
              palette: pastels, layers: [.bokeh(pastels), .fall(["🌸", "🌼"]), .confetti(pastels), .corners(["🐣", "🥚", "🐰", "🌷"])], look: "spring", light: "glow"),
        Theme(id: "valentines", name: "Valentine's Day", emoji: "❤️", greeting: "Happy Valentine's Day", months: [2],
              keywords: ["valentine", "valentines", "san valentin", "saint valentin", "情人节", "발렌타인", "be mine", "i love you"],
              palette: [pink, red], layers: [.bokeh([pink, red, 0xF8BBD0]), .rise(["❤️", "💕", "💖"]), .sparkles([pink, red])], look: "romance", light: "leak"),
        Theme(id: "stpatricks", name: "St Patrick's Day", emoji: "☘️", greeting: "Happy St. Patrick's Day", months: [3],
              keywords: ["st patrick", "st patricks", "saint patrick", "paddys day", "shamrock", "irish", "lá fhéile pádraig"],
              palette: [green, gold], layers: [.fall(["☘️", "🍀"]), .confetti([green, gold, 0x81C784]), .corners(["🍀"])]),
        Theme(id: "carnival", name: "Carnival", emoji: "🎭", greeting: "Happy Carnival", months: [2, 3],
              keywords: ["carnival", "carnaval", "mardi gras", "fasching", "karneval", "fat tuesday"],
              palette: [purple, leaf, gold], layers: [.confetti([purple, leaf, gold]), .sparkles([gold, purple]), .corners(["🎭", "🎉"])]),
        Theme(id: "halloween", name: "Halloween", emoji: "🎃", greeting: "Happy Halloween", months: [10],
              keywords: ["halloween", "spooky", "trick or treat", "samhain", "all hallows"],
              palette: [orange, purple], layers: [.glow(0xFF6F00), .stars, .bokeh([orange, purple]), .fly(["🦇", "🦇"]), .corners(["🎃", "👻", "🕸️"])], look: "spooky", light: "vignette"),
        Theme(id: "dayofthedead", name: "Day of the Dead", emoji: "💀", greeting: "Feliz Día de Muertos", months: [10, 11],
              keywords: ["dia de muertos", "dia de los muertos", "day of the dead", "calavera", "ofrenda"],
              palette: [pink, purple, orange, teal], layers: [.bokeh([orange, pink, gold]), .fall(["🌼"]), .confetti([pink, purple, orange, teal, gold]), .embers(gold), .corners(["💀", "🕯️"])], look: "festive", light: "glow"),
        Theme(id: "thanksgiving", name: "Thanksgiving", emoji: "🦃", greeting: "Happy Thanksgiving", months: [10, 11],
              keywords: ["thanksgiving", "turkey day", "friendsgiving", "action de grace", "grateful", "gratitude"],
              palette: [orange, 0x8D6E63, gold], layers: [.rays(0xFFB74D), .bokeh([orange, gold]), .fall(["🍂", "🍁", "🍂"]), .embers(0xFFCC80), .corners(["🦃", "🥧", "🌽"])], look: "harvest", light: "sun"),
        Theme(id: "july4", name: "4th of July", emoji: "🇺🇸", greeting: "Happy 4th of July", months: [7],
              keywords: ["4th of july", "fourth of july", "july 4", "independence day usa", "usa", "america"],
              palette: [red, white, blue], layers: [.stars, .bokeh([red, white, blue]), .fireworks([red, white, blue]), .confetti([red, white, blue])], look: "festive", light: "glow"),
        Theme(id: "india", name: "Independence · Republic Day", emoji: "🇮🇳", greeting: "Happy Independence Day", months: [8, 1],
              keywords: ["independence day india", "republic day", "15 august", "26 january", "स्वतंत्रता दिवस", "गणतंत्र दिवस", "jai hind", "tiranga"],
              palette: [0xFF9933, white, 0x138808], layers: [.bokeh([0xFF9933, white, 0x138808]), .fireworks([0xFF9933, white, 0x138808]), .confetti([0xFF9933, white, 0x138808]), .corners(["🇮🇳"])], look: "festive", light: "glow"),
        Theme(id: "canada", name: "Canada Day", emoji: "🇨🇦", greeting: "Happy Canada Day", months: [7],
              keywords: ["canada day", "fete du canada"],
              palette: [red, white], layers: [.fall(["🍁"]), .bokeh([red, white]), .fireworks([red, white])], look: "festive", light: "glow"),
        Theme(id: "oktoberfest", name: "Oktoberfest", emoji: "🍺", greeting: "Prost!", months: [9, 10],
              keywords: ["oktoberfest", "wiesn", "beer festival"],
              palette: [0x1565C0, white], layers: [.bubbles, .confetti([0x1565C0, white]), .corners(["🍺", "🥨"])]),
        Theme(id: "pride", name: "Pride", emoji: "🏳️‍🌈", greeting: "Happy Pride", months: [6],
              keywords: ["pride", "lgbt", "lgbtq", "rainbow"],
              palette: rainbow, layers: [.confetti(rainbow), .sparkles(rainbow), .rise(["🏳️‍🌈"])]),
        Theme(id: "mothersday", name: "Mother's Day", emoji: "💐", greeting: "Happy Mother's Day", months: [5],
              keywords: ["mothers day", "mother's day", "mom", "mum", "mama", "dia de la madre", "fete des meres", "muttertag", "festa della mamma"],
              palette: [pink, 0xF8BBD0], layers: [.bokeh([pink, 0xF8BBD0]), .fall(["🌷", "🌸"]), .sparkles([pink]), .corners(["💐"])], look: "spring", light: "glow"),
        Theme(id: "fathersday", name: "Father's Day", emoji: "👔", greeting: "Happy Father's Day", months: [6],
              keywords: ["fathers day", "father's day", "dad", "papa", "dia del padre", "fete des peres", "vatertag"],
              palette: [blue, teal, gold], layers: [.confetti([blue, teal, gold]), .sparkles([gold]), .corners(["👔", "🏆"])]),
        Theme(id: "birthday", name: "Birthday", emoji: "🎂", greeting: "Happy Birthday", months: [],
              keywords: ["birthday", "bday", "b-day", "cumpleanos", "feliz cumpleanos", "anniversaire", "geburtstag", "compleanno", "aniversario", "生日", "誕生日", "생일", "जन्मदिन", "happy bday"],
              palette: rainbow, layers: [.bokeh(pastels), .rise(["🎈", "🎈", "🎈"]), .confetti(rainbow), .sparkles([gold, white]), .corners(["🎂", "🎁"])], look: "festive", light: "glow"),
        Theme(id: "wedding", name: "Wedding", emoji: "💍", greeting: "Just Married", months: [],
              keywords: ["wedding", "married", "marriage", "shaadi", "शादी", "boda", "mariage", "hochzeit", "matrimonio", "casamento", "结婚", "engagement", "engaged", "nikah"],
              palette: [gold, white], layers: [.bokeh([gold, 0xFFF3D6, 0xF8BBD0]), .fall(["🌸", "🤍"]), .sparkles([gold, white]), .corners(["💍"])], look: "romance", light: "glow"),
        Theme(id: "anniversary", name: "Anniversary", emoji: "💞", greeting: "Happy Anniversary", months: [],
              keywords: ["anniversary", "years together"],
              palette: [gold, pink], layers: [.bokeh([gold, pink]), .rise(["💞", "❤️"]), .sparkles([gold, pink])], look: "romance", light: "glow"),
        Theme(id: "graduation", name: "Graduation", emoji: "🎓", greeting: "Congratulations, Graduate!", months: [5, 6],
              keywords: ["graduation", "graduate", "grad", "convocation", "commencement", "class of"],
              palette: [gold, 0x1A237E, white], layers: [.confetti([gold, 0x1A237E, white]), .rise(["🎓"]), .corners(["🎓", "📜"])]),
        Theme(id: "baby", name: "New baby", emoji: "🍼", greeting: "Welcome, little one!", months: [],
              keywords: ["baby", "baby shower", "newborn", "gender reveal", "its a boy", "it's a boy", "its a girl", "it's a girl", "welcome baby", "godh bharai"],
              palette: pastels, layers: [.bubbles, .rise(["🎈"]), .confetti(pastels), .corners(["🍼", "🧸"])]),
        Theme(id: "retirement", name: "Retirement", emoji: "🏖️", greeting: "Happy Retirement", months: [],
              keywords: ["retirement", "retiring", "retired"],
              palette: [gold, teal], layers: [.confetti([gold, teal]), .rise(["🎈"]), .corners(["🏖️", "🎉"])]),
        Theme(id: "congrats", name: "Congratulations", emoji: "🎉", greeting: "Congratulations!", months: [],
              keywords: ["congrats", "congratulations", "well done", "promotion", "new job", "achievement", "winner", "champion", "celebration", "party", "felicidades", "felicitations", "glückwunsch", "badhai", "बधाई"],
              palette: rainbow, layers: [.bokeh([gold, white]), .fireworks(rainbow), .confetti(rainbow), .corners(["🎉", "🏆"])], look: "festive", light: "glow"),
        Theme(id: "holidays", name: "Happy Holidays", emoji: "❄️", greeting: "Happy Holidays", months: [12, 1],
              keywords: ["holidays", "happy holidays", "holiday season", "seasons greetings", "season's greetings", "winter", "snow"],
              palette: [white, silver, 0x90CAF9], layers: [.glow(0x90CAF9), .bokeh([white, silver, 0x90CAF9, gold]), .snow, .fall(["❄️"]), .sparkles([white, silver, 0x90CAF9])], look: "frost", light: "glow"),
        Theme(id: "autumn", name: "Autumn", emoji: "🍁", greeting: "Hello, Autumn", months: [9, 10, 11],
              keywords: ["autumn", "fall season", "fall leaves"],
              palette: [orange, 0x8D6E63], layers: [.rays(0xFFB74D), .bokeh([orange, 0xFFCC80]), .fall(["🍁", "🍂"])], look: "harvest", light: "sun"),
        Theme(id: "summer", name: "Summer", emoji: "☀️", greeting: "Hello, Summer", months: [6, 7, 8],
              keywords: ["summer", "beach", "vacation", "summer holiday"],
              palette: [gold, teal], layers: [.bubbles, .sparkles([gold, teal]), .corners(["☀️", "🌴", "🏖️"])]),
    ]

    static func theme(_ id: String) -> Theme? { themes.first { $0.id == id } }

    /// Festivals that fall this month or next come first; "any day" ones (birthday, wedding…) after them.
    static func ordered(now: Date = Date()) -> [Theme] {
        let m = Calendar.current.component(.month, from: now)
        func soon(_ t: Theme) -> Int { t.months.isEmpty ? 6 : t.months.map { ($0 - m + 12) % 12 }.min() ?? 12 }
        return themes.enumerated().sorted { a, b in
            let x = soon(a.element), y = soon(b.element)
            return x != y ? x < y : a.offset < b.offset
        }.map(\.element)
    }
    static func comingUp(now: Date = Date()) -> [Theme] {
        let m = Calendar.current.component(.month, from: now)
        return ordered(now: now).filter { t in t.months.contains { ($0 - m + 12) % 12 <= 1 } }
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
    }

    /// Lower-case, accents and apostrophes gone, punctuation as single spaces — for comparing what's typed with names.
    static func norm(_ s: String) -> String {
        fold(s).replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "[^\\p{L}\\p{M}\\p{N}]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// The listed celebration someone means by what they typed, in any of the languages we know; nil if none.
    static func match(_ text: String) -> Theme? {
        let t = " " + norm(text) + " "
        var best: (Theme, Int)?
        for theme in themes {
            for k in theme.keywords + [theme.name, theme.id] {
                let key = norm(k)
                guard !key.isEmpty else { continue }
                // Whole words for Latin words ("eid" is not inside "seidel"); any position for scripts without spaces.
                let isLatin = key.unicodeScalars.allSatisfy { $0.isASCII }
                let hit = isLatin ? t.contains(" " + key + " ") || t.contains(" " + key + "s ") : t.contains(key)
                if hit, key.count > (best?.1 ?? 0) { best = (theme, key.count) }
            }
        }
        return best?.0
    }

    /// The emoji in a piece of text.
    static func emoji(in text: String) -> [String] {
        text.filter { c in
            guard let s = c.unicodeScalars.first else { return false }
            return s.properties.isEmojiPresentation || (s.properties.isEmoji && c.unicodeScalars.count > 1)
        }.map(String.init)
    }

    /// Words that suggest a picture when someone types a celebration we don't list.
    static let wordEmoji: [String: String] = [
        "dog": "🐶", "puppy": "🐶", "cat": "🐱", "kitten": "🐱", "football": "⚽", "soccer": "⚽", "cricket": "🏏",
        "basketball": "🏀", "baseball": "⚾", "tennis": "🎾", "golf": "⛳", "music": "🎵", "concert": "🎵", "pizza": "🍕",
        "coffee": "☕", "travel": "✈️", "trip": "✈️", "beach": "🏖️", "moon": "🌙", "sun": "☀️", "star": "⭐",
        "flower": "🌸", "rose": "🌹", "cake": "🎂", "love": "❤️", "friend": "🤝", "friends": "🤝", "team": "🙌",
        "game": "🎮", "book": "📚", "school": "🏫", "house": "🏡", "home": "🏡", "housewarming": "🏡", "car": "🚗",
        "wine": "🍷", "beer": "🍺", "dance": "💃", "farewell": "👋", "goodbye": "👋", "welcome": "👋", "thank": "🙏",
        "thanks": "🙏", "prayer": "🙏", "puja": "🪔", "temple": "🛕", "church": "⛪", "mosque": "🕌", "gift": "🎁",
        "money": "💰", "launch": "🚀", "anniversary": "💞", "kids": "🧒", "teacher": "🍎", "nurse": "🩺", "doctor": "🩺",
        "earth": "🌍", "tree": "🌳", "garden": "🌷", "camp": "🏕️", "fish": "🐟", "horse": "🐎", "rain": "🌧️",
    ]

    /// A celebration made from someone's own words when it isn't in the list: their emoji (or ones their words
    /// suggest) drifting and in the corners, confetti and sparkles in a palette chosen from the words.
    static func custom(from text: String) -> Theme {
        let words = fold(text).split { !$0.isLetter }.map(String.init)
        var pics = emoji(in: text)
        for w in words { if let e = wordEmoji[w], !pics.contains(e) { pics.append(e) } }
        pics = Array(pics.prefix(4))
        let palettes: [[UInt32]] = [rainbow, [gold, pink, white], [teal, blue, white], [orange, gold, red], [purple, pink, gold], [leaf, gold, teal]]
        let h = text.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        let palette = palettes[Int(h % UInt32(palettes.count))]
        var layers: [Layer] = [.sparkles(palette), .confetti(palette)]
        if !pics.isEmpty { layers.append(.rise(pics)); layers.append(.corners(pics)) }
        let greeting = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Theme(id: "custom", name: greeting.isEmpty ? "Celebration" : greeting, emoji: pics.first ?? "🎉",
                     greeting: greeting.isEmpty ? "Let's celebrate!" : greeting, months: [], keywords: [], palette: palette,
                     layers: layers, custom: true)
    }

    /// What someone typed, as a celebration: the listed one if we know it, otherwise one built from their words.
    static func resolve(_ text: String) -> Theme {
        if var t = match(text) {
            // Typed their own greeting with the festival in it ("Happy Diwali from the Shahs") — keep their words.
            let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if typed.split(separator: " ").count > 2 { t.greeting = typed }
            return t
        }
        return custom(from: text)
    }

    // MARK: - Words on the video

    enum Font: String, CaseIterable, Identifiable {
        case bold, elegant, script, hand, neon, classic
        var id: String { rawValue }
        var title: String {
            switch self {
            case .bold: return "Bold"
            case .elegant: return "Elegant"
            case .script: return "Script"
            case .hand: return "Handwritten"
            case .neon: return "Neon"
            case .classic: return "Classic"
            }
        }
        func ui(_ size: CGFloat) -> UIFont {
            func named(_ n: String) -> UIFont? { UIFont(name: n, size: size) }
            switch self {
            case .bold, .neon:
                let base = UIFont.systemFont(ofSize: size, weight: .heavy)
                return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
            case .elegant: return named("Didot-Bold") ?? named("BodoniSvtyTwoITCTT-Bold") ?? .boldSystemFont(ofSize: size)
            case .script: return named("SnellRoundhand-Black") ?? named("SnellRoundhand-Bold") ?? .italicSystemFont(ofSize: size)
            case .hand: return named("Noteworthy-Bold") ?? named("MarkerFelt-Wide") ?? .boldSystemFont(ofSize: size)
            case .classic: return named("Georgia-Bold") ?? .boldSystemFont(ofSize: size)
            }
        }
    }

    struct Caption: Equatable {
        var text: String
        var font: Font = .bold
        var color: UInt32 = 0xFFFFFF
        /// Letter height as a share of the frame's width.
        var scale: CGFloat = 0.085
        /// Where its middle sits, 0…1 across and down.
        var center = CGPoint(x: 0.5, y: 0.16)
    }

    static let captionColors: [UInt32] = [0xFFFFFF, 0xFFD54A, 0xFF8A80, 0xF8BBD0, 0x80DEEA, 0xB9F6CA, 0xFFAB40, 0x212121]

    static func color(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// The words drawn the way they'll appear on a `frame`-sized video: no box over the picture — a soft dark outline
    /// and shadow keep them readable on any background. Transparent around the letters.
    static func captionImage(_ c: Caption, frame: CGSize) -> UIImage? {
        let text = c.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, frame.width > 0 else { return nil }
        let fontSize = max(10, frame.width * c.scale)
        let font = c.font.ui(fontSize)
        let fill = color(c.color)
        let dark = c.color == 0x212121
        let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineBreakMode = .byWordWrapping
        let shadow = NSShadow()
        if c.font == .neon {
            shadow.shadowColor = fill; shadow.shadowBlurRadius = fontSize * 0.45; shadow.shadowOffset = .zero
        } else {
            shadow.shadowColor = UIColor(white: dark ? 1 : 0, alpha: 0.55); shadow.shadowBlurRadius = fontSize * 0.18
            shadow.shadowOffset = CGSize(width: 0, height: fontSize * 0.04)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: c.font == .neon ? UIColor.white : fill, .paragraphStyle: para, .shadow: shadow,
            .strokeColor: c.font == .neon ? fill : UIColor(white: dark ? 1 : 0, alpha: 0.6), .strokeWidth: c.font == .neon ? -2.5 : -3.0,
        ]
        let s = NSAttributedString(string: text, attributes: attrs)
        let maxW = frame.width * 0.88
        let box = s.boundingRect(with: CGSize(width: maxW, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let pad = fontSize * 0.6
        let size = CGSize(width: ceil(min(maxW, box.width)) + pad * 2, height: ceil(box.height) + pad * 2)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            s.draw(with: CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2),
                   options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            if c.font == .neon { s.draw(with: CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil) }
        }
    }

    /// Where the words sit by default: across the top, unless a face is there — then along the bottom.
    static func clearSpot(in frame: CGImage?) -> CGPoint {
        let top = CGPoint(x: 0.5, y: 0.16), bottom = CGPoint(x: 0.5, y: 0.82)
        guard let frame else { return top }
        let req = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: frame, options: [:]).perform([req])
        let faces = (req.results ?? []).map(\.boundingBox)        // 0…1, y up
        func covers(_ y: CGFloat) -> Bool { faces.contains { f in (1 - f.maxY) < y + 0.12 && (1 - f.minY) > y - 0.12 } }
        if !covers(top.y) { return top }
        if !covers(bottom.y) { return bottom }
        return top
    }

    // MARK: - Drawing the decorations

    /// Draws a theme's decorations for any moment of the video. Deterministic: frame t always looks the same.
    final class Painter {
        let layers: [Layer]
        let size: CGSize
        let amount: Double
        private let ctx: CGContext?
        private var sprites: [String: CGImage] = [:]
        private let lock = NSLock()

        init(theme: Theme, size: CGSize, amount: Double) {
            layers = theme.layers.sorted { $0.depth < $1.depth }
            self.size = CGSize(width: max(2, size.width.rounded()), height: max(2, size.height.rounded()))
            self.amount = amount
            ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            // Draw with the top-left as the origin, like the screen.
            ctx?.translateBy(x: 0, y: self.size.height); ctx?.scaleBy(x: 1, y: -1)
        }

        var W: CGFloat { size.width }
        var H: CGFloat { size.height }
        var u: CGFloat { min(size.width, size.height) }

        /// The decorations at `t` seconds, transparent everywhere else.
        func image(at t: Double) -> CGImage? { image(at: t, only: nil) }

        /// Light (fireworks, glows, bokeh, embers, rays, sparkles) is added onto the video so it lights it up; the
        /// rest (leaves, confetti, snow, lamps) sits on top. `light` picks which half; nil draws everything.
        func image(at t: Double, only light: Bool?) -> CGImage? {
            lock.lock(); defer { lock.unlock() }
            guard let ctx else { return nil }
            ctx.saveGState()
            ctx.clear(CGRect(origin: .zero, size: size))
            for l in layers where light == nil || l.isLight == light { draw(l, t, ctx) }
            ctx.restoreGState()
            return ctx.makeImage()
        }
        var hasLight: Bool { layers.contains { $0.isLight } }

        // Deterministic noise: the same particle always gets the same numbers.
        private func r(_ i: Int, _ salt: Int) -> CGFloat {
            var z = UInt64(bitPattern: Int64(i &* 7919 &+ salt &* 104729 &+ 1))
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            z = z ^ (z >> 31)
            return CGFloat(z % 1_000_000) / 1_000_000
        }
        private func count(_ n: Double) -> Int { max(1, Int((n * amount).rounded())) }
        /// A looping 0…1 position: start + speed·t, wrapping.
        private func loop(_ start: CGFloat, _ perSecond: CGFloat, _ t: Double, span: CGFloat = 1) -> CGFloat {
            let v = (start * span + perSecond * CGFloat(t)).truncatingRemainder(dividingBy: span)
            return v < 0 ? v + span : v
        }

        private func draw(_ l: Layer, _ t: Double, _ c: CGContext) {
            switch l {
            case .snow: snow(t, c)
            case .confetti(let p): confetti(t, p, c)
            case .sparkles(let p): sparkles(t, p, c)
            case .lights(let p): lights(t, p, c)
            case .fireworks(let p): fireworks(t, p, c)
            case .fall(let e): fall(t, e, c)
            case .rise(let e): rise(t, e, c)
            case .fly(let e): fly(t, e, c)
            case .corners(let e): corners(t, e, c)
            case .diyas: diyas(t, c)
            case .powder(let p): powder(t, p, c)
            case .bubbles: bubbles(t, c)
            case .stars: stars(t, c)
            case .glow(let col): glow(t, col, c)
            case .bokeh(let p): bokeh(t, p, c)
            case .embers(let col): embers(t, col, c)
            case .rays(let col): rays(t, col, c)
            case .sleigh: sleigh(t, c)
            }
        }

        // Sprites (drawn once, reused every frame)

        private func dot() -> CGImage? {
            if let s = sprites["dot"] { return s }
            let d = 64
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
            let img = UIGraphicsImageRenderer(size: CGSize(width: d, height: d), format: fmt).image { r in
                let cols = [UIColor.white.cgColor, UIColor(white: 1, alpha: 0.55).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.35, 1]) {
                    r.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: d / 2, y: d / 2), startRadius: 0, endCenter: CGPoint(x: d / 2, y: d / 2), endRadius: CGFloat(d) / 2, options: [])
                }
            }.cgImage
            sprites["dot"] = img
            return img
        }

        /// A lens's out-of-focus light: a soft disc with a slightly brighter rim.
        private func disc() -> CGImage? {
            if let s = sprites["disc"] { return s }
            let d = 96
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
            let img = UIGraphicsImageRenderer(size: CGSize(width: d, height: d), format: fmt).image { r in
                let cols = [UIColor(white: 1, alpha: 0.5).cgColor, UIColor(white: 1, alpha: 0.62).cgColor, UIColor(white: 1, alpha: 0.85).cgColor,
                            UIColor(white: 1, alpha: 0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.7, 0.88, 1]) {
                    r.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: d / 2, y: d / 2), startRadius: 0, endCenter: CGPoint(x: d / 2, y: d / 2), endRadius: CGFloat(d) / 2, options: [])
                }
            }.cgImage
            sprites["disc"] = img
            return img
        }

        private func glyph(_ e: String) -> CGImage? {
            if let s = sprites[e] { return s }
            let side: CGFloat = 160
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
            let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { _ in
                let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: side * 0.8)]
                let s = (e as NSString).size(withAttributes: a)
                (e as NSString).draw(at: CGPoint(x: (side - s.width) / 2, y: (side - s.height) / 2), withAttributes: a)
            }.cgImage
            sprites[e] = img
            return img
        }

        /// Draw a sprite upright (the context is flipped to screen coordinates), centred, turned and stretched.
        private func put(_ img: CGImage?, _ c: CGContext, at p: CGPoint, size s: CGFloat, angle: CGFloat = 0, sx: CGFloat = 1, sy: CGFloat = 1,
                         alpha: CGFloat = 1, tint: UIColor? = nil) {
            guard let img, s > 0.5, alpha > 0.01 else { return }
            c.saveGState()
            c.translateBy(x: p.x, y: p.y); c.rotate(by: angle); c.scaleBy(x: sx, y: -sy)
            c.setAlpha(alpha)
            let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
            if let tint {
                c.clip(to: rect, mask: img)
                c.setFillColor(tint.cgColor); c.fill(rect)
            } else {
                c.draw(img, in: rect)
            }
            c.restoreGState()
        }

        // Layers

        /// Snow with depth: tiny slow flakes far away, a few big soft out-of-focus ones right in front of the lens.
        private func snow(_ t: Double, _ c: CGContext) {
            let n = count(110)
            for i in 0..<n {
                let z = r(i, 1)
                let near = z > 0.9
                let s = near ? u * (0.045 + 0.05 * r(i, 7)) : u * (0.006 + 0.024 * z * z)
                let y = loop(r(i, 2), 0.035 + 0.12 * z, t, span: 1.15) * H - H * 0.07
                let x = loop(r(i, 3), 0.008 + 0.012 * z, t, span: 1.1) * W - W * 0.05
                    + sin(CGFloat(t) * (0.5 + r(i, 4)) + r(i, 5) * 6) * u * (0.02 + 0.05 * z)
                put(dot(), c, at: CGPoint(x: x, y: y), size: s, alpha: near ? 0.32 : 0.4 + 0.55 * z)
            }
        }

        private func confetti(_ t: Double, _ p: [UInt32], _ c: CGContext) {
            let n = count(70)
            for i in 0..<n {
                let y = loop(r(i, 11), 0.16 + 0.12 * r(i, 12), t, span: 1.2) * H - H * 0.1
                let x = r(i, 13) * W + sin(CGFloat(t) * 1.6 + r(i, 14) * 6) * u * 0.04
                let spin = CGFloat(t) * (2 + 3 * r(i, 15)) + r(i, 16) * 6
                let flip = cos(CGFloat(t) * (4 + 4 * r(i, 17)) + r(i, 18) * 6)
                let w = u * 0.022, h = u * 0.011
                c.saveGState()
                c.translateBy(x: x, y: y); c.rotate(by: spin); c.scaleBy(x: max(0.08, abs(flip)), y: 1)
                c.setFillColor(Celebrate.color(p[i % max(1, p.count)], alpha: 0.95).cgColor)
                if i % 3 == 0 { c.fillEllipse(in: CGRect(x: -h, y: -h, width: h * 2, height: h * 2)) } else { c.fill(CGRect(x: -w / 2, y: -h / 2, width: w, height: h)) }
                c.restoreGState()
            }
        }

        private func sparkles(_ t: Double, _ p: [UInt32], _ c: CGContext) {
            let n = count(26)
            for i in 0..<n {
                let period = 1.3 + 1.4 * Double(r(i, 21))
                let phase = Double(r(i, 22)) * period
                let cycle = Int(floor((t + phase) / period))
                let f = CGFloat(((t + phase) / period) - Double(cycle))
                let b = pow(sin(f * .pi), 2)
                let pt = CGPoint(x: r(i &* 31 &+ cycle, 23) * W, y: r(i &* 31 &+ cycle, 24) * H)
                let s = u * (0.02 + 0.035 * r(i, 25)) * b
                let col = Celebrate.color(p[i % max(1, p.count)])
                put(dot(), c, at: pt, size: s * 1.6, alpha: 0.7 * b, tint: col)
                c.saveGState()
                c.translateBy(x: pt.x, y: pt.y); c.rotate(by: CGFloat(t) * 0.8)
                c.setFillColor(UIColor(white: 1, alpha: 0.95 * b).cgColor)
                for k in 0..<2 {
                    c.saveGState(); c.rotate(by: CGFloat(k) * .pi / 2)
                    let m = CGMutablePath()
                    m.move(to: CGPoint(x: 0, y: -s)); m.addLine(to: CGPoint(x: s * 0.12, y: 0)); m.addLine(to: CGPoint(x: 0, y: s))
                    m.addLine(to: CGPoint(x: -s * 0.12, y: 0)); m.closeSubpath()
                    c.addPath(m); c.fillPath()
                    c.restoreGState()
                }
                c.restoreGState()
            }
        }

        private func lights(_ t: Double, _ p: [UInt32], _ c: CGContext) {
            let top = H * 0.035, sag = H * 0.045
            func wireY(_ x: CGFloat) -> CGFloat { top + sag * abs(sin(.pi * x / (W / 2))) }
            c.saveGState()
            c.setStrokeColor(UIColor(red: 0.08, green: 0.2, blue: 0.1, alpha: 0.9).cgColor); c.setLineWidth(max(1.5, u * 0.004))
            c.move(to: CGPoint(x: 0, y: wireY(0)))
            var x: CGFloat = 0
            while x <= W { c.addLine(to: CGPoint(x: x, y: wireY(x))); x += W / 60 }
            c.strokePath()
            c.restoreGState()
            let n = 14
            for i in 0..<n {
                let bx = W * (CGFloat(i) + 0.5) / CGFloat(n)
                let by = wireY(bx) + u * 0.016
                let col = Celebrate.color(p[i % max(1, p.count)])
                let tw = 0.55 + 0.45 * sin(CGFloat(t) * 2.6 + CGFloat(i) * 1.9)
                put(dot(), c, at: CGPoint(x: bx, y: by + u * 0.01), size: u * 0.11 * tw, alpha: 0.75 * tw, tint: col)
                c.setFillColor(col.cgColor)
                c.fillEllipse(in: CGRect(x: bx - u * 0.009, y: by - u * 0.004, width: u * 0.018, height: u * 0.028))
                c.setFillColor(UIColor(white: 1, alpha: 0.6 * tw).cgColor)
                c.fillEllipse(in: CGRect(x: bx - u * 0.004, y: by + u * 0.002, width: u * 0.006, height: u * 0.01))
                c.setFillColor(UIColor(white: 0.15, alpha: 1).cgColor)
                c.fill(CGRect(x: bx - u * 0.006, y: by - u * 0.012, width: u * 0.012, height: u * 0.009))
            }
        }

        /// Real fireworks: a rocket climbs with a sparking tail, bursts with a flash that lights the sky, and its stars
        /// fly out, slow in the air, fall and fade — white-hot first, then their colour, crackling as they die. Three
        /// kinds: a full peony, a golden willow that weeps long trails, and a ring.
        private func fireworks(_ t: Double, _ p: [UInt32], _ c: CGContext) {
            let cycle = 2.7
            let slots = amount >= 1.3 ? 5 : (amount >= 0.9 ? 4 : 3)
            let gold = UIColor(red: 1, green: 0.78, blue: 0.35, alpha: 1)
            c.saveGState()
            c.setBlendMode(.plusLighter)
            c.setLineCap(.round)
            for k in 0..<slots {
                let off = cycle * Double(k) / Double(slots)
                let b = Int(floor((t + off) / cycle))
                let tau = CGFloat(t + off - Double(b) * cycle)
                let key = b &* 13 &+ k
                let apex = CGPoint(x: W * (0.15 + 0.7 * r(key, 31)), y: H * (0.1 + 0.3 * r(key, 32)))
                let launchX = apex.x + (r(key, 35) - 0.5) * W * 0.18
                let col = Celebrate.color(p[Int(r(key, 33) * CGFloat(p.count)) % max(1, p.count)])
                let kind = Int(r(key, 36) * 3)            // 0 peony · 1 willow · 2 ring
                let climb: CGFloat = 0.6
                if tau < climb {
                    // The rocket: a bright head and a tail of sparks, slowing as it nears the top.
                    let q = tau / climb, e = 1 - (1 - q) * (1 - q)
                    let head = CGPoint(x: launchX + (apex.x - launchX) * e, y: H * 1.02 + (apex.y - H * 1.02) * e)
                    for i in 0..<7 {
                        let back = CGFloat(i) * u * 0.02 * (1.2 - q)
                        put(dot(), c, at: CGPoint(x: head.x + (r(i, key) - 0.5) * u * 0.01, y: head.y + back), size: u * (0.03 - CGFloat(i) * 0.003),
                            alpha: (1 - CGFloat(i) / 7) * 0.9, tint: i == 0 ? .white : gold)
                    }
                    continue
                }
                let s = tau - climb
                let life: CGFloat = kind == 1 ? 1.95 : 1.45
                guard s < life else { continue }
                let fade = 1 - s / life
                // The flash lights the sky around it.
                put(dot(), c, at: apex, size: u * 1.2, alpha: 0.22 * fade * fade, tint: col)
                if s < 0.22 { put(dot(), c, at: apex, size: u * 0.16, alpha: 1 - s / 0.22, tint: .white) }
                let n = kind == 2 ? 44 : 70
                let speed = u * (0.5 + 0.2 * r(key, 34))
                let drag: CGFloat = kind == 1 ? 1.1 : 2.3
                let g = u * (kind == 1 ? 0.26 : 0.17)
                func at(_ a: CGFloat, _ v: CGFloat, _ tt: CGFloat) -> CGPoint {
                    let d = v * (1 - exp(-drag * tt)) / drag
                    return CGPoint(x: apex.x + cos(a) * d, y: apex.y + sin(a) * d + 0.5 * g * tt * tt)
                }
                let trail: CGFloat = kind == 1 ? 0.55 : 0.2
                let path = CGMutablePath()
                var heads: [CGPoint] = []
                for j in 0..<n {
                    let a = CGFloat(j) / CGFloat(n) * 2 * .pi + r(j, key) * 0.14
                    let v = speed * (kind == 2 ? 1 : 0.55 + 0.45 * r(j, key &+ 1))
                    let head = at(a, v, s)
                    path.move(to: at(a, v, max(0, s - trail))); path.addLine(to: head)
                    heads.append(head)
                }
                c.setLineWidth(u * (kind == 1 ? 0.007 : 0.009))
                c.setStrokeColor((kind == 1 ? gold : col).withAlphaComponent(0.7 * fade).cgColor)
                c.addPath(path); c.strokePath()
                let hot = s < 0.25
                for (j, h) in heads.enumerated() {
                    var a = fade
                    if s > life * 0.55, r(j, key &+ Int(s * 18)) < 0.45 { a *= 0.2 }   // crackle as the stars die
                    put(dot(), c, at: h, size: u * (hot ? 0.036 : 0.028), alpha: a, tint: hot ? .white : (kind == 1 ? gold : col))
                }
            }
            c.restoreGState()
        }

        /// Leaves, petals, flowers drifting down with depth: small and faint far away, big and close in front, each
        /// one tumbling in 3D as it falls.
        private func fall(_ t: Double, _ e: [String], _ c: CGContext) {
            guard !e.isEmpty else { return }
            let n = count(22)
            for i in 0..<n {
                let z = r(i, 49)
                let s = u * (0.035 + 0.1 * z)
                let y = loop(r(i, 42), 0.05 + 0.1 * z, t, span: 1.25) * H - H * 0.12
                let x = r(i, 44) * W + sin(CGFloat(t) * (0.6 + r(i, 45)) + r(i, 46) * 6) * u * (0.04 + 0.06 * z)
                let ang = sin(CGFloat(t) * 1.1 + r(i, 47) * 6) * 0.8 + CGFloat(t) * 0.5 * (r(i, 48) - 0.5)
                let tumble = cos(CGFloat(t) * (1.2 + 2 * r(i, 50)) + r(i, 51) * 6)
                put(glyph(e[i % e.count]), c, at: CGPoint(x: x, y: y), size: s, angle: ang, sx: max(0.2, abs(tumble)), alpha: 0.55 + 0.45 * z)
            }
        }

        private func rise(_ t: Double, _ e: [String], _ c: CGContext) {
            guard !e.isEmpty else { return }
            let n = count(12)
            for i in 0..<n {
                let z = r(i, 57)
                let s = u * (0.05 + 0.09 * z)
                let y = H * 1.1 - loop(r(i, 52), 0.05 + 0.07 * z, t, span: 1.3) * H
                let x = r(i, 54) * W + sin(CGFloat(t) * (0.8 + r(i, 55)) + r(i, 56) * 6) * u * 0.04
                put(glyph(e[i % e.count]), c, at: CGPoint(x: x, y: y), size: s, angle: sin(CGFloat(t) * 1.3 + CGFloat(i)) * 0.12, alpha: 0.6 + 0.4 * z)
            }
        }

        private func fly(_ t: Double, _ e: [String], _ c: CGContext) {
            guard !e.isEmpty else { return }
            let n = count(5)
            for i in 0..<n {
                let right = i % 2 == 0
                let s = u * (0.07 + 0.05 * r(i, 61))
                let px = loop(r(i, 62), 0.07 + 0.06 * r(i, 63), t, span: 1.4) - 0.2
                let x = (right ? px : 1 - px) * W
                let y = H * (0.08 + 0.36 * r(i, 64)) + sin(CGFloat(t) * 2 + r(i, 65) * 6) * u * 0.03
                let flap = 0.7 + 0.3 * abs(sin(CGFloat(t) * 9 + r(i, 66) * 6))
                put(glyph(e[i % e.count]), c, at: CGPoint(x: x, y: y), size: s, sx: right ? -1 : 1, sy: flap)
            }
        }

        private func corners(_ t: Double, _ e: [String], _ c: CGContext) {
            guard !e.isEmpty else { return }
            let s = u * 0.12, inset = u * 0.1
            let spots = [CGPoint(x: inset, y: H - inset * 1.1), CGPoint(x: W - inset, y: H - inset * 1.1),
                         CGPoint(x: W - inset, y: inset * 1.7), CGPoint(x: inset, y: inset * 1.7)]
            let used = amount < 0.9 ? 2 : 4
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: u * 0.008), blur: u * 0.025, color: UIColor(white: 0, alpha: 0.45).cgColor)
            for i in 0..<used {
                let bob = 1 + 0.07 * sin(CGFloat(t) * 2.2 + CGFloat(i) * 1.3)
                put(glyph(e[i % e.count]), c, at: spots[i], size: s * bob, angle: sin(CGFloat(t) * 1.4 + CGFloat(i)) * 0.09)
            }
            c.restoreGState()
        }

        /// A row of oil lamps along the bottom: a warm pool of light on the floor, and real flames that flicker.
        private func diyas(_ t: Double, _ c: CGContext) {
            let n = W > H ? 9 : 6
            let warm = UIColor(red: 1, green: 0.6, blue: 0.15, alpha: 1)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [warm.withAlphaComponent(0.4).cgColor, warm.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: H - u * 0.35), options: [])
            }
            for i in 0..<n {
                let x = W * (CGFloat(i) + 0.5) / CGFloat(n), y = H - u * 0.06
                let flick = 0.82 + 0.18 * sin(CGFloat(t) * 11 + CGFloat(i) * 2.3) * sin(CGFloat(t) * 7.3 + CGFloat(i))
                let sway = sin(CGFloat(t) * 5.1 + CGFloat(i) * 1.7) * u * 0.004
                put(dot(), c, at: CGPoint(x: x, y: y - u * 0.04), size: u * 0.24 * flick, alpha: 0.6, tint: warm)
                put(glyph("🪔"), c, at: CGPoint(x: x, y: y), size: u * 0.1)
                // The flame: a teardrop, white-gold at its heart.
                let fh = u * 0.05 * flick, fw = u * 0.018
                let base = CGPoint(x: x + u * 0.004, y: y - u * 0.028)
                let tip = CGPoint(x: base.x + sway, y: base.y - fh)
                let flame = CGMutablePath()
                flame.move(to: tip)
                flame.addQuadCurve(to: CGPoint(x: base.x, y: base.y + fw * 0.4), control: CGPoint(x: base.x + fw * 1.3, y: base.y - fh * 0.2))
                flame.addQuadCurve(to: tip, control: CGPoint(x: base.x - fw * 1.3, y: base.y - fh * 0.2))
                c.saveGState()
                c.addPath(flame); c.clip()
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor(red: 1, green: 0.98, blue: 0.85, alpha: 1).cgColor, UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1).cgColor,
                                               UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 0.9).cgColor] as CFArray, locations: [0, 0.45, 1]) {
                    c.drawLinearGradient(g, start: base, end: tip, options: [])
                }
                c.restoreGState()
            }
        }

        private func powder(_ t: Double, _ p: [UInt32], _ c: CGContext) {
            let cycle = 2.6
            let slots = amount >= 1.3 ? 5 : (amount >= 0.9 ? 4 : 3)
            for k in 0..<slots {
                let off = cycle * Double(k) / Double(slots)
                let b = Int(floor((t + off) / cycle))
                let tau = CGFloat(t + off - Double(b) * cycle) / CGFloat(cycle)
                let key = b &* 17 &+ k
                let center = CGPoint(x: W * (0.1 + 0.8 * r(key, 71)), y: H * (0.1 + 0.8 * r(key, 72)))
                let col = Celebrate.color(p[Int(r(key, 73) * CGFloat(p.count)) % max(1, p.count)])
                let grow = 1 - pow(1 - min(1, tau * 1.6), 3)
                let alpha = 0.75 * (1 - tau)
                for j in 0..<7 {
                    let a = r(j, key &+ 5) * 2 * .pi
                    let d = u * 0.12 * grow * r(j, key &+ 6)
                    put(dot(), c, at: CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d), size: u * (0.18 + 0.3 * grow) * (0.6 + 0.4 * r(j, key &+ 7)),
                        alpha: alpha, tint: col)
                }
            }
        }

        private func bubbles(_ t: Double, _ c: CGContext) {
            let n = count(18)
            for i in 0..<n {
                let s = u * (0.025 + 0.045 * r(i, 81))
                let y = H * 1.05 - loop(r(i, 82), 0.08 + 0.08 * r(i, 83), t, span: 1.2) * H
                let x = r(i, 84) * W + sin(CGFloat(t) * 1.5 + r(i, 85) * 6) * u * 0.03
                c.setStrokeColor(UIColor(white: 1, alpha: 0.7).cgColor); c.setLineWidth(max(1, s * 0.06))
                c.strokeEllipse(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
                c.setFillColor(UIColor(white: 1, alpha: 0.12).cgColor); c.fillEllipse(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
                c.setFillColor(UIColor(white: 1, alpha: 0.75).cgColor)
                c.fillEllipse(in: CGRect(x: x - s * 0.25, y: y - s * 0.3, width: s * 0.18, height: s * 0.14))
            }
        }

        private func stars(_ t: Double, _ c: CGContext) {
            let n = count(45)
            for i in 0..<n {
                let tw = pow(sin(CGFloat(t) * (1 + 2 * r(i, 91)) + r(i, 92) * 6), 2)
                let pt = CGPoint(x: r(i, 93) * W, y: r(i, 94) * H * 0.42)
                put(dot(), c, at: pt, size: u * (0.008 + 0.014 * r(i, 95)) * (0.6 + 0.6 * tw), alpha: 0.35 + 0.65 * tw)
            }
        }

        /// Big soft out-of-focus lights drifting slowly, twinkling — the look of a lens at a party.
        private func bokeh(_ t: Double, _ p: [UInt32], _ c: CGContext) {
            guard !p.isEmpty else { return }
            let n = count(16)
            c.saveGState(); c.setBlendMode(.plusLighter)
            for i in 0..<n {
                let z = r(i, 101)
                let s = u * (0.08 + 0.24 * z)
                let x = loop(r(i, 102), 0.01 + 0.02 * (1 - z), t, span: 1.3) * W * 1.3 - W * 0.15
                let y = r(i, 103) * H + sin(CGFloat(t) * 0.5 + r(i, 104) * 6) * u * 0.03
                let tw = 0.6 + 0.4 * sin(CGFloat(t) * (0.8 + r(i, 105)) + r(i, 106) * 6)
                put(disc(), c, at: CGPoint(x: x, y: y), size: s, alpha: (0.14 + 0.2 * (1 - z)) * tw, tint: Celebrate.color(p[i % p.count]))
            }
            c.restoreGState()
        }

        /// Glowing sparks rising and flickering out, like over a lamp or a bonfire.
        private func embers(_ t: Double, _ hex: UInt32, _ c: CGContext) {
            let n = count(40)
            let col = Celebrate.color(hex)
            c.saveGState(); c.setBlendMode(.plusLighter)
            for i in 0..<n {
                let z = r(i, 111)
                let y = H * 1.05 - loop(r(i, 112), 0.05 + 0.08 * z, t, span: 1.25) * H
                let x = r(i, 113) * W + sin(CGFloat(t) * (1.2 + r(i, 114) * 1.5) + r(i, 115) * 6) * u * 0.05
                let flick = 0.5 + 0.5 * sin(CGFloat(t) * (7 + r(i, 116) * 6) + r(i, 117) * 6)
                let life = max(0, min(1, y / H * 1.5))
                put(dot(), c, at: CGPoint(x: x, y: y), size: u * (0.012 + 0.02 * z) * (0.7 + 0.3 * flick), alpha: (0.45 + 0.55 * flick) * life, tint: col)
            }
            c.restoreGState()
        }

        /// Slow beams of warm light falling from the top corner, gently shifting — late-afternoon light through a window.
        private func rays(_ t: Double, _ hex: UInt32, _ c: CGContext) {
            let col = Celebrate.color(hex)
            let origin = CGPoint(x: W * 0.12, y: -H * 0.06)
            let len = hypot(W, H) * 1.3
            c.saveGState(); c.setBlendMode(.screen)
            for i in 0..<6 {
                let mid = 0.3 + CGFloat(i) * 0.13 + sin(CGFloat(t) * 0.25 + CGFloat(i) * 1.7) * 0.03
                let half = 0.03 + 0.03 * r(i, 121)
                let beam = CGMutablePath()
                beam.move(to: origin)
                beam.addLine(to: CGPoint(x: origin.x + len * sin(mid - half), y: origin.y + len * cos(mid - half)))
                beam.addLine(to: CGPoint(x: origin.x + len * sin(mid + half), y: origin.y + len * cos(mid + half)))
                beam.closeSubpath()
                let pulse = 0.75 + 0.25 * sin(CGFloat(t) * (0.6 + r(i, 122)) + CGFloat(i))
                c.saveGState(); c.addPath(beam); c.clip()
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [col.withAlphaComponent(0.3 * pulse).cgColor, col.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
                    c.drawLinearGradient(g, start: origin, end: CGPoint(x: origin.x + len * 0.6 * sin(mid), y: origin.y + len * 0.6 * cos(mid)), options: [])
                }
                c.restoreGState()
            }
            put(dot(), c, at: CGPoint(x: W * 0.12, y: 0), size: u * 1.1, alpha: 0.4, tint: col)
            c.restoreGState()
        }

        /// Santa's sleigh and two reindeer sweep across the sky every few seconds, trailing gold sparkle.
        private func sleigh(_ t: Double, _ c: CGContext) {
            let cycle = 9.0, cross = 4.6
            let ph = CGFloat(t.truncatingRemainder(dividingBy: cycle) / cross)
            guard ph < 1 else { return }
            let s = u * 0.1
            let x = W * 1.2 - (W * 1.4 + s * 3) * ph
            let y = H * 0.2 - sin(ph * .pi) * u * 0.07
            let gold = UIColor(red: 1, green: 0.84, blue: 0.45, alpha: 1)
            c.saveGState(); c.setBlendMode(.plusLighter)
            for i in 0..<18 {
                let back = CGFloat(i) * u * 0.028
                let k = 1 - CGFloat(i) / 18
                put(dot(), c, at: CGPoint(x: x + s * 1.1 + back, y: y + s * 0.2 + sin(CGFloat(t) * 6 + CGFloat(i)) * u * 0.008),
                    size: u * 0.026 * k + u * 0.006, alpha: 0.9 * k, tint: i % 3 == 0 ? .white : gold)
            }
            c.restoreGState()
            let bob = sin(CGFloat(t) * 7) * u * 0.006
            put(glyph("🦌"), c, at: CGPoint(x: x - s * 1.9, y: y - bob), size: s)
            put(glyph("🦌"), c, at: CGPoint(x: x - s * 0.95, y: y + bob), size: s)
            put(glyph("🛷"), c, at: CGPoint(x: x + s * 0.3, y: y + s * 0.2), size: s * 1.05)
            put(glyph("🎅"), c, at: CGPoint(x: x + s * 0.3, y: y - s * 0.25), size: s * 0.75)
        }

        private func glow(_ t: Double, _ hex: UInt32, _ c: CGContext) {
            let k = 0.85 + 0.15 * sin(CGFloat(t) * 1.4)
            let cols = [Celebrate.color(hex, alpha: 0).cgColor, Celebrate.color(hex, alpha: 0.42 * k).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) else { return }
            let m = CGPoint(x: W / 2, y: H / 2), far = hypot(W, H) / 2
            c.drawRadialGradient(g, startCenter: m, startRadius: far * 0.55, endCenter: m, endRadius: far, options: [.drawsAfterEndLocation])
        }
    }

    // MARK: - The video

    /// The decorations (and, when given, the words) laid over every frame of `asset` — used both for the live
    /// preview (set on the player item) and the saved file.
    static func composition(for asset: AVAsset, theme: Theme, amount: Double, caption: Caption?) async -> AVVideoComposition? {
        let track = try? await asset.loadTracks(withMediaType: .video).first
        let t = (try? await track?.load(.preferredTransform)) ?? .identity
        let orient: CGImagePropertyOrientation = {
            switch (t.a, t.b, t.c, t.d) {
            case (0, 1, -1, 0): return .right
            case (0, -1, 1, 0): return .left
            case (-1, 0, 0, -1): return .down
            default: return .up
            }
        }()
        final class State: @unchecked Sendable {
            var painter: Painter?
            var caption: (CIImage, CGSize)?
            let lock = NSLock()
        }
        let state = State()
        return try? await AVMutableVideoComposition.videoComposition(with: asset) { request in
            let render = request.renderSize
            var src = request.sourceImage
            // Upright: some phones hand the frame over as recorded (sideways); turn it to match the output.
            if abs(src.extent.width - render.width) > 2 || abs(src.extent.height - render.height) > 2, orient != .up {
                src = src.oriented(orient)
            }
            if src.extent.origin != .zero { src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY)) }
            state.lock.lock()
            // Decorations drawn at most ~1280 px on the long side, then scaled up — they're soft, so it can't be seen.
            if state.painter == nil {
                let k = min(1, 1280 / max(render.width, render.height))
                state.painter = Painter(theme: theme, size: CGSize(width: render.width * k, height: render.height * k), amount: amount)
                if let c = caption, let img = captionImage(c, frame: render)?.cgImage {
                    state.caption = (CIImage(cgImage: img), CGSize(width: img.width, height: img.height))
                }
            }
            let painter = state.painter, cap = state.caption
            state.lock.unlock()
            let secs = request.compositionTime.seconds
            var out = src
            if let p = painter { out = decorate(out, painter: p, t: secs, size: render) }
            if let capT = cap, let c = caption {
                let (img, sz) = capT
                // Fades in over the first moment, then stays.
                let a = CGFloat(min(1, max(0, (secs - 0.15) / 0.6)))
                let x = c.center.x * render.width - sz.width / 2
                let y = (1 - c.center.y) * render.height - sz.height / 2
                let faded = img.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: a)])
                out = faded.transformed(by: CGAffineTransform(translationX: x, y: y)).composited(over: out)
            }
            request.finish(with: out.cropped(to: CGRect(origin: .zero, size: render)), context: nil)
        }
    }

    /// A frame with a celebration on it. The light (fireworks, glows, bokeh, embers, sparkle) is added onto the
    /// picture with a soft halo, so it lights the video the way real light would; leaves, confetti, snow and lamps
    /// sit on top.
    static func decorate(_ frame: CIImage, painter p: Painter, t: Double, size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        let k = size.width / p.size.width
        var out = frame
        if p.hasLight, let lightCG = p.image(at: t, only: true) {
            let light = CIImage(cgImage: lightCG).transformed(by: CGAffineTransform(scaleX: k, y: k))
            let halo = light.clampedToExtent().applyingGaussianBlur(sigma: Double(min(size.width, size.height)) * 0.012).cropped(to: rect)
            out = halo.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: out]).cropped(to: rect)
            out = light.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: out]).cropped(to: rect)
        }
        if let solidCG = p.image(at: t, only: false) {
            out = CIImage(cgImage: solidCG).transformed(by: CGAffineTransform(scaleX: k, y: k)).composited(over: out)
        }
        return out.cropped(to: rect)
    }

    /// Saves the decorated video (sound kept), with live progress. nil if the phone couldn't make it.
    static func export(_ source: URL, theme: Theme, amount: Double, caption: Caption?) async -> URL? {
        let asset = AVURLAsset(url: source)
        guard let comp = await composition(for: asset, theme: theme, amount: amount, caption: caption),
              let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = comp; s.metadata = []
        let secs = (try? await asset.load(.duration).seconds) ?? 0
        return await VideoEngine.run(s, seconds: secs) ? out : nil
    }

    /// A still photo as a short, gently moving video, so it can be decorated like any clip.
    static func videoFromPhoto(_ photo: UIImage) async -> URL? {
        var s = Animate.settings(for: [photo], style: .kenBurns)
        s.pace = .relaxed
        return await Animate.render([photo.resized(maxDimension: 1440).normalizedUp()], settings: s)
    }
}
