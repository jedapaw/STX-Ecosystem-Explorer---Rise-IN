// sources/explorer.move
module explorer_addr::explorer {
    use std::string::{String};
    use std::signer;
    use aptos_framework::table::{Self, Table};
    use std::vector;

    // --- Error Codes ---
    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_PROJECT_NOT_FOUND: u64 = 3;
    const E_NOT_AUTHORIZED: u64 = 4;
    const E_NOT_INITIALIZED: u64 = 5;

    // --- Structs ---
    struct Project has store, copy, drop {
        id: u64,
        name: String,
        description: String,
        url: String,
        category: String,
        submitted_by: address,
    }

    struct ExplorerData has key {
        projects: Table<u64, Project>,
        project_count: u64,
        owner: address,
    }

    // --- Entry Functions ---

    // CORRECTED LOGIC: Only the contract owner (@explorer_addr) can initialize the contract,
    // and the data is correctly stored under their account.
    public entry fun initialize_explorer(account: &signer) {
        let owner_address = signer::address_of(account);
        assert!(owner_address == @explorer_addr, E_NOT_OWNER);
        assert!(!exists<ExplorerData>(owner_address), E_ALREADY_INITIALIZED);
        
        move_to(account, ExplorerData {
            projects: table::new(),
            project_count: 0,
            owner: owner_address,
        });
    }

    public entry fun add_project(
        account: &signer,
        name: String,
        description: String,
        url: String,
        category: String
    ) acquires ExplorerData {
        let owner_address = @explorer_addr;
        assert!(exists<ExplorerData>(owner_address), E_NOT_INITIALIZED);
        let explorer_data = borrow_global_mut<ExplorerData>(owner_address);
        
        let project_id = explorer_data.project_count;
        let new_project = Project {
            id: project_id,
            name,
            description,
            url,
            category,
            submitted_by: signer::address_of(account),
        };
        
        table::add(&mut explorer_data.projects, project_id, new_project);
        explorer_data.project_count = project_id + 1;
    }

    public entry fun update_project(
        account: &signer,
        project_id: u64,
        name: String,
        description: String,
        url: String
    ) acquires ExplorerData {
        let caller = signer::address_of(account);
        let owner_address = @explorer_addr;
        assert!(exists<ExplorerData>(owner_address), E_NOT_INITIALIZED);
        let explorer_data = borrow_global_mut<ExplorerData>(owner_address);
        
        assert!(table::contains(&explorer_data.projects, project_id), E_PROJECT_NOT_FOUND);
        let project = table::borrow_mut(&mut explorer_data.projects, project_id);
        
        // Access Control: Only the original submitter can update.
        assert!(project.submitted_by == caller, E_NOT_AUTHORIZED);
        
        project.name = name;
        project.description = description;
        project.url = url;
    }

    // --- Public View Functions for dApp ---

    #[view]
    public fun is_initialized(): bool {
        exists<ExplorerData>(@explorer_addr)
    }

    #[view]
    public fun get_project_count(): u64 acquires ExplorerData {
        if (!exists<ExplorerData>(@explorer_addr)) {
            return 0
        };
        borrow_global<ExplorerData>(@explorer_addr).project_count
    }

    #[view]
    public fun get_project_details(project_id: u64): Project acquires ExplorerData {
        assert!(exists<ExplorerData>(@explorer_addr), E_NOT_INITIALIZED);
        let explorer_data = borrow_global<ExplorerData>(@explorer_addr);
        assert!(table::contains(&explorer_data.projects, project_id), E_PROJECT_NOT_FOUND);
        *table::borrow(&explorer_data.projects, project_id)
    }

    #[view]
    public fun get_all_projects(): vector<Project> acquires ExplorerData {
        if (!exists<ExplorerData>(@explorer_addr)) {
            return vector::empty<Project>()
        };
        
        let explorer_data = borrow_global<ExplorerData>(@explorer_addr);
        let projects = vector::empty<Project>();
        let i = 0;
        while (i < explorer_data.project_count) {
            if (table::contains(&explorer_data.projects, i)) {
                let project = *table::borrow(&explorer_data.projects, i);
                vector::push_back(&mut projects, project);
            };
            i = i + 1;
        };
        projects
    }

    // --- Helper Functions for Tests ---

    #[test_only]
    public fun get_project_name(project_id: u64): String acquires ExplorerData {
        let explorer_data = borrow_global<ExplorerData>(@explorer_addr);
        let project = table::borrow(&explorer_data.projects, project_id);
        project.name
    }

    #[test_only]
    public fun get_project_submitted_by(project_id: u64): address acquires ExplorerData {
        let explorer_data = borrow_global<ExplorerData>(@explorer_addr);
        let project = table::borrow(&explorer_data.projects, project_id);
        project.submitted_by
    }

    #[test_only]
    public fun get_project_description(project_id: u64): String acquires ExplorerData {
        let explorer_data = borrow_global<ExplorerData>(@explorer_addr);
        let project = table::borrow(&explorer_data.projects, project_id);
        project.description
    }

    #[test_only]
    public fun project_exists(project_id: u64): bool acquires ExplorerData {
        let explorer_data = borrow_global<ExplorerData>(@explorer_addr);
        table::contains(&explorer_data.projects, project_id)
    }
}
