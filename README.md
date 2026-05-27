# ClaudeUsageKit

[![Swift Tests](https://github.com/h3nryprod01/claude-usage-kit/actions/workflows/tests.yml/badge.svg)](https://github.com/h3nryprod01/claude-usage-kit/actions)

Swift Package + CLI to read Claude Code's local transcripts (`~/.claude/projects/`)
and reconstruct usage, the 5-hour rate-limit frame, and cost estimates — without
calling any API.

Powers [RateLimitMonitor](https://ratelimitmonitor.app), a macOS menu bar app.

## Install

### As a Swift Package

```swift
dependencies: [
    .package(url: "https://github.com/h3nryprod01/claude-usage-kit", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "ClaudeUsageKit", package: "claude-usage-kit"),
    ])
]
```

### CLI

```bash
git clone https://github.com/h3nryprod01/claude-usage-kit
cd claude-usage-kit
swift run claude-usage          # human-readable
swift run claude-usage --json   # machine-readable
```

## What it does

- Parses every `*.jsonl` under `~/.claude/projects/`
- Deduplicates events by `requestId` (Anthropic emits multiple chunks per request)
- Detects the active 5-hour rolling rate-limit frame (heuristic: gap > 5h starts a new frame)
- Aggregates input / output / cache-read / cache-creation tokens
- Estimates cost using a pluggable `PricingTable`
- Provides a `UsageProvider` protocol so adapters for OpenAI, Gemini, etc. can be added

## Multi-provider

| Provider | Status | Source |
|---|---|---|
| Claude Code (local logs) | ✅ shipping | `~/.claude/projects/*.jsonl` |
| OpenAI | beta | `/v1/organization/usage` (24h delay) |
| Gemini | stub | requires local proxy |

PRs welcome for new providers.

## Caveats

- The 5h frame algorithm is a heuristic. Anthropic does not document the exact
  rule; sai số có thể có.
- Anthropic JSONL schema can change between Claude Code versions. Capture
  `version` in your usage analytics and adjust when it does.
- Pricing in `PricingTable.default` is indicative — verify against the current
  Anthropic price list before using for billing.

## License

MIT. See [LICENSE](LICENSE).
