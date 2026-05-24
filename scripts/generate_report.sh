#!/bin/bash
# Produce the final reproducibility-complete reports:
#   summary/report.md           — human-readable, with metadata footer
#   summary/analysis.json       — per-(compiler,param) stats (machine-readable)
#   summary/thesis_snippet.typ  — paste-ready Typst tables (compile-time +
#                                 memory) mirroring the existing appendix
#                                 tables in source.md.

set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"
mkdir -p summary
PY="${PYTHON:-python3}"

"${PY}" - <<'PY'
import csv, json, os, sys
from datetime import datetime

try:
    import numpy as np
except ImportError:
    sys.stderr.write("ERROR: numpy missing. Run 'make venv'.\n")
    sys.exit(1)

META = "summary/metadata.json"
CSV  = "summary/combined_results.csv"
REPORT_MD     = "summary/report.md"
ANALYSIS_JSON = "summary/analysis.json"
SNIPPET_TYP   = "summary/thesis_snippet.typ"

with open(META) as f:
    meta = json.load(f)

# Per-(compiler, param_count) → list of (status, time, rss)
buckets = {}  # (compiler, param) -> {"runs": [(status, time, rss), ...]}
with open(CSV) as f:
    r = csv.DictReader(f)
    for row in r:
        c = row["compiler"]; p = int(row["param_count"])
        t = row["compilation_time_seconds"]
        m = row["peak_rss_kb"]
        def fnum(v):
            if v in (None, "", "null"): return None
            try: return float(v)
            except ValueError: return None
        buckets.setdefault((c, p), {"runs": []})["runs"].append(
            (row["status"], fnum(t), fnum(m))
        )

compilers = meta["config"]["compilers"]
pmin = meta["config"]["param_min"]
pmax = meta["config"]["param_max"]

def cell_summary(runs):
    """Return dict with status, n, mean_time, std_time, mean_rss, std_rss."""
    successes = [(t, m) for st, t, m in runs if st == "SUCCESS" and t is not None]
    n = len(successes)
    if not runs:
        return {"status_label": "—", "n": 0}
    # If any run succeeded, report the success statistics
    if n >= 1:
        ts = np.array([t for t, _ in successes], dtype=float)
        ms = np.array([m for _, m in successes if m is not None], dtype=float)
        out = {
            "status_label": "SUCCESS" if n == len(runs) else f"PARTIAL ({n}/{len(runs)})",
            "n": int(n),
            "mean_time": float(ts.mean()),
            "std_time":  float(ts.std(ddof=1)) if n >= 2 else 0.0,
            "min_time":  float(ts.min()),
            "max_time":  float(ts.max()),
        }
        if ms.size:
            out["mean_rss_kb"] = float(ms.mean())
            out["std_rss_kb"]  = float(ms.std(ddof=1)) if ms.size >= 2 else 0.0
            out["min_rss_kb"]  = float(ms.min())
            out["max_rss_kb"]  = float(ms.max())
        return out
    # No successes — report the failure mode that dominated
    statuses = [st for st, _, _ in runs]
    if statuses.count("TIMEOUT") >= statuses.count("OOM"):
        label = "TIME OUT"
    else:
        label = "OUT OF MEM."
    if "ERROR" in statuses and label not in statuses:
        label = "ERROR"
    return {"status_label": label, "n": 0,
            "n_attempted": len(runs),
            "breakdown": dict((s, statuses.count(s)) for s in set(statuses))}

table = {}
for c in compilers:
    for p in range(pmin, pmax + 1):
        runs = buckets.get((c, p), {"runs": []})["runs"]
        table[(c, p)] = cell_summary(runs)

with open(ANALYSIS_JSON, "w") as f:
    json.dump({"per_cell": {f"{c}/{p}": v for (c, p), v in table.items()},
               "config":   meta["config"],
               "compilers": meta["compilers"],
               "stdlib":    meta["stdlib"]}, f, indent=2, sort_keys=True)

# --------------------------- Markdown report --------------------------------
out = []; w = out.append
w("# Parameter Scalability Benchmark — Report")
w("")
w(f"_Generated: {datetime.now().isoformat(timespec='seconds')}_")
w("")
w("## Compilation time (seconds)")
w("")
hdr = ["Params"] + [f"{c} mean" for c in compilers] + [f"{c} std" for c in compilers]
w("| " + " | ".join(hdr) + " |")
w("|" + "|".join("---" for _ in hdr) + "|")
for p in range(pmin, pmax + 1):
    row = [str(p)]
    for c in compilers:
        s = table[(c, p)]
        row.append(f"{s['mean_time']:.3f}" if "mean_time" in s else s["status_label"])
    for c in compilers:
        s = table[(c, p)]
        row.append(f"{s['std_time']:.3f}" if "std_time" in s else "—")
    w("| " + " | ".join(row) + " |")
