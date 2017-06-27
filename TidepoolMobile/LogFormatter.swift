import CocoaLumberjack
import CocoaLumberjack.DDDispatchQueueLogFormatter

class LogFormatter: DDDispatchQueueLogFormatter {
    let df: DateFormatter
    
    override init() {
        df = DateFormatter()
        df.formatterBehavior = .behavior10_4
        df.dateFormat = "HH:mm:ss.SSS"
        
        super.init()
    }
    
    override func format(message logMessage: DDLogMessage!) -> String {
        let dateAndTime = df.string(from: logMessage.timestamp)
        
        var logLevel: String
        var useLog = true
        var formattedLog = ""
        let logFlag:DDLogFlag  = logMessage.flag
        
        if logFlag.contains(.verbose) {
            logLevel = "V"
        } else if logFlag.contains(.debug) {
            logLevel = "D"
        } else if logFlag.contains(.info) {
            logLevel = "I"
        } else if logFlag.contains(.warning) {
            logLevel = "W"
        } else if logFlag.contains(.error) {
            logLevel = "E"
        } else {
            logLevel = ""
            useLog = false
        }
        
        if (useLog) {
            if let filename = logMessage.fileName, let function = logMessage.function, let message = logMessage.message {
                formattedLog = "\(dateAndTime) \(logLevel)/[\(filename):\(logMessage.line) \(function)]: \(message)"
            }
        }
        
        return formattedLog
    }
}
