import bench_ffi
import gleam/float
import gleam/int

pub type BenchResult {
  BenchResult(
    target: String,
    codec: String,
    stage: String,
    payload: String,
    iterations: Int,
    total_ns: Int,
    ns_per_iter: Float,
    bytes: Int,
    checksum: Int,
  )
}

pub fn run(
  target target: String,
  codec codec: String,
  stage stage: String,
  payload payload: String,
  iterations iterations: Int,
  bytes bytes: Int,
  operation operation: fn() -> Int,
) -> BenchResult {
  warmup(operation, 50)
  let start = bench_ffi.now_ns()
  let checksum = loop(operation, iterations, 0)
  let total_ns = bench_ffi.now_ns() - start
  BenchResult(
    target:,
    codec:,
    stage:,
    payload:,
    iterations:,
    total_ns:,
    ns_per_iter: int.to_float(total_ns) /. int.to_float(iterations),
    bytes:,
    checksum:,
  )
}

pub fn csv_header() -> String {
  "target,codec,stage,payload,iterations,total_ns,ns_per_iter,bytes,checksum"
}

pub fn to_csv(result: BenchResult) -> String {
  result.target
  <> ","
  <> result.codec
  <> ","
  <> result.stage
  <> ","
  <> result.payload
  <> ","
  <> int.to_string(result.iterations)
  <> ","
  <> int.to_string(result.total_ns)
  <> ","
  <> float.to_string(result.ns_per_iter)
  <> ","
  <> int.to_string(result.bytes)
  <> ","
  <> int.to_string(result.checksum)
}

fn warmup(operation: fn() -> Int, remaining: Int) -> Nil {
  case remaining <= 0 {
    True -> Nil
    False -> {
      let _ = operation()
      warmup(operation, remaining - 1)
    }
  }
}

fn loop(operation: fn() -> Int, remaining: Int, checksum: Int) -> Int {
  case remaining <= 0 {
    True -> checksum
    False -> loop(operation, remaining - 1, checksum + operation())
  }
}
