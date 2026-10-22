# Privacy policy

OmniQuiz is maintained by [Missdrop](https://github.com/Missdrop). It does not
require an OmniQuiz account and has no application analytics or advertising SDK.

## Data on your device

Study documents, extracted text, questions, answers, progress, and settings are
stored locally. Imported files and backups are saved to locations you choose.
AI credentials and ChatGPT session credentials use OS secure storage and are
excluded from portable library backups. Uninstalling a platform's app may remove
its private data; desktop data and exported backups can remain until you delete them.

## AI and authentication services

When you request generation or connection/model tests, the app sends the selected
material, prompts, and relevant request context to your configured AI provider or
gateway. Responses may include questions and explanations, which are saved locally.
Do not select a provider for documents you do not want that provider to process.
Saved practice and review can work offline without new AI requests.

Direct ChatGPT sign-in opens OpenAI's browser authorization and exchanges the
authorization response for session credentials. Subsequent authorized requests
and session refreshes communicate with OpenAI. The app stores session credentials
locally, not on an OmniQuiz server. OpenAI's processing is governed by its
[privacy policy](https://openai.com/policies/privacy-policy/).
Other API providers and gateways have their own policies; consult the operator
of the endpoint you choose. The maintainer does not receive your AI credentials,
documents, or generated questions through an OmniQuiz backend.

## Updates and external links

Startup update checks are enabled by default and can be disabled in **Settings →
App updates**. Startup or manual checks contact the public GitHub Releases API.
GitHub and its infrastructure can receive normal connection information such as
your IP address and the app's update-check User-Agent. Checks do not upload your
documents, library, AI credentials, or account identity.
Only pressing **Update now** starts an installation-package download. The update
is optional and can be postponed or skipped. Downloading packages or opening
official download pages contacts GitHub and its release-asset infrastructure,
subject to the [GitHub privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
Other external links open in your browser and follow the destination's policy.

## Project signing service

The proposed SignPath integration processes public Windows build artifacts and
GitHub build provenance for release signing. It does not receive end-user library
data or credentials. The signing application and maintainer account are governed
by [SignPath's privacy policy](https://signpath.io/privacy-policy).

For questions or reports, use [GitHub issues](https://github.com/Missdrop/OmniQuiz/issues).
Do not include private documents, access tokens, passwords, or account credentials
in public issues.
