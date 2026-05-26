import Foundation

/// Service for managing word validation and generation
@MainActor
class WordService: ObservableObject {
    static let shared = WordService()

    private var validWords: Set<String> = []
    private var answerWords: [String] = []
    private var isLoaded = false

    private init() {
        loadWords()
    }

    /// Load words from JSON file
    private func loadWords() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            print("Words file not found, using fallback")
            loadFallbackWords()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let wordData = try JSONDecoder().decode(WordData.self, from: data)
            self.validWords = Set(wordData.validGuesses.map { $0.uppercased() })
            self.answerWords = wordData.solutions?.map { $0.uppercased() } ?? Array(validWords)
            isLoaded = true
        } catch {
            print("Failed to load words: \(error)")
            loadFallbackWords()
        }
    }

    /// Fallback word list
    private func loadFallbackWords() {
        let fallback = [
            "ABOUT", "ABOVE", "ABUSE", "ACTOR", "ACUTE", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN",
            "AGENT", "AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIEN", "ALIGN", "ALIKE", "ALIVE",
            "ALLOW", "ALONE", "ALONG", "ALTER", "AMONG", "ANGEL", "ANGER", "ANGLE", "ANGRY", "APART",
            "APPLE", "APPLY", "ARENA", "ARGUE", "ARISE", "ARMOR", "ARRAY", "ARROW", "ASIDE", "ASSET",
            "AUDIO", "AUDIT", "AVOID", "AWARD", "AWARE", "BEACH", "BEAST", "BEGIN", "BEING", "BELOW",
            "BENCH", "BERRY", "BIRTH", "BLACK", "BLADE", "BLAME", "BLANK", "BLAST", "BLAZE", "BLEND",
            "BLESS", "BLIND", "BLOCK", "BLOOD", "BLOOM", "BLOWN", "BOARD", "BONUS", "BOOST", "BOUND",
            "BRAIN", "BRAND", "BRAVE", "BREAD", "BREAK", "BREED", "BRICK", "BRIDE", "BRIEF", "BRING",
            "BROAD", "BROKE", "BROWN", "BRUSH", "BUILD", "BUNCH", "BURST", "BUYER", "CABLE", "CANDY",
            "CARGO", "CARRY", "CATCH", "CAUSE", "CHAIN", "CHAIR", "CHARM", "CHART", "CHASE", "CHEAP",
            "CHECK", "CHEST", "CHIEF", "CHILD", "CHINA", "CHOSE", "CIVIC", "CIVIL", "CLAIM", "CLASS",
            "CLEAN", "CLEAR", "CLERK", "CLICK", "CLIMB", "CLOCK", "CLOSE", "CLOTH", "CLOUD", "COACH",
            "COAST", "COLOR", "COUCH", "COULD", "COUNT", "COURT", "COVER", "CRACK", "CRAFT", "CRASH",
            "CRAZY", "CREAM", "CREEK", "CRIME", "CROSS", "CROWD", "CROWN", "CRUDE", "CRUEL", "CRUSH",
            "CURVE", "CYCLE", "DAILY", "DANCE", "DEATH", "DEBUT", "DECAY", "DELAY", "DEPTH", "DIRTY",
            "DOUBT", "DOZEN", "DRAFT", "DRAIN", "DRAMA", "DRANK", "DRAWN", "DREAM", "DRESS", "DRIED",
            "DRIFT", "DRILL", "DRINK", "DRIVE", "DROWN", "EARLY", "EARTH", "EIGHT", "ELECT", "ELITE",
            "EMPTY", "ENEMY", "ENJOY", "ENTER", "ENTRY", "EQUAL", "ERROR", "ESSAY", "EVENT", "EVERY",
            "EXACT", "EXIST", "EXTRA", "FAITH", "FALSE", "FANCY", "FATAL", "FAULT", "FAVOR", "FEAST",
            "FENCE", "FEVER", "FIBER", "FIELD", "FIFTY", "FIGHT", "FINAL", "FIRST", "FIXED", "FLAME",
            "FLASH", "FLESH", "FLOAT", "FLOOD", "FLOOR", "FLOUR", "FOCUS", "FORCE", "FORGE", "FORTH",
            "FORTY", "FORUM", "FOUND", "FRAME", "FRANK", "FRAUD", "FRESH", "FRONT", "FROST", "FRUIT",
            "FULLY", "FUNNY", "GIANT", "GIVEN", "GLASS", "GLOBE", "GLORY", "GOING", "GRACE", "GRADE",
            "GRAIN", "GRAND", "GRANT", "GRAPE", "GRAPH", "GRASP", "GRASS", "GRAVE", "GREAT", "GREEN",
            "GROSS", "GROUP", "GROVE", "GROWN", "GUARD", "GUESS", "GUEST", "GUIDE", "GUILT", "HABIT",
            "HAPPY", "HARSH", "HEART", "HEAVY", "HELLO", "HENCE", "HOBBY", "HONEY", "HONOR", "HORSE",
            "HOTEL", "HOUSE", "HUMAN", "HUMOR", "HURRY", "IDEAL", "IMAGE", "IMPLY", "INDEX", "INNER",
            "INPUT", "ISSUE", "JEWEL", "JOINT", "JUDGE", "JUICE", "KNOWN", "LABEL", "LABOR", "LARGE",
            "LASER", "LATER", "LAUGH", "LAYER", "LEARN", "LEASE", "LEAST", "LEAVE", "LEGAL", "LEMON",
            "LEVEL", "LIGHT", "LIMIT", "LIVES", "LOCAL", "LOGIC", "LOOSE", "LOVER", "LOWER", "LOYAL",
            "LUCKY", "LUNCH", "LYING", "MAGIC", "MAJOR", "MAKER", "MARCH", "MATCH", "MAYBE", "MAYOR",
            "MEANT", "MEDAL", "MEDIA", "MERCY", "MERGE", "MERIT", "METAL", "METER", "MIGHT", "MINOR",
            "MINUS", "MIXED", "MODEL", "MONEY", "MONTH", "MORAL", "MOTOR", "MOUNT", "MOUSE", "MOUTH",
            "MOVED", "MOVIE", "MUSIC", "NAKED", "NAMED", "NARROW", "NASTY", "NAVAL", "NERVE", "NEVER",
            "NEWLY", "NIGHT", "NINTH", "NOBLE", "NOISE", "NORTH", "NOTED", "NOVEL", "NURSE", "OCCUR",
            "OCEAN", "OFFER", "OFTEN", "OLIVE", "ORDER", "ORGAN", "OTHER", "OUGHT", "OUTER", "OWNED",
            "OWNER", "PAINT", "PANEL", "PANIC", "PAPER", "PARTY", "PASTA", "PATCH", "PEACE", "PEACH",
            "PEARL", "PENNY", "PHASE", "PHONE", "PHOTO", "PIANO", "PIECE", "PILOT", "PITCH", "PIXEL",
            "PIZZA", "PLACE", "PLAIN", "PLANE", "PLANT", "PLATE", "PLAZA", "POINT", "POLAR", "POUND",
            "POWER", "PRESS", "PRICE", "PRIDE", "PRIME", "PRINT", "PRIOR", "PRIZE", "PROOF", "PROUD",
            "PROVE", "QUEEN", "QUERY", "QUEST", "QUICK", "QUIET", "QUITE", "QUOTE", "RADAR", "RADIO",
            "RAISE", "RALLY", "RANCH", "RANGE", "RAPID", "RATIO", "REACH", "REACT", "READY", "REALM",
            "REBEL", "REFER", "REIGN", "RELAX", "REPLY", "RIDER", "RIDGE", "RIFLE", "RIGHT", "RIGID",
            "RISKY", "RIVAL", "RIVER", "ROBOT", "ROCKY", "ROUGH", "ROUND", "ROUTE", "ROYAL", "RUGBY",
            "RURAL", "SADLY", "SAINT", "SALAD", "SALES", "SANDY", "SAUCE", "SAVED", "SCALE", "SCARE",
            "SCENE", "SCENT", "SCOPE", "SCORE", "SCOUT", "SENSE", "SERVE", "SEVEN", "SHADE", "SHAKE",
            "SHALL", "SHAME", "SHAPE", "SHARE", "SHARK", "SHARP", "SHEEP", "SHEER", "SHEET", "SHELF",
            "SHELL", "SHIFT", "SHINE", "SHIRT", "SHOCK", "SHOOT", "SHORT", "SHOUT", "SHOWN", "SIGHT",
            "SIGMA", "SILLY", "SINCE", "SIXTH", "SIXTY", "SIZED", "SKILL", "SLAVE", "SLEEP", "SLICE",
            "SLIDE", "SLOPE", "SMALL", "SMART", "SMELL", "SMILE", "SMOKE", "SNAKE", "SOLID", "SOLVE",
            "SORRY", "SOUND", "SOUTH", "SPACE", "SPARE", "SPARK", "SPEAK", "SPEED", "SPELL", "SPEND",
            "SPENT", "SPILL", "SPINE", "SPLIT", "SPOKE", "SPORT", "SPRAY", "SQUAD", "STACK", "STAFF",
            "STAGE", "STAKE", "STAMP", "STAND", "STARK", "START", "STATE", "STAYS", "STEAK", "STEAL",
            "STEAM", "STEEL", "STEEP", "STICK", "STILL", "STOCK", "STONE", "STOOD", "STORE", "STORM",
            "STORY", "STRIP", "STUCK", "STUDY", "STUFF", "STYLE", "SUGAR", "SUITE", "SUNNY", "SUPER",
            "SURGE", "SWEAR", "SWEEP", "SWEET", "SWEPT", "SWIFT", "SWING", "SWORD", "TABLE", "TASTE",
            "TEACH", "TEETH", "TEMPO", "TENTH", "TERMS", "THANK", "THEFT", "THEIR", "THEME", "THERE",
            "THESE", "THICK", "THIEF", "THING", "THINK", "THIRD", "THOSE", "THREE", "THREW", "THROW",
            "THUMB", "TIGER", "TIGHT", "TIMER", "TIRED", "TITLE", "TODAY", "TOKEN", "TOOTH", "TOPIC",
            "TOTAL", "TOUCH", "TOUGH", "TOWEL", "TOWER", "TRACK", "TRADE", "TRAIL", "TRAIN", "TRAIT",
            "TRASH", "TREAT", "TREND", "TRIAL", "TRIBE", "TRICK", "TRIED", "TRUCK", "TRULY", "TRUNK",
            "TRUST", "TRUTH", "TWICE", "TWIST", "ULTRA", "UNCLE", "UNDER", "UNIFY", "UNION", "UNITE",
            "UNITY", "UNTIL", "UPPER", "UPSET", "URBAN", "USAGE", "USUAL", "VALID", "VALUE", "VENUE",
            "VERSE", "VIDEO", "VIGOR", "VIRAL", "VIRUS", "VISIT", "VITAL", "VIVID", "VOCAL", "VOICE",
            "VOTER", "WAGON", "WASTE", "WATCH", "WATER", "WEIGH", "WEIRD", "WHEAT", "WHEEL", "WHERE",
            "WHICH", "WHILE", "WHITE", "WHOLE", "WHOSE", "WIDTH", "WOMAN", "WORLD", "WORRY", "WORSE",
            "WORST", "WORTH", "WOULD", "WOUND", "WRIST", "WRITE", "WRONG", "WROTE", "YIELD", "YOUNG",
            "YOUTH", "ZEBRA", "ZONES"
        ]
        self.validWords = Set(fallback)
        self.answerWords = fallback
        isLoaded = true
    }

    /// Check if a word is valid
    func isValidWord(_ word: String) -> Bool {
        validWords.contains(word.uppercased())
    }

    /// Get random words for a new game
    func getRandomWords(count: Int = 4) -> [String] {
        Array(answerWords.shuffled().prefix(count))
    }

    /// Get words for daily puzzle based on date
    func getDailyWords(for date: Date = Date(), count: Int = 4) -> [String] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = (components.year ?? 2024) * 10000 + (components.month ?? 1) * 100 + (components.day ?? 1)

        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        return Array(answerWords.shuffled(using: &rng).prefix(count))
    }
}

/// Word data structure for JSON decoding
private struct WordData: Codable {
    let validGuesses: [String]
    let solutions: [String]?
}

/// Seeded random number generator for reproducible daily puzzles
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
