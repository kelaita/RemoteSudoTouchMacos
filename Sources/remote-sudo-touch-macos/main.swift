import Foundation
import RemoteSudoTouchCore

enum HelperMode {
  case send
  case dryRun
}

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--help") {
  print("""
  Usage: remote-sudo-touch-macos [--dry-run] [--print-request]

  Sends an approval request to a RemoteSudoTouch Mac agent and exits 0 only when approved.
  """)
  exit(0)
}

let mode: HelperMode = arguments.contains("--dry-run") || arguments.contains("--print-request") ? .dryRun : .send

do {
  let configuration = try ClientSupport.loadConfiguration()
  let request = ClientSupport.buildRequest(configuration: configuration)

  if mode == .dryRun {
    print(try ClientSupport.prettyJSON(request))
    exit(0)
  }

  let response = try ClientSupport.sendApprovalRequest(request, configuration: configuration)
  if response.approved {
    exit(0)
  }

  let reason = response.reason ?? "denied"
  fputs("remote-sudo-touch-macos: denied: \(reason)\n", stderr)
  exit(1)
} catch let error as ExitError {
  fputs("remote-sudo-touch-macos: \(error.message)\n", stderr)
  exit(error.exitCode)
} catch {
  fputs("remote-sudo-touch-macos: \(error.localizedDescription)\n", stderr)
  exit(1)
}
