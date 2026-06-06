# rain.math.fixedpoint

Docs at https://rainprotocol.github.io/rain.math.fixedpoint

## Goals

Ideally we'd not need this library as math primitives are probably best handled
in some upstream library.

What we need:

- 18 decimal fixed point math
- handle rounding directions explicitly
- rescale non-18 decimal fixed point values (e.g. ERC20 token amounts) to/from
  18 decimals so that we can do math on them
- avoid code bloat in an interpreter due to importing several libs with heavily
  overlapping scope
- open source license, but not forcing ppl to jump on the GPL crusade
- minimal surface area so we can gracefully deprecate this lib if all the above
  is provided elsewhere someday
- works on simple `uint256` values

Upstream candidates:

- Open Zeppelin
  - Has implementations that include rounding direction 👍
  - Audited code due to recent ERC4626 implementation 👍
  - Only includes math needed by the specs implemented, not general purpose 👎
- PRB math
  - General purpose fixed point math 👍
  - Where the scope overlaps OZ the logic is similar or identical 👍
  - No ability to specify rounding or to rescale outside 18 decimals 👎
  - Never audited 👎
- Others
  - Either wrong license or issues as pointed out on PRB math repo

Since we need math that isn't provided by Open Zeppelin, and we aren't going to
write it ourselves, PRB math seems to be the most reasonable foundation. At the
same time, Open Zeppelin may already be a dependency for other reasons, such as
some token implementation, so including both OZ and PRB in a single contract can
bloat code.

## Non-goals

None of this is supported/needed:

- Signed math
- Non-18 decimal fixed point math (other than rescaling)
- One size fits all solution

## Approach

- Provide a base repo (this one) that has zero dependencies, to focus on the
  logic required to rescale between decimals, that are lib agnostic.
- Provide supporting repos to normalise Open Zeppelin and PRB math
  - OZ includes `muldiv` but doesn't have an opinion on decimals, so caller is
    forced to provide "one" at every step and mentally balance multiplication
    and division
  - PRB is opinionated with sane defaults for 18 decimal math but provides no
    rounding or rescaling support

Downstream consumers are advised to select _one_ of either OZ or PRB to compile
into their contracts, using the relevant supporting libs only, to minimise
dependencies and potential code bloat, or even inconsistent behaviours between
libs.

## Install

Via [soldeer](https://soldeer.xyz):

```sh
forge soldeer install rain-math-fixedpoint~<version>
```

## Develop

This repo uses [nix](https://nixos.org/download.html). The default shell is the
slim `sol-shell` from [rainix](https://github.com/rainlanguage/rainix).

```sh
nix develop          # enter the shell
forge soldeer install # install deps declared in foundry.toml
forge test
```

Tasks:

- `rainix-sol-test` — `forge test`
- `rainix-sol-static` — slither
- `rainix-sol-legal` — `reuse lint`

Use the nix-pinned `forge` for all development.

## Publish

Tag `v<x.y.z>` on `main`. The
[`Publish to Soldeer`](.github/workflows/publish-soldeer.yaml) wrapper delegates
to rainix's reusable workflow, which derives the package name from the repo name
(`rain.math.fixedpoint` → `rain-math-fixedpoint`).

## License

DecentraLicense 1.0 (DCL-1.0) — full text in
[`LICENSES/`](LICENSES/LicenseRef-DCL-1.0.txt). Roughly `CAL-1.0`
([opensource.org](https://opensource.org/license/cal-1-0)) plus user-data
disclosure obligations consistent with permissionless-blockchain assumptions.

This repo is [REUSE 3.2](https://reuse.software/spec-3.2/) compliant. Verify
locally:

```sh
nix develop -c rainix-sol-legal
```

## Contributions

Welcome under the same license. Contributors warrant that their contributions
are compliant.
