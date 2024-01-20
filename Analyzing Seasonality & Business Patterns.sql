-- Analyzing Seasonality & Business Patterns

-- DATE functions
SELECT
	website_session_id,
    created_at, 
    HOUR(created_at) AS hr, 
    WEEKDAY(created_at) AS wkday, -- 0 = Mon, 1 = Tues, etc
    CASE 
		WHEN WEEKDAY(created_at) = 0 THEN 'Monday'
        WHEN WEEKDAY(created_at) = 1 THEN 'Tuesday'
        ELSE 'other day'
	END AS clean_weekday, 
    QUARTER(created_at) AS qtr,
    MIN(DATE(created_at)) AS qtr_date,
    MONTH(created_at) AS month,
    DATE(created_at) AS date,
    WEEK(created_at) AS wk
FROM website_sessions
WHERE website_session_id BETWEEN 150000 AND 155000 -- arbitrary
GROUP BY QUARTER(DATE(created_at)), 1,2
;

-- Pulling monthly and weekly session and order volume from the past year (2012)
SELECT
    MONTH(ws.created_at) AS month, 
    MONTHNAME(ws.created_at) AS month_name, -- not requested but added for skill practice
    SUM(COUNT(DISTINCT ws.website_session_id)) OVER(PARTITION BY MONTH(ws.created_at)) AS total_month_sessions, -- not requested but added for skill practice
    SUM(COUNT(o.order_id)) OVER(PARTITION BY MONTH(ws.created_at)) AS total_month_orders,-- not requested but added for skill practice
    WEEK(ws.created_at) AS wk,
    MIN(DATE(ws.created_at)) AS Week_start, -- not requested but added for depth of understanding for user
    COUNT(DISTINCT ws.website_session_id) as sessions,
    COUNT(DISTINCT o.order_id) AS orders
    -- FINISH LATER (only want to show 1st monthly totals for each month) CASE WHEN ROW(SUM(COUNT(o.order_id)) OVER(PARTITION BY MONTH(ws.created_at))) = 
FROM website_sessions ws
	LEFT JOIN orders o
		ON o.website_session_id = ws.website_session_id
WHERE ws.created_at < '2013-01-01'
GROUP BY 1, 2, 5, YEAR(ws.created_at)
ORDER BY YEAR(ws.created_at) ASC, 1, 3 ; -- expected results were 2 separate tables but decided to combine for overall comprehension in one place. 

-- Finding the average per day per hour of sessions volume using subquery
SELECT
	hr,
	ROUND(AVG(CASE WHEN wkday = 0 THEN sessions ELSE NULL END),1) AS mon,
    ROUND(AVG(CASE WHEN wkday = 1 THEN sessions ELSE NULL END),1) AS tues,
    ROUND(AVG(CASE WHEN wkday = 2 THEN sessions ELSE NULL END),1) AS wed,
    ROUND(AVG(CASE WHEN wkday = 3 THEN sessions ELSE NULL END),1) AS thurs,
    ROUND(AVG(CASE WHEN wkday = 4 THEN sessions ELSE NULL END),1) AS fri,
    ROUND(AVG(CASE WHEN wkday = 5 THEN sessions ELSE NULL END),1) AS sat,
    ROUND(AVG(CASE WHEN wkday = 6 THEN sessions ELSE NULL END),1) AS sun
FROM (
SELECT 
	DATE(created_at) AS created_date,
    WEEKDAY(created_at) AS wkday,
    HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'
GROUP BY 1, 2, 3) AS hourly_brkdwn_by_day
GROUP BY 1
;
-- Creating subquery of daily hourly sessions
SELECT 
	DATE(created_at) AS created_date,
    WEEKDAY(created_at) AS wkday,
    HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'
GROUP BY 1, 2, 3;