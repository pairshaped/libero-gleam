### BEAM: Server Request Decode

#### Large Shots

Decodes the Large Shots request payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 27.84 | 1229.78 | 44.17 |
| Size (B) | 71093 | 150297 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.12 | 550.00 | 34.13 |
| Size (B) | 17063 | 38403 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 15.55 | 644.47 | 41.46 |
| Size (B) | 11838 | 23256 | 1.96 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 1.83 | 71.93 | 39.40 |
| Size (B) | 236 | 603 | 2.56 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.09 | 101.67 | 48.76 |
| Size (B) | 509 | 1467 | 2.88 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 26.54 | 197.57 | 7.44 |
| Size (B) | 71085 | 150240 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 14.99 | 116.62 | 7.78 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 18.43 | 121.31 | 6.58 |
| Size (B) | 11828 | 23195 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.52 | 10.68 | 4.23 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.36 | 20.28 | 8.59 |
| Size (B) | 500 | 1407 | 2.81 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 68.96 | 489.96 | 7.10 |
| Size (B) | 71085 | 150178 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 40.75 | 264.59 | 6.49 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 51.21 | 284.97 | 5.56 |
| Size (B) | 11828 | 23095 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 9.92 | 41.50 | 4.18 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 7.65 | 54.10 | 7.07 |
| Size (B) | 500 | 1405 | 2.81 |

### JavaScript: JSON Parse Only

#### Large Shots

Parses the Large Shots JSON response without wire validation or typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 97.31 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Parses the Nested Game JSON response without wire validation or typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 54.99 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Parses the Repeated Records JSON response without wire validation or typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 57.58 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Parses the Small Admin JSON response without wire validation or typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 8.82 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Parses the Type Matrix JSON response without wire validation or typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 10.17 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Typed Decode

#### Large Shots

Rebuilds the Large Shots typed value from an already extracted JSON response value. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 340.02 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Rebuilds the Nested Game typed value from an already extracted JSON response value. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 178.75 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Rebuilds the Repeated Records typed value from an already extracted JSON response value. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 198.01 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Rebuilds the Small Admin typed value from an already extracted JSON response value. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 28.59 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Rebuilds the Type Matrix typed value from an already extracted JSON response value. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 39.56 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Wire Decode

#### Large Shots

Decodes the Large Shots JSON response frame without typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 183.92 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Decodes the Nested Game JSON response frame without typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 102.17 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Decodes the Repeated Records JSON response frame without typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 92.25 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Decodes the Small Admin JSON response frame without typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 14.96 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Decodes the Type Matrix JSON response frame without typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 17.37 |  |
| Size (B) |  | 1405 |  |
