---
# libero-05zr
title: Document libero ETF threat model in README
status: todo
type: task
priority: normal
tags:
    - security
    - docs
created_at: 2026-05-08T15:14:55Z
updated_at: 2026-05-08T16:22:01Z
---

Add a Security/Threat Model section to libero's README (or a SECURITY.md) that documents:

1. Why ETF over JSON: type fidelity (Float vs Int, BitArray, Atom-as-tagged-variant) matters for our typed RPC pipeline.

2. Trust assumptions:
   - Authenticated user (cookie/session) is required upstream of the WS handler
   - Browser environment is treated as adversarial despite serving our own JS (devtools, XSS, browser extensions, MITM if HTTPS broken)

3. Defenses in order:
   - mist frame size limit (transport layer)
   - binary_to_term(Bin, [safe]) blocks atom creation and function deserialisation
   - rpc_atoms:ensure() pre-registers all known atoms at boot
   - Resource caps (collection length, nesting depth) on both ends
   - Non-executable term validator post-decode
   - Typed dispatch decoder verifies tagged-tuple shape against a known handler before invoking

4. What ETF guidance from https://security.erlef.org/secure_coding_and_deployment_hardening/serialisation.html says NOT to do (use ETF with untrusted parties), and how we justify doing it anyway (deliberate construction of the defenses listed above).

5. What kind of changes would weaken the model — so future contributors don't accidentally weaken it.



---
**See also:** [`docs/wire-type-identity.md`](../docs/wire-type-identity.md). This README should gain a namespace-gap section describing why ETF needs the codegen-level workaround for type identity. See the spec's "Security relationship" section for the language to fold in.
