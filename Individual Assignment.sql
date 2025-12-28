USE bc2402_ia;

-- 1
SELECT product_category, COUNT(*) AS count_product
FROM baristacoffeesalestbl
GROUP BY product_category;
-- steps: group rows by product_category and count how many rows belong to each category
-- product_category is stored as TEXT, which is fine for grouping.

-- 2
WITH g1 AS -- create CTE g1 to count the number of records grouped by gender and loyalty member type
(SELECT customer_gender, loyalty_member, COUNT(*) AS records
FROM baristacoffeesalestbl
GROUP BY customer_gender, loyalty_member)
, g2 AS -- create CTE g2 to count the number of records grouped by gender, loyalty member, and repeat customer flag
(SELECT customer_gender, loyalty_member, COUNT(*) AS records, is_repeat_customer
FROM baristacoffeesalestbl
GROUP BY customer_gender, loyalty_member, is_repeat_customer)
-- join g1 and g2 to display summary by gender + loyalty, showing both overall records and split by repeat customers
SELECT g2.customer_gender, g2.loyalty_member, g1.records, g2.is_repeat_customer, g2.records
FROM g1, g2
WHERE g1.customer_gender = g2.customer_gender
AND g1.loyalty_member = g2.loyalty_member
ORDER BY g2.customer_gender, g2.loyalty_member, g2.is_repeat_customer;
-- no data type conversion is needed as all join keys are TEXT, which is fine for grouping

-- 3
-- version A: explicitly cast total_amount (text) into DECIMAL(10,0), which drops decimal fractions before summing (rounds each record first) 
SELECT product_category, customer_discovery_source, SUM(CAST(total_amount AS DECIMAL(10,0))) AS total_sales
FROM baristacoffeesalestbl
GROUP BY product_category, customer_discovery_source
ORDER BY product_category, customer_discovery_source;
-- here total_amount is stored as TEXT, if it is left as TEXT and the value inside the total_amount contains
-- invalid numerical strings sql will do implicit conversion e.g.: e.g. 'bc100'-> 0 , '100bc' -> 100
-- which is not always correct and may produce a totally wrong result
-- therefore, CAST to DECIMAL(10,0) ensures a safer way to do arithmetic operations
-- however, this conversion causes the result to not be as accurate as it drops all of the decimal place

-- version B:  relies on MySQL implicit conversion to numeric, keeps all decimal place as long as total_amount is a valid numeric text.
SELECT product_category, customer_discovery_source, SUM(total_amount) AS total_sales
FROM baristacoffeesalesTBL
GROUP BY product_category, customer_discovery_source
ORDER BY product_category, customer_discovery_source;
-- here, sql auto-converts TEXT into DOUBLE inside SUM() which preserves all of the decimal places

-- version B is more accurate as it preserves the decimal with the condition that the total_amount values are stored as valid numeric strings without non-numeric characters
-- if invalid text exists, mysql may convert it to 0 or only take the numeric prefix, which may lead to incorrect result
-- in this case version B is more accurate as the values in total_amount are valid numeric strings
-- however, the best practice in general would be to validate using REGEXP to ensure only numeric strings remain,
-- CAST into numeric and round to sufficient decimal place according to the values or cast into DOUBLE
-- invalid values should be flagged/excluded

-- 4
WITH coffee_consumption AS -- create CTE that includes dummy variables time_of_day and gender
(SELECT 
-- map dummy time_of_day flags into a single category
CASE WHEN time_of_day_afternoon = 'True' THEN 'afternoon'
WHEN time_of_day_evening = 'True' THEN 'evening'
WHEN time_of_day_morning = 'True' THEN 'morning'
END AS time_of_day, 
-- map dummy gender flags into a single category
CASE WHEN gender_female = 'True' THEN 'female'
WHEN gender_male = 'True' THEN 'male'
END AS gender, focus_level, sleep_quality
FROM caffeine_intake_tracker
WHERE beverage_coffee = 'True') -- include only rows where the beverage consumed is coffee
SELECT time_of_day, gender, AVG(focus_level) AS avg_focus_level, AVG(sleep_quality) AS avg_sleep_quality
FROM coffee_consumption
GROUP BY time_of_day, gender;
-- this query follows the criteria of the questions:
-- filters only coffee drinkers, group by time_of_day and gender, and aggregates average focus_level and average sleep_quality
-- the AVG() shown by this query are with full floating precision as I keep the data type
-- of sleep_quality and focus_level as DOUBLE and did not cast the values into a certain decimal places
-- i have checked whether the dummy variables, time_of_day and gender have invalid overlaps 
-- [e.g. time_of_day_evening = True and time_of_day_morning = True at the same row] and found none
-- the output of this query should be accurate as it aligns with the question requirements. 
-- if the sample differs, it is most likely due to rounding or simplified grouping. 
-- this query is more accurate as it retains full precision and applies grouping exactly as specified.


