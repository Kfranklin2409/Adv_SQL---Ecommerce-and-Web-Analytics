Assessment Project

/* Q1 Gsearch seems to be the biggest driver of our business. Could you pull monthly trends for gsearch sessions
and orders so that we can showcase the growth there? */

SELECT 
	MIN(DATE(ws.created_at)) AS Monthly_gsearch_trend, 
    COUNT(DISTINCT ws.website_session_id) AS gsearch_sessions, 
    COUNT(DISTINCT o.order_id) AS Orders
FROM website_sessions ws
	LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
WHERE utm_source = 'gsearch' 
	AND ws.created_at <= '2012-11-27'
GROUP BY MONTH(DATE(ws.created_at))
;

/* Q2 Next, it would be great to see a similar monthly trend for Gsearch, but this time splitting out nonbrand and
brand campaigns separately. I am wondering if brand is picking up at all. If so, this is a good story to tell. */

SELECT 
	MIN(DATE(ws.created_at)) AS Monthly_gsearch_trend, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN ws.website_session_id ELSE null END) AS gsearch_brand_sessions, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN o.order_id ELSE null END) AS brand_campaign_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN ws.website_session_id ELSE null END) AS gsearch_nonbrand_sessions,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN o.order_id ELSE null END) AS nonbrand_campaign_orders
FROM website_sessions ws
	LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
WHERE utm_source = 'gsearch' 
	AND ws.created_at <= '2012-11-27'
GROUP BY MONTH(DATE(ws.created_at))
;

/* Q3 While we’re on Gsearch, could you dive into nonbrand, and pull monthly sessions and orders split by device type? 
I want to flex our analytical muscles a little and show the board we really know our traffic sources. */

SELECT 
	MIN(DATE(ws.created_at)) AS Monthly_gsearch_nonbrand_trend, 
	COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN ws.website_session_id ELSE null END) AS desktop_sessions, 
    COUNT(DISTINCT CASE WHEN device_type = 'desktop'THEN o.order_id ELSE null END) AS desktop_orders,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN ws.website_session_id ELSE null END) AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN o.order_id ELSE null END) AS mobile_orders
FROM website_sessions ws
LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
WHERE utm_source = 'gsearch' 
	AND utm_campaign = 'nonbrand'
	AND ws.created_at <= '2012-11-27'
GROUP BY MONTH(DATE(ws.created_at))
;

/* Q4 I’m worried that one of our more pessimistic board members may be concerned about the large % of traffic from 4 Gsearch. 
Can you pull monthly trends for Gsearch, alongside monthly trends for each of our other channels? */

-- Viewing sources to determine channels 
SELECT 
	utm_source,
    utm_campaign,
    http_referer
FROM website_sessions
WHERE created_at <= '2012-11-27'
GROUP BY 1,2,3; 

-- Counting the sessions of each type of channel 
SELECT 
	MIN(DATE(ws.created_at)) AS Monthly_utm_source_trend, 
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN ws.website_session_id ELSE NULL END) AS gsearch_paid_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN ws.website_session_id ELSE NULL END) AS bsearch_paid_sessions, 
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN ws.website_session_id ELSE NULL END) AS organic_search_sessions, 
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN ws.website_session_id ELSE NULL END) AS direct_search_sessions
FROM website_sessions ws
LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
WHERE ws.created_at <= '2012-11-27'
GROUP BY MONTH(DATE(ws.created_at))
;

/* Q5 I’d like to tell the story of our website performance improvements over the course of the first 8 months.
Could you pull session to order conversion rates, by month? */

SELECT 
	MIN(DATE(ws.created_at)) AS Month, 
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS Orders, 
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2)  AS monthly_cvr
FROM website_sessions ws
LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
WHERE ws.created_at <= '2012-11-1'
GROUP BY MONTH(DATE(ws.created_at));

/* Q6 For the gsearch lander test, please estimate the revenue that test earned us (Hint: Look at the increase in CVR
from the test (Jun 19 – Jul 28), and use nonbrand sessions and revenue since then to calculate incremental value) */ 

SELECT 
	MIN(website_pageview_id) AS first_pv
FROM website_pageviews
WHERE pageview_url = '/lander-1'
;

CREATE TEMPORARY TABLE first_test_pv
SELECT
	wp.website_session_id,
    MIN(wp.website_pageview_id) AS min_pv_id
FROM website_pageviews wp
	INNER JOIN website_sessions ws
		ON ws.website_session_id = wp.website_session_id
        AND ws.created_at < '2012-07-28' 
        AND wp.website_pageview_id >= 23504
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY 1;

-- Bring in landing page to each session, restricting to home or lander-1
CREATE TEMPORARY TABLE nonbrand_test_sessions_w_landing_page
SELECT
	ftp.website_session_id,
    wp.pageview_url AS landing_page
FROM first_test_pv ftp
	LEFT JOIN website_pageviews wp
		ON wp.website_pageview_id = ftp.min_pv_id
	WHERE wp.pageview_url IN ('/home', '/lander-1');
    
