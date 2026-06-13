# rain.flow

Solidity contracts for "flows" — token movement primitives (ERC20/721/1155)
driven by rainlang expressions. A registered evaluable produces a stack; the
contract parses that stack into transfers and executes them atomically.

## Current version

### V5

V5 is the live interface (`src/interface/IFlowV5.sol`), implemented by
`src/concrete/Flow.sol`. V5 consolidated to non-mint flows: the V4 ERC20 /
ERC721 / ERC1155 mint-burn variants were dropped, leaving a single flow contract
that moves third-party tokens. V5 re-exports `RAIN_FLOW_SENTINEL`,
`MIN_FLOW_SENTINELS`, `FlowTransferV1`, and the per-token transfer structs from
the V4 declarations so that integrators on V4 transfer types can move to V5
without re-deriving them.

## Deprecated versions

All deprecated interfaces live under `src/interface/deprecated/`. They retain
their original ABI for historical deployments — their function signatures, event
topics, and struct field layouts will not change.

### V4

V4 introduced `stackToFlow` (replacing V3's `previewFlow`), allowing any caller
to simulate a flow against an arbitrary stack rather than against a registered
evaluable. V4 also targeted a newer interpreter interface than V3 — native
parsing that works off a single `bytes` for the rain bytecode rather than the
`bytes[]` older interpreters expected. V5 superseded V4 by removing the ERC
mint-burn variants.

### V3

V3 introduced `handleTransfer` and `tokenURI` evaluables on the ERC variants.
Superseded by V4's `stackToFlow` generalisation.

### V2

V2 was deprecated to remove native flows entirely from V3+. Flow implementations
are likely to want `Multicall`-like batching, and `Multicall` based on
`delegatecall` preserves `msg.sender` (good for EOA self-flow) but reuses
`msg.value` across loop iterations — a critical issue for any contract that
reads `msg.value`. See
[samczsun, "two rights might make a wrong"](https://samczsun.com/two-rights-might-make-a-wrong/).

### V1

V1 was deprecated because the upstream `SignedContext` struct it relied on was
replaced by `SignedContextV1`, a minor reordering for more efficient processing.
