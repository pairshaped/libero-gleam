# user-auth

A full-stack user-auth checklist app built with Libero. Demonstrates:

- Sign up / sign in / sign out flow
- Per-user checklist items (SQLite-backed)
- Auth state sharing across client-side page navigations via ClientContext
- Server-side rendering (SSR) with hydration
- The ClientContext pattern: a self-contained client-side model with its own update function

## Auth note

This example uses username-only sign-in for simplicity. It demonstrates the auth
flow (session tokens, cookies, ClientContext) without the complexity of password
hashing. For production use, add a `password_hash` and `salt` column to the
`users` table, hash passwords with bcrypt or argon2, verify with constant-time
comparison, and consider adding a pepper stored outside the database.

## Run

```sh
bin/dev
```

Open http://localhost:8080.

## Tests

```sh
bin/test
```

## Layout

```
user-auth/
  server/         backend (Erlang), runs the libero RPC + SSR server
    src/sql/      SQL query files for marmot
    data.db       SQLite database (auto-created)
  shared/         cross-target types, views, and routing
  clients/web/    Lustre SPA (JavaScript)
    src/client_context.gleam    self-contained auth state module
  bin/            dev and test entry points
```

## Handlers

`server/src/handler.gleam` defines eight endpoints:

**Auth:**
- `sign_up(username)` -- creates a user + session, returns SignInResult
- `sign_in(username)` -- creates a session, returns SignInResult
- `sign_out()` -- clears session user from context
- `me()` -- returns the current session user (if any)

**Items (filtered by user_id):**
- `get_items()` -- lists the current user's items
- `create_item(params)` -- creates a new item for the current user
- `toggle_item(id)` -- toggles completed status
- `delete_item(id)` -- deletes an item

## ClientContext

`clients/web/src/client_context.gleam` is a self-contained module with its own Model, Msg, init, and update functions. It holds the auth state (current user + session token) that persists across SPA page navigations. On SSR full-page loads, it is hydrated from server-embedded flags. On client-side navigations (via modem), it persists through the main app's update function.

This pattern mirrors elm-land's Shared model. Use it for any state that should survive page transitions: auth, theme, notifications, etc.

## Regenerating

After editing handler signatures or shared types, run `bin/dev` to regenerate dispatch and client stubs.