w("")

w("## Peak resident-set memory (MB; via /usr/bin/time -v)")
w("")
hdr = ["Params"] + [f"{c} mean (MB)" for c in compilers] + [f"{c} max (MB)" for c in compilers]
w("| " + " | ".join(hdr) + " |")
w("|" + "|".join("---" for _ in hdr) + "|")
for p in range(pmin, pmax + 1):
    row = [str(p)]
    for c in compilers:
        s = table[(c, p)]
        row.append(f"{s['mean_rss_kb']/1024.0:.2f}" if "mean_rss_kb" in s else s["status_label"])
    for c in compilers:
        s = table[(c, p)]
        row.append(f"{s['max_rss_kb']/1024.0:.2f}" if "max_rss_kb" in s else "—")
    w("| " + " | ".join(row) + " |")
w("")

# Identify the OOM/TIMEOUT thresholds
threshold = {}
for c in compilers:
    for p in range(pmin, pmax + 1):
        s = table[(c, p)]
        if s.get("n", 0) == 0 and s["status_label"] not in ("—",):
            threshold.setdefault(c, p)  # first failed param
w("## Failure thresholds")
w("")
if not threshold:
    w("- No compiler hit a failure threshold within the tested range.")
else:
    for c, p in threshold.items():
        w(f"- `{c}` first hit a non-SUCCESS state at **param = {p}** (`{table[(c,p)]['status_label']}`).")
w("")

# Reproducibility footer
slurm  = meta.get("slurm", {})
hw     = meta.get("hardware", {})
cfg    = meta.get("config", {})
stdlib = meta.get("stdlib", {})
w("## Reproducibility metadata")
w("")
w("### SLURM")
w("")
for k, label in [("partition","Partition"), ("account","Account"),
                  ("cpus_per_task","CPUs per task"),
                  ("mem_requested","Memory requested"),
                  ("timelimit_requested","Wall-clock cap")]:
    v = slurm.get(k, "")
    if v: w(f"- {label}: `{v}`")
nodes = hw.get("nodes_used", [])
if nodes:
    w(f"- Node(s) used: {', '.join(f'`{n}`' for n in nodes)}")
w(f"- Per-compilation wall-clock cap: `{cfg.get('run_timeout_seconds','?')} s`")
w(f"- Per-compilation virtual-memory cap: `{cfg.get('run_vmem_limit_kb','?')} KB` (ulimit -v)")
w(f"- Short-circuit threshold: `{cfg.get('shortcircuit_after','?')}` consecutive failures")
w("")

w("### Host environment")
w("")
for k, label in [("cpu_model","CPU"),
                  ("total_memory_kb","Total memory (kB)"),
                  ("kernel","Kernel"),
                  ("os_release","OS"),
                  ("gcc_version","GCC")]:
    v = hw.get(k, "")
    if v: w(f"- {label}: `{v}`")
w("")

w("### Compilers")
w("")
for c in compilers:
    cinfo = meta.get("compilers", {}).get(c, {})
    w(f"#### `{c}`")
    w("")
    w(f"- Path: `{cinfo.get('sac2c_path','')}`")
    w(f"- Commit: `{cinfo.get('sac2c_commit','') or '(no .git found)'}`")
    w(f"- Branch: `{cinfo.get('sac2c_branch','')}`")
    w(f"- `git describe`: `{cinfo.get('sac2c_describe','')}`")
    w(f"- Pre-built Stdlib: `{cinfo.get('stdlib_build','')}`")
    ver = (cinfo.get('sac2c_version_raw','') or '').replace('|', ' / ')
    if ver:
        w(f"- `sac2c -V`: {ver}")
    w("")

w("### Stdlib")
w("")
w(f"- Path: `{stdlib.get('src_path','')}`")
w(f"- Commit: `{stdlib.get('commit','') or '(no .git found)'}`")
w(f"- Branch: `{stdlib.get('branch','')}`")
w("")

w("### Benchmark configuration")
w("")
w(f"- Compilers: `{' '.join(cfg.get('compilers', []))}`")
w(f"- Param range: `{cfg.get('param_min','?')}` to `{cfg.get('param_max','?')}` inclusive")
w(f"- Runs per (compiler, param): `{cfg.get('runs_per_param','')}`")
w(f"- Measurement: wall-clock via `date +%s.%N` around `timeout … ulimit -v … sac2c …`; peak RSS via GNU `/usr/bin/time -v`.")
w("")

