# Contributing to Splitify Free Forever

Thanks for your interest in helping out! This guide explains how to report problems, suggest ideas and send changes.

By taking part, you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting bugs

1. Search [existing issues](https://github.com/Unizoy/splitify-free-forever/issues) first.
2. If it is new, open a **Bug report** and include steps to reproduce, what you expected, what happened,
   and your device/browser and app version.

Security problems should **not** be reported as issues. See [SECURITY.md](SECURITY.md).

## Suggesting features

Open a **Feature request** describing the problem you want solved, not only the solution.
For bigger changes, please discuss in an issue before writing code.

## Making changes

1. Fork the repository and create a branch from `main`:
   `git checkout -b fix/short-description`
2. Make your change. Keep pull requests small and focused on one thing.
3. Before pushing, run:
   ```powershell
   .\tool\verify.ps1
   ```
   It runs format, analyze, guard scripts, tests with coverage and a debug build.
4. Write clear, short commit messages in the imperative mood, e.g. `Fix balance rounding`.
5. Open a pull request against `main` and fill in the template.

## Never commit secrets

This repository is public. Do not commit API keys, `.env` files, keystores, `key.properties`,
`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` or service account files.
The `.gitignore` covers these, but always check `git status` before committing.
If you need to share example config, use a file like `.env.example` with placeholder values.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
