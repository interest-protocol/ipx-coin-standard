module ipx_coin_standard::ipx_coin_standard;

use std::{ascii, string, type_name::{Self, TypeName}};
use sui::{coin::{TreasuryCap, CoinMetadata, Coin}, dynamic_object_field as dof, event::emit};

// === Errors ===

const EInvalidCap: u64 = 0;

const ECapAlreadyCreated: u64 = 1;

const ETreasuryCannotBurn: u64 = 2;

const EInvalidTreasury: u64 = 3;

// === Structs ===

public struct CapWitness {
    treasury: address,
    name: TypeName,
    mint_cap_address: Option<address>,
    burn_cap_address: Option<address>,
    metadata_cap_address: Option<address>,
}

public struct MintCap has key, store {
    id: UID,
    treasury: address,
    name: TypeName,
}

public struct BurnCap has key, store {
    id: UID,
    treasury: address,
    name: TypeName,
}

public struct MetadataCap has key, store {
    id: UID,
    treasury: address,
    name: TypeName,
}

public struct IPXTreasuryStandard has key, store {
    id: UID,
    name: TypeName,
    can_burn: bool,
    metadata_cap: Option<address>,
    mint_cap: Option<address>,
    burn_cap: Option<address>,
}

// === Events ===

public struct New has copy, drop {
    name: TypeName,
    treasury: address,
    ipx_treasury: address,
}

public struct Mint has drop, copy (TypeName, u64)

public struct Burn has drop, copy (TypeName, u64)

public struct DestroyMintCap has drop, copy (TypeName)

public struct DestroyBurnCap has drop, copy (TypeName)

public struct DestroyMetadataCap has drop, copy (TypeName)

// === Public Mutative ===

public fun new<T>(cap: TreasuryCap<T>, ctx: &mut TxContext): (IPXTreasuryStandard, CapWitness) {
    let name = type_name::get<T>();

    let mut ipx_treasury_standard = IPXTreasuryStandard {
        id: object::new(ctx),
        name,
        can_burn: false,
        metadata_cap: option::none(),
        mint_cap: option::none(),
        burn_cap: option::none(),
    };

    let ipx_treasury = ipx_treasury_standard.id.to_address();
    let treasury = object::id_address(&cap);

    dof::add(&mut ipx_treasury_standard.id, name, cap);

    emit(New {
        name,
        treasury,
        ipx_treasury,
    });

    (
        ipx_treasury_standard,
        CapWitness {
            treasury: ipx_treasury,
            name,
            mint_cap_address: option::none(),
            burn_cap_address: option::none(),
            metadata_cap_address: option::none(),
        },
    )
}

// === Capabilities API ===

public fun create_mint_cap(witness: &mut CapWitness, ctx: &mut TxContext): MintCap {
    assert!(witness.mint_cap_address.is_none(), ECapAlreadyCreated);

    let id = object::new(ctx);

    witness.mint_cap_address = option::some(id.to_address());

    MintCap {
        id,
        treasury: witness.treasury,
        name: witness.name,
    }
}

public fun create_burn_cap(witness: &mut CapWitness, ctx: &mut TxContext): BurnCap {
    assert!(witness.burn_cap_address.is_none(), ECapAlreadyCreated);

    let id = object::new(ctx);

    witness.burn_cap_address = option::some(id.to_address());

    BurnCap {
        id,
        treasury: witness.treasury,
        name: witness.name,
    }
}

public fun create_metadata_cap(witness: &mut CapWitness, ctx: &mut TxContext): MetadataCap {
    assert!(witness.metadata_cap_address.is_none(), ECapAlreadyCreated);

    let id = object::new(ctx);

    witness.metadata_cap_address = option::some(id.to_address());

    MetadataCap {
        id,
        treasury: witness.treasury,
        name: witness.name,
    }
}

public fun add_burn_capability(witness: &mut CapWitness, self: &mut IPXTreasuryStandard) {
    assert!(witness.burn_cap_address.is_none(), ECapAlreadyCreated);

    witness.burn_cap_address = option::some(self.id.to_address());

    self.can_burn = true;
}

public fun destroy_cap_witness(self: &mut IPXTreasuryStandard, witness: CapWitness) {
    let CapWitness { mint_cap_address, burn_cap_address, metadata_cap_address, treasury, .. } =
        witness;

    assert!(treasury == self.id.to_address(), EInvalidTreasury);

    self.mint_cap = mint_cap_address;
    self.burn_cap = if (self.can_burn) { option::none() } else { burn_cap_address };
    self.metadata_cap = metadata_cap_address;
}

public fun destroy_mint_cap(self: &mut IPXTreasuryStandard, cap: MintCap) {
    let MintCap { id, name, treasury } = cap;

    assert!(treasury == self.id.to_address(), EInvalidTreasury);

    self.mint_cap = option::none();

    emit(DestroyMintCap(name));

    id.delete();
}