-- 5
SELECT 
CASE 
WHEN CAST(SUBSTRING_INDEX(datetime, ':', 1) AS DECIMAL(10,2)) < 12 THEN 'Before 12'
WHEN CAST(SUBSTRING_INDEX(datetime, ':', 1) AS DECIMAL(10,2))>= 12 AND CAST(SUBSTRING_INDEX(datetime, ':', 1) AS DECIMAL(10,2)) < 24 THEN 'After 12'
END AS time_period, SUM(CAST(money AS DECIMAL(10,2))) AS total_spending
FROM coffeesales
WHERE CAST(SUBSTRING_INDEX(datetime, ':', 1) AS DECIMAL(10,2)) < 24   
GROUP BY time_period
ORDER BY time_period desc;
-- datetime is stored as TEXT in format HH:MM, use SUBSTRING_INDEX to extract the hour i.e. everything before the first ':'
-- after that CAST the value as decimal so that we can compare them numerically with 12 and 24,if not converted mysql would compare strings which give out wrong results
-- money is stored as TEXT so it must be CAST to DECIMAL before performing the arithmetic operation, SUM()
-- issue with the dataset: there are some invalid datetime values that exceed 24 hours. 
-- we must exclude these invalid rows where hour >= 24 by filtering them


-- 6
WITH cp AS (
SELECT  -- bucket numeric pH into ranges of width 1 (0–1, 1–2, … 6–7).
        -- pH is TEXT so CAST to DECIMAL first.
CASE WHEN CAST(pH AS DECIMAL(10,2)) >= 0.0 AND CAST(pH AS DECIMAL(10,2)) < 1.0 THEN '0 to 1'
WHEN CAST(pH AS DECIMAL(10,2)) >= 1.0 AND CAST(pH AS DECIMAL(10,2)) < 2.0 THEN '1 to 2'
WHEN CAST(pH AS DECIMAL(10,2)) >= 2.0 AND CAST(pH AS DECIMAL(10,2)) < 3.0 THEN '2 to 3'
WHEN CAST(pH AS DECIMAL(10,2)) >= 3.0 AND CAST(pH AS DECIMAL(10,2)) < 4.0 THEN '3 to 4'
WHEN CAST(pH AS DECIMAL(10,2)) >= 4.0 AND CAST(pH AS DECIMAL(10,2)) < 5.0 THEN '4 to 5'
WHEN CAST(pH AS DECIMAL(10,2)) >= 5.0 AND CAST(pH AS DECIMAL(10,2)) < 6.0 THEN '5 to 6'
WHEN CAST(pH AS DECIMAL(10,2)) >= 6.0 AND CAST(pH AS DECIMAL(10,2)) < 7.0 THEN '6 to 7'
END AS Ph, CAST(Liking AS DOUBLE) AS Liking, CAST(FlavorIntensity AS DOUBLE) AS FlavorIntensity, 
CAST(Acidity AS DOUBLE) AS Acidity, CAST(Mouthfeel AS DOUBLE) AS Mouthfeel -- the survey metrics are stored as text, CAST to DOUBLE to compute the averages
FROM consumerpreference),
averages AS (
SELECT Ph, ROUND(AVG(Liking),2) AS avg_Liking, ROUND(AVG(FlavorIntensity),2) AS avg_FlavorIntensity,
ROUND(AVG(Acidity),2) AS avg_Acidity, ROUND(AVG(Mouthfeel),2) AS avg_Mouthfeel -- compute average ratings for each pH bucket and round to 2 decimal place
FROM cp
GROUP BY Ph),
ranges AS -- generate all Ph range explicitly so empty bins still appear
(SELECT '0 to 1' AS Ph UNION ALL
SELECT '1 to 2' UNION ALL
SELECT '2 to 3' UNION ALL
SELECT '3 to 4' UNION ALL
SELECT '4 to 5' UNION ALL
SELECT '5 to 6' UNION ALL
SELECT '6 to 7')
SELECT r.Ph, a.avg_Liking, a.avg_FlavorIntensity, a.avg_Acidity, a.avg_Mouthfeel
FROM ranges r
LEFT JOIN averages a ON r.Ph = a.Ph -- left join to ensures missing ranges show nulls and still printed
ORDER BY r.Ph;
-- pH and all of the survey metrics are stored as TEXT, to ensure correct comparison while creating the bins and while performing the arithmetic operations, must be CAST into DECIMAL or DOUBLE 
-- the resulting averages are rounded to 2 decimal places to match the sample output given, rounding is done at the end
-- after the averages are calculated to ensure the accuracy of the result is retained
-- LEFT JOIN is used instead of JOIN to ensure all Ph ranges are printed although the survey metrics are not available, again this is to match the sample output given

