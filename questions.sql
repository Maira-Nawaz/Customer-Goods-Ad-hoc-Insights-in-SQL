Select * from dim_customer
Select * from dim_product
Select * from fact_gross_price
Select * from fact_manufacturing_cost
Select * from fact_pre_invoice_deductions
Select * from fact_sales_monthly


-- 1.  Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region. 

SELECT 
    market
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive' AND region = 'APAC'


-- 2.  What is the percentage of unique product increase in 2021 vs. 2020? 

WITH unique_products_2020 AS (
SELECT 
    COUNT(DISTINCT product_code) AS count_2020
FROM
    fact_sales_monthly
WHERE
    fiscal_year = 2020
), 
unique_products_2021 AS (
SELECT 
    COUNT(DISTINCT product_code) AS count_2021
FROM
    fact_sales_monthly
WHERE
    fiscal_year = 2021
)
SELECT 
    count_2020 as unique_products_2020,
    count_2021 as unique_products_2021,
    ROUND(((count_2021 - count_2020) / count_2020) * 100,
            2) AS percentage_chg
FROM
    unique_products_2020,
    unique_products_2021



-- 3.  Provide a report with all the unique product counts for each  segment  and sort them in descending order of product counts. 
 
SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC


-- 4.  Follow-up: Which segment had the most increase in unique products in  2021 vs 2020? 

with product_2020 as (
SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count_2020
FROM
    dim_product
  WHERE product_code IN (
    SELECT product_code FROM fact_sales_monthly WHERE fiscal_year = 2020
  )
  group by segment
),
product_2021 as (
SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count_2021
FROM
    dim_product
  WHERE product_code IN (
    SELECT product_code FROM fact_sales_monthly WHERE fiscal_year = 2021
  )
  group by segment
)
SELECT 
  p21.segment,
  p20.product_count_2020,
  p21.product_count_2021,
  (p21.product_count_2021 - p20.product_count_2020) AS difference
FROM product_2020 p20
JOIN product_2021 p21 ON p20.segment = p21.segment
ORDER BY difference DESC;


-- 5.  Get the products that have the highest and lowest manufacturing costs. 
(
SELECT 
	a.product_code, a.product, b.manufacturing_cost
FROM
    dim_product as a
    join fact_manufacturing_cost as b ON a.product_code = b.product_code
ORDER BY b.manufacturing_cost
LIMIT 1
)
UNION ALL
(
SELECT 
	a.product_code, a.product, b.manufacturing_cost
FROM
    dim_product as a
    join fact_manufacturing_cost as b ON a.product_code = b.product_code
ORDER BY b.manufacturing_cost DESC
LIMIT 1
);


-- 6.  Generate a report which contains the top 5 customers who received an  average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the  Indian  market. 

SELECT 
    a.customer_code,
    a.customer,
    ROUND(AVG(b.pre_invoice_discount_pct), 2) AS average_discount_percentage
FROM
    dim_customer a
        JOIN
    fact_pre_invoice_deductions b ON a.customer_code = b.customer_code
WHERE
    a.market = 'India'
        AND b.fiscal_year = 2021
GROUP BY a.customer_code , a.customer
ORDER BY average_discount_percentage DESC
LIMIT 5
    

-- 7.  Get the complete report of the Gross sales amount for the customer  “Atliq  Exclusive”  for each month  .  This analysis helps to  get an idea of low and high-performing months and take strategic decisions. 

SELECT 
    MONTHNAME(b.date) AS Month,
    YEAR(b.date) AS Year,
    SUM(c.gross_price * b.sold_quantity) AS Gross_sales_Amount
FROM
    dim_customer a
        JOIN
    fact_sales_monthly b ON a.customer_code = b.customer_code
        JOIN
    fact_gross_price c ON b.product_code = c.product_code
    WHERE a.customer = 'Atliq Exclusive'
GROUP BY Year , Month


-- 8.  In which quarter of 2020, got the maximum total_sold_quantity? 

WITH sales_2020 AS (
  SELECT 
    MONTH(date) AS month,
    sold_quantity
  FROM fact_sales_monthly
  WHERE fiscal_year = 2020
),
sales_with_quarter AS (
  SELECT 
    CASE
      WHEN month IN (9, 10, 11) THEN 'Q1'  -- Sep, Oct, Nov
      WHEN month IN (12, 1, 2) THEN 'Q2'   -- Dec, Jan, Feb
      WHEN month IN (3, 4, 5) THEN 'Q3'    -- Mar, Apr, May
      WHEN month IN (6, 7, 8) THEN 'Q4'    -- Jun, Jul, Aug
    END AS fiscal_quarter,
    sold_quantity
  FROM sales_2020
)
SELECT 
  fiscal_quarter,
  ROUND(SUM(sold_quantity) / 1000000, 2) AS total_sold_quantity_mln
FROM sales_with_quarter
GROUP BY fiscal_quarter
ORDER BY total_sold_quantity_mln DESC


-- 9.  Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 


WITH channel_sales as (
SELECT 
    a.channel,
    Round(SUM(c.gross_price * b.sold_quantity)/1000000,2) AS gross_sales_mln
FROM
    dim_customer a
        JOIN
    fact_sales_monthly b ON a.customer_code = b.customer_code
        JOIN
    fact_gross_price c ON b.product_code = c.product_code
    WHERE b.fiscal_year = 2021
GROUP BY channel
order by gross_sales_mln desc
),
total_sales AS (
  SELECT SUM(gross_sales_mln) AS total_mln FROM channel_sales
)
SELECT 
  channel,
  gross_sales_mln,
  ROUND((gross_sales_mln / total_mln) * 100, 2) AS percentage
FROM channel_sales, total_sales
ORDER BY gross_sales_mln DESC;


-- 10.  Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 

with ranked_products as (
SELECT 
    a.division,
    a.product_code,
    a.product,
    sum(b.sold_quantity) AS total_sold_quantity,
    RANK() OVER (PARTITION BY a.division ORDER BY SUM(b.sold_quantity) DESC) AS rank_order
FROM
     dim_product a
        JOIN
    fact_sales_monthly b ON a.product_code = b.product_code
where fiscal_year = 2021
group by  a.division,
    a.product_code,
    a.product
)
SELECT *
FROM ranked_products
WHERE rank_order <= 3
ORDER BY division, rank_order;
