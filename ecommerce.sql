use parth;
-- CUSTOMER TABLE
CREATE TABLE Customer (
    CustomerID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Phone VARCHAR(15),
    Address TEXT
);

-- PRODUCT TABLE
CREATE TABLE Product (
    ProductID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Category VARCHAR(50),
    Price DECIMAL(10,2) CHECK (Price > 0),
    StockQuantity INT CHECK (StockQuantity >= 0)
);

-- ORDER TABLE
CREATE TABLE OrderTable (
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    OrderDate DATE NOT NULL,
    TotalAmount DECIMAL(10,2),
    FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
);

-- ORDER ITEM TABLE (Many-to-Many junction)
CREATE TABLE OrderItem (
    OrderItemID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT CHECK (Quantity > 0),
    PriceAtPurchase DECIMAL(10,2),
    FOREIGN KEY (OrderID) REFERENCES OrderTable(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);

-- ADMIN TABLE
CREATE TABLE Admin (
    AdminID INT PRIMARY KEY,
    Name VARCHAR(100),
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(100) NOT NULL
);

-- CUSTOMERS
INSERT INTO Customer VALUES (1, 'Alice', 'alice@example.com', '9876543210', 'Delhi');
INSERT INTO Customer VALUES (2, 'Bob', 'bob@example.com', '9876541234', 'Mumbai');

-- PRODUCTS
INSERT INTO Product VALUES (101, 'Laptop', 'Electronics', 55000.00, 10);
INSERT INTO Product VALUES (102, 'Phone', 'Electronics', 25000.00, 20);

-- ADMIN
INSERT INTO Admin VALUES (1, 'Admin User', 'admin@example.com', 'admin123');

-- ORDER
INSERT INTO OrderTable VALUES (201, 1, '2025-05-06', 80000.00);

-- ORDER ITEMS
INSERT INTO OrderItem VALUES (301, 201, 101, 1, 55000.00);
INSERT INTO OrderItem VALUES (302, 201, 102, 1, 25000.00);

-- VIEW for Admin
CREATE VIEW CustomerOrders AS
SELECT c.Name AS CustomerName, o.OrderID, o.OrderDate, o.TotalAmount
FROM Customer c
JOIN OrderTable o ON c.CustomerID = o.CustomerID;

-- TRIGGER to update stock after order
DELIMITER //
CREATE TRIGGER trg_update_stock AFTER INSERT ON OrderItem
FOR EACH ROW
BEGIN
    UPDATE Product
    SET StockQuantity = StockQuantity - NEW.Quantity
    WHERE ProductID = NEW.ProductID;
END;
//
DELIMITER ;

-- STORED PROCEDURE to insert order
DELIMITER //
CREATE PROCEDURE AddOrder(
    IN p_orderID INT,
    IN p_customerID INT,
    IN p_orderDate DATE,
    IN p_total DECIMAL(10,2),
    IN p_productID INT,
    IN p_quantity INT,
    IN p_price DECIMAL(10,2)
)
BEGIN
    INSERT INTO OrderTable VALUES (p_orderID, p_customerID, p_orderDate, p_total);
    INSERT INTO OrderItem (OrderItemID, OrderID, ProductID, Quantity, PriceAtPurchase)
    VALUES (FLOOR(RAND()*1000), p_orderID, p_productID, p_quantity, p_price);
END;
//
DELIMITER ;

--Auto-calculate TotalAmount
DELIMITER //
CREATE TRIGGER trg_calculate_total BEFORE INSERT ON OrderItem
FOR EACH ROW
BEGIN
  DECLARE total DECIMAL(10,2);
  SET total = NEW.Quantity * NEW.PriceAtPurchase;
  UPDATE OrderTable
  SET TotalAmount = COALESCE(TotalAmount, 0) + total
  WHERE OrderID = NEW.OrderID;
END;
//
DELIMITER ;

-- Add LoyaltyPoints to Customers
ALTER TABLE Customer ADD LoyaltyPoints INT DEFAULT 0;

DELIMITER //
CREATE TRIGGER trg_loyalty_points AFTER INSERT ON OrderItem
FOR EACH ROW
BEGIN
  DECLARE earnedPoints INT;
  SET earnedPoints = NEW.Quantity * 10;
  UPDATE Customer
  SET LoyaltyPoints = LoyaltyPoints + earnedPoints
  WHERE CustomerID = (SELECT CustomerID FROM OrderTable WHERE OrderID = NEW.OrderID);
END;
//
DELIMITER ;

-- View to List Low Stock Products
CREATE VIEW LowStockProducts AS
SELECT ProductID, Name, StockQuantity
FROM Product
WHERE StockQuantity < 5;

-- Add IsDeleted column to Orders instead of deleting rows
ALTER TABLE OrderTable ADD IsDeleted BOOLEAN DEFAULT FALSE;

-- Procedure to update order status
ALTER TABLE OrderTable ADD Status VARCHAR(20) DEFAULT 'Pending';
DELIMITER //
CREATE PROCEDURE UpdateOrderStatus(IN oid INT, IN new_status VARCHAR(20))
BEGIN
  UPDATE OrderTable SET Status = new_status WHERE OrderID = oid;
END;
//
DELIMITER ;

-- Total sales per product
CREATE VIEW ProductSales AS
SELECT 
  p.Name,
  SUM(oi.Quantity) AS TotalSold,
  SUM(oi.PriceAtPurchase * oi.Quantity) AS RevenueGenerated
FROM OrderItem oi
JOIN Product p ON oi.ProductID = p.ProductID
GROUP BY p.ProductID, p.Name;

-- essential commands to show output for

SELECT * FROM Customer;
SELECT * FROM Product;
SELECT * FROM OrderTable;
SELECT * FROM OrderItem;
SELECT * FROM Admin;

-- View showing customer orders
SELECT * FROM CustomerOrders;

-- View showing low stock products
SELECT * FROM LowStockProducts;

-- View showing product-wise sales
SELECT * FROM ProductSales;

-- To show the stock update, loyalty points, and order total triggers working:
-- Insert a new order (insert into OrderTable first)
INSERT INTO OrderTable VALUES (202, 2, '2025-05-07', 0.00, 'Pending', FALSE); 

-- Now insert OrderItems (triggers will fire)
INSERT INTO OrderItem VALUES (303, 202, 101, 2, 55000.00);  -- Laptop
INSERT INTO OrderItem VALUES (304, 202, 102, 1, 25000.00);  -- Phone

-- Now check updated stock
SELECT * FROM Product;

-- Check total amount updated
SELECT * FROM OrderTable WHERE OrderID = 202;

-- Check loyalty points added
SELECT * FROM Customer WHERE CustomerID = 2;

-- Stored procedure output
CALL AddOrder(203, 1, '2025-05-07', 40000.00, 102, 2, 20000.00);  -- Phone x2

-- Check the newly inserted order and order items
SELECT * FROM OrderTable WHERE OrderID = 203;
SELECT * FROM OrderItem WHERE OrderID = 203;

-- Order Status Update Procedure
CALL UpdateOrderStatus(203, 'Shipped');

-- Check updated status
SELECT OrderID, Status FROM OrderTable WHERE OrderID = 203;
