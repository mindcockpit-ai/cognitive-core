---
paths: ["**/*.rs"]
---

# Rust Conventions

- Use `clippy` lints — no `#[allow]` without justification
- Prefer `Result` over `unwrap()`/`expect()` in library code
- Derive common traits: `Debug`, `Clone`, `PartialEq` where appropriate
- Use `thiserror` for library errors, `anyhow` for application errors
