-- Conversion Funnels Excercise

SELECT 
	website_session_id,
    pageview_url,
    created_at,
    MIN(website_pageview_id)
FROM website_pageviews
WHERE pageview_url = '/billing-2'
GROUP BY 1,2,3
ORDER BY 3
;

CREATE TEMPORARY TABLE billing_pages_and_orders1 
SELECT
	website_session_id,
    MAX(billing_1_seen) AS billing1,
    MAX(billing_2_seen) AS billing2,
    MAX(order_made) AS ordered
FROM (

SELECT 
	ws.website_session_id,
    wp.pageview_url, 
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_1_seen,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_2_seen,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS order_made
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE ws.created_at < '2012-11-10' 
	AND wp.website_pageview_id >= 53550
	AND wp.pageview_url IN ('/billing-2','/billing','/thank-you-for-your-order')
) AS pages_viewed_level
GROUP BY 1
;

CREATE TEMPORARY TABLE OG_billing_ordered_sessions1
SELECT 
	bpo.website_session_id,
    billing1,
    ordered
FROM billing_pages_and_orders1 bpo
	LEFT JOIN orders o 
		ON bpo.website_session_id = o.website_session_id
WHERE billing1 = '1'   
;

CREATE TEMPORARY TABLE New_billing_ordered_sessions1
SELECT 
	bpo.website_session_id,
    billing2,
    ordered
FROM billing_pages_and_orders1 bpo
	LEFT JOIN orders o 
		ON bpo.website_session_id = o.website_session_id
WHERE billing2 = '1'
;

SELECT
	(COUNT(DISTINCT CASE WHEN obos.ordered = '1' AND obos.billing1 = '1' THEN obos.website_session_id ELSE null END) 
		/ COUNT(obos.website_session_id)) * 100 AS OG_billing_orders_Conv_rt,
	(COUNT(DISTINCT CASE WHEN nbos.ordered = '1' AND nbos.billing2 = '1'THEN nbos.website_session_id ELSE null END) 
		/ COUNT(nbos.website_session_id)) * 100 AS New_billing_orders_Conv_rt
FROM billing_pages_and_orders1 bpo
	 LEFT JOIN OG_billing_ordered_sessions1 obos
		ON obos.website_session_id = bpo.website_session_id
	LEFT JOIN New_billing_ordered_sessions1 nbos
		ON nbos.website_session_id = bpo.website_session_id
;

CREATE TEMPORARY TABLE billing_pages_sessions
SELECT 
	ws.website_session_id,
    wp.pageview_url
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE ws.created_at < '2012-11-10' 
	AND wp.website_pageview_id >= 53550
	AND wp.pageview_url IN ('/billing-2','/billing')
;

CREATE TEMPORARY TABLE Ordered_sessions
SELECT 
	website_session_id,
    pageview_url,
    MAX(ordered) AS Created_order
FROM ( 
SELECT 
	bps.website_session_id,
    bps.pageview_url,
    CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS ordered
FROM billing_pages_sessions bps
	LEFT JOIN website_pageviews wp 
		ON bps.website_session_id = wp.website_session_id
GROUP BY 1,2,3 ) AS  ordered_sessions
-- WHERE ordered = '1'
GROUP BY 1,2
ORDER BY 1
;

SELECT 
	bps.pageview_url AS billing_version_seen,
	COUNT(bps.website_session_id) AS sessions,
	COUNT(os.website_session_id) AS orders, 
    (COUNT(os.website_session_id) / COUNT(bps.website_session_id)) * 100 AS billing_to_order_rt
FROM billing_pages_sessions bps
	LEFT JOIN ordered_sessions os
		ON os.website_session_id = bps.website_session_id
GROUP BY 1
;

-- How instructor solved
SELECT 
	wp.website_session_id,
    wp.pageview_url AS billing_version_seen,
    o.order_id
FROM website_pageviews wp
	LEFT JOIN orders o
		ON o.website_session_id = wp.website_session_id
WHERE wp.created_at < '2012-11-10' 
	AND wp.website_pageview_id >= 53550
	AND wp.pageview_url IN ('/billing-2','/billing')
;

SELECT 
	billing_version_seen,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    (COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id)) * 100 AS billing_to_order_rt
