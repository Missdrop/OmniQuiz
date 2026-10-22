# Code signing policy

## Current status

OmniQuiz is applying for free Windows code signing through SignPath Foundation.
The application is pending; no certificate or signing service has been granted.
Existing Windows releases, including v1.0.0, are unsigned. Preparing the CI
integration does not retroactively sign them.

If approved, the signing attribution will be:
“Free code signing provided by [SignPath.io](https://about.signpath.io/),
certificate by [SignPath Foundation](https://signpath.org/).”
This describes the proposed arrangement, not an existing endorsement.

## People and approval

- Committer and reviewer: [Missdrop](https://github.com/Missdrop).
- Release signing approver: [Missdrop](https://github.com/Missdrop).

The maintainer must enable multi-factor authentication on GitHub and SignPath.
Every production signing request requires explicit approval in SignPath after
reviewing its source revision, workflow, tests, and artifact configuration.
Signing is restricted to the public OmniQuiz repository, `main`, and stable
`vMAJOR.MINOR.PATCH` tags. Pull requests and arbitrary branches cannot request
production signatures. Only GitHub-hosted runners may produce signing inputs.
SignPath must independently enforce these restrictions through origin verification
and a signing policy with manual approval, not merely trust the workflow's checks.

## Files covered

The proposed configuration is [.signpath/windows-artifacts.xml](../.signpath/windows-artifacts.xml).
One request signs `omniquiz.exe` in both the portable ZIP and the MSI, then the
MSI itself. Product name, original filename and exact build version are constrained.
Bundled upstream Flutter/plugin/runtime DLLs retain their original signatures or
remain unsigned; this service must not sign third-party code as our own.

After signing, CI checks Windows trust, publisher and timestamps for the MSI and
both application copies. It compares the complete payload with the local build:
only Authenticode fields and the certificate appended to our executable may differ.
Signing or verification failure prevents publication when signing is enabled.
Private signing keys remain with SignPath and are never stored in this repository.

## Privacy and reporting

See the [Privacy policy](privacy.md) for storage, AI connections, authentication,
update checks, and third-party services. Report suspected signing misuse through
[GitHub issues](https://github.com/Missdrop/OmniQuiz/issues) without posting secrets,
or contact SignPath at the address in its [project terms](https://signpath.org/terms.html).
