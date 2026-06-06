# Libero Transport Benchmark

Contract hash: `1f61b5216ac39d7be5faab0670b9c5713f9bbc007e447e2b9de9e108944f238b`

Environment:

- Date: `2026-06-06`
- Gleam: `gleam 1.16.0`
- Erlang: `27`
- Node: `v22.22.3`

Method:

- Fixture project generates artifacts from explicit Libero seeds, matching the current Rally-style API.
- The benchmark owns a tiny `bench_requests.RequestMsg` type so request decode can be measured without Libero handler scanning or generated dispatch.
- ETF helper modules were generated through Libero's public generator APIs so the benchmark can call `generated@libero_wire` without compiling any framework dispatch module.
- BEAM server encode rows include benchmark response pre-encoders plus wire frame encoding.
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
| Time (ms) | 76.04 | 3843.48 | 50.55 |
| Size (B) | 71103 | 150358 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 50.90 | 1923.54 | 37.79 |
| Size (B) | 17074 | 38458 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 47.26 | 2238.83 | 47.37 |
| Size (B) | 11846 | 23315 | 1.97 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 8.73 | 286.31 | 32.78 |
| Size (B) | 246 | 666 | 2.71 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 7.62 | 384.94 | 50.54 |
| Size (B) | 518 | 1526 | 2.95 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 41.78 | 936.87 | 22.42 |
| Size (B) | 71085 | 150243 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 27.04 | 380.86 | 14.09 |
| Size (B) | 17056 | 38344 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 29.43 | 509.65 | 17.32 |
| Size (B) | 11828 | 23198 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 5.30 | 30.20 | 5.70 |
| Size (B) | 228 | 551 | 2.42 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 4.74 | 44.28 | 9.34 |
| Size (B) | 500 | 1410 | 2.82 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 248.85 | 1967.71 | 7.91 |
| Size (B) | 71085 | 150181 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 173.49 | 1003.15 | 5.78 |
| Size (B) | 17056 | 38344 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 158.07 | 1169.32 | 7.40 |
| Size (B) | 11828 | 23098 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 38.30 | 167.38 | 4.37 |
| Size (B) | 228 | 551 | 2.42 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 25.85 | 247.80 | 9.59 |
| Size (B) | 500 | 1408 | 2.82 |


Raw CSV files:

- [results.csv](results.csv)
- [beam.csv](beam.csv)
- [js.csv](js.csv)
