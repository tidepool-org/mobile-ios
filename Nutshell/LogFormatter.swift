import CocoaLumberjack
import CocoaLumberjack.DDDispatchQueueLogFormatter

class LogFormatter: DDDispatchQueueLogFormatter {
    let df: NSDateFormatter
    
    override init() {
        df = NSDateFormatter()
        df.formatterBehavior = .Behavior10_4
        df.dateFormat = "HH:mm:ss.SSS"
        
        super.init()
    }
    
    override func formatLogMessage(logMessage: DDLogMessage!) -> String {
        let dateAndTime = df.stringFromDate(logMessage.timestamp)
        
        var logLevel: String
        var useLog = true
        var formattedLog = ""
        let logFlag:DDLogFlag  = logMessage.flag
        
        if logFlag.contains(.Verbose) {
            logLevel = "V"
        } else if logFlag.contains(.Debug) {
            logLevel = "D"
        } else if logFlag.contains(.Info) {
            logLevel = "I"
        } else if logFlag.contains(.Warning) {
            logLevel = "W"
        } else if logFlag.contains(.Error) {
            logLevel = "E"
        } else {
            logLevel = ""
            useLog = false
        }
        
        if (useLog) {
            formattedLog = "\(dateAndTime) \(logLevel)/[\(logMessage.fileName):\(logMessage.line) \(logMessage.function)]: \(logMessage.message)"
        }
        
        return formattedLog
    }
}
