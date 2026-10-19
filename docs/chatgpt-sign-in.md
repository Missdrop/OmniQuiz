# ChatGPT plan access: feasibility

Reviewed against official documentation on 2026-10-19. This is a design proposal;
OmniQuiz does not yet implement subscription sign-in.

OmniQuiz already supports configurable OpenAI-compatible Chat Completions APIs.
That protocol compatibility does not mean the provider must be OpenAI.

## Recommended route

Implement direct **Sign in with ChatGPT** for the open-source, locally hosted app.
The documented dynamic registration flow does not require an OmniQuiz backend,
client secret or partner API key. Users authorize eligible ChatGPT plan usage.
Available models and limits depend on the selected account/workspace and its
settings; subscription access must not be advertised as unlimited generation.

Use a stable per-installation host ID. Perform browser-based OAuth authorization
with PKCE, state and OIDC nonce. Validate the ID token and granted scopes before
activating the new account. Save access/refresh tokens only in secure storage,
separate from API profiles and backups. Support refresh, sign-out and revocation.

A dedicated Responses adapter must use the authorized access token, `store:false`
and `stream:true`. Obtain models for the selected account rather than hardcoding
entitlements. Read SSE through `response.completed`; failed/incomplete streams
and subscription quota errors are failures even if partial text was received.
Keep the existing local source selection, question validator and question buffer.
HTTP requests must carry required context; persistent remote conversation state
and hosted file search are not available on this route.

## Platform sequence

Desktop first: Windows, macOS and Linux can host the documented HTTP loopback
callback. Registration requires `127.0.0.1` and `/auth/callback`; an available port
may vary between attempts, but the exact URI must match within an attempt.

Android/iOS feasibility remains unverified. The reviewed protocol does not provide
an explicit mobile deep-link callback recipe. Test system-browser authorization,
loopback listener lifetime across app suspension, app return, token refresh and
signed-build networking before calling it supported. Mobile uncertainty is an
implementation/verification gap, not evidence of an explicit prohibition.

Codex app-server is an official desktop alternative, but still needs the same
user-authorized OAuth token. It adds a child process and RPC lifecycle that this
quiz application does not otherwise require. Direct Dart HTTP/OAuth adapters are
the preferred fit. Paid/remotely hosted apps follow a separate interest process.

## Modules to add

- Application ports for ChatGPT account sessions and model discovery.
- An authentication service for authorization, callback validation and refresh.
- A secure token-store adapter and platform browser/callback adapters.
- A Responses/SSE adapter behind the existing question-generation boundary.
- Settings UI for connecting an account and choosing an entitled model.

Keep token exchange, JWT validation, persistence, SSE decoding and UI separate;
none belongs in a universal provider manager or in a single giant login method.

## Official sources

- [Plan usage overview](https://developers.openai.com/siwc/token-sharing-open-source)
- [Registration and sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [Models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [Codex app-server option](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server)
