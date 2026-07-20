# SwiftUI Best Practices

Portable rules — nothing here is specific to this app. Any SwiftUI project can adopt them as is;
the project's own implementation of each rule lives in [ios-guide.md](ios-guide.md).

## A CTA that fires a network call never waits in silence

**Any control that triggers a network call shows its state in the tap itself.** A button that looks
untouched while a request flies is a button the user taps again — duplicate writes, then a screen
that jumps with no explanation. Three shapes, in this order of preference:

### 1. Inline — the icon becomes the spinner

The default for every button that saves, renames, toggles or validates. A tiny reusable atom swaps
the SF Symbol for a `ProgressView`, so no call site re-implements the branch:

```swift
/// An SF Symbol that becomes a spinner while its action is in flight.
struct ActionIcon: View {
    let systemImage: String
    let isRunning: Bool

    var body: some View {
        if isRunning { ProgressView() } else { Image(systemName: systemImage) }
    }
}

Button {
    Task { await save() }
} label: {
    ActionIcon(systemImage: "checkmark", isRunning: isSaving)
}
.disabled(isSaving)
```

Rules that come with it:

- **One source of truth for "in flight."** If the action already runs through a helper that tracks
  its own state (an error presenter, a view model flag), bind the spinner to *that* — never a
  parallel `@State` boolean that can drift out of sync.
- **Refresh inside the in-flight window.** When success is followed by a reload, `await` the reload
  in the same closure rather than in a detached `Task`: otherwise the spinner stops before the view
  can redraw its new state, and the UI shows the old value for a beat.
- **`.interactiveDismissDisabled(isRunning)` on any sheet that writes.** A swipe mid-write orphans
  the task and leaves the user unsure whether anything was saved.
- **A row in a list carries its own spinner**, in its trailing edge — a form with several actions
  needs to say *which* one is running, so track the running action as an enum, not a boolean.

### 2. Long or AI work — the full-bleed loader

A multi-second wait (an LLM call, a heavy analysis) is not a button state: it owns the screen, with
a message saying what is being done. A dedicated loading screen also gives the failure a place to
land — a retry action in context instead of an alert over a frozen form.

### 3. One-way actions — optimistic, in the background

For an action the user cannot undo and has no reason to watch (deleting a row), the best loader is
none: leave the screen immediately, drop the row from the list, and let the call run in an object
that **outlives the view** — a store or view model, not a `Task` spawned by a screen that is about
to disappear (it survives, but it no longer has a view to report into). On failure, report the error
and reload the list, which puts the row back.

### Anti-patterns

- `.disabled(isRunning)` **without** a spinner — the feedback is invisible; the control just stops
  responding.
- An `alert` button that `await`s in silence: the alert dismisses and the screen freezes with no
  indication anything is happening. An alert cannot host a spinner — either move the work to a
  screen that can, or make it optimistic (shape 3).
- A `ProgressView` parked in a section unrelated to the control that was tapped — put it *on* the
  control.
- A spinner with no `.disabled`: it says "working" while still accepting a second tap.
