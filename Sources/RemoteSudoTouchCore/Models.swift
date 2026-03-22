import Foundation

public struct ApprovalRequest: Codable {
  public let requestID: String
  public let timestamp: Int
  public let hostname: String
  public let user: String
  public let service: String
  public let tty: String
  public let rhost: String
  public let type: String

  enum CodingKeys: String, CodingKey {
    case requestID = "request_id"
    case timestamp
    case hostname
    case user
    case service
    case tty
    case rhost
    case type
  }
}

public struct ApprovalResponse: Codable {
  public let requestID: String
  public let approved: Bool
  public let reason: String?

  enum CodingKeys: String, CodingKey {
    case requestID = "request_id"
    case approved
    case reason
  }
}

public struct ClientConfiguration: Codable {
  public let host: String
  public let port: Int
  public let timeoutSeconds: Int
  public let requestKind: String
  public let helperExecutablePath: String

  public init(
    host: String = "127.0.0.1",
    port: Int = 9876,
    timeoutSeconds: Int = 30,
    requestKind: String = "sudo_auth",
    helperExecutablePath: String = "/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos"
  ) {
    self.host = host
    self.port = port
    self.timeoutSeconds = timeoutSeconds
    self.requestKind = requestKind
    self.helperExecutablePath = helperExecutablePath
  }
}

public struct ExitError: LocalizedError {
  public let message: String
  public let exitCode: Int32

  public init(_ message: String, exitCode: Int32 = 1) {
    self.message = message
    self.exitCode = exitCode
  }

  public var errorDescription: String? { message }
}
