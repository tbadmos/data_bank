
-- 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(price)
FROM sales s 
JOIN menu m
ON s.product_id = m.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(*)
FROM sales s 
JOIN menu m
ON s.product_id = m.product_id
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
WITH tab1 AS (SELECT s.customer_id, m.product_id, s.order_date,
RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS rank_
FROM sales s
JOIN menu m
ON s.product_id = m.product_id)

SELECT * 
FROM tab1
WHERE rank_ = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT  m.product_id, COUNT(*) AS times_purchased
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY 1
ORDER BY COUNT(*) DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH tab1 AS (SELECT s.customer_id, m.product_id, COUNT(*) AS count_
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_id),

tab2 AS (SELECT customer_id, MAX(count_) AS count_
FROM tab1
GROUP BY 1)

SELECT tab1.customer_id, tab1.product_id, tab2.count_
FROM tab1
JOIN tab2
ON tab1.customer_id = tab2.customer_id
AND tab1.count_ = tab2.count_;

-- 6. Which item was purchased first by the customer after they became a member?
WITH tab1 AS (SELECT s.customer_id, order_date, product_id, join_date,
			  RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date ) AS order_number_as_member
FROM sales s
JOIN members m
ON s.customer_id = m.customer_id
AND order_date >= join_date)


SELECT customer_id, order_date, join_date, product_name
FROM tab1
LEFT JOIN menu m
ON tab1.product_id = m.product_id
WHERE order_number_as_member = 1

-- 7. Which item was purchased just before the customer became a member?
--SOLUTION 1: Ignoring customers without a join date
WITH tab1 AS (SELECT s.customer_id, order_date, product_id, join_date, 
			 RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date DESC ) AS order_number_before_membership
FROM sales s
JOIN members m
ON s.customer_id = m.customer_id
AND order_date < join_date)

SELECT * 
FROM tab1
LEFT JOIN menu m
ON tab1.product_id = m.product_id
WHERE order_number_before_membership = 1;

--SOLUTION 2: Asumming purchases by customers without a join date were purchases before they become members 
WITH tab1 AS (SELECT s.customer_id, order_date, product_id, join_date, 
			 RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date DESC ) AS order_number_before_membership
FROM sales s
LEFT JOIN members m
ON s.customer_id = m.customer_id
WHERE order_date < join_date 
	 OR join_date is Null)

SELECT * 
FROM tab1
LEFT JOIN menu m
ON tab1.product_id = m.product_id
WHERE order_number_before_membership = 1;


-- 8. What is the total items and amount spent for each member before they became a member?
--SOLUTION 1: Ignoring customers without a join date
WITH tab1 AS (SELECT s.customer_id, order_date, product_id, join_date
FROM sales s
JOIN members m
ON s.customer_id = m.customer_id
AND order_date < join_date)


SELECT customer_id, COUNT(*) AS number_of_items, SUM(price) AS amount_spent 
FROM tab1
JOIN menu m
ON tab1.product_id = m.product_id
GROUP BY customer_id;

--SOLUTION 2: Asumming purchases by customers without a join date were purchases before they became members 
WITH tab1 AS (SELECT s.customer_id, order_date, product_id, join_date
FROM sales s
LEFT JOIN members m
ON s.customer_id = m.customer_id
WHERE order_date < join_date 
	 OR join_date is Null)


SELECT customer_id, COUNT(*) AS number_of_items, SUM(price) AS total_spent 
FROM tab1
LEFT JOIN menu m
ON tab1.product_id = m.product_id
GROUP BY 1;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH tab1 AS (SELECT s.customer_id, order_date, s.product_id, join_date, product_name, price,
		CASE WHEN product_name NOT LIKE 'sushi' THEN price * 10
			 ELSE price * 10 * 2
			 END AS customer_point
FROM sales s
LEFT JOIN members m
ON s.customer_id = m.customer_id
JOIN menu mm
ON s.product_id = mm.product_id)

SELECT customer_id, SUM(customer_point) AS total_points
FROM tab1
GROUP BY customer_id;

--10. In the first week after a customer joins the program (including their join date) 
--they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH tab1 AS (SELECT s.customer_id, order_date, s.product_id, join_date, product_name, price,
		(CASE WHEN order_date <= join_date + INTERVAL '6 DAYS' AND order_date >= join_date THEN (price * 10 * 2)
			 WHEN product_name NOT LIKE 'sushi' THEN price * 10
			 ELSE price * 10 * 2
			 END) AS customer_point
FROM sales s
LEFT JOIN members m
ON s.customer_id = m.customer_id
JOIN menu mm
ON s.product_id = mm.product_id
WHERE DATE_PART( 'month', order_date) = 1)

SELECT customer_id, SUM(customer_point) AS total_points
FROM tab1
GROUP BY customer_id
ORDER BY 2 DESC



--11 Show each customer, their order_date, product name, price of order and code if they are a member or not
SELECT s.customer_id, order_date, product_name, price, 
       CASE WHEN join_date IS NULL OR join_date > order_date THEN 'N'
	   ELSE 'Y'
	   END AS membership
FROM sales s
LEFT JOIN members m
ON s.customer_id =m.customer_id
JOIN menu mn
ON s.product_id = mn.product_id
ORDER BY customer_id, order_date, product_name


--12 Danny also requires further information about the ranking of customer products, but he purposely does 
--not need the ranking for non-member purchases so he expects null ranking values for the records when 
--customers are not yet part of the loyalty program.

WITH tab1 AS	(SELECT s.customer_id, order_date, join_date, product_name, price, 
		   CASE WHEN join_date IS NULL OR join_date > order_date THEN 'N'
		   ELSE 'Y'
		   END AS membership

	FROM sales s
	LEFT JOIN members m
	ON s.customer_id =m.customer_id
	JOIN menu mn
	ON s.product_id = mn.product_id
	ORDER BY customer_id, order_date, product_name),

tab2 AS (SELECT *,  CASE WHEN (order_date >= join_date) THEN (RANK() OVER (PARTITION BY  customer_id ORDER BY order_date ASC ))  END AS rank_
FROM tab1)

SELECT customer_id, order_date, product_name, price, membership,
		CASE WHEN (rank_ IS NOT NULL) THEN (RANK() OVER (PARTITION BY  customer_id ORDER BY rank_ NULLS LAST ))  END AS ranking
FROM tab2
ORDER BY customer_id, order_date, product_name