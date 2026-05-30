---
name: log-rca
description: >
  Analyze one or more Kubernetes node journal logs to identify PLEG relist lag,
  housekeeping overruns, and pod startup latency. When multiple files are given,
  produces a cross-node comparison table. Trigger: "analyze this log", "why is
  there a gap", "compare these logs", "/log-rca".
---

# Log RCA Skill

Analyze Kubernetes journal logs (`journal.folded.log` or similar) to diagnose
pod startup latency. When invoked with one or more log file paths as args, run
the analysis below on each file, then compare.

## Analysis steps per file

1. **Identify anchor pod** — if the user specifies timestamp fragments (e.g.
   `35.669260` and `52.403214`), grep for the matching lines to find the pod
   and container IDs under investigation. Otherwise focus on the pod(s) with
   the largest observed PLEG detection lag.

2. **Build pod lifecycle timeline** — grep for the target pod name and UID
   across all sources (kubelet, crio, systemd, kernel, ovs). Extract key
   milestones in timestamp order:
   - `SyncLoop ADD` (pod scheduled to node)
   - `RunPodSandbox` started / completed
   - crio `Creating container` / `Created container` / `Started container`
   - PLEG `ContainerStarted` events (one per container — pause + app)
   - `pod_startup_latency_tracker` final SLO measurement

3. **Measure PLEG detection lag** — for each container, compute:
   `PLEG event timestamp − crio "Started container" timestamp`
   This is the window where kubelet was blind to a running container.

4. **Find housekeeping overruns** — grep for `"Housekeeping took longer than
   expected"`. Extract `actual=` values and count occurrences per 5-second
   bucket to show when node pressure peaked.

5. **Find timestamp gaps in PLEG event stream** — extract all
   `SyncLoop (PLEG)` event timestamps, compute inter-event deltas. Gaps > 2s
   indicate a slow relist blocking the channel.

6. **Count concurrent pod activity** — count unique pods receiving
   `SyncLoop ADD`, `SyncLoop UPDATE`, or `ContainerStarted` events per second
   to show peak parallelism.

## Output format (single file)

```
## Timeline — <pod-name> (<node-hostname>)

| Timestamp | Source | Event |
|-----------|--------|-------|
| ...       | ...    | ...   |

## PLEG detection lag
- pause container (ID): Xs
- app container (ID): Xs  ← primary delay

## Housekeeping overruns
N overruns detected. Peak: Xs at HH:MM:SS. Bucket summary:
  HH:MM:3X–4X: N overruns (max Xs)
  ...

## PLEG relist gaps > 2s
  HH:MM:SS → HH:MM:SS : Xs gap

## Peak pod concurrency
  HH:MM:SS : N pods active simultaneously

## Root cause
<one paragraph>

## Recommended fix
<one paragraph>
```

## Output format (multi-file comparison)

After per-file sections, add:

```
## Cross-node comparison

| Node | PLEG lag (app container) | HK overruns | Peak HK actual | Peak pod concurrency | Pod SLO p50 |
|------|--------------------------|-------------|----------------|----------------------|-------------|
| ... | ...                      | ...         | ...            | ...                  | ...         |

## Which node was faster and why
<paragraph comparing the nodes>
```

## Key patterns to recognize

- **PLEG relist saturation**: crio starts container at T1, PLEG fires
  `ContainerStarted` at T2 >> T1. Caused by `ListContainers` CRI call
  blocking under high pod density. Fix: Evented PLEG (KEP-3386).
- **CNI serialization**: sandbox creation times > 3s, or large gaps between
  `RunPodSandbox started` and `Ran pod sandbox`. Multus adds latency per pod.
- **Image pull**: `totalImagesPullingTime` > 0 in latency tracker output.
- **Volume mount lag**: gap between `MountVolume started` and `SetUp succeeded`.
- **Housekeeping snowball**: overruns grow over time (1s → 1.5s → 2s) indicating
  compounding pressure, not a one-off spike.

## Notes

- `{{{` / `}}}` markers in folded logs are fold delimiters, not log content.
- crio timestamps use ISO8601; kubelet uses `MMDD HH:MM:SS.ffffff`. Convert
  before comparing.
- The sandbox container ID appears as both the `Data` field in the first PLEG
  `ContainerStarted` event AND as the `sandboxID` in crio `StartContainer`
  lines. The app container ID appears in the second PLEG event.
- `pod_startup_latency_tracker` `watchObservedRunningTime` is the wall-clock
  SLO endpoint; `observedRunningTime` is when kubelet first saw the container
  running internally.
