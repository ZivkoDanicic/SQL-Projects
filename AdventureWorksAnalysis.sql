-- Analysis Covered:
-- 1. Information Schema for DataBase
-- 2. Understading Table Relations
-- 3. Checking for Null Values (Dynamic Query Generation)
-- 4. Top Selling Products by Quantity and Revenue 
-- 5. Customer Purchase Frequency
-- 6. Product Category Sales Analysis
-- 7. Customer Segmentation Based on Revenue
-- 8. Profitability of Products by Sales and Cost
-- 9. Monthly Sales Trends
-- 10. Customer Lifetime Value
-- 11. Sales per Region (Basd on Customer Location)
-- 12. Product Return Rate (Returns Analysis)
-- 13. Product Cross-Selling Analysis
-- 14. Identifying High-Value Customers (Churn Prediction)

--Q1 - Get the Information Schema for the Database --

SELECT *
FROM SampleDB.INFORMATION_SCHEMA.TABLES;

--Q2 - Understanding How Tables in Database are Related --

SELECT
   fk.name AS FK_name,
   tp.name AS parent_table,
   ref.name AS referenced_table,
   c1.name AS parent_column,
   c2.name AS referenced_column
FROM
   sys.foreign_keys AS fk
INNER JOIN
   sys.tables AS tp ON fk.parent_object_id = tp.object_id
INNER JOIN
   sys.tables AS ref ON fk.referenced_object_id = ref.object_id
INNER JOIN
   sys.foreign_key_columns AS fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN
   sys.columns AS c1 ON fkc.parent_column_id = c1.column_id AND tp.object_id = c1.object_id
INNER JOIN
   sys.columns AS c2 ON fkc.referenced_column_id = c2.column_id AND ref.object_id = c2.object_id
ORDER BY
   parent_table, referenced_table;


--Q3 - Check for Null Values (Dynamic Query Generation) --

DECLARE @sql AS NVARCHAR(MAX)

SELECT @sql = STRING_AGG('[' + COLUMN_NAME + '] IS NULL', ' OR ')
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'SalesOrderDetail' AND TABLE_SCHEMA = 'SalesLT'

SET @sql = 'SELECT * FROM SalesLT.SalesOrderDetail WHERE ' + @sql

EXEC sp_executesql @sql



--Q4 - Top Selling Products by Quantity and Revenue - Goal: Find the top 10 best-selling products by quantity and revenue.--

SELECT TOP 10
   p.Name AS ProductName,
   SUM(sod.OrderQty) AS TotalQuantitySold,
   SUM(sod.LineTotal) AS TotalRevenue
FROM SalesLT.SalesOrderDetail AS sod
JOIN SalesLT.Product AS p
   ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalRevenue DESC;

-- Q5 - Customer Purchase Frequency - Find how frequently customers make purchases, using the number of orders per customer in the last 6 months. --

WITH LatestOrder AS (
   -- Get the latest order date in the dataset
   SELECT MAX(soh.OrderDate) AS MaxOrderDate
   FROM SalesLT.SalesOrderHeader AS soh
)
SELECT
   c.FirstName + ' ' + c.LastName AS CustomerName,
   COUNT(soh.SalesOrderID) AS NumberOfOrders,
   DATEDIFF(MONTH, MAX(soh.OrderDate), (SELECT MaxOrderDate FROM LatestOrder)) AS MonthsSinceLastOrder
FROM SalesLT.Customer AS c
JOIN SalesLT.SalesOrderHeader AS soh
   ON c.CustomerID = soh.CustomerID
-- Filter orders within the last 6 months based on the latest order date
WHERE soh.OrderDate >= DATEADD(MONTH, -6, (SELECT MaxOrderDate FROM LatestOrder))
GROUP BY c.FirstName, c.LastName
ORDER BY NumberOfOrders DESC;


-- Q6 - Product Category Sales Analysis - Goal: Find the total sales (by revenue) per product category in the last year. --

WITH LatestOrder AS (
    -- Get the most recent order date in the dataset
   SELECT MAX(sod.OrderDate) AS MaxOrderDate
   FROM SalesLT.SalesOrderDetail AS sod
)
SELECT
   pc.Name AS CategoryName,
   SUM(sod.LineTotal) AS TotalSales
FROM SalesLT.SalesOrderDetail AS sod
JOIN SalesLT.Product AS p
   ON sod.ProductID = p.ProductID
JOIN SalesLT.ProductCategory AS pc
   ON p.ProductCategoryID = pc.ProductCategoryID
-- Filter orders from the last year based on the latest order date in the dataset
WHERE sod.OrderDate >= DATEADD(YEAR, -1, (SELECT MaxOrderDate FROM LatestOrder))
GROUP BY pc.Name
ORDER BY TotalSales DESC;


-- Q7 - Customer Segmentation Based on Revenue - Goal: Segment customers into different tiers based on their total spending (e.g., Low, Medium, High).-- 

WITH CustomerRevenue AS (
   SELECT
       c.CustomerID,
       SUM(sod.LineTotal) AS TotalSpent
   FROM SalesLT.SalesOrderHeader AS soh
   JOIN SalesLT.Customer AS c ON soh.CustomerID = c.CustomerID
   JOIN SalesLT.SalesOrderDetail AS sod ON soh.SalesOrderID = sod.SalesOrderID
   GROUP BY c.CustomerID
)
SELECT
   cr.CustomerID,
   CASE
       WHEN cr.TotalSpent < 1000 THEN 'Low'
       WHEN cr.TotalSpent BETWEEN 1000 AND 5000 THEN 'Medium'
       ELSE 'High'
   END AS SpendingTier
