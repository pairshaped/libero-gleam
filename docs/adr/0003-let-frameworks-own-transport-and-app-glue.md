# Let Frameworks Own Transport And App Glue

Status: accepted

Libero does not own application transport, routing, SSR composition, browser
lifecycle, reconnect behavior, request correlation, broadcast delivery, or app
state. Frameworks such as Rally may drive Libero directly with page-local type
seeds and then compose Libero-generated codecs with their own generated
framework glue.

## Consequences

Framework consumers can generate `src/generated/libero/**` for codec and
contract artifacts while generating their app-facing request, result, push,
hydration, and transport modules elsewhere.

Endpointless framework use is valid. When a framework supplies type seeds
directly and no Libero request endpoints, generated decoder modules should not
import a fake request module just to satisfy old standalone generator shape.
