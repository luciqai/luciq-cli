# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `FORCE_RESTART` value for `luciq crashes list --type`, to list force restarts. The server lists them only when this value is given, and only on plans that include force restarts.

### Changed

- **Breaking:** `luciq crashes hangs` is removed. Use `luciq crashes list --type APP_HANG` to list app hangs.

## [0.3.0] - 2026-08-04

### Changed

- **Breaking:** `luciq upload` commands now take `--slug` and `--mode` instead of `--app-token`, matching the query commands. Uploads authenticate with your CLI login, so no application token is needed.
- `luciq whoami` and `luciq upload` now call the Luciq API gateway instead of the public backend endpoints.

### Added

- `--tag-action` on `luciq bugs update` to control how `--tags` is applied: `append` (default), `replace`, or `remove`
- Homebrew installation: `brew install luciqai/tap/luciq-cli`
- MIT LICENSE

### Fixed

- `luciq bugs update` now rejects `--clear-tags` combined with `--tag-action`, and no longer treats a tags-only change as an empty update
- Corrected the dashboard URL shown for creating a CLI token

## [0.2.0] - 2026-07-05

### Added

- `luciq crashes` - Query crashes: `list`, `show`, `patterns`, `diagnostics`, `hangs`, `occurrence-tokens`, `occurrence`
- `luciq bugs` - Query and update bugs: `list`, `show`, `update` (status, priority, tags, duplicate marking)
- `luciq apm` - Query APM data: `groups`, `group`, `occurrence`, and funnels (`funnel-events`, `funnel-create`, `funnel-update`, `funnel-delete`)
- `luciq reviews list` - Query app reviews
- `luciq surveys` - Query surveys: `list`, `show`
- `luciq apps list` - List accessible applications
- `luciq insights` - Show aggregated app-health insights
- `luciq issues list` - List issues across sources ranked by impact
- `luciq opportunities` - Query opportunities: `list`, `show`
- `luciq alerts` - Manage alert rules: `list`, `show`, `init`, `create`, `update`, `delete`
- `luciq incidents` - Manage triggered alerts: `list`, `show`, `resolve`, `reopen`
- Typed filter flags with a raw `--filters` JSON escape hatch on query commands

## [0.1.0] - 2025-12-16

### Added

- Initial release
- `luciq login` - Authenticate with CLI token
- `luciq logout` - Remove saved authentication
- `luciq whoami` - Show current authenticated user
- `luciq info` - Show CLI configuration
- `luciq upload android-mapping` - Upload Android mapping files
- `luciq version` - Show CLI version
- Support for environment variables (`LUCIQ_AUTH_TOKEN`, `LUCIQ_URL`)
- Support for config file (`~/.luciqrc`)
