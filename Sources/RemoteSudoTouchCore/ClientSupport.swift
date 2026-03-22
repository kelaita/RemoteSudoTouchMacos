import Foundation
import Network

private final class LockedBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func set(_ newValue: Value) {
    lock.lock()
    value = newValue
    lock.unlock()
  }

  func get() -> Value {
    lock.lock()
    let snapshot = value
    lock.unlock()
    return snapshot
  }
}

public enum ClientSupport {
  public static func loadConfiguration() throws -> ClientConfiguration {
    let configPath = ProcessInfo.processInfo.environment["REMOTE_SUDO_TOUCH_CONFIG"]
      ?? "/usr/local/etc/remote-sudo-touch/config.json"
    let url = URL(fileURLWithPath: configPath)

    guard FileManager.default.fileExists(atPath: url.path) else {
      return ClientConfiguration()
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(ClientConfiguration.self, from: data)
  }

  public static func buildRequest(configuration: ClientConfiguration) -> ApprovalRequest {
    let environment = ProcessInfo.processInfo.environment
    let hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName

    return ApprovalRequest(
      requestID: UUID().uuidString.lowercased(),
      timestamp: Int(Date().timeIntervalSince1970),
      hostname: hostName,
      user: environment["PAM_USER"] ?? environment["USER"] ?? NSUserName(),
      service: environment["PAM_SERVICE"] ?? "sudo",
      tty: environment["PAM_TTY"] ?? environment["TTY"] ?? "",
      rhost: environment["PAM_RHOST"] ?? "",
      type: configuration.requestKind
    )
  }

  public static func prettyJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    guard let string = String(data: data, encoding: .utf8) else {
      throw ExitError("Failed to encode JSON.")
    }
    return string
  }

  public static func sendApprovalRequest(
    _ request: ApprovalRequest,
    configuration: ClientConfiguration
  ) throws -> ApprovalResponse {
    let queue = DispatchQueue(label: "RemoteSudoTouchMacClient")
    let connection = NWConnection(
      host: NWEndpoint.Host(configuration.host),
      port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(configuration.port)),
      using: .tcp
    )

    let started = DispatchSemaphore(value: 0)
    let startError = LockedBox<Error?>(nil)

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        started.signal()
      case let .failed(error):
        startError.set(error)
        started.signal()
      default:
        break
      }
    }

    connection.start(queue: queue)

    if started.wait(timeout: .now() + .seconds(configuration.timeoutSeconds)) == .timedOut {
      connection.cancel()
      throw ExitError("Timed out connecting to \(configuration.host):\(configuration.port).")
    }

    if let startError = startError.get() {
      connection.cancel()
      throw ExitError("Connection failed: \(startError.localizedDescription)")
    }

    let payload = try JSONEncoder().encode(request) + Data([0x0A])

    let sendCompleted = DispatchSemaphore(value: 0)
    let sendError = LockedBox<NWError?>(nil)
    connection.send(content: payload, completion: .contentProcessed { error in
      sendError.set(error)
      sendCompleted.signal()
    })

    if sendCompleted.wait(timeout: .now() + .seconds(configuration.timeoutSeconds)) == .timedOut {
      connection.cancel()
      throw ExitError("Timed out sending request.")
    }

    if let sendError = sendError.get() {
      connection.cancel()
      throw ExitError("Failed to send request: \(sendError.localizedDescription)")
    }

    let responseData = try receiveLine(from: connection, timeoutSeconds: configuration.timeoutSeconds)
    connection.cancel()

    do {
      return try JSONDecoder().decode(ApprovalResponse.self, from: responseData)
    } catch {
      throw ExitError("Invalid response from RemoteSudoTouch: \(error.localizedDescription)")
    }
  }

  private static func receiveLine(from connection: NWConnection, timeoutSeconds: Int) throws -> Data {
    let semaphore = DispatchSemaphore(value: 0)
    let receivedData = LockedBox<Data>(Data())
    let receivedError = LockedBox<Error?>(nil)

    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
      if let error {
        receivedError.set(error)
        semaphore.signal()
        return
      }

      if let data, !data.isEmpty {
        receivedData.set(data)
      }

      semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + .seconds(timeoutSeconds)) == .timedOut {
      throw ExitError("Timed out waiting for approval response.")
    }

    if let receivedError = receivedError.get() {
      throw ExitError("Failed while receiving response: \(receivedError.localizedDescription)")
    }

    let data = receivedData.get()
    guard !data.isEmpty else {
      throw ExitError("Empty response from RemoteSudoTouch.")
    }

    if let newlineIndex = data.firstIndex(of: 0x0A) {
      return data.prefix(upTo: newlineIndex)
    }

    return data
  }
}
