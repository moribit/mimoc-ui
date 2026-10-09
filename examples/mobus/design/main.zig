//! Candidate starts from the frozen reference. Change only this layer for redesign.
//! Scenario and fixture remain shared; no mutable state or captured golden is copied.
const reference = @import("mobus_reference");
pub const Fixture = reference.fixtures.Fixture;
pub const Scenario = reference.Scenario;
pub fn render(scenario: Scenario, fixture: Fixture, pixels: *[1024]u8) void {
    reference.render(scenario, fixture, pixels);
}
