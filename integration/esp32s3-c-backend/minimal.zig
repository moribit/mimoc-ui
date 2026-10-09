//! Reproduces the upstream C ABI assertion issue without importing mimoc-ui.
pub export fn mimoc_abi_minimal(value: u32) u32 {
    return value +% 1;
}