public fun destroy_burn_cap(self: &mut IPXTreasuryStandard, cap: BurnCap) {
    let BurnCap { id, name, treasury } = cap;

    assert!(treasury == self.id.to_address(), EInvalidTreasury);

    self.burn_cap = option::none();

    emit(DestroyBurnCap(name));

    id.delete();
}

public fun destroy_metadata_cap(self: &mut IPXTreasuryStandard,cap: MetadataCap) {
    let MetadataCap { id, name, treasury } = cap;

    assert!(treasury == self.id.to_address(), EInvalidTreasury);

    self.metadata_cap = option::none();

    emit(DestroyMetadataCap(name));

    id.delete();
}

// === Mint/Burn API === 

public fun mint<T>(
    cap: &MintCap,
    self: &mut IPXTreasuryStandard,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(cap.treasury == self.id.to_address(), EInvalidCap);

    emit(Mint(self.name, amount));

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    cap.mint(amount, ctx)
}

public fun cap_burn<T>(cap: &BurnCap, self: &mut IPXTreasuryStandard, coin: Coin<T>) {
    assert!(cap.treasury == self.id.to_address(), EInvalidCap);

    emit(Burn(self.name, coin.value()));

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    cap.burn(coin);
}

public fun treasury_burn<T>(self: &mut IPXTreasuryStandard, coin: Coin<T>) {
    assert!(self.can_burn, ETreasuryCannotBurn);

    emit(Burn(self.name, coin.value()));

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    cap.burn(coin);
}

// === Metadata API ===

public fun update_name<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    name: string::String,
) {
    assert!(cap.treasury == self.id.to_address(), EInvalidCap);

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_name(metadata, name);
}

public fun update_symbol<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    symbol: ascii::String,
) {
    assert!(cap.treasury == self.id.to_address(), EInvalidCap);

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_symbol(metadata, symbol);
}

public fun update_description<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    description: string::String,
) {
    assert!(cap.treasury == self.id.to_address(), EInvalidCap);

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_description(metadata, description);
}

public fun update_icon_url<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    url: ascii::String,
) {
    assert!(cap.treasury == self.id.to_address(), EInvalidCap);

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_icon_url(metadata, url);
}

// === Public View Functions ===

public fun total_supply<T>(self: &IPXTreasuryStandard): u64 {
    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.total_supply()
}

public fun can_burn(self: &IPXTreasuryStandard): bool {
    self.can_burn
}

public fun cap_witness_treasury(witness: &CapWitness): address {
    witness.treasury
}

public fun mint_cap_treasury(cap: &MintCap): address {
    cap.treasury
}

public fun burn_cap_treasury(cap: &BurnCap): address {
    cap.treasury
}

public fun metadata_cap_treasury(cap: &MetadataCap): address {
    cap.treasury
}

public fun treasury_cap_name(cap: &IPXTreasuryStandard): TypeName {
    cap.name
}

public fun cap_witness_name(witness: &CapWitness): TypeName {
    witness.name
}

public fun mint_cap_name(cap: &MintCap): TypeName {
    cap.name
}

public fun burn_cap_name(cap: &BurnCap): TypeName {
    cap.name
}

public fun metadata_cap_name(cap: &MetadataCap): TypeName {
    cap.name
}

public fun mint_cap_address(witness: &CapWitness): Option<address> {
    witness.mint_cap_address
}

public fun burn_cap_address(witness: &CapWitness): Option<address> {
    witness.burn_cap_address
}

public fun metadata_cap_address(witness: &CapWitness): Option<address> {
    witness.metadata_cap_address
}

// === Method Aliases ===

public use fun cap_burn as BurnCap.burn;
public use fun treasury_burn as IPXTreasuryStandard.burn;

public use fun cap_witness_treasury as CapWitness.treasury;
public use fun mint_cap_treasury as MintCap.treasury;
public use fun burn_cap_treasury as BurnCap.treasury;
public use fun metadata_cap_treasury as MetadataCap.treasury;

public use fun treasury_cap_name as IPXTreasuryStandard.name;
public use fun cap_witness_name as CapWitness.name;
public use fun mint_cap_name as MintCap.name;
public use fun burn_cap_name as BurnCap.name;
public use fun metadata_cap_name as MetadataCap.name;

// === Test Functions ===

#[test_only]
public fun treasury_metadata_cap(self: &IPXTreasuryStandard): Option<address> {
    self.metadata_cap
}

#[test_only]
public fun treasury_mint_cap(self: &IPXTreasuryStandard): Option<address> {
    self.mint_cap
}

#[test_only]
public fun treasury_burn_cap(self: &IPXTreasuryStandard): Option<address> {
    self.burn_cap
}
