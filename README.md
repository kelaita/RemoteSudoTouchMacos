# RemoteSudoTouchMacos

`RemoteSudoTouchMacos` is a macOS-specific client for RemoteSudoTouch that
lets a remote Mac use your main Mac's Touch ID approval flow through an
`rsudo` wrapper instead of PAM integration.

## What it provides

- `remote-sudo-touch-macos`
  - sends an approval request to a RemoteSudoTouch agent
  - exits `0` only when the request is approved
- `rsudo`
  - calls `remote-sudo-touch-macos`
  - on approval, invokes real `/usr/bin/sudo`

## Important limitation

This does **not** modify stock macOS `sudo` behavior.

You use:

```bash
rsudo <command>
```

not:

```bash
sudo <command>
```

This is intentional. The Linux `pam_exec` approach does not map cleanly to the
tested macOS environment.

## How it works

- You run `rsudo <command>` on the remote Mac
- `rsudo` calls `remote-sudo-touch-macos`
- the helper sends an approval request to the RemoteSudoTouch agent
- if approved, `rsudo` invokes real `/usr/bin/sudo`
- if denied or unreachable, `rsudo` exits nonzero and does not run `sudo`

## Remote Mac requirements

- a working path from the remote Mac to your main Mac's RemoteSudoTouch agent
- typically that means the remote Mac has `127.0.0.1:9876` forwarded to the
  main Mac agent on `127.0.0.1:8765`
- the main Mac RemoteSudoTouch agent must already be installed and running

## Quick install on a remote Mac

Build a package on your main Mac:

```bash
cd /Users/paul/Xcode/RemoteSudoTouchMacos
./scripts/build-pkg.sh arm64
```

That creates:

```text
dist/RemoteSudoTouchMacos-<version>-arm64.pkg
```

Copy and install it remotely:

```bash
scp dist/RemoteSudoTouchMacos-$(cat VERSION)-arm64.pkg Maczilla:/tmp/
ssh Maczilla 'sudo installer -pkg /tmp/RemoteSudoTouchMacos-'"$(cat VERSION)"'-arm64.pkg -target /'
```

Then edit config on the remote Mac if needed:

```bash
ssh Maczilla 'sudo nano /usr/local/etc/remote-sudo-touch/config.json'
```

Then test:

```bash
ssh Maczilla '/usr/local/bin/rsudo date'
```

## Architecture-specific packages

Package version is read from the top-level `VERSION` file by default.

Current version:

```bash
cat VERSION
```

If you need to override it for a one-off build, you still can:

```bash
./scripts/build-pkg.sh 0.2.0 arm64
```

Build Apple Silicon package:

```bash
./scripts/build-pkg.sh arm64
```

Build Intel package:

```bash
./scripts/build-pkg.sh x86_64
```

Output files:

- `dist/RemoteSudoTouchMacos-<version>-arm64.pkg`
- `dist/RemoteSudoTouchMacos-<version>-x86_64.pkg`

## Developer build

Native build:

```bash
cd /Users/paul/Xcode/RemoteSudoTouchMacos
./scripts/build-release.sh
```

Apple Silicon build:

```bash
./scripts/build-release.sh arm64
```

Intel build:

```bash
./scripts/build-release.sh x86_64
```

## Clean generated files

Standard clean:

```bash
./scripts/clean.sh
```

That removes the generated package/build output under:

- `build/`
- `dist/`

If you want a deeper cleanup, including SwiftPM state and the old pre-rename
scratch directory:

```bash
./scripts/clean.sh --all
```

## Install locally from source

```bash
sudo ./scripts/install-local.sh
```

That installs:

- `/usr/local/bin/rsudo`
- `/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos`
- `/usr/local/etc/remote-sudo-touch/config.json`

## Build installer package

To create a standalone macOS installer package for the local architecture:

```bash
./scripts/build-pkg.sh
```

That writes a `.pkg` into `dist/` which you can copy to another Mac and install
directly. The package version comes from `VERSION`.

If you want to sign the package:

```bash
PKG_SIGNING_IDENTITY="Developer ID Installer: ..." ./scripts/build-pkg.sh
```

## Configuration

Default config file:

```text
/usr/local/etc/remote-sudo-touch/config.json
```

Fields:

- `host`
- `port`
- `timeoutSeconds`
- `requestKind`
- `helperExecutablePath`

Default transport assumes a local forwarded port on the remote Mac:

- helper connects to `127.0.0.1:9876`
- your tunnel or other transport must make that path reach the main Mac agent

Default config:

```json
{
  "host": "127.0.0.1",
  "port": 9876,
  "timeoutSeconds": 30,
  "requestKind": "sudo_auth",
  "helperExecutablePath": "/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos"
}
```

## Manual tests

Dry run:

```bash
/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos --dry-run
```

Real approval request:

```bash
/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos
```

Wrapper test:

```bash
rsudo date
```

## Troubleshooting

If `rsudo` fails:

1. Verify the helper can reach the forwarded port:

```bash
nc -vz 127.0.0.1 9876
```

2. Verify the helper itself:

```bash
/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos --dry-run
/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos
```

3. Verify the main Mac agent is running and able to approve requests.

4. If approval works but `rsudo` still fails, run:

```bash
rsudo --help
which rsudo
```

## Repo relationship

Main macOS manager app:
[RemoteSudoTouch](https://github.com/kelaita/RemoteSudoTouch)

## Repo relationship

Main macOS manager app:
[RemoteSudoTouch](https://github.com/kelaita/RemoteSudoTouch)
