// Custom resolver that maps gleam_stdlib and compiled-Gleam imports
// to the local shim when loading src/libero/json/wire_ffi.mjs.

const dir = new URL(".", import.meta.url).href;

export function resolve(specifier, context, nextResolve) {
  if (specifier.includes("gleam_stdlib/gleam.mjs")) {
    return { url: dir + "json_wire_shim.mjs", shortCircuit: true };
  }

  if (specifier.includes("gleam_stdlib/gleam/option.mjs")) {
    return { url: dir + "json_wire_shim_option.mjs", shortCircuit: true };
  }

  if (specifier.endsWith("/frame.mjs") && context.parentURL?.includes("json/wire_ffi.mjs")) {
    return { url: dir + "json_wire_shim_frame.mjs", shortCircuit: true };
  }

  if (specifier === "./error.mjs" && context.parentURL?.includes("json/wire_ffi.mjs")) {
    return { url: dir + "json_wire_shim_error.mjs", shortCircuit: true };
  }

  return nextResolve(specifier, context);
}
