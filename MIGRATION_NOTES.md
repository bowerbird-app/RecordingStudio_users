# Upgrade notes

## 0.1.3

This release replaces the addon template with Recording Studio Users.

1. Pin Recording Studio `v4.1.0`, Root Switchable `v0.5.0`, and Accessible 0.6.1 or newer. Until Accessible `v0.6.1` is tagged, pin its `main` branch or a known commit.
2. Run `bin/rails generate recording_studio_users:install`.
3. Review `config/initializers/recording_studio_users.rb`; set the host `root_creator` callback and Root Switchable scope key.
4. Enable Accessible on the host root recordable.
5. Run `bin/rails db:migrate` and rebuild Tailwind.
6. Remove any custom membership table, first-owner ENV bypass, or root list that ignores Accessible.

The install generator creates a Devise `User` only when the host does not already have one. Existing applications should keep their current User model and ensure it exposes a normalized email.

There is no compatibility layer for the former template’s example service, sample page table, API-key configuration, or feature hooks. Those were template examples, not Users APIs.
