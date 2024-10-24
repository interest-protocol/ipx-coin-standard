#[test_only]
module ipx_coin::treasury_cap_tests;

use std::type_name;

use sui::{
    test_scenario as ts, 
    test_utils::{assert_eq, destroy},
    coin::{Self, TreasuryCap, CoinMetadata}
};

use ipx_coin::{ 
    ipx_coin,
    aptos::{Self, APTOS},
};

const ADMIN: address = @0xdead;

public struct ETH has drop()

#[test]
fun test_end_to_end() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let mut metadata = scenario.take_shared<CoinMetadata<APTOS>>(); 
    let name = type_name::get<APTOS>();

    assert_eq(metadata.get_decimals(), 9);
    assert_eq(metadata.get_symbol(), b"APT".to_ascii_string());
    assert_eq(metadata.get_name(), b"Aptos".to_string());
    assert_eq(metadata.get_description(), b"The second best move chain".to_string());
    assert_eq(metadata.get_icon_url(), option::none());
    assert_eq(cap.total_supply(), 0);

    let (mut treasury_cap, mut witness) = ipx_coin::new(cap, scenario.ctx());
    
    assert_eq(witness.mint_cap_address().is_none(), true);
    assert_eq(witness.burn_cap_address().is_none(), true);
    assert_eq(witness.metadata_cap_address().is_none(), true);

    let mint_cap = witness.create_mint_cap(scenario.ctx());
    let burn_cap = witness.create_burn_cap(scenario.ctx());
    let metadata_cap = witness.create_metadata_cap(scenario.ctx()); 

    assert_eq(witness.mint_cap_address().destroy_some(), object::id(&mint_cap).to_address());
    assert_eq(witness.burn_cap_address().destroy_some(), object::id(&burn_cap).to_address());
    assert_eq(witness.metadata_cap_address().destroy_some(), object::id(&metadata_cap).to_address());

    assert_eq(treasury_cap.name(), name);
    assert_eq(mint_cap.name(), name);
    assert_eq(burn_cap.name(), name);
    assert_eq(metadata_cap.name(), name);
    assert_eq(witness.name(), name);
    assert_eq(witness.treasury(), object::id(&treasury_cap).to_address());

    let aptos_coin = mint_cap.mint<APTOS>(&mut treasury_cap, 100, scenario.ctx());

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 2);

    assert_eq(treasury_cap.total_supply<APTOS>(), 100);
    assert_eq(aptos_coin.value(), 100);

    burn_cap.burn<APTOS>(&mut treasury_cap, aptos_coin);

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 1);

    assert_eq(treasury_cap.total_supply<APTOS>(), 0);

    let treasury_address = object::id(&treasury_cap).to_address();

    assert_eq(treasury_cap.can_burn(), false);
    assert_eq(treasury_address, mint_cap.treasury());
    assert_eq(treasury_address, burn_cap.treasury());
    assert_eq(treasury_address, metadata_cap.treasury());
    
    treasury_cap.update_name<APTOS>(&mut metadata,&metadata_cap, b"Aptos V2".to_string()); 
    treasury_cap.update_symbol<APTOS>(&mut metadata,&metadata_cap, b"APT2".to_ascii_string()); 
    treasury_cap.update_description<APTOS>(&mut metadata,&metadata_cap, b"Aptos V2 is the best".to_string());
    treasury_cap.update_icon_url<APTOS>(&mut metadata,&metadata_cap, b"https://aptos.dev/logo.png".to_ascii_string());

    assert_eq(metadata.get_name(), b"Aptos V2".to_string());
    assert_eq(metadata.get_symbol(), b"APT2".to_ascii_string());
    assert_eq(metadata.get_description(), b"Aptos V2 is the best".to_string());
    assert_eq(metadata.get_icon_url().borrow().inner_url(), b"https://aptos.dev/logo.png".to_ascii_string());

    mint_cap.destroy();
    burn_cap.destroy();
    metadata_cap.destroy();

    destroy(treasury_cap);
    destroy(metadata);
    destroy(scenario);
}

#[test]
fun test_treasury_burn() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let aptos_coin = cap.mint<APTOS>( 100, scenario.ctx());

    let (mut treasury_cap, mut witness) = ipx_coin::new(cap, scenario.ctx());

    witness.add_burn_capability(&mut treasury_cap);

    treasury_cap.burn(aptos_coin);

    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
