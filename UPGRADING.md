# Upgrading

## 0.25.1

Bump to `0.25.1`. No migration.

To render the same partial at the start of every unsigned auth `<body>` (sign in, sign up, and the rest) without copying the layout or overriding `auth_site_logo`:

```ruby
config.auth_body_start_partial = "shared/views_tracking"
```

Leave it unset (`nil`) and the auth HTML stays as in `0.25.0`. If a view already filled `content_for :recording_studio_user_auth_body_start`, that markup wins and the partial is not rendered.
