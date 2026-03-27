# Fix: Allow passkey management for email-auth users

## Context

Users who log in via email magic link and already have a passkey on another device are blocked from adding/managing passkeys with: *"You need to authenticate via an additional factor before continuing."*

This is a catch-22: Rodauth's `webauthn` feature depends on `two_factor_base`, which treats email_auth + webauthn as a 2FA setup (2 methods). When a user logs in via email_auth alone, they're "partially authenticated" and blocked from webauthn routes — but the second factor it wants IS webauthn, which the user can't provide (different device).

## Fix

Override `two_factor_authentication_setup?` to return `false` inside `auth_class_eval`.

This is semantically correct: this app uses email_auth and webauthn as **alternative first factors**, not first + second. There are no passwords, no OTP, no SMS. The `two_factor_base` feature is only loaded because `webauthn` depends on it.

## File to modify

`app/misc/rodauth_main.rb` — add inside the existing `auth_class_eval` block:

```ruby
def two_factor_authentication_setup?
  false
end
```

## Verification

1. `mise x -- bundle exec rake project:tests`
2. `mise x -- bundle exec rake project:system-tests`
3. Docker rebuild + live test:
   - Log in via email magic link on desktop
   - Navigate to "Add passkey" — should load without error
   - Navigate to "Manage passkeys" — should load without error
