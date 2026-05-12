-- OBJ01 - Finding Nulls in Database

Select count(*) from customer where company is null;
Select count(*) from customer where state is null;
Select count(*) from customer where fax is null;
Select count(*) from track where composer is null;
Select count(*) from employee where reports_to is null;

-- OBJ02 - Top Artist in USA

WITH data AS (
    SELECT 
        a.name, 
        g.name AS genre_name, 
        SUM(il.unit_price * quantity) AS revenue 
    FROM invoice i 
    JOIN invoice_line il ON i.invoice_id = il.invoice_id 
    JOIN track t ON il.track_id = t.track_id 
    JOIN album al ON t.album_id = al.album_id 
    JOIN artist a ON al.artist_id = a.artist_id 
    JOIN genre g ON g.genre_id = t.genre_id
    WHERE billing_country = 'USA' 
    GROUP BY a.name, g.name
)
SELECT * 
FROM data 
ORDER BY revenue DESC 
LIMIT 10;

-- OBJ03 - Customer Distribution by Country

SELECT 
    country, 
    COUNT(*) AS customer_count 
FROM customer 
GROUP BY country
ORDER BY customer_count DESC;

-- OBJ04 - Revenue by Location

SELECT 
    billing_city,
    billing_state,
    billing_country,
    SUM(total) AS total_revenue,
    COUNT(invoice_id) AS total_orders
FROM invoice 
GROUP BY billing_city, billing_state, billing_country
ORDER BY total_revenue DESC;

-- OBJ05 - Top 5 Customers per Country

WITH cte1 AS (
    SELECT 
        c.customer_id,
        first_name,
        last_name, 
        billing_country,
        SUM(total) AS total_revenue 
    FROM invoice i 
    JOIN customer c ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, first_name, last_name, billing_country
),
ranking AS (
    SELECT *, 
           ROW_NUMBER() OVER (
               PARTITION BY billing_country 
               ORDER BY total_revenue DESC
           ) AS rnk 
    FROM cte1
)
SELECT * 
FROM ranking 
WHERE rnk <= 5 
ORDER BY billing_country, rnk;

-- OBJ06 - Most Purchased Track per Customer

WITH cte1 AS (
    SELECT 
        i.customer_id, 
        il.track_id, 
        SUM(il.quantity * il.unit_price) AS total_spent
    FROM invoice i 
    JOIN invoice_line il 
        ON i.invoice_id = il.invoice_id
    GROUP BY i.customer_id, il.track_id
),
cte2 AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id 
               ORDER BY total_spent DESC
           ) AS rnk
    FROM cte1
)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    t.track_id,
    t.name AS track_name,
    c2.total_spent
FROM cte2 c2
JOIN customer c ON c.customer_id = c2.customer_id
JOIN track t ON t.track_id = c2.track_id
WHERE rnk = 1;

-- OBJ07 - Customer Behavior Analysis

-- Purchase Frequency
SELECT 
    customer_id, 
    COUNT(*) AS total_purchases,
    MIN(invoice_date) AS first_purchase,
    MAX(invoice_date) AS recent_purchase 
FROM invoice 
GROUP BY customer_id
ORDER BY total_purchases;

-- Average Order Value
SELECT 
    customer_id, 
    ROUND(AVG(total), 2) AS avg_order_value, 
    SUM(total) AS total_spent 
FROM invoice 
GROUP BY customer_id 
ORDER BY avg_order_value DESC;

-- Monthly Trends
SELECT 
    MONTH(invoice_date) AS month,
    COUNT(*) AS total_orders,
    SUM(total) AS revenue 
FROM invoice 
GROUP BY MONTH(invoice_date) 
ORDER BY month;

-- Purchase Interval
WITH cte1 AS (
    SELECT 
        customer_id, 
        invoice_date, 
        LAG(invoice_date) OVER (
            PARTITION BY customer_id 
            ORDER BY invoice_date
        ) AS prev_date 
    FROM invoice
)
SELECT 
    customer_id, 
    AVG(DATEDIFF(invoice_date, prev_date)) AS avg_days_between_purchases 
