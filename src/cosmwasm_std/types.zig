pub const Env = struct {
    block: struct {
        height: u64,
        time: []const u8, // as u64
        chain_id: []const u8,
    },
    transaction: struct { index: u32 },
    contract: struct {
        address: []const u8,
    },
};

pub const MessageInfo = struct {
    /// The `sender` field from `MsgInstantiateContract` and `MsgExecuteContract`.
    /// You can think of this as the address that initiated the action (i.e. the message). What that
    /// means exactly heavily depends on the application.
    ///
    /// The x/wasm module ensures that the sender address signed the transaction or
    /// is otherwise authorized to send the message.
    ///
    /// Additional signers of the transaction that are either needed for other messages or contain unnecessary
    /// signatures are not propagated into the contract.
    sender: []const u8,
    /// The funds that are sent to the contract as part of `MsgInstantiateContract`
    /// or `MsgExecuteContract`. The transfer is processed in bank before the contract
    /// is executed such that the new balance is visible during contract execution.
    funds: []Coin,
};

pub const Coin = struct {
    denom: []const u8,
    amount: []const u8, // as u128
};
