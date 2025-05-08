-- CREATE DATABASE 
CREATE DATABASE grocerydb;
USE grocerydb;

-- CREATE TABLES
-- Create Customers table
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100),
    CustomerEmail VARCHAR(100),
    CustomerJoinDate DATE
);

-- Create Products table
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50),
    UnitPrice DECIMAL(10, 2)
);

-- Create Stores table
CREATE TABLE Stores (
    StoreID INT PRIMARY KEY,
    StoreName VARCHAR(100),
    Region VARCHAR(50)
);

-- Create Orders table
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    OrderDate DATE,
    CustomerID INT,
    StoreID INT,
    TotalAmount DECIMAL(10, 2),
    PaymentMethod VARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (StoreID) REFERENCES Stores(StoreID)
);

-- Create OrderItems table
CREATE TABLE OrderItems (
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(10, 2),
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

-- LOAD DATA INTO TABLES
-- Load data into Customers table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE Customers
FIELDS TERMINATED BY ','  
ENCLOSED BY '"'            
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(CustomerID, @CustomerName, @CustomerEmail, @CustomerJoinDate)
SET CustomerName = @CustomerName,
    CustomerEmail = @CustomerEmail,
    CustomerJoinDate = STR_TO_DATE(@CustomerJoinDate, '%m/%d/%Y');
    
-- Load data into Products table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Products.csv'
INTO TABLE Products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(ProductID, ProductName, Category, UnitPrice);

-- Load data into Stores table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Stores.csv'
INTO TABLE Stores
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(StoreID, StoreName, Region);

-- Load data into Orders table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Orders.csv'
INTO TABLE Orders
FIELDS TERMINATED BY ','  
ENCLOSED BY '"'            
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(OrderID, @OrderDate, CustomerID, StoreID, TotalAmount, PaymentMethod)
SET OrderDate = STR_TO_DATE(@OrderDate, '%d/%m/%Y');

-- Load data into OrderItems table
SET sql_mode = 'NO_BACKSLASH_ESCAPES';  -- Optional, in case you encounter issues with escape characters
SET GLOBAL sql_notes = 0;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Orderitems.csv'
IGNORE
INTO TABLE OrderItems
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(OrderID, ProductID, Quantity, UnitPrice);

-- CREATE THE DIMENSION & FACT TABLES
-- Create DimDateTable
CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY,  -- Date in YYYYMMDD format (e.g., 20240321)
    FullDate DATE,
    DayOfWeek VARCHAR(10),
    Month INT,
    Quarter INT,
    Year INT,
    IsHoliday BOOLEAN
);

CREATE TABLE DimPaymentMethod (
    PaymentMethodID INT PRIMARY KEY AUTO_INCREMENT,
    PaymentMethod VARCHAR(50)
);

INSERT INTO DimPaymentMethod (PaymentMethod)
SELECT DISTINCT PaymentMethod
FROM Orders;