-- 7         
WITH aggregated AS (
    SELECT 
        MONTH(STR_TO_DATE(c.date, '%e/%c/%Y')) AS month_num, -- extract month number
        UPPER(DATE_FORMAT(STR_TO_DATE(c.date, '%e/%c/%Y'), '%b')) AS trans_month, -- extract abbreviated month name in uppercase
        b.store_id, c.shopID,
        b.store_location,
        l.location_name,
        AVG(CAST(SUBSTRING_INDEX(t.agtron, '/', 1) AS DECIMAL(10,2))) AS avg_agtron, -- agtron is stored in xx/yy format where yy is possibly the benchmark, 
																					-- we only want to calculate the average of the first number (xx), use SUBSTRING_INDEX to extract that part and cast to numeric since it is stored as text to ensure accurate arithmetic calculation
        COUNT(*) AS trans_amt, -- count total number of transactions per shop per store per month
        ROUND(SUM(CAST(c.money AS DECIMAL(10,2))),2) AS total_money -- CAST c.money as numeric as it is originally stored as text to ensure accurate arithmetic calculation, then calculate total money using SUM() and round to 2 d.p.
    FROM coffeesales c
    JOIN `top-rated-coffee` t ON c.coffeeID = t.ID
    JOIN list_coffee_shops_in_kota_bogor l ON c.shopID = l.no
    JOIN baristacoffeesalestbl b 
    -- customer id in coffeesales and baristacoffeesalestbl have different format
    -- customer id in baristacoffeesalestbl have 'CUST_' prefix, remove that part using REPLACE
    -- CAST both customer ID to numeric to ensure accurate comparison
         ON CAST(c.customer_id AS UNSIGNED) 
          = CAST(REPLACE(b.customer_id, 'CUST_', '') AS UNSIGNED)
    GROUP BY c.shopID, month_num, trans_month, b.store_id, b.store_location, l.location_name 
    -- group by month, shop id, and store id. 
    -- since we want store location and location name to show in the final table, we have to group by them also. 
    -- the addition of these two do not mess with the structure since each store_id is always tied to a unique store_location,   
    -- and each shopID is tied to a unique location_name. grouping by them just ensures we can SELECT them without affecting the aggregates.
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY month_num ORDER BY total_money DESC) AS rn -- rank store+shop by total_money per month, descending
    FROM aggregated
)
SELECT 
    trans_month,
    store_id,
    store_location,
    location_name,
    avg_agtron,
    trans_amt,
    total_money
FROM ranked
WHERE rn <= 3 -- keep only the top 3 stores per month
ORDER BY month_num, rn; -- order by month in correct order of sum money for readability

-- use STR_TO_DATE(c.date, '%e/%c/%Y') for date parsing because %e and %c are flexible, they accept both '03' and '3' for example for days/months.this avoids parsing errors if dates are stored without leading zeros.
-- customer id join condition uses CAST(... AS UNSIGNED) to ensures value like '00123' (if exists) and '123' are still matched correctly. 
-- also to address the different formatting of customer id in the two table, we remove 'CUST_' prefix from the baristacoffeesalestbl table while matching the two tables
-- aggregates are rounded to 2 d.p. to match the sample output
-- note on differences vs. sample output:
-- my query ranks stores based only on SUM(c.money) in descending order, this matches the requirement (top 3 by money per month).
-- however, when multiple stores have the same SUM(c.money), ROW_NUMBER() does not guarantee a consistent order between them.
-- as a result, my output may show a different store+shop combination as compared to the sample, even though the sum money are the same.
-- since the total_money ranking is correct, the differences are only due to tie-handling and do not affect the validity of the result.
