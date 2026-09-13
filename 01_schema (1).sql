-- =========================================================================
-- Online Grocery Delivery Platform — DA-2 Implementation
-- Schema matches the BCNF-normalized design from DA-1
-- Target: Oracle Database (SQL + PL/SQL)
-- =========================================================================

-- Run this whole file first in SQL*Plus / SQL Developer / Oracle Live SQL.
-- Drop-if-exists guards are included so you can re-run this file cleanly
-- while you're iterating.

-- ---------- Cleanup (safe re-run) ----------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN (
    'CONTAINS','CART','REVIEW','PAYMENT','INVOICE','REFUND','RETURNS',
    'ORDERS','OFFERS','ADDRESS','STORED_IN_QTY','STORED_IN_SLOT',
    'PRODUCT','CATEGORY','WAREHOUSE','DELIVERY_SCHEDULE','DELIVERY_AGENT',
    'PAYMENT_METHOD','PINCODE_INFO','CUSTOMER'
  )) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/

-- ---------- Independent / lookup tables first ----------

CREATE TABLE Pincode_Info (
  Pincode      VARCHAR2(10) PRIMARY KEY,
  City         VARCHAR2(50) NOT NULL,
  State        VARCHAR2(50) NOT NULL
);
-- Split out of ADDRESS: Pincode -> City, State was a BCNF violation
-- (Pincode determines City/State but isn't a key of the whole Address table)

CREATE TABLE Category (
  Category_Name VARCHAR2(50) PRIMARY KEY,
  Description   VARCHAR2(255),
  Items         VARCHAR2(255)
);

CREATE TABLE Warehouse (
  Warehouse_Code VARCHAR2(10) PRIMARY KEY,
  Location       VARCHAR2(100),
  Capacity       NUMBER(10)
);

CREATE TABLE Payment_Method (
  Method_Name       VARCHAR2(20) PRIMARY KEY,
  Transaction_Limit NUMBER(10,2),
  Availability      VARCHAR2(10) DEFAULT 'Yes'
);

CREATE TABLE Delivery_Agent (
  Agent_ID   VARCHAR2(10) PRIMARY KEY,
  Vehicle_No VARCHAR2(20) UNIQUE NOT NULL,
  Phone_No   VARCHAR2(15) UNIQUE NOT NULL,
  Status     VARCHAR2(20) DEFAULT 'Available'
);

-- ---------- Second layer ----------

CREATE TABLE Customer (
  Customer_ID   VARCHAR2(10) PRIMARY KEY,
  Customer_Name VARCHAR2(100) NOT NULL,
  Reg_Date      DATE DEFAULT SYSDATE,
  Phone_No      VARCHAR2(15) UNIQUE NOT NULL
);

CREATE TABLE Address (
  Customer_ID VARCHAR2(10),
  Line_No     VARCHAR2(10),
  Pincode     VARCHAR2(10) NOT NULL,
  PRIMARY KEY (Customer_ID, Line_No),
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID) ON DELETE CASCADE,
  FOREIGN KEY (Pincode) REFERENCES Pincode_Info(Pincode)
);

CREATE TABLE Product (
  Product_ID     VARCHAR2(10) PRIMARY KEY,
  Product_Name   VARCHAR2(100) NOT NULL,
  Price_Of_Item  NUMBER(10,2) NOT NULL,
  Category_Name  VARCHAR2(50),
  FOREIGN KEY (Category_Name) REFERENCES Category(Category_Name)
);
-- Note: the redundant "Category" text attribute was dropped in BCNF —
-- Category_Name -> Category was a transitive dependency on a non-key attr.

CREATE TABLE Delivery_Schedule (
  Tracking_ID    VARCHAR2(10) PRIMARY KEY,
  Time_Slot      VARCHAR2(30),
  Current_Status VARCHAR2(20) DEFAULT 'Scheduled',
  Agent_ID       VARCHAR2(10) NOT NULL,
  FOREIGN KEY (Agent_ID) REFERENCES Delivery_Agent(Agent_ID),
  CONSTRAINT uq_agent_slot UNIQUE (Agent_ID, Time_Slot)
  -- (Agent_ID, Time_Slot) is the *second* candidate key found in DA-1's
  -- BCNF check for this entity, alongside Tracking_ID -- enforced here.
);

-- STORED_IN decomposed per DA-1 (two overlapping composite candidate keys
-- meant the original 4-attribute table violated BCNF):
CREATE TABLE Stored_In_Slot (         -- R1: which product sits on which shelf
  Warehouse_Code VARCHAR2(10),
  Shelf_No       VARCHAR2(10),
  Product_ID     VARCHAR2(10) NOT NULL,
  PRIMARY KEY (Warehouse_Code, Shelf_No),
  FOREIGN KEY (Warehouse_Code) REFERENCES Warehouse(Warehouse_Code),
  FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID)
);

