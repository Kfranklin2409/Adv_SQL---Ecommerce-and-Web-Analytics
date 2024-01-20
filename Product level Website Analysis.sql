Product level Website Analysis including pre- and post product analysis, cross-selling analysis, pathing analysis, conversion funnel analysis, and refund rates. COUNT-CASE pivot method, conditional, and aggregate functions used along with multiple joins.  

-- Product Sales Analysis	
SELECT
    COUNT(order_id) AS orders,
    SUM(price_usd) AS revenue,
    SUM(price_usd - cogs_usd) AS margin,
    AVG(price_usd) AS avg_order_value -- AOV: average price generated per order 
FROM orders
WHERE order_id BETWEEN 100 AND 200;

SELECT 
	primary_product_id,
	COUNT(order_id) AS orders, 
    SUM(price_usd) AS revenue,
    SUM(price_usd - cogs_usd) AS margin,
    AVG(price_usd) AS aov    
FROM orders
WHERE order_id BETWEEN 10000 AND 11000
GROUP BY 1
ORDER BY 2 DESC
;
-- Finding no. of sales, revenue, and margin in a given timeframe
SELECT
	YEAR(created_at) AS yr,
    MONTH(created_at) AS month,
    COUNT(order_id) AS Number_of_sales, 
    SUM(price_usd) AS revenue,
    SUM(price_usd - cogs_usd) AS margin
FROM orders
WHERE created_at < '2013-01-04'
GROUP BY 1, 2
;

-- Finding orders, conversion rate, revenue per session, and product sales breakdown
SELECT 
	YEAR(ws.created_at) AS yr,
    MONTH(ws.created_at) AS month,
    COUNT(DISTINCT order_id) AS orders,
	COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) AS conv_rate,
    SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id) AS revenue_per_session2,
    COUNT(DISTINCT CASE WHEN primary_product_id = 1 THEN order_id ELSE NULL END) AS product_one_orders,
    COUNT(DISTINCT CASE WHEN primary_product_id = 2 THEN order_id ELSE NULL END) AS product_two_orders
FROM  website_sessions ws
	LEFT JOIN orders o
		ON o.website_session_id = ws.website_session_id
WHERE ws.created_at BETWEEN '2012-04-01' AND '2013-04-01'
GROUP BY 1,2
;

-- Pre and post analysis of product launch on Dec. 12th, 2013
SELECT
	CASE 
		WHEN ws.created_at < '2013-12-12' THEN 'A. Pre_Birthday_Bear'
        WHEN ws.created_at >= '2013-12-12' THEN 'B. Post_Birthday_Bear'
        ELSE 'Check logic'
	END AS time_period,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders, 
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) as conv_rt,
    SUM(o.price_usd) AS total_revenue,
    SUM(o.items_purchased) AS total_products_sold,
    SUM(o.price_usd) / COUNT(DISTINCT o.order_id) AS avg_order_value,
    AVG(o.price_usd) AS AOV, 
    SUM(o.items_purchased) /  COUNT(DISTINCT o.order_id) AS products_per_order,
	SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id) AS revenue_per_session
FROM website_sessions ws
	LEFT JOIN orders o
		ON o.website_session_id = ws.website_session_id
WHERE ws.created_at BETWEEN '2013-11-12' AND '2014-01-12' -- month before and after product launch
GROUP BY 1; 


-- Products Cross-sell analysis
SELECT 
    o.primary_product_id,
    COUNT(DISTINCT o.order_id) AS orders,
    
    COUNT(DISTINCT CASE WHEN oi.product_id = 1 THEN o.order_id ELSE NULL END) AS x_sell_prod1, 
    ROUND(COUNT(DISTINCT CASE WHEN oi.product_id = 1 THEN o.order_id ELSE NULL END) /COUNT(DISTINCT o.order_id) * 100,2) AS x_sell_prod1_rt, 
    
    COUNT(DISTINCT CASE WHEN oi.product_id = 2 THEN o.order_id ELSE NULL END) AS x_sell_prod2,
        ROUND(COUNT(DISTINCT CASE WHEN oi.product_id = 2 THEN o.order_id ELSE NULL END)/COUNT(DISTINCT o.order_id) * 100,2) AS x_sell_prod2_rt,
        
    COUNT(DISTINCT CASE WHEN oi.product_id = 3 THEN o.order_id ELSE NULL END) AS x_sell_prod3,
    ROUND(COUNT(DISTINCT CASE WHEN oi.product_id = 3 THEN o.order_id ELSE NULL END)/COUNT(DISTINCT o.order_id) * 100,2) AS x_sell_prod3_rt