-- Create the FactSales Table
CREATE TABLE FactSales (
    OrderID INT,
    ProductID INT,
    CustomerID INT,
    StoreID INT,
    PaymentMethodID INT,  -- Use PaymentMethodID as a foreign key
    Quantity INT,
    UnitPrice DECIMAL(10, 2),
    TotalAmount DECIMAL(10, 2),
    OrderDate INT,  -- Assuming DateKey is an integer
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (StoreID) REFERENCES Stores(StoreID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    FOREIGN KEY (PaymentMethodID) REFERENCES DimPaymentMethod(PaymentMethodID),  -- Reference to DimPaymentMethod
    FOREIGN KEY (OrderDate) REFERENCES DimDate(DateKey)
);

ALTER TABLE FactSales ADD ProductID INT;
ALTER TABLE FactSales ADD FOREIGN KEY (ProductID) REFERENCES Products(ProductID);

ALTER TABLE FactSales ADD Quantity INT;

ALTER TABLE OrderItems
MODIFY COLUMN Quantity INT NOT NULL;

ALTER TABLE OrderItems
MODIFY COLUMN UnitPrice DECIMAL(10, 2) NOT NULL;

ALTER TABLE FactSales
ADD COLUMN UnitPrice DECIMAL(10, 2);

ALTER TABLE Orders
ADD COLUMN TotalAmount DECIMAL(10, 2);

ALTER TABLE Orders
ADD COLUMN PaymentMethod VARCHAR(50);

ALTER TABLE Orders DROP PRIMARY KEY;

-- LOAD UPDATED DATA OF TABLE ORDERS
USE grocerydb;
CREATE TABLE TempOrders (
    OrderID INT,
    OrderDate DATE,
    CustomerID INT,
    StoreID INT,
    TotalAmount DECIMAL(10, 2),
    PaymentMethod VARCHAR(50)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Orders.csv'
INTO TABLE TempOrders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(OrderID, @OrderDate, CustomerID, StoreID, TotalAmount, PaymentMethod)
SET OrderDate = STR_TO_DATE(@OrderDate, '%d/%m/%Y');

INSERT INTO Orders (OrderID, OrderDate, CustomerID, StoreID, TotalAmount, PaymentMethod)
SELECT OrderID, OrderDate, CustomerID, StoreID, TotalAmount, PaymentMethod
FROM TempOrders AS tmp
ON DUPLICATE KEY UPDATE
    CustomerID = tmp.CustomerID,
    StoreID = tmp.StoreID,
    TotalAmount = tmp.TotalAmount,
    PaymentMethod = tmp.PaymentMethod,
    OrderDate = tmp.OrderDate;
    
DROP TABLE TempOrders;


-- INSERT DATA INTO TABLE FACTSALES
DELIMITER //
CREATE PROCEDURE generate_dates()
BEGIN
  DECLARE start_date DATE;
  DECLARE end_date DATE;
  SET start_date = '2020-01-01';  -- Adjust the start date as needed
  SET end_date = '2025-12-31';    -- Adjust the end date as needed

  WHILE start_date <= end_date DO
    INSERT INTO DimDate (DateKey) 
    VALUES (DATE_FORMAT(start_date, '%Y%m%d'));
    SET start_date = DATE_ADD(start_date, INTERVAL 1 DAY);
  END WHILE;
END;
//
DELIMITER ;

CALL generate_dates();

SELECT * FROM DimDate LIMIT 10;

INSERT INTO FactSales (
    OrderID,
    ProductID,
    CustomerID,
    StoreID,
    PaymentMethodID,
    Quantity,
    UnitPrice,
    TotalAmount,
    OrderDate
)
SELECT 
    OrderItems.OrderID,
    OrderItems.ProductID,
    Orders.CustomerID,
    Orders.StoreID,
    DimPaymentMethod.PaymentMethodID,
    OrderItems.Quantity,
    OrderItems.UnitPrice,  -- Direct reference to the UnitPrice column
    Orders.TotalAmount,
    DATE_FORMAT(Orders.OrderDate, '%Y%m%d')  -- Convert date to YYYYMMDD format for DateKey
FROM 
    OrderItems
JOIN 
    Orders ON OrderItems.OrderID = Orders.OrderID
JOIN 
    DimPaymentMethod ON Orders.PaymentMethod = DimPaymentMethod.PaymentMethod
JOIN 
    DimDate ON DATE_FORMAT(Orders.OrderDate, '%Y%m%d') = DimDate.DateKey;
    

SELECT 
    s.StoreName, 
    s.Region,
    SUM(f.TotalAmount) AS TotalSales
FROM 
    FactSales f
JOIN 
    stores s ON f.StoreID = s.StoreID
GROUP BY 
    s.StoreID, s.Region, s.StoreName
ORDER BY 
    TotalSales DESC;
    
-- Total & Average Sales by Day, Month, and YearGetTotalAvgSalesByDateRange

Use grocerydb;
DELIMITER $$
DELIMITER $$

-- Change the date format to DATE
ALTER TABLE DimDate
MODIFY COLUMN DateKey DATE;

ALTER TABLE FactSales
DROP FOREIGN KEY factsales_ibfk_5;

SELECT CONSTRAINT_NAME 
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
WHERE TABLE_NAME = 'FactSales' AND COLUMN_NAME = 'OrderDate';

ALTER TABLE DimDate
MODIFY COLUMN DateKey DATE;

ALTER TABLE FactSales
MODIFY COLUMN OrderDate DATE;

ALTER TABLE FactSales
ADD CONSTRAINT fk_orderdate
FOREIGN KEY (OrderDate) REFERENCES DimDate(DateKey);

-- STORED PROCUDURE
USE grocerydb;

-- 1) Stored Procedure: Total & Average Sales by Day, Month, and Year
-- Stored Procedure for Total Sales:
DELIMITER $$

CREATE PROCEDURE TotalSales (
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    -- Total sales by day
    SELECT 
        OrderDate,
        SUM(TotalAmount) AS TotalSales
    FROM FactSales
    WHERE OrderDate BETWEEN start_date AND end_date
      AND TotalAmount IS NOT NULL
    GROUP BY OrderDate
    ORDER BY OrderDate;

    -- Total sales by month and year
    SELECT 
        YEAR(OrderDate) AS Year, 
        MONTH(OrderDate) AS Month,
        SUM(TotalAmount) AS TotalSales
    FROM FactSales
    WHERE OrderDate BETWEEN start_date AND end_date
      AND TotalAmount IS NOT NULL
    GROUP BY Year, Month
    ORDER BY Year, Month;
END $$

DELIMITER ;

-- Stored Procedure for Average Sales
DELIMITER $$

CREATE PROCEDURE AverageSales (
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    -- Main query: Calculate total sales by month and then average those monthly sales
    SELECT 
        YEAR(o.OrderDate) AS Year,
        MONTH(o.OrderDate) AS Month,
        SUM(f.TotalAmount) AS MonthlySales,
        AVG(SUM(f.TotalAmount)) OVER () AS AvgMonthlySales
    FROM factsales f
    JOIN orders o ON f.OrderID = o.OrderID
    WHERE o.OrderDate BETWEEN start_date AND end_date
      AND f.TotalAmount IS NOT NULL
    GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate)
    ORDER BY Year, Month;
END $$
DELIMITER ;


-- 2) Stored Procedure: Sales Trends by Product Category and Region
DELIMITER $$
CREATE PROCEDURE SalesByRegion (
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    SELECT 
        p.Category,
        s.Region,
        SUM(f.TotalAmount) AS TotalSales
    FROM FactSales f
    JOIN Products p ON f.ProductID = p.ProductID
    JOIN Stores s ON f.StoreID = s.StoreID
    WHERE f.OrderDate BETWEEN start_date AND end_date
    GROUP BY p.Category, s.Region
    ORDER BY TotalSales DESC;
END $$
DELIMITER ;

-- 3) Stored Procedure: Customer Retention
-- 3.1) Customer List
DELIMITER $$