CREATE TABLE Stored_In_Qty (           -- R2: how much is on that shelf
  Warehouse_Code   VARCHAR2(10),
  Shelf_No         VARCHAR2(10),
  Quantity_Stored  NUMBER(10) DEFAULT 0,
  PRIMARY KEY (Warehouse_Code, Shelf_No),
  FOREIGN KEY (Warehouse_Code, Shelf_No)
    REFERENCES Stored_In_Slot(Warehouse_Code, Shelf_No) ON DELETE CASCADE
);

CREATE TABLE Offers (
  Coupon_Code VARCHAR2(10) PRIMARY KEY,
  Valid_Upto  DATE,
  Discount    NUMBER(5,2),
  Product_ID  VARCHAR2(10),
  FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID)
);

CREATE TABLE Cart (
  Cart_ID      VARCHAR2(10) PRIMARY KEY,
  Total_Items  NUMBER(5) DEFAULT 0,
  Total_Price  NUMBER(10,2) DEFAULT 0,   -- maintained by trigger, see 02_plsql_logic.sql
  Customer_ID  VARCHAR2(10) UNIQUE,      -- 1:1 Customer<->Cart per DA-1
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID)
);

CREATE TABLE Returns (        -- named plural: RETURN is a reserved PL/SQL word
  Return_ID   VARCHAR2(10) PRIMARY KEY,
  Reason      VARCHAR2(255),
  Item_Status VARCHAR2(20) DEFAULT 'Requested',
  Customer_ID VARCHAR2(10) NOT NULL,
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID)
);

-- ---------- Third layer ----------

CREATE TABLE Contains (
  Cart_ID            VARCHAR2(10),
  Product_ID         VARCHAR2(10),
  Price_At_Addition  NUMBER(10,2),
  Quantity           NUMBER(5) DEFAULT 1,
  PRIMARY KEY (Cart_ID, Product_ID),
  FOREIGN KEY (Cart_ID) REFERENCES Cart(Cart_ID) ON DELETE CASCADE,
  FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID)
);

CREATE TABLE Orders (
  Order_ID     VARCHAR2(10) PRIMARY KEY,
  Order_Date   DATE DEFAULT SYSDATE,
  Status       VARCHAR2(20) DEFAULT 'Placed',
  Total_Amount NUMBER(10,2) DEFAULT 0,
  Agent_ID     VARCHAR2(10),
  Customer_ID  VARCHAR2(10) NOT NULL,
  FOREIGN KEY (Agent_ID) REFERENCES Delivery_Agent(Agent_ID),
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID)
);

CREATE TABLE Review (
  Review_ID   VARCHAR2(10) PRIMARY KEY,
  Review_Date DATE DEFAULT SYSDATE,
  Ratings     NUMBER(2,1) CHECK (Ratings BETWEEN 0 AND 5),
  Comments    VARCHAR2(500),
  Customer_ID VARCHAR2(10) NOT NULL,
  Product_ID  VARCHAR2(10) NOT NULL,
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID),
  FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID)
);

CREATE TABLE Refund (
  Refund_No     VARCHAR2(10) PRIMARY KEY,
  Date_Expected DATE,
  Total_Amount  NUMBER(10,2),
  Return_ID     VARCHAR2(10) UNIQUE NOT NULL,   -- 1:1 with Returns
  FOREIGN KEY (Return_ID) REFERENCES Returns(Return_ID)
);

-- ---------- Fourth layer ----------

CREATE TABLE Payment (
  Payment_ID  VARCHAR2(10) PRIMARY KEY,
  Pay_Date    DATE DEFAULT SYSDATE,
  Pay_Amount  NUMBER(10,2),
  Order_ID    VARCHAR2(10) UNIQUE NOT NULL,     -- 1:1 with Orders
  Method_Name VARCHAR2(20),
  FOREIGN KEY (Order_ID) REFERENCES Orders(Order_ID),
  FOREIGN KEY (Method_Name) REFERENCES Payment_Method(Method_Name)
);

CREATE TABLE Invoice (
  Invoice_No   VARCHAR2(10) PRIMARY KEY,
  Tax          NUMBER(10,2),
  Invoice_Date DATE DEFAULT SYSDATE,
  Total_Amount NUMBER(10,2),
  Method_Name  VARCHAR2(20),
  Refund_No    VARCHAR2(10) UNIQUE NOT NULL,    -- 1:1 with Refund (per DA-1)
  FOREIGN KEY (Method_Name) REFERENCES Payment_Method(Method_Name),
  FOREIGN KEY (Refund_No) REFERENCES Refund(Refund_No)
);

COMMIT;
