# Validation and reproducibility

The public repository contains the game, original asset inputs, test source,
deterministic preparation scripts and concise acceptance summaries. Raw test
logs, machine-specific paths and generated run reports are not needed to edit or
play it and are deliberately kept out of the shared source tree.

The existing detailed reports remain preserved locally. Some historical parity
documents identify their filenames for the developer who has that workspace;
those filenames are not downloadable repository artifacts. Do not infer a
missing test result from a deliberately untracked log directory.

To create your own current evidence:

```sh
python3 scripts/prepare-native.py --godot /path/to/godot
bash scripts/verify-native.sh
bash scripts/verify-party.sh
```

For complete assisted CPU route matrices, add `--full` to the party launcher, or
use `--routes-only --world=1` through `--world=6`. It prints the location of its
local logs and source hashes. Save logs privately when diagnosing a failure;
remove environment paths, account details and unrelated information before
sharing a selected excerpt.

See `CURRENT_NATIVE_CHECKPOINT.md` for the current tested scope and limitations,
`NATIVE_PARTY_ACCEPTANCE.md` for per-world party coverage, and the corresponding
source suites for the precise assertions/assistance. Device rendering, physical
input, natural difficulty, final asset rights and release approval remain
separate from automated passing results.
