// tests/explorer_tests.move
#[test_only]
module explorer_addr::explorer_tests {
    use std::signer;
    use std::string;
    use aptos_framework::account;
    
    // Import the module we want to test
    use explorer_addr::explorer;
    
    #[test(explorer_owner = @explorer_addr, user = @user)]
    fun test_full_lifecycle_success(explorer_owner: &signer, user: &signer) {
        // 1. Setup accounts
        account::create_account_for_test(signer::address_of(explorer_owner));
        account::create_account_for_test(signer::address_of(user));
        
        // 2. Initialize the contract as the explorer_owner
        explorer::initialize_explorer(explorer_owner);
        
        // 3. Add a project as the user
        explorer::add_project(
            user,
            string::utf8(b"Test dApp"),
            string::utf8(b"A test description."),
            string::utf8(b"https://test.com"),
            string::utf8(b"Testing")
        );
        
        // 4. Verify the project was added correctly
        assert!(explorer::project_exists(0), 1);
        assert!(explorer::get_project_name(0) == string::utf8(b"Test dApp"), 2);
        assert!(explorer::get_project_submitted_by(0) == signer::address_of(user), 3);
        assert!(explorer::get_project_count() == 1, 4);
        
        // 5. Update the project as the correct user
        explorer::update_project(
            user,
            0,
            string::utf8(b"Updated dApp"),
            string::utf8(b"Updated description."),
            string::utf8(b"https://updated.com")
        );
        
        // 6. Verify the update worked
        assert!(explorer::get_project_name(0) == string::utf8(b"Updated dApp"), 5);
        assert!(explorer::get_project_description(0) == string::utf8(b"Updated description."), 6);
    }

    #[test(explorer_owner = @explorer_addr, user1 = @user1, attacker = @attacker)]
    #[expected_failure(abort_code = 4, location = explorer_addr::explorer)]
    fun test_update_fails_for_unauthorized_user(explorer_owner: &signer, user1: &signer, attacker: &signer) {
        // 1. Setup accounts
        account::create_account_for_test(signer::address_of(explorer_owner));
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(attacker));
        
        // 2. Initialize the contract
        explorer::initialize_explorer(explorer_owner);
        
        // 3. user1 adds a project
        explorer::add_project(
            user1,
            string::utf8(b"User1 dApp"),
            string::utf8(b"Desc."),
            string::utf8(b"https://user1.com"),
            string::utf8(b"NFT")
        );
        
        // 4. 'attacker' tries to update user1's project. This MUST fail.
        explorer::update_project(
            attacker,
            0,
            string::utf8(b"Hacked dApp"),
            string::utf8(b"Hacked desc."),
            string::utf8(b"https://hacked.com")
        );
    }
}
