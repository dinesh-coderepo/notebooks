--Write an SQL query to find the top 3 customers who have spent the most on their orders in the past 6 months.
with a as (
select 
customer_id,
sum(TotalAMount) as total_spent
from CustomerOrders
where date(OrderDate) > CURRENT_DATE - INTERVAL 6 MONTH
group by customer_id)
,b as (
select customer_id,total_spent, dense_rank() over(order by total_spent desc) as rk
 from a)
 select customer_id,total_spent from b
 where rk <= 3

 -- Write a query to find the products that have a higher-than-average sales amount in each month. 
 -- For each month, include the product ID and the difference between the product’s sales amount and the average sales amount for that month.

with a as (
select 
ProductID,
cast(date_extract(SaleDate,'year') as string) || cast(date_extract(SaleDate,'month') as string) as yearmonth,
sum(SaleAmount) as total_sum
from ProductSales
group by 1,2)
select 
ProductID,
yearmonth,
total_sum - avg(total_sum) over(partition by yearmonth) as diff
from a
where total_sum - avg(total_sum) over(partition by yearmonth) as diff > 0 

/*
Column Alias in WHERE Clause: The WHERE clause cannot use column aliases defined in the SELECT clause in the same query. Instead, you should use a subquery or CTE.
	2.	Date Formatting for Year-Month: Using || for string concatenation is valid in some SQL dialects, but it’s safer to use a proper format function like FORMAT_DATE or TO_CHAR to handle year-month extraction cleanly.
	3.	Improper Use of the Alias: You used where total_sum - avg(total_sum) over(partition by yearmonth) as diff > 0, which contains an alias in an incomplete WHERE clause condition.

Corrected Query:
*/

WITH a AS (
  SELECT 
    ProductID,
    DATE_FORMAT(SaleDate, '%Y-%m') AS yearmonth,
    SUM(SaleAmount) AS total_sum
  FROM ProductSales
  GROUP BY ProductID, yearmonth
)
SELECT 
  ProductID,
  yearmonth,
  total_sum,
  total_sum - AVG(total_sum) OVER(PARTITION BY yearmonth) AS diff
FROM a
WHERE total_sum > AVG(total_sum) OVER(PARTITION BY yearmonth);


/*
Write an SQL query to find the top 3 products in each region in terms of sales amount over the past year. Include the region, product ID, and the total sales amount.

This requires joining the tables, applying a window function, and filtering. Let me know your solution!
*/

with a as (
select a.ProductID, b.Region, sum(SaleAmount) as sale_total 
from Sales a 
inner join Stores b on a.StoreID = b.StoreID
where SaleDate > CURRENT_DATE - INTERVAL 1 YEAR --give syntax with date add as well
group by 1,2
)

select ProductID,Region from 
(
select * ,dense_rank() over(partition by Region order by sale_total desc) as rk
from a
)
where rk <= 3;

/*
	1.	Correctness of Join and Filtering Logic:
	•	The join and the date filtering logic are well done. You correctly filtered data to include only sales from the past year.
	•	However, you used CURRENT_DATE - INTERVAL 1 YEAR. To use DATE_ADD, it should be DATE_ADD(CURRENT_DATE, INTERVAL -1 YEAR). While both are correct, DATE_ADD is generally preferred for more complex date manipulations.
	2.	Sorting in DENSE_RANK:
	•	The ORDER BY clause in your DENSE_RANK() function should use DESC to rank by the highest sales amounts. Otherwise, it will rank in ascending order (by default).
	3.	Grouping and Filtering:
	•	Everything else in your query logic is fine. Just ensure that your partitioning is working as expected for each region.
    */

WITH a AS (
  SELECT 
    a.ProductID, 
    b.Region, 
    SUM(SaleAmount) AS sale_total 
  FROM Sales a 
  INNER JOIN Stores b ON a.StoreID = b.StoreID
  WHERE SaleDate > DATE_ADD(CURRENT_DATE, INTERVAL -1 YEAR)
  GROUP BY a.ProductID, b.Region
),
ranked_products AS (
  SELECT 
    ProductID, 
    Region, 
    sale_total, 
    DENSE_RANK() OVER(PARTITION BY Region ORDER BY sale_total DESC) AS rk
  FROM a
)
SELECT 
  ProductID, 
  Region 
FROM ranked_products
WHERE rk <= 3;