if meta.get("warnings"):
    w("### Warnings emitted during collection")
    w("")
    for warn in meta["warnings"]:
        w(f"- {warn}")
    w("")

w(f"_Started: {meta.get('started_at','?')} — Finished: {meta.get('finished_at','?')}_")
w("")
w("Source data: `summary/combined_results.csv` (one row per individual compilation), "
  "`summary/all_runs.json` (full per-task records), `summary/metadata.json` (this footer).")

with open(REPORT_MD, "w") as f:
    f.write("\n".join(out))

# --------------------- Thesis-ready Typst snippets --------------------------
def fmt_time(s):
    if "mean_time" in s: return f"{s['mean_time']:.3f}"
    return s["status_label"]
def fmt_rss(s):
    if "mean_rss_kb" in s: return f"{s['mean_rss_kb']/1024.0:.2f}"
    return s["status_label"]
def fmt_std_time(s):
    if "std_time" in s and s["std_time"] > 0: return f"{s['std_time']:.3f}"
    return "—"
def fmt_std_rss(s):
    if "std_rss_kb" in s and s["std_rss_kb"] > 0: return f"{s['std_rss_kb']/1024.0:.2f}"
    return "—"

snippet = []
sw = snippet.append
sw("// Auto-generated by param-bench/scripts/generate_report.sh")
sw("// Paste into the thesis appendix; update caption wording if needed.")
sw("")
sw("// ----- Compilation time table (analogue of L1704-1737 in source.md) -----")
sw("#figure(")
sw("  table(")
sw("    columns: 5,")
sw("    align: (center, center, center, center, center),")
sw("    table.header(")
sw("      [Params], [Mod. Avg (s)], [Mod. SD], [Base. Avg (s)], [Base. SD]")
sw("    ),")
for p in range(pmin, pmax + 1):
    new = table[("new",  p)] if ("new",  p) in table else {"status_label":"—"}
    org = table[("orig", p)] if ("orig", p) in table else {"status_label":"—"}
    sw(f"    [{p}], [{fmt_time(new)}], [{fmt_std_time(new)}], [{fmt_time(org)}], [{fmt_std_time(org)}],")
sw("  ),")
nodes_str = ", ".join(nodes) if nodes else "the SLURM node listed in @hardware"
sw(f"  caption: [Parameter-benchmark compilation time (seconds) on {nodes_str}, ")
sw(f"           N={cfg.get('runs_per_param','?')} runs per (compiler, param) cell, ")
sw(f"           per-compilation wall-clock cap {cfg.get('run_timeout_seconds','?')} s, ")
sw(f"           per-compilation virtual-memory cap {cfg.get('run_vmem_limit_kb','?')} KB. ")
sw(f"           `TIME OUT` = wall-clock cap hit; `OUT OF MEM.` = ulimit -v hit. ")
sw(f"           Modified compiler commit `{(meta.get('compilers',{}).get('new',{}).get('sac2c_commit','') or '?')[:12]}`; ")
sw(f"           baseline commit `{(meta.get('compilers',{}).get('orig',{}).get('sac2c_commit','') or '?')[:12]}`; ")
sw(f"           Stdlib commit `{(stdlib.get('commit','') or '?')[:12]}`.],")
sw(") <compilation-time-table>")
sw("")
sw("// ----- Memory usage table (analogue of L1738-1770 in source.md) -----")
sw("#figure(")
sw("  table(")
sw("    columns: 5,")
sw("    align: (center, center, center, center, center),")
sw("    table.header(")
sw("      [Params], [Mod. Avg (MB)], [Mod. SD], [Base. Avg (MB)], [Base. SD]")
sw("    ),")
for p in range(pmin, pmax + 1):
    new = table[("new",  p)] if ("new",  p) in table else {"status_label":"—"}
    org = table[("orig", p)] if ("orig", p) in table else {"status_label":"—"}
    sw(f"    [{p}], [{fmt_rss(new)}], [{fmt_std_rss(new)}], [{fmt_rss(org)}], [{fmt_std_rss(org)}],")
sw("  ),")
sw(f"  caption: [Parameter-benchmark peak resident-set memory (MB; via `/usr/bin/time -v`) ")
sw(f"           on {nodes_str}, N={cfg.get('runs_per_param','?')} runs per cell. ")
sw(f"           `TIME OUT` and `OUT OF MEM.` carry the same meaning as in @compilation-time-table.],")
sw(") <memory-usage-table>")
sw("")

with open(SNIPPET_TYP, "w") as f:
    f.write("\n".join(snippet) + "\n")

print(f"wrote {REPORT_MD}")
print(f"wrote {ANALYSIS_JSON}")
print(f"wrote {SNIPPET_TYP}")
PY
