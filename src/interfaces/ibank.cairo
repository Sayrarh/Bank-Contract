use starknet::ContractAddress;

#[starknet::interface]

pub trait IBank<TContractState>{
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn add_supported_token(ref self: TContractState, token_address: ContractAddress);
}