-- ============================================================================
-- DATABASE INITIALIZATION & TUNING
-- ============================================================================
DROP DATABASE IF EXISTS bpcl_dallirajhara_db;
CREATE DATABASE bpcl_dallirajhara_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bpcl_dallirajhara_db;

SET foreign_key_checks = 0;
DROP TABLE IF EXISTS fact_dispenser_sales;
DROP TABLE IF EXISTS fact_fuel_procurement;
DROP TABLE IF EXISTS fact_daily_operating_expense;
DROP TABLE IF EXISTS fact_daily_tank_dip;
DROP TABLE IF EXISTS dim_nozzle_dispenser;
DROP TABLE IF EXISTS dim_fuel_tank;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_shift;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS audit_price_changes;
SET foreign_key_checks = 1;

-- ============================================================================
-- 1. DIMENSION TABLES
-- ============================================================================

CREATE TABLE dim_date (
    date_id INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_number TINYINT NOT NULL,
    day_name VARCHAR(10) NOT NULL,
    month_number TINYINT NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    quarter TINYINT NOT NULL,
    year_val SMALLINT NOT NULL,
    is_weekend BOOLEAN NOT NULL DEFAULT 0,
    is_holiday BOOLEAN NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE dim_product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sap_material_code VARCHAR(20) NOT NULL UNIQUE,
    product_name VARCHAR(60) NOT NULL,
    category ENUM('FUEL', 'LUBRICANT') NOT NULL,
    unit_of_measure VARCHAR(10) NOT NULL,
    current_cost_price DECIMAL(10, 4) NOT NULL,
    current_selling_price DECIMAL(10, 4) NOT NULL,
    dealer_commission_per_unit DECIMAL(8, 4) NOT NULL,
    cg_vat_percentage DECIMAL(5, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE dim_customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    sap_customer_code VARCHAR(20) NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    customer_type ENUM('RETAIL_CASH', 'UPI_DIGITAL', 'CORPORATE_FLEET', 'MINING_SAIL') NOT NULL,
    credit_limit DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    outstanding_balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_terms_days INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE dim_shift (
    shift_id INT PRIMARY KEY,
    shift_code VARCHAR(10) NOT NULL UNIQUE,
    shift_name VARCHAR(30) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    supervisor_in_charge VARCHAR(60) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE dim_fuel_tank (
    tank_id INT AUTO_INCREMENT PRIMARY KEY,
    tank_number VARCHAR(10) NOT NULL UNIQUE,
    product_id INT NOT NULL,
    total_capacity_litres DECIMAL(10, 2) NOT NULL,
    dead_stock_litres DECIMAL(8, 2) NOT NULL,
    current_dip_stock_litres DECIMAL(10, 2) NOT NULL,
    reorder_level_litres DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_tank_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
) ENGINE=InnoDB;

CREATE TABLE dim_nozzle_dispenser (
    nozzle_id INT AUTO_INCREMENT PRIMARY KEY,
    dispenser_unit_code VARCHAR(10) NOT NULL,
    nozzle_number VARCHAR(10) NOT NULL UNIQUE,
    tank_id INT NOT NULL,
    product_id INT NOT NULL,
    totalizer_reading_start DECIMAL(12, 2) NOT NULL,
    is_operational BOOLEAN NOT NULL DEFAULT 1,
    CONSTRAINT fk_nozzle_tank FOREIGN KEY (tank_id) REFERENCES dim_fuel_tank(tank_id),
    CONSTRAINT fk_nozzle_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
) ENGINE=InnoDB;

CREATE TABLE audit_price_changes (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    old_selling_price DECIMAL(10, 4) NOT NULL,
    new_selling_price DECIMAL(10, 4) NOT NULL,
    changed_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50) DEFAULT 'SAP_INTERFACE'
) ENGINE=InnoDB;

-- ============================================================================
-- 2. FACT TABLES
-- ============================================================================

CREATE TABLE fact_daily_tank_dip (
    dip_fact_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_id INT NOT NULL,
    tank_id INT NOT NULL,
    opening_dip_litres DECIMAL(10, 2) NOT NULL,
    inward_receipt_litres DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    metered_sale_litres DECIMAL(10, 2) NOT NULL,
    closing_dip_litres DECIMAL(10, 2) NOT NULL,
    shrinkage_loss_litres DECIMAL(8, 2) GENERATED ALWAYS AS (
        (opening_dip_litres + inward_receipt_litres) - metered_sale_litres - closing_dip_litres
    ) STORED,
    CONSTRAINT fk_dip_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    CONSTRAINT fk_dip_tank FOREIGN KEY (tank_id) REFERENCES dim_fuel_tank(tank_id),
    INDEX idx_dip_date_tank (date_id, tank_id)
) ENGINE=InnoDB;

CREATE TABLE fact_fuel_procurement (
    procurement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sap_po_number VARCHAR(20) NOT NULL,
    sap_migo_number VARCHAR(20) NOT NULL,
    date_id INT NOT NULL,
    product_id INT NOT NULL,
    tank_id INT NOT NULL,
    tanker_truck_number VARCHAR(20) NOT NULL,
    invoice_volume_litres DECIMAL(10, 2) NOT NULL,
    actual_received_litres DECIMAL(10, 2) NOT NULL,
    transit_loss_litres DECIMAL(8, 2) GENERATED ALWAYS AS (invoice_volume_litres - actual_received_litres) STORED,
    cost_per_litre DECIMAL(10, 4) NOT NULL,
    freight_charges DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    total_invoice_amount DECIMAL(14, 2) NOT NULL,
    payment_status ENUM('PAID', 'PENDING', 'BPCL_DEPOSIT_CLEARED') NOT NULL,
    CONSTRAINT fk_proc_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    CONSTRAINT fk_proc_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    CONSTRAINT fk_proc_tank FOREIGN KEY (tank_id) REFERENCES dim_fuel_tank(tank_id),
    INDEX idx_proc_date (date_id)
) ENGINE=InnoDB;

CREATE TABLE fact_dispenser_sales (
    sale_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_uuid VARCHAR(64) NOT NULL UNIQUE,
    sap_billing_doc VARCHAR(20),
    date_id INT NOT NULL,
    sale_timestamp DATETIME NOT NULL,
    shift_id INT NOT NULL,
    nozzle_id INT NOT NULL,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    volume_sold_litres DECIMAL(10, 2) NOT NULL,
    unit_cost_price DECIMAL(10, 4) NOT NULL,
    unit_selling_price DECIMAL(10, 4) NOT NULL,
    dealer_margin_per_litre DECIMAL(8, 4) NOT NULL,
    gross_revenue DECIMAL(12, 2) GENERATED ALWAYS AS (volume_sold_litres * unit_selling_price) STORED,
    dealer_gross_margin DECIMAL(12, 2) GENERATED ALWAYS AS (volume_sold_litres * dealer_margin_per_litre) STORED,
    total_cost_of_goods DECIMAL(12, 2) GENERATED ALWAYS AS (volume_sold_litres * unit_cost_price) STORED,
    payment_mode ENUM('CASH', 'UPI', 'POS_CARD', 'FLEET_CREDIT') NOT NULL,
    is_mining_truck BOOLEAN NOT NULL DEFAULT 0,
    CONSTRAINT fk_sale_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    CONSTRAINT fk_sale_shift FOREIGN KEY (shift_id) REFERENCES dim_shift(shift_id),
    CONSTRAINT fk_sale_nozzle FOREIGN KEY (nozzle_id) REFERENCES dim_nozzle_dispenser(nozzle_id),
    CONSTRAINT fk_sale_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    CONSTRAINT fk_sale_customer FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    INDEX idx_sale_perf (date_id, shift_id, product_id),
    INDEX idx_sale_timestamp (sale_timestamp)
) ENGINE=InnoDB;

CREATE TABLE fact_daily_operating_expense (
    expense_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_id INT NOT NULL,
    shift_id INT,
    electricity_cseb_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    generator_diesel_burn_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    staff_forecourt_wages DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    testing_calibration_fuel_cost DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    credit_card_mdr_charges DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    evaporation_shrinkage_cost DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    miscellaneous_expenses DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    total_daily_opex DECIMAL(12, 2) GENERATED ALWAYS AS (
        electricity_cseb_amount + generator_diesel_burn_amount + 
        staff_forecourt_wages + testing_calibration_fuel_cost + 
        credit_card_mdr_charges + evaporation_shrinkage_cost + miscellaneous_expenses
    ) STORED,
    CONSTRAINT fk_opex_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    CONSTRAINT fk_opex_shift FOREIGN KEY (shift_id) REFERENCES dim_shift(shift_id),
    INDEX idx_opex_date (date_id)
) ENGINE=InnoDB;

-- ============================================================================
-- 3. TRIGGERS & PROCEDURES
-- ============================================================================

DELIMITER $$

CREATE TRIGGER trg_after_sale_update_stock
AFTER INSERT ON fact_dispenser_sales
FOR EACH ROW
BEGIN
    UPDATE dim_fuel_tank t
    JOIN dim_nozzle_dispenser n ON t.tank_id = n.tank_id
    SET t.current_dip_stock_litres = t.current_dip_stock_litres - NEW.volume_sold_litres
    WHERE n.nozzle_id = NEW.nozzle_id;
END$$

CREATE TRIGGER trg_audit_fuel_price_update
BEFORE UPDATE ON dim_product
FOR EACH ROW
BEGIN
    IF OLD.current_selling_price <> NEW.current_selling_price THEN
        INSERT INTO audit_price_changes (product_id, old_selling_price, new_selling_price)
        VALUES (OLD.product_id, OLD.current_selling_price, NEW.current_selling_price);
    END IF;
END$$

CREATE PROCEDURE sp_calculate_daily_operating_profit(IN query_date DATE)
BEGIN
    DECLARE target_date_id INT;
    SET target_date_id = CAST(DATE_FORMAT(query_date, '%Y%m%d') AS UNSIGNED);

    WITH SalesSummary AS (
        SELECT 
            s.date_id,
            SUM(s.gross_revenue) AS total_gross_turnover,
            SUM(s.total_cost_of_goods) AS total_cogs,
            SUM(s.dealer_gross_margin) AS total_dealer_commission,
            SUM(CASE WHEN s.payment_mode = 'FLEET_CREDIT' THEN s.gross_revenue ELSE 0 END) AS credit_turnover,
            SUM(CASE WHEN s.payment_mode IN ('CASH', 'UPI', 'POS_CARD') THEN s.gross_revenue ELSE 0 END) AS cash_digital_collected,
            SUM(s.volume_sold_litres) AS total_fuel_litres_dispensed
        FROM fact_dispenser_sales s
        WHERE s.date_id = target_date_id
        GROUP BY s.date_id
    ),
    OpexSummary AS (
        SELECT 
            e.date_id,
            SUM(e.total_daily_opex) AS total_station_operating_cost,
            SUM(e.generator_diesel_burn_amount) AS total_dg_fuel_cost,
            SUM(e.staff_forecourt_wages) AS total_salaries_paid,
            SUM(e.evaporation_shrinkage_cost) AS total_shrinkage_loss_cost
        FROM fact_daily_operating_expense e
        WHERE e.date_id = target_date_id
        GROUP BY e.date_id
    )
    SELECT 
        d.full_date,
        COALESCE(ss.total_fuel_litres_dispensed, 0.00) AS total_litres_dispensed,
        COALESCE(ss.total_gross_turnover, 0.00) AS gross_revenue_inr,
        COALESCE(ss.total_cogs, 0.00) AS bpcl_inventory_cogs_inr,
        COALESCE(ss.total_dealer_commission, 0.00) AS total_dealer_gross_margin_inr,
        COALESCE(op.total_station_operating_cost, 0.00) AS station_operating_expenses_inr,
        (COALESCE(ss.total_dealer_commission, 0.00) - COALESCE(op.total_station_operating_cost, 0.00)) AS net_daily_operating_profit_inr,
        ROUND(((COALESCE(ss.total_dealer_commission, 0.00) - COALESCE(op.total_station_operating_cost, 0.00)) / NULLIF(ss.total_gross_turnover, 0)) * 100, 2) AS net_profit_percentage_on_turnover,
        COALESCE(ss.cash_digital_collected, 0.00) AS liquid_cashflow_collected,
        COALESCE(ss.credit_turnover, 0.00) AS receivable_unrealized_credit
    FROM dim_date d
    LEFT JOIN SalesSummary ss ON d.date_id = ss.date_id
    LEFT JOIN OpexSummary op ON d.date_id = op.date_id
    WHERE d.date_id = target_date_id;
END$$

DELIMITER ;

-- ============================================================================
-- 4. SEED DATA
-- ============================================================================

INSERT INTO dim_date (date_id, full_date, day_number, day_name, month_number, month_name, quarter, year_val, is_weekend, is_holiday)
VALUES 
(20261101, '2026-11-01', 1, 'Sunday', 11, 'November', 4, 2026, 1, 0),
(20261102, '2026-11-02', 2, 'Monday', 11, 'November', 4, 2026, 0, 0),
(20261103, '2026-11-03', 3, 'Tuesday', 11, 'November', 4, 2026, 0, 0);

INSERT INTO dim_product (product_id, sap_material_code, product_name, category, unit_of_measure, current_cost_price, current_selling_price, dealer_commission_per_unit, cg_vat_percentage)
VALUES 
(1, 'MAT-MS-101', 'Petrol (Motor Spirit 91)', 'FUEL', 'L', 97.4000, 101.8100, 4.4100, 24.00),
(2, 'MAT-HSD-201', 'High Speed Diesel (BS-VI)', 'FUEL', 'L', 91.5000, 94.4900, 2.9900, 19.50),
(3, 'MAT-SPD-301', 'Speed Premium Petrol', 'FUEL', 'L', 101.2000, 106.8500, 5.6500, 24.00),
(4, 'MAT-LUB-401', 'MAK Diamond 15W-40 5L', 'LUBRICANT', 'EA', 1350.0000, 1750.0000, 400.0000, 18.00);

INSERT INTO dim_customer (customer_id, sap_customer_code, customer_name, customer_type, credit_limit, outstanding_balance, payment_terms_days, is_active)
VALUES 
(1, 'CUST-CASH-00', 'Forecourt Retail Cash/Walk-in', 'RETAIL_CASH', 0.00, 0.00, 0, 1),
(2, 'CUST-UPI-01', 'Forecourt UPI / QR Customer', 'UPI_DIGITAL', 0.00, 0.00, 0, 1),
(3, 'CUST-SAIL-100', 'SAIL Dalli Rajhara Iron Ore Mines', 'MINING_SAIL', 6000000.00, 1845000.00, 30, 1),
(4, 'CUST-LOGI-200', 'Chhattisgarh Earthmovers Fleet', 'CORPORATE_FLEET', 2000000.00, 720000.00, 15, 1);

INSERT INTO dim_shift (shift_id, shift_code, shift_name, start_time, end_time, supervisor_in_charge)
VALUES 
(1, 'SH-MOR', 'Morning Shift (06:00 - 14:00)', '06:00:00', '14:00:00', 'Ramesh Verma'),
(2, 'SH-EVE', 'Evening Shift (14:00 - 22:00)', '14:00:00', '22:00:00', 'Suresh Sahu'),
(3, 'SH-NIG', 'Night Mining Shift (22:00 - 06:00)', '22:00:00', '06:00:00', 'Amitabh Pradhan');

INSERT INTO dim_fuel_tank (tank_id, tank_number, product_id, total_capacity_litres, dead_stock_litres, current_dip_stock_litres, reorder_level_litres)
VALUES 
(1, 'TK-MS-01', 1, 20000.00, 1500.00, 16200.00, 5000.00),
(2, 'TK-HSD-01', 2, 25000.00, 2000.00, 22400.00, 7000.00),
(3, 'TK-HSD-02', 2, 25000.00, 2000.00, 19800.00, 7000.00),
(4, 'TK-SPD-01', 3, 15000.00, 1000.00, 11500.00, 3000.00);

INSERT INTO dim_nozzle_dispenser (nozzle_id, dispenser_unit_code, nozzle_number, tank_id, product_id, totalizer_reading_start, is_operational)
VALUES 
(1, 'MPD-01', 'NZ-01-MS', 1, 1, 412030.00, 1),
(2, 'MPD-01', 'NZ-02-HSD', 2, 2, 856940.00, 1),
(3, 'MPD-02', 'NZ-03-HSD', 2, 2, 912340.00, 1),
(4, 'MPD-02', 'NZ-04-HSD', 3, 2, 654210.00, 1),
(5, 'MPD-03', 'NZ-05-SPD', 4, 3, 120450.00, 1),
(6, 'MPD-03', 'NZ-06-HSD', 3, 2, 498300.00, 1);

INSERT INTO fact_dispenser_sales 
(transaction_uuid, sap_billing_doc, date_id, sale_timestamp, shift_id, nozzle_id, product_id, customer_id, volume_sold_litres, unit_cost_price, unit_selling_price, dealer_margin_per_litre, payment_mode, is_mining_truck)
VALUES 
(UUID(), '90001021', 20261102, '2026-11-02 06:45:10', 1, 1, 1, 2, 15.00, 97.4000, 101.8100, 4.4100, 'UPI', 0),
(UUID(), '90001022', 20261102, '2026-11-02 07:15:33', 1, 2, 2, 4, 250.00, 91.5000, 94.4900, 2.9900, 'FLEET_CREDIT', 1),
(UUID(), '90001023', 20261102, '2026-11-02 11:20:05', 1, 3, 2, 3, 400.00, 91.5000, 94.4900, 2.9900, 'FLEET_CREDIT', 1),
(UUID(), '90001024', 20261102, '2026-11-02 16:30:12', 2, 1, 1, 1, 35.00, 97.4000, 101.8100, 4.4100, 'CASH', 0),
(UUID(), '90001025', 20261102, '2026-11-02 18:45:50', 2, 5, 3, 2, 40.00, 101.2000, 106.8500, 5.6500, 'UPI', 0),
(UUID(), '90001026', 20261102, '2026-11-02 23:10:14', 3, 4, 2, 3, 500.00, 91.5000, 94.4900, 2.9900, 'FLEET_CREDIT', 1),
(UUID(), '90001027', 20261102, '2026-11-03 02:40:22', 3, 6, 2, 3, 450.00, 91.5000, 94.4900, 2.9900, 'FLEET_CREDIT', 1);

INSERT INTO fact_daily_tank_dip (date_id, tank_id, opening_dip_litres, inward_receipt_litres, metered_sale_litres, closing_dip_litres)
VALUES 
(20261102, 1, 16250.00, 0.00, 50.00, 16190.00),
(20261102, 2, 24000.00, 0.00, 650.00, 23340.00),
(20261102, 3, 21000.00, 0.00, 950.00, 20035.00);

INSERT INTO fact_daily_operating_expense 
(date_id, shift_id, electricity_cseb_amount, generator_diesel_burn_amount, staff_forecourt_wages, testing_calibration_fuel_cost, credit_card_mdr_charges, evaporation_shrinkage_cost, miscellaneous_expenses)
VALUES 
(20261102, 1, 1400.00, 1200.00, 2400.00, 472.00, 185.00, 944.90, 300.00),
(20261102, 2, 1800.00, 1400.00, 2400.00, 0.00, 290.00, 0.00, 200.00),
(20261102, 3, 1100.00, 1800.00, 2600.00, 0.00, 110.00, 1417.35, 250.00);
