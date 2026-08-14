# Ticket 04 code-quality review

- Reviewed range: `15adcf4522930c50e5ee78c7e9dd4ef53c3f4a86..eed8936b698412aa5595ec775119dcfe0d7882ab`
- Reviewed HEAD: `eed8936b698412aa5595ec775119dcfe0d7882ab`
- Scope: durable routine-draft editing, revision/save/delete command receipts, migration, and iOS editor integration.
- Result: **BLOCK / REQUEST_CHANGES**

## Skill-perspective check

Ran before judging tests and maintainability: `omo:programming` and `omo:remove-ai-slops`.

- `programming`: violates the required async-correct/serial-boundary perspective. A process-local `NSRecursiveLock` plus separate `open`/`save` operations is not a transaction across `AppRuntime` instances; stale writers can replace a newer root state.
- `remove-ai-slops`: no deletion-only test or prose/prompt test was added. However, the migration test below is a tautological current-format round trip, and the new production flow adds unneeded state-root replacement risk rather than a bounded persistence primitive.

## Findings

### CRITICAL

None.

### HIGH

1. **Discard is a stale cached-root destructive write.**  
   `Sources/UmjjilRunningCore/AppRuntimeRoutineEditing.swift:109-139`

   Unlike save/delete, `discardRoutineDraft` never calls `refreshDurableStateForEditing()`. A second runtime can change settings, current routine, or a durable draft after this editor began. The stale runtime then builds `next` from its cached `state`, nils `routineDraft`, and calls `storage.save(next)`, replacing the whole root and silently rolling back the newer fields. This violates the persistence contract that only the draft is discarded and that destructive actions preserve unrelated durable state. Refreshing before the write is a minimum mitigation; correctness requires an atomic conditional mutation/compare-and-swap at the storage seam so the state cannot change between refresh and commit.

2. **Save/delete remain TOCTOU races despite preflight refresh; atomic file replacement is not an atomic read-modify-write transaction.**  
   `Sources/UmjjilRunningCore/AppRuntimeRoutineEditing.swift:68-105, 146-172`  
   `Sources/UmjjilRunningCore/AppRuntimeRoutineEditingSupport.swift:4-15, 64-77`  
   `Sources/UmjjilRunningCore/AppRuntimeStorage.swift:213-237`

   `flushRoutineDraft` opens state, then `saveRoutineDraft`/`deleteCurrent` validates it and later writes a complete root. Two `AppRuntime`s can both read the same base revision, both validate, and each atomically replace the JSON; the latter write wins, losing the former command receipt/current routine/settings change. The per-runtime lock and `Data.WritingOptions.atomic` protect neither inter-runtime ordering nor the validation-to-save gap. Introduce a storage-owned serial transaction/CAS keyed by root generation (and make all routine mutations execute inside it), then add deterministic barrier tests for save-vs-save, delete-vs-save, and discard-vs-settings/draft interleavings.

### MEDIUM

1. **The claimed v4 migration test does not decode a v4 payload.**  
   `Tests/UmjjilRunningCoreTests/RoutineDraftEditingTests.swift:226-233`

   It encodes the current `RuntimeStoreState`, whose encoder writes `routineCommandReceipts`, then decodes it. Therefore it cannot fail if the new decoder default for a missing `routineCommandReceipts` field breaks. Use a fixture/envelope produced by schema v4 (without both new keys) and exercise `FileAppRuntimeStorage.open()` migration; retain assertions that existing fields survive.

2. **Tests cover serialized stale cases, not the actual concurrent mutation race.**  
   `Tests/UmjjilRunningCoreTests/RoutineDraftEditingTests.swift:109-145, 191-227`

   The tests sequence two runtimes so the later caller refreshes after the first finishes. They never force two writers to pass `open()` before either reaches `save()`, and no test covers discard against a newly persisted root. This gives false confidence for the exact race above. Add a controllable storage barrier plus observable assertions for preservation of the winning root and command receipts.

### LOW

None.

## Verification independently run

- `swift build --target UmjjilRunningCore` — passed.
- `swift run UmjjilRunningCoreChecks` — 7/7 passed.
- `swift run UmjjilRunningAppleChecks` — 6/6 passed.
- `swift test` — 79 tests passed.
- `git diff --check baseline HEAD` — passed.
- Worktree status was clean; no generated Xcode project was present, so the iOS app source was not separately Xcode-built. Swift Package verification does not compile `Apps/iOS`.
- Pure LOC: changed production files are within 250 pure LOC (`AppRuntimeRoutineEditing` 171, support 120, `RoutineDraftEditing` 129, `RoutineBuilderView` 233, `UmjjilApp` 159).

Passing tests do not clear the two HIGH root-overwrite races because their storage adapter does not force the unsafe interleavings.
