# BPCL Retail Outlet Analytics - Dalli Rajhara, Chhattisgarh (PIN: 491228)
## 24x7 Net Daily Operating Profit Calculation Architecture

### End-to-End Pipeline
1. **SAP S/4HANA (SD & MM):** Forecourt billing, bulk B2B credit orders (SAIL mining fleet), tank receipts, and stock postings.
2. **ETL Staging Engine:** RFC/IDoc (ORDERS, INVOIC, MBGMCR) to JSON/JDBC ingestion.
3. **MySQL 8.0 DW:** Star schema warehouse storing transactions, shift schedules, nozzle totalizers, and dip calibrations.
4. **Power BI Analytical Layer:** DirectQuery/Import hybrid model with custom DAX calculating net operating margins.

### SAP Enterprise Structure
- Company Code: 1000 (BPCL Retail West/Central)
- Sales Org: 1100 (BPCL Retail Raipur Territory)
- Distribution Channels: 10 (Forecourt Retail), 20 (Mining/Institutional Bulk)
- Divisions: 01 (Motor Spirit & HSD), 02 (Lubricants & Grease)
- Plant: CG01 (Dalli Rajhara Retail Outlet & Tank Farm)
- Storage Locations:
  - TK01: Tank 01 MS (Petrol - 20,000 L)
  - TK02: Tank 02 HSD (Diesel A - 25,000 L)
  - TK03: Tank 03 HSD (Diesel B - 25,000 L)
  - TK04: Tank 04 Speed (High Octane - 15,000 L)
  - LB01: Lube Bay Godown (MAK Lubricants)

### Verification Checkpoints
- Daily dispenser totalizer readings reconcile against SAP VF01 billing docs.
- Physical dipstick shrinkage reconciled via SAP MM movement types 551 (Scrapping) or 701/702 (Inventory Variance).
- Direct deterministic decimal arithmetic used for financial metrics (DECIMAL(12, 2)).
