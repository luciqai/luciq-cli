# Luciq CLI

Command-line interface for Luciq: upload symbol files and query or manage your
app data — crashes, bugs, APM, reviews, surveys, issues, opportunities, alerts,
and more.

## Installation

### Using RubyGems

```bash
gem install luciq-cli
```

### Using Homebrew (macOS/Linux)

```bash
brew install luciqai/tap/luciq-cli
```

### From Source

```bash
git clone https://github.com/luciqai/luciq-cli.git
cd luciq-cli
bundle install
bundle exec rake install
```

## Quick Start

### 1. Authenticate

Generate a CLI token from your [Luciq Dashboard](https://dashboard.luciq.ai/company/luciq-cli), then:

> **Self-hosted clusters:** Replace `dashboard.luciq.ai` with your cluster URL.

```bash
luciq login
```

Or pass the token directly:

```bash
luciq login --auth-token YOUR_CLI_TOKEN
```

### 2. Upload Symbol Files

Upload Android mapping files (`mapping.txt`):

```bash
luciq upload android-mapping mapping.txt \
  --slug my-app \
  --mode production \
  --version-name 1.0.0 \
  --version-code 1
```

| Option | Description |
|--------|-------------|
| `--slug` | Application slug (required) |
| `--mode` | Application mode, e.g., `production` (required) |
| `--version-name` | App version name, e.g., `1.0.0` (required) |
| `--version-code` | App version code, e.g., `1` (required) |

## Commands

| Command | Description |
|---------|-------------|
| `luciq login` | Authenticate with Luciq |
| `luciq logout` | Remove saved authentication |
| `luciq whoami` | Show current authenticated user |
| `luciq info` | Show CLI configuration |
| `luciq version` | Show CLI version |
| `luciq upload` | Upload symbol files (see below) |
| `luciq crashes` | Query crashes (including app hangs) and occurrences |
| `luciq bugs` | Query and update bugs |
| `luciq apm` | Query APM metrics and manage funnels |
| `luciq reviews` | Query app store reviews |
| `luciq surveys` | Query surveys and their responses |
| `luciq apps` | List accessible applications |
| `luciq issues` | List issues across sources, ranked by impact |
| `luciq opportunities` | Query product opportunities |
| `luciq alerts` | Manage alert rules |
| `luciq incidents` | Manage triggered alerts |
| `luciq insights` | Show aggregated app-health insights |

See [Query & management commands](#query--management-commands) for the full option
set of the data commands.

### Upload commands

Run `luciq upload help SUBCOMMAND` for the full options of any command.

**iOS**

| Command | File | Description |
|---------|------|-------------|
| `luciq upload ios-dsym FILE` | `.zip` | iOS dSYM symbols |

**Android**

| Command | File | Description |
|---------|------|-------------|
| `luciq upload android-mapping FILE` | `mapping.txt` | Proguard/R8 mapping file |
| `luciq upload android-ndk FILE` | `.zip` | NDK `.so` shared object files (`--arch`) |

**React Native**

| Command | File | Description |
|---------|------|-------------|
| `luciq upload react-native-ios-dsym FILE` | `.zip` | iOS native dSYM symbols |
| `luciq upload react-native-ios-sourcemap FILE` | `.json`/`.txt` | iOS JavaScript source map |
| `luciq upload react-native-android-mapping FILE` | `mapping.txt` | Android native Proguard/R8 mapping |
| `luciq upload react-native-android-sourcemap FILE` | `.json`/`.txt` | Android JavaScript source map |
| `luciq upload react-native-ndk FILE` | `.zip` | NDK `.so` shared object files (`--arch`) |

**Flutter**

| Command | File | Description |
|---------|------|-------------|
| `luciq upload flutter-ios-dsym FILE` | `.zip` | iOS native dSYM symbols |
| `luciq upload flutter-ios-sourcemap FILE` | `.zip` | iOS Dart symbol files |
| `luciq upload flutter-android-mapping FILE` | `mapping.txt` | Android native Proguard/R8 mapping |
| `luciq upload flutter-android-sourcemap FILE` | `.zip` | Android Dart symbol files |
| `luciq upload flutter-ndk FILE` | `.zip` | NDK `.so` shared object files (`--arch`) |

Common options: `--slug` and `--mode` are required for every command — uploads use
your CLI login, the same as query commands. dSYM commands (`*-ios-dsym`) need only
`--slug` / `--mode`. Mapping, source-map, and
Flutter Dart-symbol commands also require `--version-name` / `--version-code`
(React Native source-map commands additionally accept `--codepush`). NDK commands
require `--version-name` and `--arch` (`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`)
— not `--version-code`.

## Query & management commands

Beyond uploading symbols, the CLI queries and manages your Luciq data. Every
response is printed as pretty-printed JSON, so it pipes cleanly into tools like
`jq`.

### Shared options

Most data commands target one application in one environment and share a common
set of options:

| Option | Description |
|--------|-------------|
| `--slug` | Application slug (required) |
| `--mode` | Environment: `production`, `beta`, `staging`, `alpha`, `qa`, `development` (required) |
| `--offset`, `--limit` | Pagination |
| `--sort-by`, `--direction` | Sort field and direction (`asc`/`desc`) — some commands use `--sort-direction` instead |
| `--filters` | Raw filter JSON object, merged with the typed filter flags (typed flags win on key conflicts) |

Common filters have dedicated typed flags (`--status`, `--platform`,
`--app-version`, …). Anything a tool supports but that has no flag can be passed
through `--filters`, e.g. `--filters '{"devices":["iPhone15,2"],"os_versions":["17.4"]}'`.
Run `luciq <group> help <subcommand>` for the full option list and the filter
keys each command accepts.

### Crashes

`luciq crashes SUBCOMMAND`

| Subcommand | Description |
|------------|-------------|
| `list` | List crashes. Flags: `--status` (open/closed/in_progress), `--platform` (IOS/ANDROID/DART/JAVASCRIPT), `--type` (CRASH/ANR/OOM/NON_FATAL/APP_HANG/FORCE_RESTART; force restarts are listed only with FORCE_RESTART), `--app-version` |
| `show --number N` | Details for one crash |
| `patterns --number N` | Grouped patterns. Flags: `--pattern-key`, `--sort-by`, `--direction` |
| `diagnostics --number N` | Diagnostics for one crash |
| `occurrence-tokens --number N` | Occurrence cursor tokens. Flags: `--current-token`, `--direction` (first/last) |
| `occurrence --number N --ulid U` | Details for a single occurrence |

```bash
luciq crashes list --slug my-app --mode production --status open --limit 20
luciq crashes show --slug my-app --mode production --number 42
```

### Bugs

`luciq bugs SUBCOMMAND`

| Subcommand | Description |
|------------|-------------|
| `list` | List bugs. Flags: `--status` (new/closed/in_progress), `--priority` (na/trivial/minor/major/blocker), `--app-version` |
| `show --number N` | Details for one bug |
| `update --number N` | Update a bug. Flags: `--status`, `--priority`, `--tags`, `--tag-action`, `--clear-tags`, `--duplicate-of`, `--action` |

```bash
luciq bugs update --slug my-app --mode production --number 7 --status closed --priority major
luciq bugs update --slug my-app --mode production --number 7 --duplicate-of 3
luciq bugs update --slug my-app --mode production --number 7 --tags urgent regression
luciq bugs update --slug my-app --mode production --number 7 --tags stale --tag-action remove
luciq bugs update --slug my-app --mode production --number 7 --tags only-this --tag-action replace
```

Provide at least one change. Duplicate marking (`--duplicate-of` / `--action`)
can't be combined with `--status`/`--priority`. Tags: `--tags` appends to the existing
tags by default; `--tag-action replace` sets `--tags` as the full list (removing others),
`--tag-action remove` deletes `--tags` and keeps the rest; `--clear-tags` removes all.

### APM

`luciq apm SUBCOMMAND`

| Subcommand | Description |
|------------|-------------|
| `groups --metric M` | Rank groups worst-first. `--metric`: network, launch, flows, screen_loading, frame_drop, funnels. `--sort` is a JSON object `{"by":…,"direction":…}` |
| `group --metric M` | Panels for one group; identify with `--group-uuid` or `--group-url`. `--views` is a JSON array (default `["summary"]`); `--method` applies to network |
| `occurrence --metric M --selector S` | Inspect occurrences (`--selector`: worst/by_token/list). Flags: `--token`, `--current-token`, `--direction`, `--limit` |
| `funnel-events` | List events pickable for funnels. Flags: `--event-type`, `--q`, `--limit` |
| `funnel-create --name N --events JSON` | Create a funnel from 2–20 steps |
| `funnel-update --ulid U` | Update a funnel (`--name`, `--events`) |
| `funnel-delete --ulid U` | Delete a funnel |

```bash
luciq apm groups --slug my-app --mode production --metric network \
  --sort '{"by":"p95","direction":"desc"}'
```

### Reviews

`luciq reviews list` — Flags: `--rating` (1–5), `--country`, `--os` (ios/android),
`--sort-by date`, `--sort-direction`.

### Surveys

`luciq surveys SUBCOMMAND`

| Subcommand | Description |
|------------|-------------|
| `list` | List surveys. Flags: `--type` (0=custom 1=nps 2=app_store), `--status` (0=draft 1=published 2=paused) |
| `show --id N` | A survey's questions and response statistics. `--page` paginates responses |

### Apps

`luciq apps list` — List the applications you can access (no `--slug`/`--mode`).
Optional `--platform` (ios/android/react_native/flutter).

### Insights

`luciq insights --slug my-app --mode production` — Aggregated app-health insights.
Narrow with `--filters` (`date_ms`, `app_version`).

### Issues

`luciq issues list` — Issues across crashes, APM, AI, and bugs, ranked by Apdex
impact. Flags: `--limit`, `--sort-by` (apdex_impact/occurrences_counter),
`--sort-direction`, `--top-issues` (curated shortlist), `--pagination`
(per-source cursor tokens JSON).

### Opportunities

`luciq opportunities SUBCOMMAND`

| Subcommand | Description |
|------------|-------------|
| `list` | List opportunities. Flags: `--status`, `--priority` (1–4/unset), `--team-id` |
| `show --id N` | Details for one opportunity |

### Alerts

`luciq alerts SUBCOMMAND` — Manage alert rules.

| Subcommand | Description |
|------------|-------------|
| `list` | List rules (`--sort-by`, `--sort-direction`) |
| `show --ulid U` | Show one rule |
| `init` | Show the menu (types, triggers, conditions, actions) for building a rule |
| `create --payload JSON` | Create a rule |
| `update --ulid U --payload JSON` | Update a rule |
| `delete --ulid U` | Delete a rule |

Run `luciq alerts init` first to discover the valid rule building blocks, then
pass the rule body as `--payload`.

### Incidents

`luciq incidents SUBCOMMAND` — Manage triggered alerts.

| Subcommand | Description |
|------------|-------------|
| `list` | List incidents. Flags: `--sort-by`, `--sort-direction`, `--status`, `--type` |
| `show --ulid U` | Show one incident |
| `resolve --ulid U` | Resolve an incident |
| `reopen --ulid U` | Reopen an incident |

## Configuration

Configuration is read from environment variables and `~/.luciqrc` file.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `LUCIQ_AUTH_TOKEN` | Authentication token |
| `LUCIQ_URL` | API base URL (default: https://api.luciq.ai) |

### Config File

```
# ~/.luciqrc
token=your-cli-token
url=https://api.luciq.ai
```

### Self-Hosted / Single Tenant

If you're using a self-hosted or single tenant cluster, you need to configure the API URL:

**Option 1: Environment variable**

```bash
export LUCIQ_URL=https://api.your-cluster.luciq.ai
```

**Option 2: Config file**

Add the `url` to your `~/.luciqrc`:

```
token=your-cli-token
url=https://api.your-cluster.luciq.ai
```

## Development

Clone the repo and install dependencies as in [From Source](#from-source), then:

```bash
# Run tests
bundle exec rspec

# Test locally
bundle exec bin/luciq --help
```

## Releasing

After publishing a new gem version to RubyGems, sync the Homebrew formula in
the [homebrew-tap](https://github.com/luciqai/homebrew-tap) repo:

```bash
bundle exec rake formula:bump   # writes to ../homebrew-tap, override with TAP_DIR
```

Open a pull request in the tap repo with the result: Homebrew users stay on
the previous version until the bumped formula lands on its `main` branch.
`brew livecheck luciq-cli` reports when the formula lags RubyGems.