-- Bring in orders
Create TEMPORARY TABLE nonbrand_test_sessions_w_orders
SELECT
	nblp.website_session_id,
    nblp.landing_page,
    o.order_id AS order_id
FROM nonbrand_test_sessions_w_landing_page nblp
	LEFT JOIN orders o
		ON o.website_session_id = nblp.website_session_id;

-- Counting the landing page sessions from the above table and calculating conversion rate
SELECT 
	landing_page, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    COUNT(DISTINCT order_id) AS orders, 
    ROUND(COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id) * 100, 2) AS conv_rate
FROM nonbrand_test_sessions_w_orders
GROUP BY 1; 

-- /home		3.18
-- /lander-1	4.06
-- comparing original home page to new landing page there is an additional 0.87%  orders per session

-- finding the nost recent pageview for gsearch nonbrand where the traffic was sent to /home
SELECT 
	MAX(ws.website_session_id) AS most_recent_gsearch_nonbrand_home_pv
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
    AND pageview_url = '/home'
    AND ws.created_at < '2012-11-27';
    
-- max wbsite_session_id = 17145
-- Created a temp table to count the session since the /lander-1 test
CREATE TEMPORARY TABLE sessions_since_lander1_test
SELECT 
	COUNT(website_session_id) AS session_since_test
FROM website_sessions
WHERE utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
    AND website_session_id > 17145  -- last /home session
    AND created_at < '2012-11-27';
    
-- 22,972 website session since the test
-- Calculated the incremental orders since all traffic has been diverted to lander-1 home page
SELECT
	session_since_test * 0.0087 AS incremental_orders
FROM sessions_since_lander1_test; 

-- Results: ~50 extra orders per month! 

/* Q7 For the landing page test you analyzed previously, it would be great to show a full conversion funnel from each
of the two pages to orders. You can use the same time period you analyzed last time (Jun 19 – Jul 28).*/ 

-- created a subquery to flag what pages each session id saw and from what lander page

-- selected the session id and max of each pageview from subquery above to break out how far each session id made it and from what landing page (lander-1 or home)
-- CREATE TEMPORARY TABLE session_level_made_it_flagged 
SELECT
	website_session_id,
	MAX(homepage) AS saw_homepage,
    MAX(custom_lander) AS saw_custom_lander,
    MAX(products_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it, 
    MAX(thankyou_page) AS thankyou_made_it
FROM (
SELECT 
	ws.website_session_id,
	wp.pageview_url,
    -- wp.created_at AS pv_created_at, 
    CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS homepage,
	CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS custom_lander,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions ws
	LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
    AND ws.created_at <'2012-07-28'
    AND ws.created_at > '2012-06-19'
ORDER BY 1,2 
) AS pageview_level

GROUP BY 1
; 

-- part 2 of solution is determining the click through rate for each page by taking each page and dividing it by the total sessions
SELECT
	CASE
		WHEN saw_homepage = 1 THEN 'saw_homepage'
        WHEN saw_custom_lander = 1 THEN 'saw_custom_lander'
        ELSE 'oh no... check logic'
	END AS segment, 
    ROUND(COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS lander_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS product_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS mrfuzzy_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS cart_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS shipping_click_rt,
    ROUND(COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id)*100, 2) AS billing_click_rt
FROM session_level_made_it_flagged 
GROUP BY 1; 
    
/*  Q8 I’d love for you to quantify the impact of our billing test, as well. Please analyze the lift generated from the test
(Sep 10 – Nov 10), in terms of revenue per billing page session, and then pull the number of billing page sessions
for the past month to understand monthly impact. */ 

-- Create a query to view the billing version seen from the billing test timeframe
-- Use above to create subquery to count sessions and billing revenue per billing page seen 
SELECT 
	billing_version_seen, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    ROUND(SUM(price_usd) / COUNT(DISTINCT website_session_id),2) AS revenue_per_billing_page_seen
FROM (
SELECT 
	wp.website_session_id, 
    wp.pageview_url AS billing_version_seen, 
    o.order_id,
    o.price_usd
FROM website_pageviews wp
	LEFT JOin orders o
		ON o.website_session_id = wp.website_session_id
WHERE wp.created_at > '2012-09-10' -- assignment factor
	AND wp.created_at < '2012-11-10' -- assignment factor
    AND wp.pageview_url IN ('/billing', '/billing-2')
) AS billing_pageviews_and_order_data
GROUP BY 1
; 

-- $22.83 revenue per billing page for old version
-- $31.34 for the new billing page
-- New billing page has a lift of $8.51 

SELECT 
	COUNT(website_session_id) AS billing_sessions_past_month
FROM website_pageviews
WHERE pageview_url IN ('/billing', '/billing-2')
	AND created_at BETWEEN '2012-10-27' AND '2012-11-27'; -- past month
    
-- 1,194 billing session in past month
-- LIFT:$8.51 per billing session
-- VALUE OF BILLING TEST: $10,160 over the past month
