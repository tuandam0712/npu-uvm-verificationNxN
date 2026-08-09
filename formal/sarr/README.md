# SARR formal

Run the bounded regression sequentially so SymbiYosys does not start every Z3
engine at once:

```bash
bash formal/sarr/run_sarr_formal.sh quick
```

Run the exact RTL parameters (`N=8`, `WIDTH=8`) with a per-task timeout:

```bash
bash formal/sarr/run_sarr_formal.sh 8x8
```

The quick profile uses `N=2`, `WIDTH=4`, and depth 8. It is intended for fast
regression of the parameterized routing, valid, reset, clear, and PE interface
properties. The 8x8 profile uses depth 4 for one-cycle invariant proofs and
depth 20 for cover reachability.

Both profiles use Z3 with SMT functions unrolled and incremental solving
disabled. This avoids the Z3 4.8.12 stall observed at step 0 with the default
SymbiYosys Z3 configuration.
