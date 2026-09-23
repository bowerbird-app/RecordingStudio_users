# Demo stills

## Create-password extra_fields slot (Users 0.12.1)

PR: https://github.com/bowerbird-app/RecordingStudio_users/pull/27

`signup-password-extra-fields.png` is the create-password step with the blank Users `extra_fields` slot.

## Dummy TnC integration (Users 0.12.2)

PR: https://github.com/bowerbird-app/RecordingStudio_users/pull/28

Dummy installs released `recording_studio_terms_and_conditions` `v0.6.5` and Flatpack `v0.1.196`. Users detects that gem and pending live Terms on create-password. TnC `Gate.root_for_signup` falls back to the first live-Terms root when the current workspace has none. Production Users stays independent of a gemspec pin. Dummy uses the gem Accept screen (continue-notice + **Continue**).

- `signup-password-tnc-notice-closed.png` — `/users/sign_up/password` with the xs muted “By continuing…” notice and Terms & Conditions link. Modal closed.
- `signup-password-tnc-modal-open.png` — the same page with the Flatpack Modal open on the standalone Terms document (`Terms and Conditions v1.0`).
