# Security

Configure every policy explicitly for the host's authorization model. Defaults are self-only and
search is disabled.

Never pass request-controlled class names or variant names. Avatar sizes map to trusted Attachable
variants. Search uses a configured relation, escaped wildcard input, bounded results, identity
filtering, and optional root authorization.

`log_user_event` accepts allowlisted actions and scalar metadata only. Keys resembling passwords,
tokens, secrets, sessions, signed blob IDs, blob keys, and storage URLs are discarded.

Do not log or expose plaintext passwords, encrypted passwords, reset/confirmation/unlock tokens,
session identifiers, API credentials, Active Storage keys, signed IDs, or provider URLs.

The provisioning and avatar exceptions are private execution-local contexts with exact object and
operation matching. They are cleared in `ensure` and are not request-controlled bypasses.
