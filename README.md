# Recording Studio Users

People, invitations, workspace onboarding, and operating roles for Recording Studio.

Users keeps three responsibilities separate:

- Devise identifies the signed-in person.
- Recording Studio Accessible authorizes that person on root recordings.
- Recording Studio Root Switchable chooses the current root.

A workspace (or another host root recordable) is the team. This gem does not add a `Team` model, an access table, impersonation, or a second root switcher.

## Supported versions

```ruby
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.1.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", branch: "main"
gem "recording_studio_root_switchable", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"
gem "recording_studio_users", github: "bowerbird-app/RecordingStudio_users"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.129"
```

Accessible must include `bootstrap_owner_access!` (0.6.1 or newer). Until `v0.6.1` is tagged, pin Accessible to `main` or a known commit.

## Install

```bash
bin/rails generate recording_studio_users:install
bin/rails db:migrate
bin/rails tailwindcss:build
```

The generator:

- installs a host `User` through Devise when one does not exist;
- mounts the Users engine;
- copies the invitation migration;
- includes Root Switchable controller support and the Users current-context gate;
- adds an initializer for Users and Accessible;
- adds Tailwind source paths for Users and Flatpack.

Review the generated initializer. Its `root_creator` is deliberately a host callback:

```ruby
RecordingStudioUsers.configure do |config|
  config.root_creator = ->(name:, **) { Workspace.create!(name: name) }
  config.mailer_sender = "people@example.com"
end
```

Invitation emails use `config.action_mailer.default_url_options` to generate an absolute acceptance URL. Set a real host in every deployed environment.

Declare and enable access on the host root:

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
end
```

Configure Root Switchable from Accessible, never from every root in the database:

```ruby
RecordingStudioRootSwitchable.configure do |config|
  config.scope :workspaces do |scope|
    scope.switchable_root_types = ["Workspace"]
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
  end
end
```

## Onboarding

`RecordingStudioUsers::CurrentContext` sends an authenticated person with no accessible roots to Users onboarding. Devise routes are skipped. Once at least one root is available, Root Switchable resolves the current root normally.

Creating the first workspace follows one trusted path:

1. call the host `root_creator`;
2. resolve the root with `RecordingStudio.root_recording_for`;
3. reject shared roots;
4. call `RecordingStudioAccessible.bootstrap_owner_access!`;
5. select the root through Root Switchable.

Bootstrap never runs for shared roots and never uses the Accessible demo/ENV authorizer.

## Invitations and membership

Mount the people screen wherever it fits your product:

```erb
<%= link_to "People",
  recording_studio_users.invitations_path(root_recording_id: current_root_recording.id) %>
```

Invitations store a digest of the emailed token. A signed-out recipient is sent through Devise and returned to the same invitation. Acceptance requires the invited email, grants through `RecordingStudioAccessible.grant_access`, and selects the accepted root through Root Switchable. If the inviter no longer has admin access, Accessible fails the grant closed; send a new invitation from a current admin.

Role changes and revocation use Accessible’s update and revoke services. No membership ACL is stored by Users.

For Accessible’s optional low-level access screen, route unresolved email addresses into Users:

```ruby
config.access_management_missing_actor_handler = lambda do |email:, recording:, role:, **|
  {
    status: :requires_resolution,
    location: RecordingStudioUsers::Engine.routes.url_helpers.invitations_path(
      root_recording_id: recording.id,
      email: email,
      role: role
    )
  }
end
```

## Operating roles

An operating role is a temporary, session-backed hat. It can only demote below the Accessible ceiling.

```ruby
RecordingStudioUsers.current_operating_role(
  actor: current_user,
  recording: current_root_recording,
  session: session
)

RecordingStudioUsers.authorize!(
  actor: current_user,
  recording: current_root_recording,
  role: :admin,
  mode: :both,
  session: session
)
```

Modes:

- `:both` checks the Accessible ceiling and operating role. This is the default for invite, grant, change-role, and revoke flows.
- `:operating` checks the clamped operating role.
- `:ceiling` checks Accessible only.

Users intentionally does not define `authorized?`; that name remains Accessible’s ceiling check.

## Development

Run both suites:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

The dummy app proves sign-up/onboarding, first-root bootstrap, invitations, membership, root selection, and operating-role demotion with real Rails wiring.

## Admin

Recording Studio Admin is optional. Users 0.1 has no hard Admin dependency. Staff-facing user search and lifecycle screens belong in a later Admin 2.0 integration.
