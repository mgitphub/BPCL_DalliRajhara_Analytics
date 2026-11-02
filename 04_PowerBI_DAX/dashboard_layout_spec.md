# Power BI Dashboard Specification: Dalli Rajhara Retail Outlet

## Theme Settings
- Background: `#0B132B` (Dark Forecourt Night Ops)
- Primary Accent: `#FFD000` (BPCL Yellow)
- Secondary Accent: `#004B87` (BPCL Blue)
- KPI Cards: Transparent background with `#1C2541` borders

## Page Canvas: 1920x1080 (16:9)

### Row 1: Executive KPI Ribbon (Cards)
- `Total Volume Sold (L)`
- `Total Gross Turnover`
- `Dealer Gross Commission`
- `Station Total Opex`
- `Net Daily Operating Profit`
- `Total Tank Evaporation Loss (L)`

### Row 2: Operational Breakdowns
- **Visual 1 (Left - 60% Width):** Line and Clustered Column Chart
  - X-Axis: `dim_shift[shift_name]` & `fact_dispenser_sales[sale_timestamp]` (Hourly)
  - Column Y-Axis: `Total Volume Sold (L)`
  - Line Y-Axis: `Dealer Gross Commission`
- **Visual 2 (Right - 40% Width):** Donut & Scatter Plot Matrix
  - Donut: Contribution percentage by `dim_product[product_name]`
  - Scatter: X = `Volume Sold`, Y = `Dealer Gross Margin`, Legend = `dim_customer[customer_type]`

### Row 3: Inventory Gauges & Working Capital Control
- **Visual 3 (Left - 50% Width):** Underground Tank Calibration & Stock Levels
  - Visual: Radial Gauge or Bullet Chart per tank (`TK-MS-01`, `TK-HSD-01`, `TK-HSD-02`, `TK-SPD-01`)
  - Value: `dim_fuel_tank[current_dip_stock_litres]`
  - Target: `dim_fuel_tank[reorder_level_litres]`
- **Visual 4 (Right - 50% Width):** 100% Stacked Bar Chart (Cashflow & Fleet Exposure)
  - Axis: `dim_date[full_date]`
  - Values: Cash/UPI Realized vs. Mining Credit Exposure (`SAIL Dalli Rajhara`)
