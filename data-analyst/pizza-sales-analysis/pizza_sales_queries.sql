-- 1) Total Revenue
SELECT SUM(total_price ) AS  Total_revenue
FROM pizza_sales;

-- 2) Average Order Value
SELECT SUM(total_price)  / Count(Distinct order_id)    AS Avg_order_value
FROM pizza_sales;

-- 3) Total Pizzas Sold
SELECT SUM(quantity) AS  Total_pizas_sold
FROM pizza_sales;

-- 4) Total Orders 

SELECT COUNT(Distinct order_ID) AS Total_orders 
FROM [pizza_sales];


-- 5) Average Pizzas Per Order

Select CAST(SUM(quantity)  AS decimal(10,2)) / COUNT(Distinct order_ID)  AS Avg_pizzas_per_order
FROM pizza_sales;


-- CHARTS REQUIREMENT

-- 1 Daily Trend for total Orders

Select DATENAME(DW, Order_Date)			AS Order_Day, 
COUNT(DISTINCT order_id)                AS Total_orders
FROM pizza_sales
GROUP BY DATENAME(DW, Order_Date);


-- 2 Monthly Trend for Total Orders
Select DATENAME(MONTH, Order_Date)			AS Month_name, 
COUNT(DISTINCT order_id)                AS Total_orders
FROM pizza_sales
GROUP BY DATENAME(MONTH, Order_Date)
Order BY Total_orders DESC;	



-- 3 Percentage of sales by pizza Category 
SELECT pizza_category,
      SUM(Total_price)  AS Total_sales,
      SUM(total_price) * 100 / (SELECT SUM(total_price) from pizza_sales) AS Total_percenateg_sales
FROM pizza_sales
GROUP by  pizza_category;


SELECT * FROM pizza_sales;



-- 4 Percentage of Sals by pizza size
SELECT pizza_size,
      SUM(Total_price)  AS Total_sales,
      CAST(SUM(total_price) * 100 / (SELECT SUM(total_price) from pizza_sales) AS DECIMAL(10,2)) AS Total_percenateg_sales
FROM pizza_sales
GROUP by  pizza_size;


-- 5 total pizas sold by Pizza Category
SELECT pizza_size,
      SUM(Total_price)  AS Total_sales,
      CAST(SUM(total_price) * 100 / (SELECT SUM(total_price) from pizza_sales WHERE DATEPART(QUARTER,order_date) =1) AS DECIMAL(10,2)) AS Total_percenateg_sales
FROM pizza_sales
WHERE DATEPART(QUARTER,order_date) =1
GROUP by  pizza_size
Order by  Total_percenateg_sales DESC ;



-- 6 Top 5 Best Sallers by Total Pizzas Sold

SELECT  TOP 5 pizza_name,
	    SUM(total_price)                     AS Total_sales
from pizza_sales
GROUP BY pizza_name
ORDER BY SUM(total_price) DESC; 

-- 7 Bottom 5 worst Sellers by total Pizzas Sold
SELECT  TOP 5 pizza_name,
	    CAST(SUM(total_price) AS DECIMAL(10,2))                     AS Total_sales
from pizza_sales
GROUP BY pizza_name
ORDER BY SUM(total_price) ASC; 


-- 8 TOP 5 Pizzas by Quantity
SELECT  TOP 5 pizza_name,
	    SUM(quantity)                     AS Total_quantity
from pizza_sales
GROUP BY pizza_name
ORDER BY Total_quantity DESC; 


-- 9 Bottom 5 Pizzas by Quantity
SELECT  TOP 5 pizza_name,
	    SUM(quantity)                     AS Total_quantity
from pizza_sales
GROUP BY pizza_name
ORDER BY Total_quantity ASC; 



-- 10 . Top 5 Pizzas by Total Orders
SELECT  TOP 5 pizza_name,
	    COUNT(DISTINCT order_id)                     AS Total_orders
from pizza_sales
GROUP BY pizza_name
ORDER BY Total_orders DESC; 


-- 11. bottom 5 Pizzas by Total Orders
	SELECT  TOP 5 pizza_name,
			COUNT(DISTINCT order_id)                     AS Total_orders
	from pizza_sales
	GROUP BY pizza_name
	ORDER BY Total_orders ASC; 
