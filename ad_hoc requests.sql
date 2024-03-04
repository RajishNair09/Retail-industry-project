-- 1. provide a list of products with a base price greater than 500 and that are featured in promo type of 'BOGOF'. 
--    This information will help us to identify high value products that are currently being heavily discounted, 
--    which can be useful for evaluating our pricing and promotion strategies.
select promo_type from fact_events;
SELECT 
    dp.product_code,
    dp.product_name,
    fe.base_price,
    fe.promo_type
FROM
    dim_products dp
        JOIN
    fact_events fe ON dp.product_code = fe.product_code
WHERE
    fe.base_price > 500
        AND fe.promo_type = 'BOGOF';

-- 2.
-- Generate a report that provides an overview of the number of stores in each city. The results will be sorted in descending order of
-- store counts, allowing us to identify the cities with the highest store presence. The report includes two essential fields city and store count,
-- which will assist in optimizing our retail operations.

SELECT 
    city,
    COUNT(store_id) AS store_count
FROM 
    dim_stores
GROUP BY 
    city
ORDER BY 
    store_count DESC;
    
-- 3.
-- Generate a report that displays each campaign along with the total revenue generated before and after the campaign? the report includes three key fieldds
-- campaign name, total_revenue(before_promotion), total_revenue(after_promotion). this report should help in evaluating the financial impact of our
-- promotional campaigns.(display values in millions)

SELECT 
    dc.campaign_name,
    ROUND(SUM(fe.base_price * fe.`quantity_sold(before_promo)`) / 1000000, 2) AS total_revenue_before_promotion_millions,
    ROUND(SUM(fe.base_price * fe.`quantity_sold(after_promo)`) / 1000000, 2) AS total_revenue_after_promotion_millions
FROM 
    dim_campaigns dc
JOIN 
    fact_events fe ON dc.campaign_id = fe.campaign_id
GROUP BY 
    dc.campaign_name;

-- 4. produce a report that calculates the incremental sold quantity (isu%) for each category during the diwali campaign. 
-- additionally provide rankings for the categories based on their isu%. the report will include three key feilds category, isu%, and rank order
-- this information will assist in assessing the category wise success and impact of the diwali campaign on incremental sales.
-- isu% (incremental sold quantity percentage) is calculated as the percentage increase/decrease in quantity sold(after promo) compared to quantity sold(before promo)

WITH Diwali_Sales AS (
    SELECT 
        dp.category,
        SUM(fe.`quantity_sold(after_promo)`) AS total_quantity_sold_after,
        SUM(fe.`quantity_sold(before_promo)`) AS total_quantity_sold_before
    FROM 
        dim_products dp
    JOIN 
        fact_events fe ON dp.product_code = fe.product_code
    JOIN 
        dim_campaigns dc ON fe.campaign_id = dc.campaign_id
    WHERE 
        dc.campaign_name = 'Diwali'
    GROUP BY 
        dp.category
)
SELECT 
    category,
    ROUND(((total_quantity_sold_after - total_quantity_sold_before) / total_quantity_sold_before) * 100, 2) AS ISU_percentage,
    DENSE_RANK() OVER (ORDER BY ((total_quantity_sold_after - total_quantity_sold_before) / total_quantity_sold_before) DESC) AS rank_order
FROM 
    Diwali_Sales;

------------------------------------------------------
-- 5.create a report featuring the top 5 products, ranked by incremental revenue percentage(IR%) across all campaigns.
-- the report will provide essential information including product name, category, and ir%.
-- this analysis helps identify the most successful products in terms of incremental revenue across our campaigns,
-- assisting in product optimization.

WITH Product_IR AS (
    SELECT 
        dp.product_name,
        dp.category,
        SUM(fe.base_price * (fe.`quantity_sold(after_promo)` - fe.`quantity_sold(before_promo)`)) AS incremental_revenue,
        SUM(fe.base_price * fe.`quantity_sold(before_promo)`) AS total_revenue_before
    FROM 
        dim_products dp
    JOIN 
        fact_events fe ON dp.product_code = fe.product_code
    GROUP BY 
        dp.product_name, dp.category
)
SELECT 
    product_name,
    category,
    ROUND(((incremental_revenue / total_revenue_before) * 100), 2) AS IR_percentage
FROM 
    Product_IR
ORDER BY 
    IR_percentage DESC
LIMIT 5;

 -- ===================================STORE PERFORMANCE ANALYSIS ========================
 
 -- which are the top 10 stores in terms of incremental revenue generated from promotions

WITH Incremental_Revenue AS (
    SELECT 
        store_id,
        SUM(base_price * (`quantity_sold(after_promo)` - `quantity_sold(before_promo)`)) AS incremental_revenue
    FROM 
        fact_events
    GROUP BY 
        store_id
)
SELECT 
    s.store_id,
    s.city,
    IR.incremental_revenue