FROM orders o
	LEFT JOIN order_items oi
		ON oi.order_id = o.order_id
        AND oi.is_primary_item = 0 -- cross sell only
-- WHERE o.order_id BETWEEN 10000 AND 11000
WHERE o.created_at BETWEEN '2013-01-01' AND '2013-12-31'
GROUP BY 1;


-- Cross-Selling Performance

-- STEP 1: Identify the relevant /cart page views and their sessions
-- STEP 2: See which of those /cart sessions clicked through to the shipping
-- STEP 3: Find the orders associated with the /cart sessions. Analyze products purchased, AOV
-- STEP 4: Aggregate and analyze a summary of our findings

CREATE TEMPORARY TABLE sessions_seeing_cart
SELECT 
    CASE 
		WHEN created_at < '2013-09-25' THEN 'A. Pre_Cross_Sell'
        WHEN created_at >= '2013-01-06' THEN 'B.Post_Cross_Sell'
        ELSE 'Check logic'
	END as time_period,
    website_session_id AS cart_session_id,
    website_pageview_id AS cart_pageview_id
FROM website_pageviews
WHERE created_at BETWEEN '2013-08-25' AND '2013-10-25'
	AND pageview_url = '/cart';


CREATE TEMPORARY TABLE cart_sessions_seeing_another_page
SELECT 
	ssc.time_period,
    ssc.cart_session_id,
    MIN(wp.website_pageview_id) AS pv_id_after_cart
FROM sessions_seeing_cart ssc
	LEFT JOIN website_pageviews wp
		ON wp.website_session_id = ssc.cart_session_id
        AND wp.website_pageview_id > ssc.cart_pageview_id -- Only getting pageviews that happened AFTER the /cart pageview_url
GROUP BY ssc.time_period,
    ssc.cart_session_id
HAVING MIN(wp.website_pageview_id) IS NOT NULL;

CREATE TEMPORARY TABLE pre_post_sessions_orders
SELECT 
	time_period,
    cart_session_id,
    order_id,
    items_purchased,
    price_usd
FROM sessions_seeing_cart ssc
	INNER JOIN orders o -- inner join to get only orders that were placed
		ON ssc.cart_session_id = o.website_session_id;

SELECT
	time_period,
    COUNT(DISTINCT cart_session_id) AS cart_sessions,
    SUM(clicked_to_another_page) AS clickthroughs,
    SUM(clicked_to_another_page) / COUNT(DISTINCT cart_session_id) as cart_ctr,
    SUM(placed_order) AS orders_placed,
    SUM(items_purchased) AS products_purchased,
    SUM(items_purchased) / SUM(placed_order) AS products_per_order,
    SUM(price_usd) AS revenue,
    SUM(price_usd) / SUM(placed_order) AS aov,
    AVG(price_usd) AS aov2, -- Same result as above
    SUM(price_usd) / COUNT(DISTINCT cart_session_id) AS rev_per_cart_session
FROM (
	SELECT 
		ssc.time_period, 
		ssc.cart_session_id,
		CASE WHEN cssap.cart_session_id IS NULL THEN 0 ELSE 1 END AS clicked_to_another_page,
		CASE WHEN ppso.order_id IS NULL THEN 0 ELSE 1 END AS placed_order,
		ppso.items_purchased,
		ppso.price_usd
	FROM sessions_seeing_cart ssc
		LEFT JOIN cart_sessions_seeing_another_page cssap
			ON ssc.cart_session_id = cssap.cart_session_id
		LEFT JOIN pre_post_sessions_orders ppso
			ON ssc.cart_session_id = ppso.cart_session_id
	ORDER BY ssc.cart_session_id
    ) AS full_data
