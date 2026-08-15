import OSLog

enum HEOSLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "HEOSLocalRemote"
    static let connection = Logger(subsystem: subsystem, category: "connection")
    static let command = Logger(subsystem: subsystem, category: "command")
    static let response = Logger(subsystem: subsystem, category: "response")
    static let event = Logger(subsystem: subsystem, category: "event")
    static let parsing = Logger(subsystem: subsystem, category: "parsing")
    static let error = Logger(subsystem: subsystem, category: "error")
}
