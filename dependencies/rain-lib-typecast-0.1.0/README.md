# rain.lib.typecast

Common casts and conversions between Solidity types that aren't natively possible
due to the Solidity compiler enforcing constraints or them being ambiguous and/or
unsafe generally.

In this context a cast moves between Solidity types without changing the binary
data, it merely forces the type system to treat some type as another. For example
we have functions here to convert `uint256[]` to `bytes32[]` without changing any
of the internal values of the arrays.

Conversions involve mutations to the binary data in the process of moving between
types. For example, moving from `uint256[]` to `bytes` involves mutating the
length of the collection even if the binary data values are unchanged.
