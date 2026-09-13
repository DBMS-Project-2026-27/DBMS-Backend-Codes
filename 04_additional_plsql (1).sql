-- =========================================================================
-- Additional PL/SQL objects for a complete DA-2 submission:
-- a FUNCTION, a CURSOR-based procedure, and a PACKAGE.
-- Run this AFTER 01_schema.sql, 02_plsql_logic.sql, 03_sample_data.sql.
-- =========================================================================

-- ---------- FUNCTION: returns a single value, usable inside SELECT ----------
-- Computes how many times a given product has been ordered in total
-- across all carts that were ever converted into orders. Demonstrates
-- a function you can call directly in a query, unlike a procedure.

CREATE OR REPLACE FUNCTION fn_product_review_avg (
  p_product_id IN VARCHAR2
) RETURN NUMBER
IS
  v_avg NUMBER(3,2);
BEGIN
  SELECT NVL(AVG(Ratings), 0) INTO v_avg
  FROM Review
  WHERE Product_ID = p_product_id;

  RETURN v_avg;
END;
/

-- Try it:
-- SELECT Product_ID, Product_Name, fn_product_review_avg(Product_ID) AS avg_rating
-- FROM Product;

-- ---------- CURSOR-based procedure ----------
-- Loops row-by-row through a customer's order history and prints a
-- summary. This is the classic "explicit cursor" demonstration --
-- procedures that just run one INSERT/UPDATE (like sp_place_order)
-- don't actually need a cursor, so examiners specifically look for
-- something like this to confirm you know how to use one.

CREATE OR REPLACE PROCEDURE sp_print_order_history (
  p_customer_id IN VARCHAR2
) IS
  CURSOR c_orders IS
    SELECT Order_ID, Order_Date, Status, Total_Amount
    FROM Orders
    WHERE Customer_ID = p_customer_id
    ORDER BY Order_Date;

  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Order history for ' || p_customer_id || ':');

  FOR r IN c_orders LOOP
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE(
      '  ' || r.Order_ID || ' | ' ||
      TO_CHAR(r.Order_Date, 'DD-MON-YYYY') || ' | ' ||
      r.Status || ' | Rs.' || r.Total_Amount
    );
  END LOOP;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  (no orders found)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Total orders: ' || v_count);
  END IF;
END;
/

-- Try it:
-- SET SERVEROUTPUT ON;
-- EXEC sp_print_order_history('C001');

-- ---------- PACKAGE: bundles related order operations together ----------
-- A package has two parts: the SPEC (public interface, what callers see)
-- and the BODY (actual implementation, hidden from callers). This mirrors
-- how you'd group related logic in any language's module/class.

CREATE OR REPLACE PACKAGE pkg_orders AS
  -- Public procedures/functions any calling program can use:
  PROCEDURE place_order (
    p_customer_id IN  VARCHAR2,
    p_cart_id     IN  VARCHAR2,
    p_order_id    OUT VARCHAR2
  );

  PROCEDURE cancel_order (
    p_order_id IN VARCHAR2
  );

  FUNCTION get_order_status (
    p_order_id IN VARCHAR2
  ) RETURN VARCHAR2;
END pkg_orders;
/

CREATE OR REPLACE PACKAGE BODY pkg_orders AS

  PROCEDURE place_order (
    p_customer_id IN  VARCHAR2,
    p_cart_id     IN  VARCHAR2,
    p_order_id    OUT VARCHAR2
  ) IS
    v_total Cart.Total_Price%TYPE;
    v_items Cart.Total_Items%TYPE;
  BEGIN
    SELECT Total_Price, Total_Items INTO v_total, v_items
    FROM Cart
    WHERE Cart_ID = p_cart_id AND Customer_ID = p_customer_id;

    IF v_items = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'Cart is empty -- nothing to order.');
    END IF;

    INSERT INTO Orders (Order_Date, Status, Total_Amount, Customer_ID)
    VALUES (SYSDATE, 'Placed', v_total, p_customer_id)
    RETURNING Order_ID INTO p_order_id;

    DELETE FROM Contains WHERE Cart_ID = p_cart_id;
    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20001, 'Cart not found for this customer.');
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END place_order;

  PROCEDURE cancel_order (
    p_order_id IN VARCHAR2
  ) IS
  BEGIN
    UPDATE Orders SET Status = 'Cancelled' WHERE Order_ID = p_order_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20004, 'Order_ID not found.');
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END cancel_order;

  FUNCTION get_order_status (
    p_order_id IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_status Orders.Status%TYPE;
  BEGIN
    SELECT Status INTO v_status FROM Orders WHERE Order_ID = p_order_id;
    RETURN v_status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'NOT FOUND';
  END get_order_status;

END pkg_orders;
/

-- Try it:
-- DECLARE
--   v_order_id VARCHAR2(10);
-- BEGIN
--   pkg_orders.place_order('C001', 'CT001', v_order_id);
--   DBMS_OUTPUT.PUT_LINE('Status: ' || pkg_orders.get_order_status(v_order_id));
--   pkg_orders.cancel_order(v_order_id);
--   DBMS_OUTPUT.PUT_LINE('Status after cancel: ' || pkg_orders.get_order_status(v_order_id));
-- END;
-- /
