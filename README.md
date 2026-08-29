# Tinest

Flutter GUI and a pure-Dart AI coding-agent daemon. The daemon owns workspace,
agent, timeline, and approval state; desktop and mobile applications connect to
the same versioned WebSocket protocol.

## Development

```sh
dart pub get --enforce-lockfile
dart run melos verify
dart run melos verify:debug
```

Quality commands use every detected logical processor by default. Limit a run
with `TINEST_JOBS=8` or invoke the package CLI directly with `--jobs=8`.
Machine-readable phase timings are available through
`dart run tinest_quality verify --report=build/quality/verify.json`; focused
tests stay in the package that owns them.

Desktop Debug E2E uses one lane at `--jobs=1` and at most two isolated,
staggered lanes otherwise. Capture per-lane build-ready time, seed, duration,
and exit status with
`dart run tinest_quality e2e --report=build/quality/e2e.json`.

Run the standalone daemon. The seeded OpenAI provider reads
`OPENAI_API_KEY`; additional providers can use an environment variable or a
locally stored credential configured from the Settings screen:

```sh
dart run melos run run:daemon
```

The default endpoint is `ws://127.0.0.1:7337/v4/ws`. Override the state/config
directory and listener with `TINYRACK_TINEST_HOME` and
`TINYRACK_TINEST_LISTEN`. Without an override, Linux uses the XDG config/state
directories, macOS uses Application Support, and Windows uses AppData.

The app shell does not require a daemon connection. Desktop enables its
app-owned embedded daemon by default, while mobile remains remote-only. Global
Settings can disable the embedded daemon and save any number of independent
`ws://` or `wss://` remote daemon profiles. Desktop Settings also controls
whether the embedded daemon listens only on `127.0.0.1` or on every IPv4
interface (`0.0.0.0`); changing it restarts only that app-owned daemon. Offline
profiles and the last selected host remain navigable.

Provider and Markdown Agent setup belongs to a connected daemon. Every client
uses one bearer token, which grants the complete daemon API for both local and
remote connections. `tinest-cli` both hosts a daemon and drives the same
setup from a terminal against an already running one, discovering its token
from the same configuration directory:

```sh
brew install tinyrack-net/tap/tinest-cli   # or winget install Tinyrack.TinestCLI
tinest-cli daemon start
tinest-cli provider list
tinest-cli agent apply reviewer --file reviewer.md
```

Run `tinest-cli completion bash` (or `zsh`, `fish`, `powershell`) to install
shell completion.

From a checkout, `dart run melos run:cli -- provider list` runs the same
commands without installing anything.

Desktop, mobile, and web use separate targets so that only the desktop
bootstrap can start a daemon. Run these commands from `packages/app`:

```sh
cd ../desktop_app
flutter run -d linux -t lib/main.dart
flutter run -t lib/main_mobile.dart
flutter run -d chrome -t lib/main_web.dart
```

The web build is a client only, hosted at `https://tinest.tinyrack.net`. It
connects to a daemon you run yourself, which has to allow the page's origin
first. A daemon on your own machine also works, after granting the browser's
Local Network Access permission once.

Release builds, packaging, and the winget and Homebrew channels are driven by
`.github/workflows/pipeline.yml`.

`flutter pub outdated` offers upgrades that are actually blocked by the Flutter
SDK or an upstream package; check the real constraint before bumping anything.

The daemon intentionally does not implement TLS or certificate bypasses. Keep
it bound to loopback when terminating TLS in a local reverse proxy. Binding to
all interfaces exposes the plain daemon port, which must be isolated by the
operator's firewall when TLS is mandatory.

External MCP servers are configured through the Settings screen or a
repository-declared `.tinest/config.json`, which is trusted code and should be
reviewed like any other dependency.