FROM ( 
SELECT 
	wp.website_session_id,
    wp.pageview_url AS billing_version_seen,
    o.order_id
FROM website_pageviews wp
	LEFT JOIN orders o
		ON o.website_session_id = wp.website_session_id
WHERE wp.created_at < '2012-11-10' 
	AND wp.website_pageview_id >= 53550
	AND wp.pageview_url IN ('/billing-2','/billing')
) AS billing_sessions_w_orders
GROUP BY 1
;

CREATE TEMPORARY TABLE session_level_flags2
SELECT
	website_session_id,
    MAX(products_ct) AS products_made_it,
    MAX(mrfuzzy_ct) AS mrfuzzy_made_it,
    MAX(cart_ct) AS cart_made_it,
    MAX(shipping_ct) AS shipping_made_it,
    MAX(thankyou_ct) AS thankyou_made_it
FROM (

SELECT 
	ws.website_session_id,
    wp.pageview_url,
    wp.created_at, 
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_ct, 
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_ct, 
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_ct, 
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_ct, 
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_ct    
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE ws.created_at BETWEEN '2012-08-05' AND '2012-09-05'
	AND pageview_url <> '/home'
    AND utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
ORDER BY 1,3
) AS page_level_views
GROUP BY 1;

SELECT 
	COUNT(website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE null END) AS click_to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE null END) AS click_to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE null END) AS click_to_cart,
	COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE null END) AS click_to_shipping,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE null END) AS click_to_thankyou
FROM session_level_flags1

UNION ALL

SELECT 
	COUNT(website_session_id) AS sessions,
    (COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE null END)/ COUNT(website_session_id)) * 100 AS lander_clickthrough_rate, 
	(COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE null END) / COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE null END)) * 100 AS products_clickthrough_rate,
	(COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE null END)  / COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE null END)) * 100 AS mrfuzzy_clickthrough_rate,
	(COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE null END) / COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE null END)) * 100 AS cart_clickthrough_rate,
	(COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE null END) / COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE null END)) * 100 AS shipping_clickthrough_rate
FROM session_level_flags2;

-- Building Conversion Funnels

-- BUSINESS CONTEXT
	-- We want to build a mini conversion funnel, from /lander-2 to /cart
    -- We want to know how many people reach each step, and also dropoff rates
    -- for simplicity of the demo, we're looking at /lander-2 traffic only
    -- for simplicity, we're looking at customers who like Mr. Fuzzy only

-- STEP 1: select all pageviews for relevant sessions
-- STEP 2: identify each relevant pageview as the specific funnel step
-- STEP 3: create the session-level conversion funnel view
-- STEP 4: aggregate the data to assess funnel performance

SELECT 
	ws.website_session_id,
    wp.pageview_url,
    wp.created_at AS pageview_created_at
    , CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page
    , CASE WHEN pageview_url = '/the-original-mr-fuzzy'THEN 1 ELSE 0 END AS mrfuzzy_page
    , CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE ws.created_at BETWEEN '2014-01-01' AND '2014-02-01' -- RANDOM TIMEFRAME FOR DEMO
	AND wp.pageview_url IN ('/lander-2','/products','/the-original-mr-fuzzy','/cart')
ORDER BY 1,3
;

CREATE TEMPORARY TABLE session_level_flags
SELECT 
	website_session_id,
    MAX(products_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it
FROM ( 

SELECT 
	ws.website_session_id,
    wp.pageview_url,
    wp.created_at AS pageview_created_at
    , CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page
    , CASE WHEN pageview_url = '/the-original-mr-fuzzy'THEN 1 ELSE 0 END AS mrfuzzy_page
    , CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE ws.created_at BETWEEN '2014-01-01' AND '2014-02-01' -- RANDOM TIMEFRAME FOR DEMO
	AND wp.pageview_url IN ('/lander-2','/products','/the-original-mr-fuzzy','/cart')
ORDER BY 1,3
) AS pageview_level
GROUP BY 1;

SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
    
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS Clicked_to_products,
	(COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT website_session_id)) * 100 AS lander_clickedthrough_rate,
        
	COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS Clicked_to_mrfuzzy,
    (COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END)) * 100 AS products_clickedthrough_rate,
        
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS clicked_to_cart,
    (COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)) * 100 AS mrfuzzy_clickedthrough_rate
        
FROM session_level_flags
;