-- Write a query to find the average duration per user per day over the past month. Then, determine the percentage change in the average duration for each user between consecutive days. Include the UserID, Date, AverageDuration, and the PercentageChange for each day. (Hint: Use LAG and consider edge cases.)

WebTraffic

Column Name	Data Type
VisitID	INT
PageID	INT
VisitDate	DATE
UserID	INT
Duration	INT

with a as (
select 
UserID,
date(VisitDate) as day_date
avg(Duration) as avg_duration
from WebTraffic
where VisitDate > CURRENT_DATE - INTERVAL 1 MONTH
group by 1,2
)

select UserID, day_date, avg_duration,
 lag(avg_duration,1) over(partition by userID order by day_date) as prev_duration , 
 ((avg_duration - lag(avg_duration,1) over(partition by userID order byy day_date))*100)/(lag(avg_duration,1) over(partition by userID order by day_date))  as PercentageChange 
from a

WITH daily_avg AS (
  SELECT 
    UserID,
    DATE(VisitDate) AS day_date,
    AVG(Duration) AS avg_duration
  FROM WebTraffic
  WHERE VisitDate > DATE_ADD(CURRENT_DATE, INTERVAL -1 MONTH)
  GROUP BY UserID, DATE(VisitDate)
),
daily_change AS (
  SELECT 
    UserID,
    day_date,
    avg_duration,
    LAG(avg_duration, 1) OVER(PARTITION BY UserID ORDER BY day_date) AS prev_avg,
    CASE 
      WHEN LAG(avg_duration, 1) OVER(PARTITION BY UserID ORDER BY day_date) IS NULL THEN 0
      ELSE (avg_duration - LAG(avg_duration, 1) OVER(PARTITION BY UserID ORDER BY day_date)) / 
            LAG(avg_duration, 1) OVER(PARTITION BY UserID ORDER BY day_date) * 100
    END AS PercentageChange
  FROM daily_avg
)
SELECT 
  UserID,
  day_date,
  avg_duration,
  prev_avg,
  PercentageChange
FROM daily_change
ORDER BY UserID, day_date;

-- Write an SQL query to classify customers into 3 segments based on their transaction history over the past year:


	•	High-Spending: Customers with a total amount spent in the top 10% of all customers.
	•	Medium-Spending: Customers with a total amount spent between 50% and 90%.
	•	Low-Spending: Customers with a total amount spent in the bottom 50%.

Include the CustomerID, CustomerName, Segment, and SpendingCategory (High, Medium, or Low).

with stage1 as (
select a.CustomerID  , b.CustomerName , b.Segment , sum(a.AmountSpent) as amt
from Transactions a 
inner join Customers b on a.CustomerID = b.CustomerID
where TransactionDate >= CURRENT_DATE - INTERVAL 1 YEAR
group by 1,2,3
)

select CustomerID , CustomerName,Segment,
case when (percent_rank() over(order by amt desc))*100 < 10 then 'High-Spending'
when (percent_rank() over(order by amt desc))*100 >= 10 and (percent_rank() over(order by amt desc))*100 <= 50 then 'Medium-Spending'
when (percent_rank() over(order by amt desc))*100 > 50  then 'Low-Spending' end as SpendingCategory
from stage1

--
WITH CustomerSpending AS (
  SELECT 
    a.CustomerID,  
    b.CustomerName, 
    b.Segment, 
    SUM(a.AmountSpent) AS TotalSpent
  FROM Transactions a 
  INNER JOIN Customers b ON a.CustomerID = b.CustomerID
  WHERE TransactionDate >= DATE_ADD(CURRENT_DATE, INTERVAL -1 YEAR)
  GROUP BY a.CustomerID, b.CustomerName, b.Segment
),
CustomerRanks AS (
  SELECT 
    CustomerID, 
    CustomerName, 
    Segment, 
    TotalSpent, 
    PERCENT_RANK() OVER(ORDER BY TotalSpent DESC) AS SpendingRank
  FROM CustomerSpending
)
SELECT 
  CustomerID, 
  CustomerName, 
  Segment, 
  CASE 
    WHEN SpendingRank < 0.1 THEN 'High-Spending'
    WHEN SpendingRank >= 0.1 AND SpendingRank < 0.5 THEN 'Medium-Spending'
    ELSE 'Low-Spending'
  END AS SpendingCategory
FROM CustomerRanks
ORDER BY SpendingRank;