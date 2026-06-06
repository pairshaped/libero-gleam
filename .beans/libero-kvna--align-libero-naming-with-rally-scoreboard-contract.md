---
# libero-kvna
title: Align Libero naming with Rally Scoreboard contract language
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T20:00:00Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Libero docs and generated artifact language now describe the supported Rally
shape:

- Framework-owned seeds.
- Framework-owned app protocol modules.
- Libero-owned `decoders`, `contract.json`, `generated@libero_wire`,
  `generated@libero_atoms`, ETF facade, JSON codecs, and `TransportError`.

Canonical test artifacts no longer use legacy request-message names for
standalone generated dispatch. Rally-generated names live under Rally's own
generated modules.
