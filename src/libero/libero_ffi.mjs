let counter = 0;

export function uniqueId() {
  counter += 1;
  return Date.now().toString(36) + "-" + counter.toString(36);
}
