import Foundation
import RemoteSudoTouchCore

let commandArguments = Array(CommandLine.arguments.dropFirst())

if commandArguments.isEmpty || commandArguments.contains("--help") {
  print("""
  Usage: rsudo <command> [args...]

  Requests remote approval from RemoteSudoTouch before invoking /usr/bin/sudo.
  """)
  exit(commandArguments.contains("--help") ? 0 : 1)
}

do {
  let configuration = try ClientSupport.loadConfiguration()
  let helperPath = ProcessInfo.processInfo.environment["RSUDO_HELPER_PATH"] ?? configuration.helperExecutablePath

  guard FileManager.default.isExecutableFile(atPath: helperPath) else {
    throw ExitError("Helper executable is missing: \(helperPath)")
  }

  let helper = Process()
  helper.executableURL = URL(fileURLWithPath: helperPath)
  helper.arguments = []
  helper.standardInput = FileHandle.standardInput
  helper.standardOutput = FileHandle.standardOutput
  helper.standardError = FileHandle.standardError
  try helper.run()
  helper.waitUntilExit()

  guard helper.terminationStatus == 0 else {
    exit(helper.terminationStatus)
  }

  let sudo = Process()
  sudo.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
  sudo.arguments = commandArguments
  sudo.standardInput = FileHandle.standardInput
  sudo.standardOutput = FileHandle.standardOutput
  sudo.standardError = FileHandle.standardError
  try sudo.run()
  sudo.waitUntilExit()
  exit(sudo.terminationStatus)
} catch let error as ExitError {
  fputs("rsudo: \(error.message)\n", stderr)
  exit(error.exitCode)
} catch {
  fputs("rsudo: \(error.localizedDescription)\n", stderr)
  exit(1)
}
