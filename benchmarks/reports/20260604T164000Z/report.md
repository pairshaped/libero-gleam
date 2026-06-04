# Libero Transport Benchmark

Contract hash: `48e037415fa01e87b6571d9c34cd351f512a58caf012171e8118eb57e1eeb111`

Environment:

- Date: `2026-06-04`
- Gleam: `gleam 1.17.0`
- Erlang: `29`
- Node: `v23.10.0`

Method:

- Fixture project generated JSON transport through the default CLI path.
- ETF helper modules were generated through Libero's public generator APIs so the benchmark can call `generated@rpc_wire` without compiling the old ETF dispatch module.
- BEAM server encode rows include generated response helpers plus wire frame encoding.
- BEAM server request decode rows include wire request decode plus generated `ClientMsg` decode.
- JS client response decode rows include wire frame decode plus generated typed payload rebuild for JSON. ETF uses the generated decoder registration path.
- Each result subsection compares ETF and JSON for one target, stage, and payload. The `Ratio` column is JSON divided by ETF for the same metric.
- CSV files include additional diagnostic rows, such as JSON parse-only, JSON wire-decode-only, JSON typed-decode-only, BEAM `etf_full_data_precheck`, BEAM `etf_strict_data_terms`, and JS `etf_depth_limit` measurements. The Markdown report omits those rows because they are not the main ETF vs JSON comparison.
- Warmup: 50 untimed iterations per row.

## Results

### BEAM: Server Request Decode

#### Large Shots

Decodes the Large Shots request payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 24.94 | 1063.94 | 42.65 |
| Size (B) | 71093 | 150297 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.20 | 557.07 | 34.39 |
| Size (B) | 17063 | 38403 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.04 | 611.70 | 38.14 |
| Size (B) | 11838 | 23256 | 1.96 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 1.91 | 71.48 | 37.41 |
| Size (B) | 236 | 603 | 2.56 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.03 | 103.59 | 50.92 |
| Size (B) | 509 | 1467 | 2.88 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 27.04 | 194.87 | 7.21 |
| Size (B) | 71085 | 150240 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 14.84 | 115.86 | 7.81 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 17.57 | 123.30 | 7.02 |
| Size (B) | 11828 | 23195 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.19 | 10.51 | 4.79 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.35 | 20.42 | 8.69 |
| Size (B) | 500 | 1407 | 2.81 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 66.62 | 493.88 | 7.41 |
| Size (B) | 71085 | 150178 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 40.26 | 267.77 | 6.65 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 52.08 | 282.01 | 5.41 |
| Size (B) | 11828 | 23095 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 9.76 | 40.31 | 4.13 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 7.82 | 53.92 | 6.90 |
| Size (B) | 500 | 1405 | 2.81 |


Raw CSV files:

- [results.csv](results.csv)
- [beam.csv](beam.csv)
- [js.csv](js.csv)
