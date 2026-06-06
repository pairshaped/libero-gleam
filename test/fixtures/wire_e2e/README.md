## Wire E2E fixture

A staged multi-package Gleam fixture used by `test/js/wire_e2e_setup.sh` to
produce compiled artifacts for JavaScript ETF wire tests.

### Directory layout

The fixture uses template directories instead of a conventional nested `src/`
layout. `shared_src/` and `client_src/` contain `.gleam.template` files rather
than `.gleam` files. This prevents the root `gleam test` from compiling the
nested fixture as part of Libero itself.

During setup, the fixture sources are copied to an external staging directory
under `$TMPDIR` arranged as a three-peer project:

- `server/`
- `shared/`
- `clients/web/`

The setup script writes a small staged Libero generator module, supplies type
seeds explicitly, and writes generated Libero artifacts into the staged server
and web packages.

### Files

- `gleam.toml`: server package config after staging.
- `shared_src/shared/types.gleam.template`: type coverage matrix.
- `shared_src/shared/collision.gleam.template`: same-name type collision
  coverage.
- `client_src/app.gleam.template`: minimal client app that imports generated
  modules.
- `shared/gleam.toml`: shared package definition.
- `clients/web/gleam.toml`: web client package definition.
