export function now_ns() {
  return Math.floor(performance.now() * 1_000_000);
}
