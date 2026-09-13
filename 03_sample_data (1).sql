-- =========================================================================
-- Sample data for demo / testing. Run AFTER 01_schema.sql and 02_plsql_logic.sql.
-- IDs are left NULL where a trigger auto-generates them.
-- =========================================================================

-- Lookup tables
INSERT INTO Pincode_Info VALUES ('400001', 'Mumbai', 'Maharashtra');
INSERT INTO Pincode_Info VALUES ('302001', 'Jaipur', 'Rajasthan');
INSERT INTO Pincode_Info VALUES ('560001', 'Bengaluru', 'Karnataka');

INSERT INTO Category VALUES ('Dairy', 'Milk, cheese, yogurt', 'Perishable');
INSERT INTO Category VALUES ('Produce', 'Fruits and vegetables', 'Perishable');
INSERT INTO Category VALUES ('Snacks', 'Packaged snacks', 'Non-perishable');

INSERT INTO Warehouse VALUES ('W001', 'Mumbai Central', 5000);
INSERT INTO Warehouse VALUES ('W002', 'Bengaluru East', 6000);

INSERT INTO Payment_Method VALUES ('UPI', 50000, 'Yes');
INSERT INTO Payment_Method VALUES ('Card', 100000, 'Yes');
INSERT INTO Payment_Method VALUES ('COD', 5000, 'Yes');
INSERT INTO Payment_Method VALUES ('Wallet', 20000, 'Yes');

INSERT INTO Delivery_Agent VALUES ('A001', 'MH12AB1234', '9876543210', 'Available');
INSERT INTO Delivery_Agent VALUES ('A002', 'MH12CD5678', '9876543211', 'Available');

-- Customers
INSERT INTO Customer (Customer_Name, Reg_Date, Phone_No) VALUES ('Shardul Sharma', SYSDATE, '9000000001');
INSERT INTO Customer (Customer_Name, Reg_Date, Phone_No) VALUES ('Priya Nair', SYSDATE, '9000000002');
COMMIT;

-- Addresses (composite key: Customer_ID, Line_No)
INSERT INTO Address VALUES ('C001', 'L1', '400001');
INSERT INTO Address VALUES ('C002', 'L1', '560001');

-- Products
INSERT INTO Product (Product_Name, Price_Of_Item, Category_Name) VALUES ('Toned Milk 1L', 60, 'Dairy');
INSERT INTO Product (Product_Name, Price_Of_Item, Category_Name) VALUES ('Banana (dozen)', 50, 'Produce');
INSERT INTO Product (Product_Name, Price_Of_Item, Category_Name) VALUES ('Potato Chips', 20, 'Snacks');
COMMIT;

-- Stock placement
INSERT INTO Stored_In_Slot VALUES ('W001', 'S1', 'P001');
INSERT INTO Stored_In_Qty  VALUES ('W001', 'S1', 200);
INSERT INTO Stored_In_Slot VALUES ('W001', 'S2', 'P002');
INSERT INTO Stored_In_Qty  VALUES ('W001', 'S2', 150);

-- Delivery schedule
INSERT INTO Delivery_Schedule VALUES ('T001', '09:00-11:00', 'Scheduled', 'A001');
INSERT INTO Delivery_Schedule VALUES ('T002', '11:00-13:00', 'Scheduled', 'A002');

-- Carts + cart contents (Total_Items / Total_Price auto-maintained by trigger)
INSERT INTO Cart (Customer_ID) VALUES ('C001');
COMMIT;

INSERT INTO Contains VALUES ('CT001', 'P001', 60, 2);   -- 2x Milk
INSERT INTO Contains VALUES ('CT001', 'P003', 20, 3);   -- 3x Chips
COMMIT;

-- Check the trigger worked:
-- SELECT * FROM Cart WHERE Cart_ID = 'CT001';
-- Expect Total_Items = 5, Total_Price = 180

-- Place an order from that cart via the stored procedure:
-- DECLARE v_order_id VARCHAR2(10);
-- BEGIN sp_place_order('C001', 'CT001', v_order_id); DBMS_OUTPUT.PUT_LINE(v_order_id); END;
-- /