FROM CustomerRevenue AS cr;


-- Q8 - Profitability of Products by Sales and Cost - Goal: Calculate the profit for each product (revenue minus cost) and rank the top products based on profitability.--

SELECT TOP 10
   p.Name AS ProductName,
   SUM(sod.LineTotal) AS TotalRevenue,
   SUM(p.StandardCost * sod.OrderQty) AS TotalCost,
   SUM(sod.LineTotal) - SUM(p.StandardCost * sod.OrderQty) AS Profit
FROM SalesLT.SalesOrderDetail AS sod
JOIN SalesLT.Product AS p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY Profit DESC

-- Q9 - Monthly Sales Trends - Goal: Show monthly sales (by revenue) for the past 12 months to analyze trends. -- 

WITH LatestOrder AS (
   -- Get the most recent order date in the dataset (based on OrderDate)
   SELECT MAX(soh.OrderDate) AS MaxOrderDate
   FROM SalesLT.SalesOrderHeader AS soh
)
SELECT
   YEAR(soh.OrderDate) AS Year,
   MONTH(soh.OrderDate) AS Month,
   SUM(sod.LineTotal) AS MonthlySales
FROM SalesLT.SalesOrderDetail AS sod
JOIN SalesLT.SalesOrderHeader AS soh ON sod.SalesOrderID = soh.SalesOrderID
-- Filter orders within the last 12 months based on the most recent order date
WHERE soh.OrderDate >= DATEADD(MONTH, -12, (SELECT MaxOrderDate FROM LatestOrder))
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate)
ORDER BY Year DESC, Month DESC;

-- Q10 - Customer Lifetime Value (CLV) - Goal: Calculate the Customer Lifetime Value (CLV) by summing the total revenue per customer. -- 

SELECT
   c.CustomerID,
   c.FirstName + ' ' + c.LastName AS CustomerName,
   SUM(sod.LineTotal) AS TotalSpent
FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
JOIN SalesLT.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY c.CustomerID, c.FirstName, c.LastName
ORDER BY TotalSpent DESC;

-- Q11 - Sales per Region (Based on Customer Location) - Goal: Calculate the total sales revenue by customer location (region/country). -- 

SELECT
   a.CountryRegion AS Country,
   SUM(sod.LineTotal) AS TotalSales
FROM SalesLT.SalesOrderDetail sod
JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
JOIN SalesLT.CustomerAddress ca ON soh.CustomerID = ca.CustomerID
JOIN SalesLT.Address a ON ca.AddressID = a.AddressID
GROUP BY a.CountryRegion
ORDER BY TotalSales DESC;

-- Q12 - Product Return Rate (Returns Analysis) --

SELECT
   p.Name AS ProductName,
   COUNT(DISTINCT sod.SalesOrderID) AS TotalOrders,
   COUNT(DISTINCT r.SalesOrderID) AS TotalReturns,
   (COUNT(DISTINCT r.SalesOrderID) * 100.0 / COUNT(DISTINCT sod.SalesOrderID)) AS ReturnRate
FROM SalesLT.SalesOrderDetail sod
JOIN SalesLT.Product p ON sod.ProductID = p.ProductID
LEFT JOIN SalesLT.SalesOrderDetail r ON sod.ProductID = r.ProductID AND r.ReturnReasonCode IS NOT NULL
GROUP BY p.Name
ORDER BY ReturnRate DESC;

-- Q13 - Product Cross-Selling Analysis -- 

WITH CrossSell AS (
   SELECT
       sod1.ProductID AS Product1,
       sod2.ProductID AS Product2,
       COUNT(DISTINCT soh.CustomerID) AS CustomerCount
   FROM SalesLT.SalesOrderDetail sod1
   JOIN SalesLT.SalesOrderDetail sod2 ON sod1.SalesOrderID = sod2.SalesOrderID
   JOIN SalesLT.SalesOrderHeader soh ON sod1.SalesOrderID = soh.SalesOrderID
   WHERE sod1.ProductID != sod2.ProductID
   GROUP BY sod1.ProductID, sod2.ProductID
)
SELECT
   p1.Name AS Product1Name,
   p2.Name AS Product2Name,
   CustomerCount
FROM CrossSell cs
JOIN SalesLT.Product p1 ON cs.Product1 = p1.ProductID
JOIN SalesLT.Product p2 ON cs.Product2 = p2.ProductID
ORDER BY CustomerCount DESC
LIMIT 10;

-- Q13 - Identifying High-Value Customers (Churn Prediction) -- 

WITH RecentOrders AS (
   SELECT CustomerID
   FROM SalesLT.SalesOrderHeader
   WHERE OrderDate >= DATEADD(MONTH, -6, GETDATE())
   GROUP BY CustomerID
)
SELECT
   c.CustomerID,
   c.FirstName + ' ' + c.LastName AS CustomerName,
   SUM(sod.LineTotal) AS TotalSpent
FROM SalesLT.SalesOrderHeader soh
JOIN SalesLT.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE soh.CustomerID NOT IN (SELECT CustomerID FROM RecentOrders)
GROUP BY c.CustomerID, c.FirstName, c.LastName
HAVING SUM(sod.LineTotal) > 5000
ORDER BY TotalSpent DESC;

