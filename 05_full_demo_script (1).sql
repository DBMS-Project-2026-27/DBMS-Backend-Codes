-- =========================================================================
-- FULL DEMO / VERIFICATION SCRIPT
-- Run AFTER 01_schema.sql, 02_plsql_logic.sql, 03_sample_data.sql,
-- 04_additional_plsql.sql have all been run successfully.
--
-- Run ONE SECTION AT A TIME (select just that section's text and run it,
-- or run the whole script and scroll through the output section by
-- section) -- take a screenshot after each section's output appears.
-- =========================================================================

SET SERVEROUTPUT ON;

-- ################################################################
-- SECTION 1: Prove auto-generated IDs (sequences + BEFORE INSERT triggers)
-- ################################################################

INSERT INTO Customer (Customer_Name, Reg_Date, Phone_No)
VALUES ('Demo User', SYSDATE, '9999900000');

SELECT Customer_ID, Customer_Name, Phone_No FROM Customer
ORDER BY Customer_ID;
-- Expect: a new row with an ID like C003 -- you never typed that ID yourself.


-- ################################################################
-- SECTION 2: Prove the Cart-total trigger (business rule automation)
-- ################################################################

-- Make a fresh cart for the demo customer we just inserted:
INSERT INTO Cart (Customer_ID) VALUES ('C003');

SELECT Cart_ID, Total_Items, Total_Price FROM Cart WHERE Customer_ID = 'C003';
-- Expect: Total_Items = 0, Total_Price = 0 (empty cart)

-- Now add an item -- watch the trigger recompute automatically:
INSERT INTO Contains VALUES (
  (SELECT Cart_ID FROM Cart WHERE Customer_ID = 'C003'), 'P001', 60, 2
);

SELECT Cart_ID, Total_Items, Total_Price FROM Cart WHERE Customer_ID = 'C003';
-- Expect: Total_Items = 2, Total_Price = 120 -- computed with NO manual UPDATE statement.


-- ################################################################
-- SECTION 3: Prove the stored procedure (transactional business logic)
-- ################################################################

DECLARE
  v_cart_id  VARCHAR2(10);
  v_order_id VARCHAR2(10);
BEGIN
  SELECT Cart_ID INTO v_cart_id FROM Cart WHERE Customer_ID = 'C003';

  sp_place_order('C003', v_cart_id, v_order_id);

  DBMS_OUTPUT.PUT_LINE('Order placed successfully: ' || v_order_id);
END;
/

SELECT * FROM Orders WHERE Customer_ID = 'C003';
-- Expect: one Orders row, Total_Amount = 120

SELECT Cart_ID, Total_Items, Total_Price FROM Cart WHERE Customer_ID = 'C003';
-- Expect: Total_Items = 0, Total_Price = 0 -- the procedure emptied the cart.


-- ################################################################
-- SECTION 4: Prove exception handling (deliberately trigger the error)
-- ################################################################

DECLARE
  v_cart_id  VARCHAR2(10);
  v_order_id VARCHAR2(10);
BEGIN
  SELECT Cart_ID INTO v_cart_id FROM Cart WHERE Customer_ID = 'C003';

  -- The cart is already empty from Section 3 -- this SHOULD fail:
  sp_place_order('C003', v_cart_id, v_order_id);

  DBMS_OUTPUT.PUT_LINE('This line should never print.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Caught expected error: ' || SQLERRM);
END;
/
-- Expect output: "Caught expected error: ORA-20002: Cart is empty -- nothing to order."


-- ################################################################
-- SECTION 5: Prove the function (usable directly inside a SELECT)
-- ################################################################

-- Add a review first so the function has data to average:
INSERT INTO Review (Ratings, Comments, Customer_ID, Product_ID)
VALUES (4.5, 'Fresh and good quality', 'C003', 'P001');

SELECT Product_ID, Product_Name, fn_product_review_avg(Product_ID) AS avg_rating
FROM Product
ORDER BY Product_ID;
-- Expect: P001 shows 4.5, other products show 0 (no reviews yet).


-- ################################################################
-- SECTION 6: Prove the cursor-based procedure (row-by-row processing)
-- ################################################################

EXEC sp_print_order_history('C003');
-- Expect: printed list of C003's orders, one line per order, plus a total count.


-- ################################################################
-- SECTION 7: Prove the package (grouped, modular operations)
-- ################################################################

-- Give the demo customer a fresh cart + item so we have something to order:
INSERT INTO Cart (Customer_ID) VALUES ('C002');
INSERT INTO Contains VALUES (
  (SELECT Cart_ID FROM Cart WHERE Customer_ID = 'C002'), 'P002', 50, 1
);

DECLARE
  v_cart_id  VARCHAR2(10);
  v_order_id VARCHAR2(10);
BEGIN
  SELECT Cart_ID INTO v_cart_id FROM Cart WHERE Customer_ID = 'C002';

  pkg_orders.place_order('C002', v_cart_id, v_order_id);
  DBMS_OUTPUT.PUT_LINE('Status after placing: ' || pkg_orders.get_order_status(v_order_id));

  pkg_orders.cancel_order(v_order_id);
  DBMS_OUTPUT.PUT_LINE('Status after cancelling: ' || pkg_orders.get_order_status(v_order_id));
END;
/
-- Expect:
--   Status after placing: Placed
--   Status after cancelling: Cancelled
-- This single block proves 3 package members were called in sequence.


-- ################################################################
-- SECTION 8: Final integrity check (everything is still consistent)
-- ################################################################

SELECT table_name FROM user_tables ORDER BY table_name;         -- 19 tables
SELECT object_name, object_type, status FROM user_objects
WHERE status = 'INVALID';                                        -- expect ZERO rows
