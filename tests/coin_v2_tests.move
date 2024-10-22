#[test_only]
module coin_v2::treasury_cap_tests;

use std::type_name;

use sui::{
    test_scenario as ts, 
    test_utils::{assert_eq, destroy},
    coin::{Self, TreasuryCap, CoinMetadata}
};

use coin_v2::{ 
    coin_v2,
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

    let (mut treasury_cap, mut witness) = coin_v2::new(cap, scenario.ctx());
    
    assert_eq(witness.mint_cap_address().is_none(), true);
    assert_eq(witness.burn_cap_address().is_none(), true);
    assert_eq(witness.metadata_cap_address().is_none(), true);

    let mint_cap = witness.create_mint_cap(scenario.ctx());
    let burn_cap = witness.create_burn_cap(scenario.ctx());
    let metadata_cap = witness.create_metadata_cap(scenario.ctx()); 

    assert_eq(witness.mint_cap_address().destroy_some(), object::id(&mint_cap).to_address());
    assert_eq(witness.burn_cap_address().destroy_some(), object::id(&burn_cap).to_address());
    assert_eq(witness.metadata_cap_address().destroy_some(), object::id(&metadata_cap).to_address());
    assert_eq(burn_cap.indestructible(), false);

    assert_eq(treasury_cap.name(), name);
    assert_eq(mint_cap.name(), name);
    assert_eq(burn_cap.name(), name);
    assert_eq(metadata_cap.name(), name);

    let aptos_coin = treasury_cap.mint<APTOS>(&mint_cap, 100, scenario.ctx());

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 1);

    assert_eq(treasury_cap.total_supply<APTOS>(), 100);
    assert_eq(aptos_coin.value(), 100);

    treasury_cap.burn<APTOS>(&burn_cap, aptos_coin);

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 1);

    assert_eq(treasury_cap.total_supply<APTOS>(), 0);

    let treasury_address = object::id(&treasury_cap).to_address();

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
#[expected_failure(abort_code = coin_v2::EBurnCapIsIndestructible)]
fun test_burn_cap_is_indestructible() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = coin_v2::new(eth_treasury_cap, scenario.ctx());

    let burn_cap = witness.create_indestructible_burn_cap(scenario.ctx()); 

    assert_eq(burn_cap.indestructible(), true);

    burn_cap.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}

#[test] 
#[expected_failure(abort_code = coin_v2::EInvalidCap)]
fun test_invalid_metadata_cap() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let aptos_treasury_cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let mut aptos_metadata = scenario.take_shared<CoinMetadata<APTOS>>(); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (aptos_treasury_cap_v2, _) = coin_v2::new(aptos_treasury_cap, scenario.ctx());

    let (eth_treasury_cap_v2, mut eth_cap_witness) = coin_v2::new(eth_treasury_cap, scenario.ctx());

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
#[expected_failure(abort_code = coin_v2::EInvalidCap)]
fun test_invalid_mint_cap() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let aptos_treasury_cap = scenario.take_from_sender<TreasuryCap<APTOS>>();

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (mut aptos_treasury_cap_v2, _) = coin_v2::new(aptos_treasury_cap, scenario.ctx());

    let (eth_treasury_cap_v2, mut eth_cap_witness) = coin_v2::new(eth_treasury_cap, scenario.ctx());

    let eth_mint_cap = eth_cap_witness.create_mint_cap(scenario.ctx());

    let aptos_coin = aptos_treasury_cap_v2.mint<APTOS>(&eth_mint_cap, 100, scenario.ctx());

    destroy(scenario); 
    destroy(aptos_coin);
    destroy(aptos_treasury_cap_v2);
    destroy(eth_treasury_cap_v2);
    eth_mint_cap.destroy();
}

#[test] 
#[expected_failure(abort_code = coin_v2::EInvalidCap)]
fun test_invalid_burn_cap() {
    let mut scenario = ts::begin(ADMIN); 

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();

    let eth_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut aptos_treasury_cap_v2, _) = coin_v2::new(cap, scenario.ctx());

    let (eth_treasury_cap_v2, mut eth_cap_witness) = coin_v2::new(eth_cap, scenario.ctx());

    let eth_burn_cap = eth_cap_witness.create_burn_cap(scenario.ctx());

    aptos_treasury_cap_v2.burn<APTOS>(&eth_burn_cap, aptos_coin);

    destroy(scenario); 
    destroy(aptos_treasury_cap_v2);
    destroy(eth_treasury_cap_v2);
    eth_burn_cap.destroy();
}

#[test]
#[expected_failure(abort_code = coin_v2::ECapAlreadyCreated)]
fun test_mint_cap_already_created() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = coin_v2::new(eth_treasury_cap, scenario.ctx());

    let mint_cap = witness.create_mint_cap(scenario.ctx()); 
    let mint_cap_2 = witness.create_mint_cap(scenario.ctx());


    mint_cap.destroy();
    mint_cap_2.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}

#[test]
#[expected_failure(abort_code = coin_v2::ECapAlreadyCreated)]
fun test_burn_cap_already_created() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = coin_v2::new(eth_treasury_cap, scenario.ctx());

    let burn_cap = witness.create_burn_cap(scenario.ctx());
    let burn_cap_2 = witness.create_burn_cap(scenario.ctx());

    burn_cap.destroy();
    burn_cap_2.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}

#[test]
#[expected_failure(abort_code = coin_v2::ECapAlreadyCreated)]
fun test_metadata_cap_already_created() {
    let mut scenario = ts::begin(ADMIN); 

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (treasury_cap_v2, mut witness) = coin_v2::new(eth_treasury_cap, scenario.ctx());

    let metadata_cap = witness.create_metadata_cap(scenario.ctx());
    let metadata_cap_2 = witness.create_metadata_cap(scenario.ctx());

    metadata_cap.destroy();
    metadata_cap_2.destroy();
    destroy(scenario); 
    destroy(treasury_cap_v2);
}