FROM cte1 
WHERE prev_date IS NOT NULL 
GROUP BY customer_id;

-- OBJ08 - Churn Rate
WITH total AS (
    SELECT COUNT(*) AS total FROM customer
),
last AS (
    SELECT 
        c.customer_id, 
        MAX(invoice_date) AS recent 
    FROM customer c 
    LEFT JOIN invoice i 
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
churned AS (
    SELECT COUNT(*) AS churned 
    FROM last 
    WHERE TIMESTAMPDIFF(
        MONTH, 
        recent, 
        (SELECT MAX(invoice_date) FROM invoice)
    ) > 3
)
SELECT (churned * 100.0 / total) AS churn_rate 
FROM total, churned;


-- OBJ09 - Best Selling Artist (USA)
WITH cte1 AS (
    SELECT 
        a.name AS artist_name, 
        SUM(il.unit_price * quantity) AS revenue 
    FROM invoice i 
    JOIN invoice_line il ON i.invoice_id = il.invoice_id 
    JOIN track t ON il.track_id = t.track_id 
    JOIN album al ON t.album_id = al.album_id 
    JOIN artist a ON al.artist_id = a.artist_id 
    WHERE billing_country = 'USA' 
    GROUP BY a.name
)
SELECT artist_name, revenue 
FROM cte1 
ORDER BY revenue DESC 
LIMIT 5;

-- OBJ10 - Customers with Diverse Taste
WITH data AS (
    SELECT 
        customer_id, 
        COUNT(DISTINCT g.genre_id) AS genre_count
    FROM invoice i 
    JOIN invoice_line il ON i.invoice_id = il.invoice_id 
    JOIN track t ON il.track_id = t.track_id 
    JOIN genre g ON g.genre_id = t.genre_id
    GROUP BY customer_id)
SELECT 
    d.customer_id, 
    first_name, 
    last_name, 
    genre_count 
FROM data d 
JOIN customer c ON d.customer_id = c.customer_id 
WHERE genre_count >= 3
ORDER BY genre_count DESC, customer_id;


-- OBJ11 - Genre Ranking (USA)

WITH data AS (
    SELECT 
        g.name AS genre_name, 
        SUM(il.unit_price * quantity) AS total_sales
    FROM invoice i 
    JOIN invoice_line il ON i.invoice_id = il.invoice_id 
    JOIN track t ON il.track_id = t.track_id 
    JOIN genre g ON g.genre_id = t.genre_id
    WHERE billing_country = 'USA' 
    GROUP BY g.name
)
SELECT 
    genre_name, 
    total_sales, 
    RANK() OVER (ORDER BY total_sales DESC) AS rnk 
FROM data;

-- OBJ12 - Churned Customers List

WITH max_date AS (
    SELECT MAX(invoice_date) AS max_dt FROM invoice
),
last AS (
    SELECT 
        c.customer_id, 
        MAX(i.invoice_date) AS recent 
    FROM customer c 
    LEFT JOIN invoice i 
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
)
SELECT l.customer_id
FROM last l
CROSS JOIN max_date m
WHERE TIMESTAMPDIFF(MONTH, l.recent, m.max_dt) > 3;

-- SUBJECTIVE QUESTION
-- SUB01
WITH usa_album_sales AS (
    SELECT 
        al.album_id,
        al.title AS album_title,
        ar.name AS artist_name,
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS total_revenue
    FROM customer c
    JOIN invoice i 
        ON c.customer_id = i.customer_id
    JOIN invoice_line il 
        ON i.invoice_id = il.invoice_id
    JOIN track t 
        ON il.track_id = t.track_id
    JOIN album al 
        ON t.album_id = al.album_id
    JOIN artist ar 
        ON al.artist_id = ar.artist_id
    JOIN genre g 
        ON t.genre_id = g.genre_id
    WHERE c.country = 'USA'
    GROUP BY al.album_id, al.title, ar.name, g.name
),
ranked_albums AS (
    SELECT *,
           RANK() OVER (ORDER BY total_revenue DESC) AS rnk
    FROM usa_album_sales
)
SELECT 
    album_title,
    artist_name,
    genre_name,
    total_revenue
FROM ranked_albums
WHERE rnk <= 3;

-- SUB02
-- =========================================
WITH data AS (
    SELECT g.name AS genre_name, billing_country,
           SUM(il.unit_price * quantity) AS revenue
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    JOIN genre g ON g.genre_id = t.genre_id
    GROUP BY g.name, billing_country
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY billing_country ORDER BY revenue DESC) AS rnk
    FROM data
)
SELECT *
FROM ranked
WHERE 
    (billing_country = 'USA' AND rnk <= 3)
    OR
    (billing_country != 'USA' AND rnk <= 3)
