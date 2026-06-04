# Libero Transport Benchmarks

This directory contains a reproducible benchmark harness for comparing the JSON
transport path with the secondary ETF path.

Run it from the repository root:

```sh
bash benchmarks/run.sh
```

The script creates a temporary Gleam project, points it at this checkout of
Libero, generates JSON code through the default CLI path, generates ETF helper
modules through Libero's public generator APIs, then runs benchmark modules
against the generated helpers. Results are written under `benchmarks/reports/`.

The benchmark deliberately measures separate stages:

- server encode: generated response helper plus wire frame encoding
- server request decode: wire request decode plus generated `ClientMsg` decode
- JS JSON parse only: `gleam/json.parse` without generated typed rebuild
- JS JSON wire decode: `libero/json/wire.decode_server_frame` without generated
  typed rebuild
- JS JSON typed decode: generated typed payload rebuild from an already
  extracted response value
- JS response decode: wire frame decode plus generated typed payload rebuild

Payload coverage includes app-like shapes plus an explicit `type_matrix` payload
covering shared transport shapes: primitives, `BitArray`, lists, `Option`,
`Result`, tuples, zero-field variants, unlabelled constructors, nested custom
types, and `Dict` with `String`, `Int`, and `Bool` keys.

Do not compare a single row as "JSON vs ETF overall". The report labels each
row by stage because the useful signal is where each codec spends time.
