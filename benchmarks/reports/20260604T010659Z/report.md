# Libero Transport Benchmark

Contract hash: `48e037415fa01e87b6571d9c34cd351f512a58caf012171e8118eb57e1eeb111`

Environment:

- Date: `2026-06-04`
- Gleam: `gleam 1.16.0`
- Erlang: `28`
- Node: `v23.10.0`

Method:

- Fixture project generated JSON transport through the default CLI path.
- ETF helper modules were generated through Libero's public generator APIs so the benchmark can call `generated@rpc_wire` without compiling the old ETF dispatch module.
- BEAM server encode rows include generated response helpers plus wire frame encoding.
- BEAM server request decode rows include wire request decode plus generated `ClientMsg` decode.
- JS JSON parse-only rows use `gleam/json.parse` without wire frame validation or generated typed payload rebuild.
- JS JSON wire-decode rows include `libero/json/wire.decode_server_frame` and stop before generated typed payload rebuild.
- JS JSON typed-decode rows reuse an already extracted response `value` and measure generated typed payload rebuild only.
- JS client response decode rows include wire frame decode plus generated typed payload rebuild for JSON. ETF uses the generated decoder registration path.
- Each result subsection compares ETF and JSON for one target, stage, and payload. The `Ratio` column is JSON divided by ETF for the same metric. Rows without a matching ETF stage leave the ratio blank.
- Warmup: 50 untimed iterations per row.

## Results

### BEAM: Server Request Decode

#### Large Shots

Decodes the Large Shots request payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 26.11 | 1073.56 | 41.11 |
| Size (B) | 71093 | 150297 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.59 | 574.33 | 34.63 |
| Size (B) | 17063 | 38403 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 15.89 | 624.79 | 39.31 |
| Size (B) | 11838 | 23256 | 1.96 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.12 | 85.25 | 40.27 |
| Size (B) | 236 | 603 | 2.56 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.09 | 105.13 | 50.35 |
| Size (B) | 509 | 1467 | 2.88 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 26.74 | 200.54 | 7.50 |
| Size (B) | 71085 | 150240 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 14.65 | 129.59 | 8.84 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 20.05 | 140.94 | 7.03 |
| Size (B) | 11828 | 23195 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.74 | 14.69 | 5.37 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.54 | 21.85 | 8.59 |
| Size (B) | 500 | 1407 | 2.81 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 65.97 | 528.05 | 8.00 |
| Size (B) | 71085 | 150178 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 40.37 | 310.05 | 7.68 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 54.11 | 331.44 | 6.13 |
| Size (B) | 11828 | 23095 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 10.86 | 52.81 | 4.86 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 7.59 | 57.46 | 7.57 |
| Size (B) | 500 | 1405 | 2.81 |

### JavaScript: JSON Parse Only

#### Large Shots

Parses the Large Shots JSON response without wire validation or typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 100.35 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Parses the Nested Game JSON response without wire validation or typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 55.52 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Parses the Repeated Records JSON response without wire validation or typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 61.94 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Parses the Small Admin JSON response without wire validation or typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 9.14 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Parses the Type Matrix JSON response without wire validation or typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 10.41 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Typed Decode

#### Large Shots

Rebuilds the Large Shots typed value from an already extracted JSON response value. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 357.62 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Rebuilds the Nested Game typed value from an already extracted JSON response value. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 216.37 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Rebuilds the Repeated Records typed value from an already extracted JSON response value. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 224.89 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Rebuilds the Small Admin typed value from an already extracted JSON response value. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 36.22 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Rebuilds the Type Matrix typed value from an already extracted JSON response value. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 42.12 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Wire Decode

#### Large Shots

Decodes the Large Shots JSON response frame without typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 179.92 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Decodes the Nested Game JSON response frame without typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 103.21 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Decodes the Repeated Records JSON response frame without typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 120.51 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Decodes the Small Admin JSON response frame without typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 15.51 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Decodes the Type Matrix JSON response frame without typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 16.62 |  |
| Size (B) |  | 1405 |  |


Raw CSV files:

- [results.csv](results.csv)
- [beam.csv](beam.csv)
- [js.csv](js.csv)