#[expected_failure(abort_code = ipx_coin::ETreasuryCannotBurn)]
fun test_treasury_cannot_burn() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let aptos_coin = cap.mint<APTOS>( 100, scenario.ctx());

    let (mut treasury_cap, _) = ipx_coin::new(cap, scenario.ctx());

    treasury_cap.burn(aptos_coin);

    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
#[expected_failure(abort_code = ipx_coin::ECapAlreadyCreated)]
fun test_burn_cap_already_created_for_treasury() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (mut treasury_cap_v2, mut witness) = ipx_coin::new(eth_treasury_cap, scenario.ctx());

    let burn_cap = witness.create_burn_cap(scenario.ctx());

    witness.add_burn_capability(&mut treasury_cap_v2);

    burn_cap.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}

#[test] 
#[expected_failure(abort_code = ipx_coin::EInvalidCap)]
fun test_invalid_metadata_cap() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let aptos_treasury_cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let mut aptos_metadata = scenario.take_shared<CoinMetadata<APTOS>>(); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (aptos_treasury_cap_v2, _) = ipx_coin::new(aptos_treasury_cap, scenario.ctx());

    let (eth_treasury_cap_v2, mut eth_cap_witness) = ipx_coin::new(eth_treasury_cap, scenario.ctx());

    let eth_metadata_cap = eth_cap_witness.create_metadata_cap(scenario.ctx());

    aptos_treasury_cap_v2.update_name<APTOS>(
        &mut aptos_metadata,
        &eth_metadata_cap,
        b"Aptos V2".to_string()
    ); 

    destroy(scenario); 
    destroy(aptos_metadata);
    destroy(aptos_treasury_cap_v2);
    destroy(eth_treasury_cap_v2);
    eth_metadata_cap.destroy();
}

#[test] 
#[expected_failure(abort_code = ipx_coin::EInvalidCap)]
fun test_invalid_mint_cap() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let aptos_treasury_cap = scenario.take_from_sender<TreasuryCap<APTOS>>();

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (mut aptos_treasury_cap_v2, _) = ipx_coin::new(aptos_treasury_cap, scenario.ctx());

    let (eth_treasury_cap_v2, mut eth_cap_witness) = ipx_coin::new(eth_treasury_cap, scenario.ctx());

    let eth_mint_cap = eth_cap_witness.create_mint_cap(scenario.ctx());

    let aptos_coin = eth_mint_cap.mint<APTOS>(&mut aptos_treasury_cap_v2, 100, scenario.ctx());

    destroy(scenario); 
    destroy(aptos_coin);
    destroy(aptos_treasury_cap_v2);
    destroy(eth_treasury_cap_v2);
    eth_mint_cap.destroy();
}

#[test] 
#[expected_failure(abort_code = ipx_coin::EInvalidCap)]
fun test_invalid_burn_cap() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();

    let eth_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut aptos_treasury_cap_v2, _) = ipx_coin::new(cap, scenario.ctx());

    let (eth_treasury_cap_v2, mut eth_cap_witness) = ipx_coin::new(eth_cap, scenario.ctx());

    let eth_burn_cap = eth_cap_witness.create_burn_cap(scenario.ctx());

    eth_burn_cap.burn<APTOS>(&mut aptos_treasury_cap_v2, aptos_coin);

    destroy(scenario); 
    destroy(aptos_treasury_cap_v2);
    destroy(eth_treasury_cap_v2);
    eth_burn_cap.destroy();
}

#[test]
#[expected_failure(abort_code = ipx_coin::ECapAlreadyCreated)]
fun test_mint_cap_already_created() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = ipx_coin::new(eth_treasury_cap, scenario.ctx());

    let mint_cap = witness.create_mint_cap(scenario.ctx()); 
    let mint_cap_2 = witness.create_mint_cap(scenario.ctx());


    mint_cap.destroy();
    mint_cap_2.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}

#[test]
#[expected_failure(abort_code = ipx_coin::ECapAlreadyCreated)]
fun test_burn_cap_already_created() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = ipx_coin::new(eth_treasury_cap, scenario.ctx());

    let burn_cap = witness.create_burn_cap(scenario.ctx());
    let burn_cap_2 = witness.create_burn_cap(scenario.ctx());

    burn_cap.destroy();
    burn_cap_2.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}

#[test]
#[expected_failure(abort_code = ipx_coin::ECapAlreadyCreated)]
fun test_metadata_cap_already_created() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = ipx_coin::new(eth_treasury_cap, scenario.ctx());

    let metadata_cap = witness.create_metadata_cap(scenario.ctx());
    let metadata_cap_2 = witness.create_metadata_cap(scenario.ctx());

    metadata_cap.destroy();
    metadata_cap_2.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}