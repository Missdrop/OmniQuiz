# ChatGPT plan access: feasibility

Rechecked against the current official sign-in, sessions, inference, limits,
UI guidance and DevKit documentation. Public OIDC discovery was also fetched;
its issuer, authorization/token endpoints, JWKS and revocation endpoint match
these docs. An experimental direct implementation is now present. No real account
authorization or plan-funded inference has been verified.

OmniQuiz already supports configurable OpenAI-compatible Chat Completions APIs.
That protocol compatibility does not mean the provider must be OpenAI.

## Current implementation: standalone devices

The required experience is independent phone login without a gateway, computer,
or server. The primary implementation now uses the official dynamic-registration
flow directly in Dart. CLIProxyAPI remains an optional compatible endpoint.

Settings exposes experimental sign-in, saved account registrations, account model
selection, a small inference test before activation, sign-out and a usage link.
The ChatGPT connection is an explicit profile mode. API-key connections remain
available, but generation never silently falls back between billing modes.

- Android uses Custom Tabs and iOS uses SFSafariViewController through url_launcher.
  The app starts a loopback-only listener before opening that browser component.
  An unsupported browser mode fails instead of silently switching to a WebView.
- State, nonce, PKCE, callback host/path, issued client ID, JWT RSA signature,
  issuer, audience, expiry and returning subject are checked.
- Registrations and tokens are stored together in OS secure storage, outside
  SQLite and backups. Refreshes are serialized; rotated tokens are stored before
  verifying a replacement identity token, and remain unusable until verified.
- Only the fixed public Responses endpoint receives ChatGPT access tokens. Text
  is accepted only after response.completed; failures and truncated streams fail.
- macOS Release permits a local listener through its network-server entitlement.

Local Android API 36 emulator tests exercise real Chrome Custom Tabs redirects
to the app's loopback listener and native encrypted credential storage, alongside
OIDC/refresh/SSE and validated question-generation tests. They use synthetic
authorization codes and tokens, not an OpenAI account. Small-screen UI tests cover
Android and iOS themes in English and Chinese with enlarged text.

These checks do not prove real account eligibility or plan-funded inference.
Android and iOS signed-device tests remain required. In particular, system termination during
login discards the pending attempt; the user must start a new login. No remote
credential relay or CLI subprocess is used. iOS browser/lifecycle behavior is
still an engineering hypothesis to validate on a physical device.

## Direct protocol


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

Desktop and mobile are implementation targets. Windows, macOS and Linux can host the documented HTTP loopback
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

## Eligibility, usage and SDK choice

The official quickstart identifies eligible Plus/Pro accounts. Login alone does
not authorize inference: check the actual granted plan-usage scope and admission
result for the selected account/workspace. Paid/remotely hosted products follow
the separate interest process described by OpenAI; this design targets the
current open-source local application.

ChatGPT Settings -> Usage manages the app's allowance and whether available
credits can be used after plan limits. The official sessions guide says Plus's
five-hour allowance is shared across apps; do not promise a separate allowance,
unlimited quizzes, a fixed reset time, or an exact remaining balance inferred
from a generic 429. Never silently fall back to a paid API-key connection.

The official DevKit is Node.js/React and its local package requires Node >=22.
Its OpenAI-authored code/documentation uses the **Sign-in with ChatGPT DevKit
Noncommercial License v1.0**, not a permissive MIT/Apache license. Do not assume
it can be copied into or bundled with this GPL-3.0 project without a compatibility
review. The recommended implementation independently follows the documented
HTTP/OIDC protocol in Dart rather than copying the DevKit or adding a Node
sidecar. OpenAI branding has separate usage requirements. Codex app-server is
an alternative integration, not a prerequisite and not an authentication bypass.

## Platform readiness

| Platform | Assessment and work before claiming support |
| --- | --- |
| Windows/Linux | Best initial validation targets: browser authorization and a listener bound only to `127.0.0.1`, with a per-attempt ephemeral port. Test occupied ports, cancellation, wrong state and request timeouts. |
| macOS | Same desktop flow, but Release now includes network-server access for the listener. Validate the signed Release app. |
| Android | Experimental until tested: the loopback listener must remain available while the system browser is foregrounded. Test process/activity lifecycle, receiving the callback, explicit return to OmniQuiz and subsequent refresh. Existing Internet permission/local cleartext configuration does not prove the login works. |
| iOS | Requires a feasibility spike: switching to the browser can suspend the app/listener. The reviewed OpenAI docs specify loopback, not a custom URL scheme or Universal Link recipe. Do not replace the callback with one of those without documented server support. |

These mobile assessments are engineering inferences from the documented callback
contract and app lifecycle, not an official prohibition. A successful desktop
login, a compiling mobile binary, or an available model list does not establish
successful plan-funded inference on a phone.

## Exact authorization and inference contract

- Persist `ext_agent_host_id` once per installation before first sign-in, using
  a supported format such as `urn:uuid:<UUIDv4>`. Keep it across restarts and
  account/library switches; do not clone it through study-library backups.
- First authorization uses `client_id=dynamic_agent_client`, the actual app name
  as `agent_name_hint`, fresh state/nonce, PKCE S256 and
  `resource=https://api.openai.com/v1`. Request `openid profile email
  offline_access resource.invoke chatgpt.tokens.use.direct`.
- Listen before opening the browser. Use exactly
  `http://127.0.0.1:<port>/auth/callback`; the exact same URI must be used in code
  exchange. Neither `localhost` nor a different callback path is equivalent.