FROM 
    dim_stores s
JOIN 
    Incremental_Revenue IR ON s.store_id = IR.store_id
ORDER BY 
    IR.incremental_revenue DESC
LIMIT 10;

-- which are the bottom 10 stores when it comes to incremental sold units during the promotional period

WITH Incremental_Units AS (
    SELECT 
        store_id,
        SUM(`quantity_sold(after_promo)` - `quantity_sold(before_promo)`) AS incremental_sold_units
    FROM 
        fact_events
    GROUP BY 
        store_id
)
SELECT 
    s.store_id,
    s.city,
    IU.incremental_sold_units
FROM 
    dim_stores s
JOIN 
    Incremental_Units IU ON s.store_id = IU.store_id
ORDER BY 
    IU.incremental_sold_units ASC
LIMIT 10;

 -- ===================================PROMOTION TYPE ANALYSIS ========================

-- WHAT are the top 2 promotion types that resulted in the highest incremental revenue
SELECT 
    fe.promo_type,
    SUM(fe.base_price * (fe.`quantity_sold(after_promo)` - fe.`quantity_sold(before_promo)`)) AS incremental_revenue
FROM 
    fact_events fe
GROUP BY 
    fe.promo_type
ORDER BY 
    incremental_revenue DESC
LIMIT 2;


-- what are the bottom 2 promotion types in terms of their impact on incremental sold units

SELECT 
    fe.promo_type,
    SUM(fe.`quantity_sold(after_promo)` - fe.`quantity_sold(before_promo)`) AS incremental_sold_units
FROM 
    fact_events fe
GROUP BY 
    fe.promo_type
ORDER BY 
    incremental_sold_units ASC
LIMIT 2;

-- is there a signigicant difference in the performance of discount based promotions versus BOGOG or cashback promotions ?

SELECT 
    promo_type,
    SUM(base_price * (`quantity_sold(after_promo)` - `quantity_sold(before_promo)`)) AS incremental_revenue,
    SUM(`quantity_sold(after_promo)` - `quantity_sold(before_promo)`) AS incremental_sold_units
FROM 
    fact_events
GROUP BY 
    promo_type;

-- which promotions strike the best balance between incremental sold units and maintaining healthy margins ?

WITH Incremental_Metrics AS (
    SELECT 
        promo_type,
        SUM(base_price * (`quantity_sold(after_promo)` - `quantity_sold(before_promo)`)) AS incremental_revenue,
        SUM(`quantity_sold(after_promo)` - `quantity_sold(before_promo)`) AS incremental_sold_units
    FROM 
        fact_events
    GROUP BY 
        promo_type
)
SELECT 
    promo_type,
    (CAST(incremental_revenue AS FLOAT) / NULLIF(incremental_sold_units, 0)) AS revenue_per_unit_sold
FROM 
    Incremental_Metrics
ORDER BY 
    revenue_per_unit_sold DESC;

-- ===================================PRODUCT AND CATEGORY ANALYSIS ========================

-- WHICH PRODUCT CATEGORIES SAW THE MOST SIGNIFICANT LIFT IN SALES FROM THE PROMOTIONS

WITH Sales_Lift AS (
    SELECT 
        dp.category,
        SUM(fe.`quantity_sold(after_promo)` - fe.`quantity_sold(before_promo)`) AS incremental_sold_units,
        SUM(fe.`quantity_sold(before_promo)`) AS total_sold_units_before_promo
    FROM 
        fact_events fe
    JOIN 
        dim_products dp ON fe.product_code = dp.product_code
    GROUP BY 
        dp.category
)
SELECT 
    category,
    (CAST(incremental_sold_units AS FLOAT) / NULLIF(total_sold_units_before_promo, 0)) * 100 AS sales_lift_percentage
FROM 
    Sales_Lift
ORDER BY 
    sales_lift_percentage DESC;

-- are there specific products that respond exceptionally well or poorly to promotions

WITH Product_Response AS (
    SELECT 
        dp.product_name,
        dp.category,
        SUM(fe.`quantity_sold(after_promo)` - fe.`quantity_sold(before_promo)`) AS incremental_sold_units,
        SUM(fe.`quantity_sold(before_promo)`) AS total_sold_units_before_promo
    FROM 
        fact_events fe
    JOIN 
        dim_products dp ON fe.product_code = dp.product_code
    GROUP BY 
        dp.product_name, dp.category
)
SELECT 
    product_name,
    category,
    (CAST(incremental_sold_units AS FLOAT) / NULLIF(total_sold_units_before_promo, 0)) * 100 AS sales_lift_percentage
FROM 
    Product_Response
ORDER BY 
    sales_lift_percentage DESC;






