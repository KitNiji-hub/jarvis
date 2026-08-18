# Security Policy

## Supported Versions

This repository is a personal, local-first Jarvis fork under active development.

| Version / Branch | Supported |
| ---------------- | --------- |
| `kitniji/fast-pipeline` | Yes |
| Latest published release | Yes |
| Older releases and tags | Best effort only |

Security fixes are developed on `kitniji/fast-pipeline` first and may later
be included in a tagged release.

## Reporting a Vulnerability

Please use GitHub's private vulnerability reporting / Security Advisory
features when available.

Do not post sensitive vulnerability details, API keys, credentials, personal
information, or private local data in a public issue.

A useful report should include:

- The affected commit, branch, or release.
- Steps needed to reproduce the issue.
- The security impact.
- Relevant logs with secrets and personal information removed.
- Whether the issue requires a particular tool, MCP server, or configuration.

This is a personal/experimental project, so response times are best effort.

## Local-First Security Model

Jarvis is intended to run locally wherever practical. Local model inference,
speech recognition, text-to-speech, memory, and other components can remain
on the user's machine.

Optional features may communicate outside the computer when explicitly
configured, including web search, browser tools, MCP servers, email/calendar
integrations, or other external services.

Users should review the permissions and network behavior of optional tools
before enabling them.

## Security Priorities

Issues are considered especially important when they could cause:

- Unintended remote network exposure.
- Unauthorized command or tool execution.
- Access to files outside an intended scope.
- Credential, token, or private-data disclosure.
- Unsafe MCP or external-service access.
- Unexpected persistence or background execution.