ORDER BY billing_country, revenue DESC;

-- SUB03
-- =========================================
with data as (
	select c.customer_id,
    sum(total) as total_spent,
    avg(total) as AOV,
    count(invoice_id) as order_count, 
    min((invoice_date)) as first,
    max((invoice_date)) as recent 
    from customer c join invoice i on c.customer_id=i.customer_id  group by customer_id 
)
,cte1 as (
select customer_id, total_spent, AOV, order_count, 
timestampdiff(month, first, recent) as tenure from data
)
, cte2 as (
select customer_id, total_spent, AOV, order_count, tenure, 
case 
	when tenure<=30 then 'New'
    when tenure>40 then 'Long-Term'
    else 'Mid-Term' end as category from cte1 order by tenure
)
select category, 
	round(avg(total_spent),2) avg_total_spent, 
    round(avg(aov),2) avg_AOV, 
    round(avg(order_count),2) avg_order_count, 
    round(avg(tenure),2) avg_tenure 
    from cte2 
    group by category 
    order by avg(tenure);

-- SUB04
-- =========================================
WITH data AS (
    SELECT 
        i.invoice_id,
        t.album_id,
        g.name AS genre_name,
        a.name AS artist_name,
        al.title AS album_title
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON g.genre_id = t.genre_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
)

-- 1. Genre affinity
SELECT 
    d1.genre_name AS genre_1,
    d2.genre_name AS genre_2,
    COUNT(*) AS freq
FROM data d1
JOIN data d2 
    ON d1.invoice_id = d2.invoice_id 
    AND d1.genre_name < d2.genre_name
GROUP BY d1.genre_name, d2.genre_name
ORDER BY freq DESC
LIMIT 3;


-- 2. Artist affinity
WITH data AS (
    SELECT 
        i.invoice_id,
        t.album_id,
        g.name AS genre_name,
        a.name AS artist_name,
        al.title AS album_title
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON g.genre_id = t.genre_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
)

SELECT 
    d1.artist_name AS artist_1,
    d2.artist_name AS artist_2,
    COUNT(*) AS freq
FROM data d1
JOIN data d2 
    ON d1.invoice_id = d2.invoice_id 
    AND d1.artist_name < d2.artist_name
GROUP BY d1.artist_name, d2.artist_name
ORDER BY freq DESC
LIMIT 3;


-- 3. Album affinity
WITH data AS (
    SELECT 
        i.invoice_id,
        t.album_id,
        g.name AS genre_name,
        a.name AS artist_name,
        al.title AS album_title
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON g.genre_id = t.genre_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
)

SELECT 
    d1.album_title AS album_1,
    d2.album_title AS album_2,
    COUNT(*) AS freq
FROM data d1
JOIN data d2 
    ON d1.invoice_id = d2.invoice_id 
    AND d1.album_title < d2.album_title
GROUP BY d1.album_title, d2.album_title
ORDER BY freq DESC
LIMIT 3;

