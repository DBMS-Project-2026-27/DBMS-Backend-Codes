-- =========================================================================
-- PL/SQL layer: sequences, auto-ID triggers, business-rule triggers,
-- and stored procedures. Run this AFTER 01_schema.sql.
-- =========================================================================

-- ---------- Sequences for auto-generated IDs ----------
CREATE SEQUENCE seq_customer START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_product  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_cart     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_orders   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_payment  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_return   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_refund   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_review   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_invoice  START WITH 1 INCREMENT BY 1;

-- ---------- Auto-ID triggers (repeat this pattern for any table you add) ----------

CREATE OR REPLACE TRIGGER trg_customer_id
BEFORE INSERT ON Customer
FOR EACH ROW
WHEN (NEW.Customer_ID IS NULL)
BEGIN
  :NEW.Customer_ID := 'C' || LPAD(seq_customer.NEXTVAL, 3, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_product_id
BEFORE INSERT ON Product
FOR EACH ROW
WHEN (NEW.Product_ID IS NULL)
BEGIN
  :NEW.Product_ID := 'P' || LPAD(seq_product.NEXTVAL, 3, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_cart_id
BEFORE INSERT ON Cart
FOR EACH ROW
WHEN (NEW.Cart_ID IS NULL)
BEGIN
  :NEW.Cart_ID := 'CT' || LPAD(seq_cart.NEXTVAL, 3, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_orders_id
BEFORE INSERT ON Orders
FOR EACH ROW
WHEN (NEW.Order_ID IS NULL)
BEGIN
  :NEW.Order_ID := 'O' || LPAD(seq_orders.NEXTVAL, 4, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_payment_id
BEFORE INSERT ON Payment
FOR EACH ROW
WHEN (NEW.Payment_ID IS NULL)
BEGIN
  :NEW.Payment_ID := 'PM' || LPAD(seq_payment.NEXTVAL, 4, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_return_id
BEFORE INSERT ON Returns
FOR EACH ROW
WHEN (NEW.Return_ID IS NULL)
BEGIN
  :NEW.Return_ID := 'RT' || LPAD(seq_return.NEXTVAL, 3, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_refund_id
BEFORE INSERT ON Refund
FOR EACH ROW
WHEN (NEW.Refund_No IS NULL)
BEGIN
  :NEW.Refund_No := 'RF' || LPAD(seq_refund.NEXTVAL, 3, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_review_id
BEFORE INSERT ON Review
FOR EACH ROW
WHEN (NEW.Review_ID IS NULL)
BEGIN
  :NEW.Review_ID := 'RV' || LPAD(seq_review.NEXTVAL, 3, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_invoice_id
BEFORE INSERT ON Invoice
FOR EACH ROW
WHEN (NEW.Invoice_No IS NULL)
BEGIN
  :NEW.Invoice_No := 'INV' || LPAD(seq_invoice.NEXTVAL, 3, '0');
END;
/

-- ---------- Business-rule trigger: keep Cart totals in sync with Contains ----------
-- Total_Items / Total_Price are derived values (flagged as such back in the
-- EER) -- this trigger is what keeps that derivation honest at the DB level
-- instead of trusting the frontend to recompute it correctly every time.

CREATE OR REPLACE TRIGGER trg_update_cart_totals
AFTER INSERT OR UPDATE OR DELETE ON Contains
FOR EACH ROW
DECLARE
  v_cart_id Cart.Cart_ID%TYPE;
BEGIN
  v_cart_id := COALESCE(:NEW.Cart_ID, :OLD.Cart_ID);

  UPDATE Cart
  SET Total_Items = (SELECT NVL(SUM(Quantity), 0) FROM Contains WHERE Cart_ID = v_cart_id),
      Total_Price = (SELECT NVL(SUM(Quantity * Price_At_Addition), 0) FROM Contains WHERE Cart_ID = v_cart_id)
  WHERE Cart_ID = v_cart_id;
END;
/

-- ---------- Stored procedure: place an order from a cart ----------
-- Demonstrates a transactional business operation: read the cart total,
-- create the order, empty the cart, all-or-nothing.

CREATE OR REPLACE PROCEDURE sp_place_order (
  p_customer_id IN  VARCHAR2,
  p_cart_id     IN  VARCHAR2,
  p_order_id    OUT VARCHAR2
) AS
  v_total  Cart.Total_Price%TYPE;
  v_items  Cart.Total_Items%TYPE;
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
  -- trg_update_cart_totals fires automatically and zeroes the cart totals

  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20001, 'Cart not found for this customer.');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/

-- ---------- Stored procedure: process a return into a refund ----------
-- Demonstrates a second business workflow chained across two tables.

CREATE OR REPLACE PROCEDURE sp_process_return (
  p_return_id     IN  VARCHAR2,
  p_days_to_refund IN NUMBER DEFAULT 7,
  p_refund_no     OUT VARCHAR2
) AS
  v_order_total NUMBER(10,2);
BEGIN
  -- Look up the order total via the customer's most recent order as a stand-in
  -- for "amount to refund" -- adjust this lookup to match your actual
  -- return-to-order linkage once you decide how granular returns should be.
  UPDATE Returns SET Item_Status = 'Approved' WHERE Return_ID = p_return_id;

  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Return_ID not found.');
  END IF;

  INSERT INTO Refund (Date_Expected, Total_Amount, Return_ID)
  VALUES (SYSDATE + p_days_to_refund, 0, p_return_id)  -- fill in real amount from your order-line logic
  RETURNING Refund_No INTO p_refund_no;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/

-- ---------- Quick sanity test (run manually, not part of automated build) ----------
-- DECLARE
--   v_order_id VARCHAR2(10);
-- BEGIN
--   sp_place_order('C001', 'CT001', v_order_id);
--   DBMS_OUTPUT.PUT_LINE('Created order: ' || v_order_id);
-- END;
-- /
