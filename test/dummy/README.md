# RecordingStudioUser dummy

This host app demonstrates the installed engine with global profiles, FlatPack
Devise views, a normal `My workspace` root, and a separate access-controlled
`Admin` root.

```sh
bin/rails db:setup
bin/rails tailwindcss:build
bin/dev
```

Defaults:

- admin: `admin@example.com`
- normal user: `user@example.com`
- development-only password: `Password123!`

Set `DUMMY_ADMIN_EMAIL`, `DUMMY_ADMIN_PASSWORD`, `DUMMY_USER_EMAIL`, and
`DUMMY_USER_PASSWORD` before seeding to override them.

Visit `/users/sign_in`, `/profile`, and `/admin`. Only the admin seed receives a
RecordingStudioAccessible grant to the Admin root.
