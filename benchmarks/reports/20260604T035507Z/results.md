### BEAM: Server Request Decode

#### Large Shots

Decodes the Large Shots request payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 25.58 | 1064.59 | 41.62 |
| Size (B) | 71093 | 150297 | 2.11 |

#### Nested Game

Decodes the Nested Game request payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.25 | 615.53 | 37.89 |
| Size (B) | 17063 | 38403 | 2.25 |

#### Repeated Records

Decodes the Repeated Records request payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 16.14 | 636.67 | 39.45 |
| Size (B) | 11838 | 23256 | 1.96 |

#### Small Admin

Decodes the Small Admin request payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 1.93 | 71.38 | 36.94 |
| Size (B) | 236 | 603 | 2.56 |

#### Type Matrix

Decodes the Type Matrix request payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.04 | 101.44 | 49.78 |
| Size (B) | 509 | 1467 | 2.88 |

### BEAM: Server Response Encode

#### Large Shots

Encodes the Large Shots response payload on BEAM. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 26.18 | 203.74 | 7.78 |
| Size (B) | 71085 | 150240 | 2.11 |

#### Nested Game

Encodes the Nested Game response payload on BEAM. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 15.52 | 123.22 | 7.94 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Encodes the Repeated Records response payload on BEAM. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 18.42 | 117.48 | 6.38 |
| Size (B) | 11828 | 23195 | 1.96 |

#### Small Admin

Encodes the Small Admin response payload on BEAM. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.61 | 10.53 | 4.03 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Encodes the Type Matrix response payload on BEAM. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 2.40 | 20.53 | 8.54 |
| Size (B) | 500 | 1407 | 2.81 |

### JavaScript: Client Response Decode

#### Large Shots

Decodes the Large Shots response payload on JavaScript. 250 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 68.31 | 509.96 | 7.47 |
| Size (B) | 71085 | 150178 | 2.11 |

#### Nested Game

Decodes the Nested Game response payload on JavaScript. 500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 42.80 | 296.05 | 6.92 |
| Size (B) | 17056 | 38341 | 2.25 |

#### Repeated Records

Decodes the Repeated Records response payload on JavaScript. 1000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 59.86 | 291.57 | 4.87 |
| Size (B) | 11828 | 23095 | 1.95 |

#### Small Admin

Decodes the Small Admin response payload on JavaScript. 5000 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 9.94 | 41.16 | 4.14 |
| Size (B) | 228 | 548 | 2.40 |

#### Type Matrix

Decodes the Type Matrix response payload on JavaScript. 2500 iterations per codec.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) | 7.83 | 55.92 | 7.14 |
| Size (B) | 500 | 1405 | 2.81 |

### JavaScript: JSON Parse Only

#### Large Shots

Parses the Large Shots JSON response without wire validation or typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 105.55 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Parses the Nested Game JSON response without wire validation or typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 89.27 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Parses the Repeated Records JSON response without wire validation or typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 55.73 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Parses the Small Admin JSON response without wire validation or typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 8.46 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Parses the Type Matrix JSON response without wire validation or typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 10.22 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Typed Decode

#### Large Shots

Rebuilds the Large Shots typed value from an already extracted JSON response value. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 348.22 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Rebuilds the Nested Game typed value from an already extracted JSON response value. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 196.42 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Rebuilds the Repeated Records typed value from an already extracted JSON response value. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 198.87 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Rebuilds the Small Admin typed value from an already extracted JSON response value. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 28.75 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Rebuilds the Type Matrix typed value from an already extracted JSON response value. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 39.29 |  |
| Size (B) |  | 1405 |  |

### JavaScript: JSON Wire Decode

#### Large Shots

Decodes the Large Shots JSON response frame without typed rebuild. 250 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 206.25 |  |
| Size (B) |  | 150178 |  |

#### Nested Game

Decodes the Nested Game JSON response frame without typed rebuild. 500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 109.89 |  |
| Size (B) |  | 38341 |  |

#### Repeated Records

Decodes the Repeated Records JSON response frame without typed rebuild. 1000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 90.19 |  |
| Size (B) |  | 23095 |  |

#### Small Admin

Decodes the Small Admin JSON response frame without typed rebuild. 5000 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 14.60 |  |
| Size (B) |  | 548 |  |

#### Type Matrix

Decodes the Type Matrix JSON response frame without typed rebuild. 2500 JSON iterations. No matching ETF stage.

| Metric | ETF | JSON | Ratio |
|---|---:|---:|---:|
| Time (ms) |  | 16.50 |  |
| Size (B) |  | 1405 |  |
