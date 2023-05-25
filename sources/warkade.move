module warkade::warkade {
    use std::signer;
    use std::bcs;
    use std::hash;
    use std::vector;
    use aptos_std::from_bcs;
    use std::string::{Self, String};
    use aptos_framework::object;
    use aptos_framework::timestamp;
    use aptos_token_objects::aptos_token::{Self,AptosToken};
    use aptos_framework::account;
    use aptos_framework::coin::{Self};
    use aptos_framework::aptos_coin::AptosCoin;

    struct MintInfo has key{
        base_uri:String,
        last_mint:u64,
        maximum_values_layers:vector<u64>,
        //treasury_cap
        treasury_cap:account::SignerCapability,
        resource_address:address,
        price:u64,
        collection_name:String,
        description:String,
        //keys
        key:vector<String>,
        //types
        type:vector<String>,
        }
    // ERRORS 
    const ENO_NOT_MODULE_CREATOR:u64=0;
    const ENO_KEYS_MAX_VALUE_UNEQUAL:u64=1;

    public entry fun initiate_collection(
        account: &signer,
        collection:String,
        description:String,
        base_uri:String,
        price:u64,)
    {
        let owner_addr = signer::address_of(account);
        assert!(owner_addr==@warkade,ENO_NOT_MODULE_CREATOR);
        let (resource, resource_cap) = account::create_resource_account(account, bcs::to_bytes(&collection));
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        let resource_address = signer::address_of(&resource);
        let flag= true;
        aptos_token::create_collection(
            &resource_signer_from_cap,
            description,
            1000000000,
            collection,
            base_uri,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            0,
            1,
        );
        move_to<MintInfo>(account,
                MintInfo{
                base_uri:base_uri,
                last_mint:0,
                maximum_values_layers:vector<u64>[],
                treasury_cap:resource_cap,
                resource_address:resource_address,
                price:price,
                collection_name:collection,
                description:description,
                key:vector<String>[],
                //types
                type:vector<String>[],
        });
    }
    public entry fun initiate_layers(
        module_owner:&signer,
        maximum_values_layers:vector<u64>,
        keys:vector<String>,
    )acquires MintInfo
    {
            let owner_addr = signer::address_of(module_owner);
            assert!(owner_addr==@warkade,ENO_NOT_MODULE_CREATOR);
            let mint_info = borrow_global_mut<MintInfo>(owner_addr);
            assert!(vector::length(&maximum_values_layers)==vector::length(&keys),ENO_KEYS_MAX_VALUE_UNEQUAL);
            let len = vector::length(&maximum_values_layers);
            mint_info.maximum_values_layers=maximum_values_layers;
            mint_info.key=keys;
            mint_info.type=vector<String>[];
            while(len>0)
            {
                vector::push_back(&mut mint_info.type,string::utf8(b"u8") );
                len=len-1;
            };

    }
    public entry fun update_price(
        module_owner:&signer,
        price:u64,
    )acquires MintInfo
    {
            let owner_addr = signer::address_of(module_owner);
            assert!(owner_addr==@warkade,ENO_NOT_MODULE_CREATOR);
            let mint_info = borrow_global_mut<MintInfo>(owner_addr);
            mint_info.price=price;

    }
    public entry fun update_uri(
        module_owner:&signer,
        base_uri:String,
    )acquires MintInfo
    {
            let owner_addr = signer::address_of(module_owner);
            assert!(owner_addr==@warkade,ENO_NOT_MODULE_CREATOR);
            let mint_info = borrow_global_mut<MintInfo>(owner_addr);
            mint_info.base_uri=base_uri;

    }
    public entry fun add_layer(
        module_owner:&signer,
        maximum_value:u64,
        keys:String
    )acquires MintInfo
    {
            let owner_addr = signer::address_of(module_owner);
            assert!(owner_addr==@warkade,ENO_NOT_MODULE_CREATOR);
            let mint_info = borrow_global_mut<MintInfo>(owner_addr);
            vector::push_back(&mut mint_info.key, keys);
            vector::push_back(&mut mint_info.maximum_values_layers, maximum_value);
            vector::push_back(&mut mint_info.type,string::utf8(b"u8") );

    }
    public entry fun mint_warkade(
            receiver: &signer,
    )acquires MintInfo
        {
            let receiver_addr = signer::address_of(receiver);
            assert!(exists<MintInfo>(@warkade),12);
            let mint_info = borrow_global_mut<MintInfo>(@warkade);
            let resource_signer_from_cap = account::create_signer_with_capability(&mint_info.treasury_cap);
            let baseuri = mint_info.base_uri;
            let mint_position=mint_info.last_mint+1;
            string::append(&mut baseuri,num_str(mint_position));
            let token_name = mint_info.collection_name;
            string::append(&mut token_name,string::utf8(b" #"));
            string::append(&mut token_name,num_str(mint_position));
            string::append(&mut baseuri,string::utf8(b".json"));
            let token_creation_num = account::get_guid_next_creation_num(mint_info.resource_address);
           
            let x = vector<vector<u8>>[];
            let len = vector::length(&mint_info.maximum_values_layers);
            let i=0;
            let now=timestamp::now_seconds();
            while(i < len)
            {
                let max_value=vector::borrow(&mint_info.maximum_values_layers,i);
                let vala = pseudo_random(receiver_addr,*max_value,now);
                now = now +vala; // changing the value to bring some more randomness
                let u8val= (vala as u8);

                vector::push_back(&mut x, bcs::to_bytes<u8>(&u8val) );
                i=i+1;
            };
            aptos_token::mint(
                &resource_signer_from_cap,
                mint_info.collection_name,
                mint_info.description,
                token_name,
                baseuri,
                mint_info.key,
                mint_info.type,
                   x,);
            let minted_token = object::address_to_object<AptosToken>(object::create_guid_object_address(mint_info.resource_address, token_creation_num));
            object::transfer( &resource_signer_from_cap, minted_token, receiver_addr);
            coin::transfer<AptosCoin>(receiver,@warkade , mint_info.price);   
            mint_info.last_mint=mint_info.last_mint+1; 
        }


    /// utility function

    fun pseudo_random(add:address,remaining:u64,timestamp:u64):u64
    {
        let x = bcs::to_bytes<address>(&add);
        let y = bcs::to_bytes<u64>(&remaining);
        let z = bcs::to_bytes<u64>(&timestamp);
        vector::append(&mut x,y);
        vector::append(&mut x,z);
        let tmp = hash::sha2_256(x);

        let data = vector<u8>[];
        let i =24;
        while (i < 32)
        {
            let x =vector::borrow(&tmp,i);
            vector::append(&mut data,vector<u8>[*x]);
            i= i+1;
        };
        assert!(remaining>0,999);

        let random = from_bcs::to_u64(data) % remaining+1;
        random
    }
    fun num_str(num: u64): String
        {
        let v1 = vector::empty();
        while (num/10 > 0){
            let rem = num%10;
            vector::push_back(&mut v1, (rem+48 as u8));
            num = num/10;
        };
        vector::push_back(&mut v1, (num+48 as u8));
        vector::reverse(&mut v1);
        string::utf8(v1)
    }

}