GROUP BY time_period;


SELECT 
    pageview_url,
    COUNT(DISTINCT wp.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders, 
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT wp.website_session_id) AS viewed_product_to_order_rate 
		-- conversion rate (typically sessions to orders) 
FROM website_pageviews wp
	LEFT JOIN orders o
		ON o.website_session_id = wp.website_session_id
WHERE wp.created_at BETWEEN '2013-02-01' AND '2013-03-01' -- arbitrary
	AND pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear')
GROUP BY 1
;

-- Product Pathing Analysis

-- pulling clickthrough rates from products since Jan. 6th, 2013 new product launch, by product, comparing the 3mo leading up to launch as a baseline

-- Step 1: find the relevant /products pageviews with website_session_id
-- Step 2: find the next pageview id that occurs AFTER the product pageview
-- Step 3: find the pageview_url associated with any applicable next pageview id
-- Step 4: summarize the datea and analyze the pre vs post periods

-- Step 1: find the relevant /products pageviews 
CREATE TEMPORARY TABLE products_pageviews
SELECT 
	website_session_id,
    website_pageview_id, 
    created_at, 
    CASE
		WHEN created_at < '2013-01-06' THEN 'A. Pre_Product_2'
        WHEN created_at >= '2013-01-06' THEN 'B. Post_Product_2'
        ELSE 'check logic'
	END AS time_period
FROM website_pageviews
WHERE created_at < '2013-04-06' 
	AND created_at >'2012-10-06' -- date of request and 3mo b4 product 2 launch
	AND pageview_url = '/products';

-- Step 2: Find the next pageview id that occurs AFTER the product pageview
CREATE TEMPORARY TABLE sessions_w_next_pageview_id
SELECT
	pg.time_period,
    pg.website_session_id,
    MIN(wp.website_pageview_id) AS min_next_pageview_id    
FROM products_pageviews pg
	LEFT JOIN website_pageviews wp
		ON wp.website_session_id = pg.website_session_id
        AND wp.website_pageview_id > pg.website_pageview_id
GROUP BY 1,2;

-- Step 3: find the pageview_url associated with any applicable next pageview id
CREATE TEMPORARY TABLE sessions_w_next_pageview_url
SELECT 
	snp.time_period,
    snp.website_session_id,
    wp.pageview_url AS next_pageview_url
FROM sessions_w_next_pageview_id snp
	LEFT JOIN website_pageviews wp
		ON wp.website_pageview_id = snp.min_next_pageview_id;
        
