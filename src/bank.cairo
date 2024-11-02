#[starknet::contract]

mod Bank{
    use starknet::{ContractAddress, contract_address_const, get_caller_address, get_contract_address};
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, 
        Map, StoragePathEntry
    };
    use bank::interfaces::ibank::IBank;
    use bank::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage{
        owner: ContractAddress,
        balances: Map<(ContractAddress, ContractAddress), u256>,//Map(userAddress, tokenAddress), amount
        supported_tokens: Map<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event{
        DepositSuccessful: DepositSuccessful,
        WithdrawSuccessful: WithdrawSuccessful,
    }

     #[derive(Drop, starknet::Event)]
    struct DepositSuccessful{
        user: ContractAddress,
        token: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawSuccessful{
        user: ContractAddress,
        token: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(ref self:ContractState, owner:ContractAddress){
        assert!(owner != contract_address_const::<0>(), "address zero detected");
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl BankImpl of IBank<ContractState>{
        fn deposit(ref self: ContractState, token_address:ContractAddress, amount:u256){
            assert!(amount > 0, "can't deposit zero amount");

            let caller = get_caller_address();
            let this_contract = get_contract_address();

            let is_supported = self.supported_tokens.entry(token_address).read();
            assert!(is_supported == true, "Token address not supported");

            let token = IERC20Dispatcher {contract_address: token_address};

            let transfer = token.transfer_from(caller, this_contract, amount);

            assert!(transfer, "transfer failed");
            //IERC20Dispatcher {contract_address: token_address}.transfer_from(caller, this_contract, amount);

            let prev_balance = self.balances.entry((caller, token_address)).read();
            self.balances.entry((caller, token_address)).write(prev_balance + amount);

            self.emit(DepositSuccessful{user:caller, token:token_address, amount});
        }

        fn withdraw(ref self:ContractState, token_address:ContractAddress, amount: u256){
            let caller = get_caller_address();
            
            let token = IERC20Dispatcher {contract_address: token_address};
            let acct_balance = self.balances.entry((caller, token_address)).read();

            assert!(acct_balance >= amount, "No sufficient funds");

            self.balances.entry((caller, token_address)).write(acct_balance - amount);

            let transfer = token.transfer(caller, amount);
            assert!(transfer, "transfer failed");

            self.emit(WithdrawSuccessful{user:caller, token:token_address, amount});
        }

        fn add_supported_token(ref self: ContractState, token_address:ContractAddress){
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can add tokens");
            assert!(token_address != contract_address_const::<0>(), "address zero detected");

            self.supported_tokens.entry(token_address).write(true);
        }
    }
}