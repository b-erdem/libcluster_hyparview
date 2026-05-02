# Contributing to libcluster_hyparview

Thanks for your interest. This is a small, single-purpose package — it
wires `hyparview` into `libcluster`. Contributions that fit that scope
are welcome.

## Scope

In scope:
- Bug fixes against the `Cluster.Strategy.HyParView` module
- Better error reporting / observability
- Tests that exercise edge cases (partition, churn, restart)
- Documentation, examples, integration notes

Out of scope (we will politely decline):
- Changes to the HyParView protocol itself — those belong in
  [`hyparview`](https://github.com/b-erdem/hyparview)
- Alternate clustering strategies — that's libcluster's territory

## Developer setup

```sh
asdf install                  # uses .tool-versions (Elixir 1.19, OTP 28)
mix deps.get
mix check                     # format + credo + dialyzer + test
```

## Pull request workflow

1. Fork and create a topic branch off `main`.
2. Keep changes focused. One logical change per PR.
3. Add tests.
4. Run `mix check` before pushing.
5. Open a PR with a description that explains *why*, not just *what*.

## Developer Certificate of Origin (DCO)

All commits must carry a `Signed-off-by` line certifying the
[Developer Certificate of Origin](https://developercertificate.org/).
Use `git commit -s` to add it automatically.

## Releases

Maintainers cut releases by tagging `vX.Y.Z`, updating `CHANGELOG.md`,
and running `mix hex.publish`.