-- SUB05
-- =========================================
select 
    billing_country,
    sum(total) as revenue,
    count(invoice_id) as orders,
    count(distinct customer_id) as customers,
    
    round(sum(total)/count(invoice_id),2) as AOV,
    round(sum(total)/count(distinct customer_id),2) as revenue_per_customer,
    round(count(invoice_id)/count(distinct customer_id),2) as orders_per_customer,
    
    date(min(invoice_date)) as first_purchase,
    date(max(invoice_date)) as last_purchase,
    timestampdiff(day, max(invoice_date), current_date) as days_since_last_purchase,
    
    rank() over (order by sum(total) desc) as revenue_rank,
    round(sum(total) * 100 / sum(sum(total)) over (),2) as revenue_pct

from invoice
group by billing_country
order by revenue_rank;

-- SUB06
-- =========================================
with customer_metrics as (
    select 
        c.customer_id,
        c.country,
        count(i.invoice_id) as order_count,
        sum(i.total) as total_spent,
        avg(i.total) as aov,
        max(i.invoice_date) as last_purchase,
        min(i.invoice_date) as first_purchase
    from customer c
    left join invoice i 
        on c.customer_id = i.customer_id
    group by c.customer_id, c.country
),

rfm as (
    select *,
        timestampdiff(month, last_purchase, (select max(invoice_date) from invoice)) as months_inactive
    from customer_metrics
),

segmented as (
    select *,
        case 
            when months_inactive >= 6 then 'high_risk'
            when months_inactive between 3 and 5 then 'medium_risk'
            else 'low_risk'
        end as risk_segment
    from rfm
)

select 
    country,
    risk_segment,
    count(*) as customers,
    round(avg(total_spent),2) as avg_spend,
    round(avg(order_count),2) as avg_orders,
    round(
        sum(case when risk_segment = 'high_risk' then 1 else 0 end) * 100.0
        / sum(count(*)) over (partition by country),
    2) as churn_rate
from segmented
group by country, risk_segment;

-- SUB07
-- =========================================
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        MIN(i.invoice_date) AS first_purchase,
        MAX(i.invoice_date) AS last_purchase,
        COUNT(DISTINCT i.invoice_id) AS order_count,
        SUM(i.total) AS total_spent,
        AVG(i.total) AS avg_order_value
    FROM customer c
    JOIN invoice i 
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),

final AS (
    SELECT 
        customer_id,
        TIMESTAMPDIFF(MONTH, first_purchase, last_purchase) AS tenure,
        TIMESTAMPDIFF(MONTH, last_purchase, (SELECT MAX(invoice_date) FROM invoice)) AS recency,
        order_count,
        total_spent,
        avg_order_value,
        order_count / NULLIF(TIMESTAMPDIFF(MONTH, first_purchase, last_purchase),0) AS purchase_frequency,
        avg_order_value * order_count AS estimated_clv
    FROM customer_metrics
)

SELECT *,
    CASE 
        WHEN recency <= 3 AND order_count >= 10 THEN 'High Value'
        WHEN recency > 6 THEN 'Churned'
        WHEN order_count <= 3 THEN 'Low Engagement'
        ELSE 'Mid Value'
    END AS segment
FROM final;

-- SUB10
-- =========================================

ALTER TABLE album
ADD COLUMN ReleaseYear INTEGER;
select * from album;

-- SUB11
-- =========================================
with customer_stats as (
    select 
        c.customer_id,
        c.country,
        sum(i.total) as total_spent,
        count(il.track_id) as total_tracks
    from customer c
    left join invoice i 
        on c.customer_id = i.customer_id
    left join invoice_line il 
        on i.invoice_id = il.invoice_id
    group by c.customer_id, c.country
)

select 
    country,
    count(customer_id) as num_customers,
    round(avg(total_spent), 2) as avg_total_spent,
    round(avg(total_tracks), 2) as avg_tracks_per_customer
from customer_stats
group by country
order by country;




