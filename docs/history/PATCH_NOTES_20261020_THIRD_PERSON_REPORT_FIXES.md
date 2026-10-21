# Third Person report fixes — Steam update, 2026-10-20

Pack: `cd49f1f6b03923cfdbc1f6d03aa2da29`; Workshop item `3822187184`. Built through RPFM; 499 offline tests passed; charge and aiming pose verified live. Flamethrower visual probes are excluded.

## Patch notes

```text
[list]
[*]Fixed forced sprint animations interrupting native charges for large single entities.
[*]Corrected ranged aiming poses to use each projectile's gravity, including Irondrakes.
[*]Removed a Windows-only address restriction that could prevent keyboard and mouse input from initializing under Wine/Proton.
[*]Input initialization failures now show their own message instead of incorrectly reporting that memreader Plus is missing.
[/list]
Known issue: the upward Irondrake flame visual remains under investigation. Its projectile damage travels forward. The Wine/Proton detection change passed simulated address-layout tests; real Proton testing is still pending.
```

Published 2026-10-20 **17:33 Manila time**. Steam upload finished **OK**, manifest **3023342121841813751**. Steam query returned updated timestamp `1792488791`; the public changelog was fetched and the exact note text verified. Local Workshop pack remains `cd49f1f6b03923cfdbc1f6d03aa2da29`. Evidence: Backup `steam_publish_result.json`, `steam_changelog.html`, and Steam `logs/workshop_log.txt`. Content and change note only; title, description, preview and tags were not changed.
