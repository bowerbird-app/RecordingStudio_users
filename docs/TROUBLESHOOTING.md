# Troubleshooting

## Registration fails

Verify `provisioning_actor` returns a persisted system actor and Accessible allows `User` as an
access actor type. Registration intentionally fails when private topology cannot be committed.

## Profile or avatar is missing

Run `RecordingStudioUsers.validate_user_profile!(user)`. Lookup methods never repair. Correct the
conflicting data deliberately or retry `provision` only after the topology is safe.

## Stored avatar falls back to initials

The stored-avatar delivery policy may be false for the current actor or the Attachable route may
not be able to verify the presentation context. Use a context-independent route-verifiable policy,
configure an external resolver, or keep the initials fallback.

## Avatar upload does not submit

Ensure the host application loads Active Storage's JavaScript. The Profile form intentionally uses
direct uploads and does not accept a server-side multipart fallback.

## Search returns no users

Configure both `search_scope` and `search_authorizer`. Queries shorter than two characters,
unauthenticated actors, unauthorized roots, and invisible identities are rejected or omitted.

## Admin Users is unavailable

Register `section :users` on the host Admin root and configure RecordingStudioAdmin's site-access
recording. A private UserRoot admin grant is intentionally insufficient.
