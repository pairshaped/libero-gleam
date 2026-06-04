### BEAM: Server Request Decode

#### Large Shots

Decodes the Large Shots request payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 25.46 | 1090.57 | 42.83 |
| Size (B) | 71093 | 150297 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.20 | 557.24 | 34.41 |
| Size (B) | 17063 | 38403 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.13 | 615.80 | 38.17 |
| Size (B) | 11838 | 23256 | 1.96 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 1.88 | 71.28 | 37.99 |
| Size (B) | 236 | 603 | 2.56 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 1.99 | 101.65 | 51.03 |
| Size (B) | 509 | 1467 | 2.88 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 26.56 | 203.92 | 7.68 |
| Size (B) | 71085 | 150240 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 15.12 | 120.98 | 8.00 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 17.82 | 117.05 | 6.57 |
| Size (B) | 11828 | 23195 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.49 | 10.89 | 4.38 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.39 | 19.96 | 8.35 |
| Size (B) | 500 | 1407 | 2.81 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 81.21 | 551.36 | 6.79 |
| Size (B) | 71085 | 150178 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 41.63 | 269.62 | 6.48 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 52.53 | 289.42 | 5.51 |
| Size (B) | 11828 | 23095 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 9.52 | 41.29 | 4.34 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 7.63 | 52.66 | 6.90 |
| Size (B) | 500 | 1405 | 2.81 |

### JavaScript: JSON Parse Only

#### Large Shots

Parses the Large Shots JSON response without wire validation or typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 96.23 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Parses the Nested Game JSON response without wire validation or typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 54.56 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Parses the Repeated Records JSON response without wire validation or typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 56.38 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Parses the Small Admin JSON response without wire validation or typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 8.43 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Parses the Type Matrix JSON response without wire validation or typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 11.84 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Typed Decode

#### Large Shots

Rebuilds the Large Shots typed value from an already extracted JSON response value. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 342.85 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Rebuilds the Nested Game typed value from an already extracted JSON response value. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 182.68 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Rebuilds the Repeated Records typed value from an already extracted JSON response value. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 195.95 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Rebuilds the Small Admin typed value from an already extracted JSON response value. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 28.22 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Rebuilds the Type Matrix typed value from an already extracted JSON response value. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 38.64 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Wire Decode

#### Large Shots

Decodes the Large Shots JSON response frame without typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 179.61 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Decodes the Nested Game JSON response frame without typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 102.56 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Decodes the Repeated Records JSON response frame without typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 90.95 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Decodes the Small Admin JSON response frame without typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 14.55 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Decodes the Type Matrix JSON response frame without typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 17.46 |  |
| Size (B) |  | 1405 |  |