- Save the issued client ID from a validated registration callback, not
  `dynamic_agent_client`. Verify ID-token signature, issuer, issued-client-ID
  audience, expiry and nonce using a maintained JWT/JWKS implementation. Keep
  new authorization separate until identity and scopes have been verified.
- Store access/refresh/retained ID tokens in secure storage under ChatGPT-specific
  keys, separate from API profiles, database snapshots, logs and backup archives.
  Associate them with validated identity and issued client ID, not email alone.
- Refresh using the saved issued client ID, without a client secret. Respect
  server expiry/refresh metadata; atomically replace rotating token sets and
  serialize refresh for a session. Temporary network failures must not erase
  valid registrations. Revoke the renewable session when signing out; if remote
  revocation cannot be confirmed, clear locally and explain that distinction.
- Fetch `GET https://api.openai.com/v1/models` with the selected session token.
  Its documented response is a `models` array; display `display_name` for entries
  with `visibility: list` and use `slug` for inference. Do not assume the API-key
  model-catalog shape or entitlement merely from seeing a model name.
- Call `POST https://api.openai.com/v1/responses` with the OAuth bearer token,
  `store:false`, `stream:true` and array-form `input`. Put quiz rules in
  `instructions` or developer messages. Existing Chat Completions `messages`,
  `response_format` and system-message items must not be copied blindly.
- The current route rejects fields including `temperature`, `max_output_tokens`,
  `background`, `conversation` and HTTP `previous_response_id`. Build each batch
  from the existing bounded local source chunks. Hosted file search and the
  Files upload API are unavailable on this route; local TXT/Markdown/PDF parsing
  already fits this constraint.
- Decode UTF-8/SSE incrementally, bound buffered data, and accept output only
  after `response.completed`. Handle failed/incomplete responses and terminal
  quota errors even if text deltas were already received. Only completed JSON
  proceeds to the existing question validator and question-bank transaction.

## Modules to add

- Application ports for ChatGPT account sessions and model discovery.
- An authentication service for authorization, callback validation and refresh.
- A secure token-store adapter and platform browser/callback adapters.
- A Responses/SSE adapter behind the existing question-generation boundary.
- Settings UI for connecting an account and choosing an entitled model.

Keep token exchange, JWT validation, persistence, SSE decoding and UI separate;
none belongs in a universal provider manager or in a single giant login method.

## Fit with the current code

`AiQuestionGenerator` and `GenerationCoordinator` already separate inference
from the question buffer and persistence. Keep those boundaries. The current
`ProviderProfile`/`GenerationRequest` still assume a Chat Completions endpoint,
API-key reference and model; add an explicit connection kind and account
registration reference, with backward-compatible defaults for saved API jobs.
Never store OAuth tokens in a generation job payload.

Extract reusable quiz-prompt building and completed-result JSON decoding from
`ChatCompletionsGenerator`. Add a ChatGPT-plan generator and a dispatcher behind
`AiQuestionGenerator`, sharing `QuestionValidator` but using separate transports.
Keep OAuth, account/session persistence, token refresh, SSE parsing and settings
view models in separate modules. Account/model changes must stop active
requests before replacing the selected connection. Library switching must not
create a new account registration or host ID.

Treat plan-limit errors as a distinct paused state. Existing retryable 429
handling is insufficient: `subscription_sharing_usage_limit_exceeded` should
pause prefill and offer Manage usage, while temporary usage-check outages may
use bounded backoff. Do not replay an uncertain paid request or continue saving
partial questions. Retain existing buffered questions while generation is paused.

## Remaining acceptance gates

1. Build a small desktop OAuth/model-discovery/completed-inference spike using
   an explicitly authorized eligible account and a trivial non-private prompt.
   Login or model listing by itself is not a pass. Do not automatically launch
   account authorization as part of unit tests or CI.
2. Exercise the implemented account/session and Responses adapters through the
   real settings UI. Check account switching, model selection and usage links.
3. Test callback state/nonce mismatch, duplicate callbacks, occupied ports,
   identity mismatch, missing scopes, token rotation races, revocation, split
   UTF-8/SSE events, quota failures after output, cancelled streams and backup
   exclusion of all account credentials. Run real signed desktop smoke tests.
4. Run Android mobile validation before presenting that platform
   as supported. Exercise browser round trips, activity/process recreation,
   cancellation, account switching, lock/unlock, refresh and completed inference.
5. Validate iOS separately, especially background suspension and browser return.
   Do not claim a supported callback or introduce a remote credential relay just
   to mask an unresolved native lifecycle problem.

Research has confirmed the public protocol and identified repository changes.
End-to-end authorization, account eligibility and phone support remain unverified.

## Official sources

- [Plan usage overview](https://developers.openai.com/siwc/token-sharing-open-source)
- [Registration and sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [Models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [Codex app-server option](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server)

- [Quickstart and eligible accounts](https://developers.openai.com/siwc/quickstart)
- [Accounts, refresh and usage](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [Errors and recovery](https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery)
- [UI/UX guidance](https://developers.openai.com/siwc/ui-ux-guidelines)
- [Official desktop integration cookbook](https://developers.openai.com/cookbook/articles/sign-in-with-chatgpt)
- [DevKit README and license](https://github.com/openai/sign-in-with-chatgpt-devkit)
- [DevKit license text](https://github.com/openai/sign-in-with-chatgpt-devkit/blob/main/LICENSE)
