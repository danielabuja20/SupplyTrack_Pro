# SupplyTrack_Pro
 
# SupplyTrack Pro

A decentralized supply chain verification and tracking system built on Stacks blockchain using Clarity smart contracts.

## Overview

SupplyTrack Pro provides a robust solution for supply chain management with features including product tracking, supplier verification, and inventory management. The system enables transparent and immutable record-keeping of supply chain operations.

## Features

- **Product Tracking**
  - Unique product identification
  - Product status monitoring
  - Timestamp tracking
  - Verification status

- **Supplier Management** 
  - Supplier registration
  - Verification system
  - Product count tracking
  - Authorization controls

- **Inventory Control**
  - Real-time quantity tracking
  - Update history
  - Automated timestamp logging

## Smart Contract Functions

### Public Functions

1. `add-product`
   - Adds new products to the system
   - Parameters: product-id (uint), name (string-ascii)
   - Requires supplier authorization

2. `register-supplier`
   - Registers new suppliers in the system
   - Parameters: name (string-ascii)
   - Creates supplier profile with verification status

3. `update-inventory`
   - Updates product inventory levels
   - Parameters: product-id (uint), quantity (uint)
   - Restricted to authorized suppliers

### Read-Only Functions

1. `is-supplier`
   - Verifies if an address is a registered supplier
   - Parameters: address (principal)

2. `get-product-details`
   - Retrieves complete product information
   - Parameters: product-id (uint)

3. `get-supplier-details`
   - Fetches supplier profile information
   - Parameters: supplier (principal)

4. `get-inventory-level`
   - Checks current inventory levels
   - Parameters: product-id (uint)