CREATE PROCEDURE CustomerList (
    IN min_orders INT
)
BEGIN
    -- Get the list of customers with at least `min_orders` orders, including their names
    SELECT 
        c.CustomerID,
        c.CustomerName,
        COUNT(fs.OrderID) AS OrderCount
    FROM FactSales fs
    JOIN Customers c ON fs.CustomerID = c.CustomerID
    GROUP BY c.CustomerID, c.CustomerName
    HAVING OrderCount >= min_orders
    ORDER BY OrderCount DESC;  -- Optional: Sort by OrderCount
END $$

DELIMITER ;

-- 3.2) Customer Retention
DELIMITER $$

CREATE PROCEDURE CustomerRetention (
    IN min_orders INT
)
BEGIN
    -- Get customers with at least `min_orders`
    SELECT 
        CustomerID,
        COUNT(*) AS OrderCount
    FROM FactSales
    GROUP BY CustomerID
    HAVING OrderCount >= min_orders;

    -- Calculate retained customers and retention percentage
    SELECT 
        COUNT(DISTINCT fs.CustomerID) AS RetainedCustomers,
        (COUNT(DISTINCT fs.CustomerID) / (SELECT COUNT(DISTINCT CustomerID) FROM FactSales)) * 100 AS RetentionPercentage
    FROM FactSales fs
    INNER JOIN (
        SELECT CustomerID
        FROM FactSales
        GROUP BY CustomerID
        HAVING COUNT(*) >= min_orders
    ) AS RetainedCustomersList
    ON fs.CustomerID = RetainedCustomersList.CustomerID;
END $$

DELIMITER ;

-- 4) Stored Procedure: Payment Method Distribution in Top Region
USE grocerydb;

DELIMITER $$
CREATE PROCEDURE PaymentMethod (
    IN min_orders INT
)
BEGIN
    -- Identify the top revenue-generating region
    DECLARE top_region_id INT;

    SELECT s.storeID INTO top_region_id
    FROM factsales f
    JOIN stores s ON f.StoreID = s.storeID
    GROUP BY s.storeID
    ORDER BY SUM(f.TotalAmount) DESC
    LIMIT 1;

    -- Debug: Print top region ID
    SELECT CONCAT('Top Region ID: ', top_region_id) AS debug_output;

    -- Payment method distribution in top region
    SELECT
        p.PaymentMethod,
        COUNT(*) AS payment_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
    FROM factsales f
    JOIN orders o ON f.OrderID = o.OrderID
    JOIN customers c ON o.CustomerID = c.CustomerID
    JOIN dimpaymentmethod p ON o.PaymentMethod = p.PaymentMethod
    WHERE f.StoreID = top_region_id
    GROUP BY p.PaymentMethod;
END $$
DELIMITER ;

