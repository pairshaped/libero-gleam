#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK_DIR=$(mktemp -d)
REPORT_DIR="$ROOT_DIR/benchmarks"
RESULTS_MD="$WORK_DIR/results.md"

cleanup() {
  cd / >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$REPORT_DIR"
rm -f \
  "$REPORT_DIR/beam.csv" \
  "$REPORT_DIR/js.csv" \
  "$REPORT_DIR/results.csv" \
  "$REPORT_DIR/report.md"
cp -R "$ROOT_DIR/benchmarks/fixture_src/." "$WORK_DIR/"

cd "$WORK_DIR"
sed -i.bak "s|LIBERO_PATH|$ROOT_DIR|g" gleam.toml
rm -f gleam.toml.bak

echo "== Generating JSON transport =="
gleam run -m libero

CONTRACT_HASH=$(
  sed -n 's/.*"contract_hash":"\([^"]*\)".*/\1/p' \
    src/generated/libero/contract.json
)

if [ -z "$CONTRACT_HASH" ]; then
  echo "Could not read contract_hash from generated contract.json" >&2
  exit 1
fi

rm -f src/generated/libero/dispatch.gleam

echo "== Generating ETF transport helpers =="
gleam run -m generate_etf_bench

cp -R "$ROOT_DIR/benchmarks/runner_src/src/." "$WORK_DIR/src/"
sed -i.bak "s|CONTRACT_HASH|$CONTRACT_HASH|g" src/bench_runner.gleam
rm -f src/bench_runner.gleam.bak

gleam format src

echo "== Running BEAM benchmarks =="
gleam run -m bench_runner > "$REPORT_DIR/beam.csv"

rm -f \
  src/bench_runner.gleam \
  src/bench_etf_helpers.gleam \
  src/bench_etf_request_helpers.gleam \
  src/bench_etf_request_helpers_ffi.erl \
  src/bench_time_ffi.erl \
  src/generated@libero_atoms.erl \
  src/generated@libero_wire.erl

echo "== Running JavaScript benchmarks =="
gleam run --target javascript -m bench_js_runner > "$REPORT_DIR/js.csv"

{
  head -n 1 "$REPORT_DIR/beam.csv"
  tail -n +2 "$REPORT_DIR/beam.csv" | sort -t, -k3,3 -k4,4 -k2,2
  tail -n +2 "$REPORT_DIR/js.csv" | sort -t, -k3,3 -k4,4 -k2,2
} > "$REPORT_DIR/results.csv"

awk -F, '
  NR == 1 { next }
  {
    key = $1 "," $3 "," $4
    if (!(key in seen)) {
      seen[key] = 1
      keys[++key_count] = key
      target[key] = $1
      stage[key] = $3
      payload[key] = $4
    }
    iterations[key "," $2] = $5
    total_ns[key "," $2] = $6
    bytes[key "," $2] = $8
  }
  END {
    for (i = 1; i <= key_count; i += 1) {
      key = keys[i]
      json_key = key ",json"
      etf_key = key ",etf"
      group = target[key] "," stage[key]

      if (!(json_key in total_ns) || !(etf_key in total_ns)) {
        continue
      }

      if (group != previous_group) {
        print "### " target_label(target[key]) ": " stage_label(stage[key])
        print ""
        previous_group = group
      }

      print "#### " payload_label(payload[key])
      print ""
      print description(target[key], stage[key], payload[key], iterations[etf_key], iterations[json_key])
      print ""
      print "| Metric | ETF | JSON | Ratio |"
      print "|---|---:|---:|---:|"
      printf "| Time (ms) | %s | %s | %s |\n", ms(total_ns[etf_key]), ms(total_ns[json_key]), ratio(total_ns[json_key], total_ns[etf_key])
      printf "| Size (B) | %s | %s | %s |\n", bytes[etf_key], bytes[json_key], ratio(bytes[json_key], bytes[etf_key])
      print ""
    }
  }

  function description(target, stage, payload, etf_iterations, json_iterations) {
    if (json_iterations == etf_iterations) {
      return comparable_description(target, stage, payload) " " json_iterations " iterations per codec."
    }
    return comparable_description(target, stage, payload) " ETF " etf_iterations " iterations; JSON " json_iterations " iterations."
  }

  function comparable_description(target, stage, payload) {
    if (stage == "server_request_decode") {
      return "Decodes the " payload_label(payload) " request payload on " target_label(target) "."
    }
    if (stage == "server_response_encode") {
      return "Encodes the " payload_label(payload) " response payload on " target_label(target) "."
    }
    if (stage == "client_response_decode") {
      return "Decodes the " payload_label(payload) " response payload on " target_label(target) "."
    }
    return "Measures " stage_label(stage) " for " payload_label(payload) " on " target_label(target) "."
  }

  function target_label(value) {
    if (value == "beam") {
      return "BEAM"
    }
    if (value == "js") {
      return "JavaScript"
    }
    return value
  }

  function stage_label(value) {
    if (value == "server_request_decode") {
      return "Server Request Decode"
    }
    if (value == "server_response_encode") {
      return "Server Response Encode"
    }
    if (value == "client_response_decode") {
      return "Client Response Decode"
    }
    if (value == "client_response_parse_only") {
      return "JSON Parse Only"
    }
    if (value == "client_response_typed_decode") {
      return "JSON Typed Decode"
    }
    if (value == "client_response_wire_decode") {
      return "JSON Wire Decode"
    }
    return value
  }

  function payload_label(value) {
    if (value == "large_shots") {
      return "Large Shots"
    }
    if (value == "nested_game") {
      return "Nested Game"
    }
    if (value == "repeated_records") {
      return "Repeated Records"
    }
    if (value == "small_admin") {
      return "Small Admin"
    }
    if (value == "type_matrix") {
      return "Type Matrix"
    }
    return value
  }

  function ms(value) {
    if (value == "") {
      return ""
    }
    return sprintf("%.2f", value / 1000000)
  }

  function ratio(value, baseline, ratio_value) {
    if (value == "" || baseline == "") {
      return ""
    }
    ratio_value = value / baseline
    if (ratio_value == 1) {
      return "1"
    }
    return sprintf("%.2f", ratio_value)
  }
' "$REPORT_DIR/results.csv" > "$RESULTS_MD"

{
  echo "# Libero Transport Benchmark"
  echo
  echo "Contract hash: \`$CONTRACT_HASH\`"
  echo
  echo "Environment:"
  echo
  echo "- Date: \`$(date -u +"%Y-%m-%d")\`"
  echo "- Gleam: \`$(gleam --version)\`"
  echo "- Erlang: \`$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')\`"
  echo "- Node: \`$(node --version)\`"
  echo
  echo "Method:"
  echo
  echo "- Fixture project opts into JSON generation with \`use_json = true\` so the benchmark can compare JSON against Libero's default ETF transport."
  echo "- ETF helper modules were generated through Libero's public generator APIs so the benchmark can call \`generated@libero_wire\` without compiling the old ETF dispatch module."
  echo "- BEAM server encode rows include generated response helpers plus wire frame encoding."
  echo "- BEAM server request decode rows include wire request decode plus generated \`RequestMsg\` decode."
  echo "- JS client response decode rows include wire frame decode plus generated typed payload rebuild for JSON. ETF uses the generated decoder registration path."
  echo "- Each result subsection compares ETF and JSON for one target, stage, and payload. The \`Ratio\` column is JSON divided by ETF for the same metric."
  echo "- CSV files include additional diagnostic rows, such as JSON parse-only, JSON wire-decode-only, JSON typed-decode-only, BEAM \`etf_full_data_precheck\`, BEAM \`etf_strict_data_terms\`, and JS \`etf_depth_limit\` measurements. The Markdown report omits those rows because they are not the main ETF vs JSON comparison."
  echo "- Warmup: 50 untimed iterations per row."
  echo
  echo "## Results"
  echo
  cat "$RESULTS_MD"
  echo
  echo "Raw CSV files:"
  echo
  echo "- [results.csv](results.csv)"
  echo "- [beam.csv](beam.csv)"
  echo "- [js.csv](js.csv)"
} > "$REPORT_DIR/report.md"

echo "Wrote $REPORT_DIR/report.md"
