# Libero Transport Benchmark

Contract hash: `48e037415fa01e87b6571d9c34cd351f512a58caf012171e8118eb57e1eeb111`

Environment:

- Date: `2026-06-04`
- Gleam: `gleam 1.17.0`
- Erlang: `29`
- Node: `v23.10.0`

Method:

- Fixture project opts into JSON generation with `use_json = true` so the benchmark can compare JSON against Libero's default ETF transport.
- ETF helper modules were generated through Libero's public generator APIs so the benchmark can call `generated@libero_wire` without compiling the old ETF dispatch module.
- BEAM server encode rows include generated response helpers plus wire frame encoding.
- BEAM server request decode rows include wire request decode plus generated `RequestMsg` decode.
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
| Time (ms) | 25.75 | 1071.32 | 41.60 |
| Size (B) | 71093 | 150297 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 17.25 | 563.34 | 32.65 |
| Size (B) | 17063 | 38403 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 15.84 | 627.43 | 39.62 |
| Size (B) | 11838 | 23256 | 1.96 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 1.93 | 74.28 | 38.44 |
| Size (B) | 236 | 603 | 2.56 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.04 | 102.33 | 50.05 |
| Size (B) | 509 | 1467 | 2.88 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 31.33 | 218.37 | 6.97 |
| Size (B) | 71085 | 150240 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 15.40 | 118.83 | 7.72 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 18.39 | 119.22 | 6.48 |
| Size (B) | 11828 | 23195 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.44 | 10.54 | 4.32 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.43 | 25.64 | 10.53 |
| Size (B) | 500 | 1407 | 2.81 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 67.96 | 499.91 | 7.36 |
| Size (B) | 71085 | 150178 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 40.61 | 262.60 | 6.47 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 51.66 | 290.92 | 5.63 |
| Size (B) | 11828 | 23095 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 10.58 | 41.24 | 3.90 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 8.81 | 54.64 | 6.20 |
| Size (B) | 500 | 1405 | 2.81 |


Raw CSV files:

- [results.csv](results.csv)
- [beam.csv](beam.csv)
- [js.csv](js.csv)
