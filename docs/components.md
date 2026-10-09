# Components and identity

A component is an ordinary Zig function. There is no component object, heap tree, callback DSL, or runtime reflection:

```zig
fn header(ui: *Ui, title: []const u8) void {
    var component = ui.scope(.header);
    defer component.end();
    ui.text(.title, title);
    ui.divider(.line, 120);
}
```

The layers are primitive → widget → component function → screen function. A scope combines its parent's stable `u16` key and a typed logical ID. Sibling components can reuse local `.title` and `.line` IDs. `Scope.id(.title)` or `Ui.childId(parent, .title)` exposes a stable key for focus restoration or tests. Composite widgets derive internal IDs by semantic role, so adding a border does not shift the public widget ID. A bounded linear duplicate check catches truncated `u16` collisions and reports `IdentityCollision`; there is no lookup table or heap map.

Prefer one unique logical ID for each sibling. `var scope = ui.row(.controls, .{}); defer scope.end();` closes a container even on early return. `ui.scope(.component)` creates an ID namespace without adding a Node. `ui.panel`, `ui.list`, `ui.toggle`, `ui.progress`, `ui.tuner`, and `ui.knob` use the same identity rule. `ui.finishChecked()` catches unclosed and double-ended scopes in tests. A failed build is a configuration/programming error; a normal `ui.finish()` panics in Debug and traps in ReleaseSmall.

For application state, pass values into widget calls on every rebuild and react to `Action` IDs. Focus and presentation tracks refer to derived Node IDs; Navigation can save those IDs. A component should not retain a pointer to `Ui` beyond a rebuild. Bitmap and text slices must remain valid through rendering.

Desktop widgets add `ui.textField(id, &application_field, options)` and `ui.pressable(id, label, options)`. Their borrowed state, input intents and disabled behavior are documented in [Desktop Foundation](desktop-foundation.md).