-- Step 4: summarize the data and analyze the pre vs post periods
SELECT 
	time_period, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NULL END) AS w_next_pg,
    ROUND(COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS pct_w_next_pg,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS to_mrfuzzy, 
	ROUND(COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS pct_to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS to_lovebear,
    ROUND(COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS pct_to_lovebear
FROM sessions_w_next_pageview_url
GROUP BY 1;


-- Conversion funnel from each product page to conversion & comparison between the 2 conversion funnels, for all website traffic
-- Creating multiple conversion funnels at the same time

-- Step 1: select all pageview for relevant sessions
-- Step 2: figure out which pageview urls to look for
-- Step 3: pull all pageviews and identify the funnel steps
-- Step 4: create the session level conversion funnel view
-- Step 5: aggregate the data to assess funnel performance 

-- Step 1: select all pageview for relevant sessions
CREATE TEMPORARY TABLE sessions_seeing_product_pages
SELECT 
	website_session_id, 
    website_pageview_id,
    pageview_url AS product_page_seen
FROM website_pageviews
WHERE created_at < '2013-04-10'
	AND created_at > '2013-01-06' -- product 2 launch
    AND pageview_url IN ('/the-original-mr-fuzzy','/the-forever-love-bear');
    
-- finding the right pageview_urls to build the funnel
SELECT DISTINCT 
	wp.pageview_url
FROM sessions_seeing_product_pages sspp
	LEFT JOIN website_pageviews wp
		ON wp.website_session_id = sspp.website_session_id
        AND wp.website_pageview_id > sspp.website_pageview_id 
        -- Want greater bc it gives only website pageviews that happened AFTER the customer saw the product
;

-- Create inner query to look over the pageview-level results
SELECT
	sspp.website_session_id,
    sspp.product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM sessions_seeing_product_pages sspp
	LEFT JOIN website_pageviews wp
		ON wp.website_session_id = sspp.website_session_id
        AND wp.website_pageview_id > sspp.website_pageview_id
ORDER BY 1,2;

-- creating subquery from above to 
CREATE TEMPORARY TABLE session_product_level_made_it_flags
SELECT
	website_session_id, 
    CASE
		WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
        WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
        ELSE 'check logic'
	END AS product_seen,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM ( 
SELECT
	sspp.website_session_id,
    sspp.product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM sessions_seeing_product_pages sspp
	LEFT JOIN website_pageviews wp
		ON wp.website_session_id = sspp.website_session_id
        AND wp.website_pageview_id > sspp.website_pageview_id
ORDER BY 1,2
) AS pageview_level
GROUP BY 1, 2; -- grouping by product seen

-- final output part 1 
SELECT
	product_seen, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_product_level_made_it_flags
GROUP BY 1;

-- FINAL OUTPUT - click rates
SELECT 
	product_seen, 
    ROUND(COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) *100, 2)AS product_page_click_rt, 
	ROUND(COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)*100, 2) AS cart_page_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)*100, 2) AS shipping_page_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) *100, 2) AS billing_page_click_rt
FROM session_product_level_made_it_flags
GROUP BY 1;


-- Analyzing Product Refund Rates
SELECT 
	oi.order_id,
    oi.order_item_id,
    oi.price_usd AS price_paid_usd,
    oi.created_at AS order_date,
    oiref.order_item_refund_id,
    oiref.refund_amount_usd,
    oiref.created_at AS refund_date
FROM order_items oi
	LEFT JOIN order_item_refunds oiref
		ON oiref.order_item_id = oi.order_item_id
WHERE oi.order_id IN (3489, 32049, 27061)
; 

-- Monthly refund rate
SELECT 
	YEAR(oi.created_at) AS yr,
    MONTH(oi.created_at) AS month,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(DISTINCT oiref.order_item_refund_id) AS total_refunds, 
    COUNT(DISTINCT oiref.order_item_refund_id) / COUNT(DISTINCT oi.order_id) AS refund_conv_rt
FROM order_items oi
	LEFT JOIN order_item_refunds oiref
		ON oi.order_item_id = oiref.order_item_id
GROUP BY 1,2        
;

--  Analyzing monthly product refund rate by product to address any quality and/or supplier concerns and affects on orders and sales. 
SELECT 
	YEAR(oi.created_at) AS yr,
    MONTH(oi.created_at) AS month_num,
    MONTHNAME(oi.created_at) AS month,
    COUNT(DISTINCT CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS p1_orders, 
    ROUND(COUNT(DISTINCT CASE WHEN product_id = 1 THEN oiref.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END)*100,2) AS p1_refund_rt,
        
	COUNT(DISTINCT CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS p2_orders, 
    ROUND(COUNT(DISTINCT CASE WHEN product_id = 2 THEN oiref.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END)*100, 2) AS p2_refund_rt,
        
	COUNT(DISTINCT CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS p3_orders, 
    ROUND(COUNT(DISTINCT CASE WHEN product_id = 3 THEN oiref.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END)*100, 2) AS p3_refund_rt,
        
	COUNT(DISTINCT CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS p4_orders, 
    ROUND(COUNT(DISTINCT CASE WHEN product_id = 4 THEN oiref.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END)*100, 2) AS p4_refund_rt
FROM order_items oi
	LEFT JOIN order_item_refunds oiref
		ON oi.order_item_id = oiref.order_item_id
WHERE oi.created_at < '2014-10-15'
GROUP BY 1,2,3 ; 
