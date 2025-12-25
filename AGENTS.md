# Repository Guidelines

This repository is currently empty (no source, tests, or configuration files). Use the guidance below as the starting structure and update it as the project takes shape.

## Project Structure & Module Organization

- Place application/source code in `src/`.
- Keep tests in `tests/` (unit) and `tests/integration/` if needed.
- Store static assets in `assets/` or `public/`.
- Keep configuration at the root (for example, `package.json`, `pyproject.toml`, or `Makefile`).

## Build, Test, and Development Commands

No build or test tooling is configured yet. When adding tooling, document the exact commands here (examples):

- `npm run build` — compile/bundle the app.
- `npm test` — run the test suite.
- `npm run dev` — start a local development server.

## Coding Style & Naming Conventions

No style rules are defined yet. When you add a language/tooling stack, record the conventions here (examples):

- Indentation: 2 spaces for JS/TS, 4 spaces for Python.
- Naming: `camelCase` for variables/functions, `PascalCase` for types/classes.
- Tooling: `eslint`, `prettier`, `ruff`, `black`, `gofmt`, etc.

## Testing Guidelines

No testing framework is set up yet. When you add one, specify:

- Framework (for example, `jest`, `vitest`, `pytest`).
- File naming (for example, `*.test.ts`, `test_*.py`).
- How to run unit vs. integration tests.

## Commit & Pull Request Guidelines

There is no Git history or commit convention to follow yet. Until conventions exist:

- Write clear, imperative commit messages (for example, `Add login form validation`).
- Include a short PR description and link related issues.
- Add screenshots for UI changes and note any manual testing performed.

## Security & Configuration Tips

- Do not commit secrets. Use `.env` files and document required variables in `README.md`.
- Keep environment-specific config out of source control; provide `.env.example` instead.
