CREATE DATABASE IF NOT EXISTS zomato_db;
show databases;
use zomato_db;
select * from zomato_restaurants limit 50;

-- Phase 1: Baseline & Geographic Distribution Analysis -- 
-- 1) Baseline & Geographic Distribution
-- The business question: calculate the total number of restaurants in the dataset, the global average rating, total customer votes, and the distinct count of cities and countries represented.
-- Query 1.1 calculate the total number of restaurants in the dataset, the global average rating, total customer votes, and the distinct count of cities and countries represented.
SELECT 
    COUNT(*) AS total_restaurants,
    COUNT(DISTINCT city) AS total_cities,
    COUNT(DISTINCT country_code) AS total_countries,
    ROUND(AVG(aggregate_rating), 2) AS global_avg_rating,
    ROUND(AVG(average_cost_for_two), 2) AS global_avg_cost,
    MAX(votes) AS max_votes_single_restaurant
FROM zomato_restaurants;

-- 2) Market Concentration & City Baselines
-- The Business Question: Which top 10 cities have the highest concentration of restaurants, and how do their average customer ratings compare?
-- Query 1.2: [Write a query to aggregate the total number of restaurants, average aggregate rating, and total votes grouped by city. 
--            Sort the output to highlight the top cities by restaurant volume and observe how unrated listings affect average ratings].
SELECT 
    city, 
    COUNT(*) AS restaurant_count,
    ROUND(AVG(aggregate_rating), 2) AS avg_city_rating,
    SUM(votes) AS total_city_votes
FROM zomato_restaurants
GROUP BY city
ORDER BY restaurant_count DESC
LIMIT 10;


-- Phase 2: Operational Features & Pricing Dynamics -- 
-- 1) Operational Services Analysis (Online Delivery vs. Table Booking)
-- The Business Question: How does the availability of Online Delivery and Table Booking affect a restaurant's aggregate rating and customer vote volume?
-- Query 2.1: [Write a query to analyze customer satisfaction and engagement across service offerings. 
--            Display the combination of Online Delivery (has_online_delivery) and Table Booking (has_table_booking), 
--            along with the total restaurant count, average rating, and average votes for each combination].
SELECT 
    has_online_delivery,
    has_table_booking,
    COUNT(*) AS restaurant_count,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM zomato_restaurants)), 2) AS pct_of_total,
    ROUND(AVG(aggregate_rating), 2) AS avg_rating,
    ROUND(AVG(votes), 0) AS avg_votes
FROM zomato_restaurants
GROUP BY has_online_delivery, has_table_booking
ORDER BY avg_votes DESC;

-- 2) Pricing Tier vs Service Tier Segmentation
-- The Business Question: What is the average cost and rating distribution across the 4 price ranges, and how are listings distributed across Budget, Mid-Range, Premium, and Luxury categories?
-- Query 2.2: Price Range Segmentation & Performance Analysis
SELECT 
    price_range,
    CASE price_range
        WHEN 1 THEN 'Budget'
        WHEN 2 THEN 'Mid-Range'
        WHEN 3 THEN 'Premium'
        WHEN 4 THEN 'Luxury'
    END AS price_category,
    COUNT(*) AS total_restaurants,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM zomato_restaurants)), 2) AS pct_of_total,
    ROUND(AVG(average_cost_for_two), 2) AS avg_cost,
    ROUND(AVG(aggregate_rating), 2) AS avg_rating,
    ROUND(AVG(votes), 0) AS avg_votes
FROM zomato_restaurants
GROUP BY price_range, price_category
ORDER BY price_range ASC;


-- Phase 3: Advanced SQL Analytics & Strategic Discovery -- 
-- 1) Identify the Top 3 rated restaurants in every city
-- The Business Question: In every city, which top 3 restaurants achieve the highest ratings and vote volume?
-- Query 3.1: Top 3 Restaurants Per City Using DENSE_RANK()
WITH RankedRestaurants AS (
    SELECT 
        city,
        restaurant_name,
        cuisines,
        aggregate_rating,
        votes,
        DENSE_RANK() OVER (
            PARTITION BY city 
            ORDER BY aggregate_rating DESC, votes DESC
        ) AS city_rank
    FROM zomato_restaurants
    WHERE is_rated = 1
)
SELECT 
    city,
    city_rank,
    restaurant_name,
    cuisines,
    aggregate_rating,
    votes
FROM RankedRestaurants
WHERE city_rank <= 3
ORDER BY city, city_rank;

-- 2) Locality Outlier Detection using Aggregate Window Functions
-- The Business Question: Which restaurants have a rating at least 1.0 point higher than their city's average rating?
-- Query 3.2: City Benchmark Outliers (Restaurants Rating >= City Avg + 1.0)
WITH CityAverages AS (
    SELECT 
        restaurant_name,
        city,
        cuisines,
        aggregate_rating,
        votes,
        ROUND(AVG(aggregate_rating) OVER (PARTITION BY city), 2) AS city_avg_rating
    FROM zomato_restaurants
    WHERE is_rated = 1
)
SELECT 
    restaurant_name,
    city,
    cuisines,
    aggregate_rating,
    city_avg_rating,
    ROUND((aggregate_rating - city_avg_rating), 2) AS rating_diff,
    votes
FROM CityAverages
WHERE aggregate_rating >= (city_avg_rating + 1.0)
ORDER BY rating_diff DESC, votes DESC;

-- 3) Top 10 Popular Cuisines Analysis
-- The Business Question: Which cuisines dominate the platform, and do the most widespread cuisines also attract the highest customer engagement (votes)?
-- Query 3.3: [list the top 10 most frequent cuisine types on the platform. 
--            Display the cuisine combination, total restaurant count, total votes, average rating, and average cost for two, ordered by restaurant count descending].
SELECT 
    cuisines,
    COUNT(*) AS total_restaurants,
    SUM(votes) AS total_votes,
    ROUND(AVG(aggregate_rating), 2) AS avg_rating,
    ROUND(AVG(average_cost_for_two), 2) AS avg_cost
FROM zomato_restaurants
WHERE cuisines IS NOT NULL AND cuisines != ''
GROUP BY cuisines
ORDER BY total_restaurants DESC
LIMIT 17;

-- 4) Price Range vs Delivery Feature Cross-Analysis
-- The Business Question: Does offering online delivery allow cheap/budget restaurants to charge higher average prices or secure better customer ratings compared to non-delivery options?
-- Query 3.4: [cross-analyze price tiers against online delivery availability. 
--            Group the data by price_range and has_online_delivery, showing total restaurant count, average cost for two, and average rating for each combination].
SELECT 
    price_range,
    has_online_delivery,
    COUNT(*) AS restaurant_count,
    ROUND(AVG(average_cost_for_two), 2) AS avg_cost,
    ROUND(AVG(aggregate_rating), 2) AS avg_rating
FROM zomato_restaurants
GROUP BY price_range, has_online_delivery
ORDER BY price_range ASC, has_online_delivery DESC;

-- 5) Rating Category Breakdown & Customer Participation
-- The Business Question: How are restaurants distributed across actual rating buckets (e.g., Excellent, Very Good, Good, Average, Poor, Unrated)?
-- Query 3.5: [Write a query using a CASE WHEN statement to categorize restaurants into sentiment buckets based on aggregate_rating 
--            (Excellent: 4.5–5.0, Very Good: 4.0–4.4, Good: 3.5–3.9, Average: 2.5–3.4, Poor: 0.1–2.4, Not Rated: 0.0). 
--            Display the total restaurant count, percentage of total listings, and sum of votes for each bucket].
SELECT 
    CASE 
        WHEN aggregate_rating >= 4.5 THEN 'Excellent (4.5 - 5.0)'
        WHEN aggregate_rating >= 4.0 THEN 'Very Good (4.0 - 4.4)'
        WHEN aggregate_rating >= 3.5 THEN 'Good (3.5 - 3.9)'
        WHEN aggregate_rating >= 2.5 THEN 'Average (2.5 - 3.4)'
        WHEN aggregate_rating > 0.0  THEN 'Poor (0.1 - 2.4)'
        ELSE 'Not Rated (0.0)'
    END AS rating_bucket,
    COUNT(*) AS restaurant_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM zomato_restaurants), 2) AS pct_of_total,
    SUM(votes) AS bucket_votes
FROM zomato_restaurants
GROUP BY rating_bucket
ORDER BY MIN(aggregate_rating) DESC;

-- 6) High-Rating Affordable Restaurants ("Value Gems")
-- The Business Question: Which affordable/budget-friendly restaurants (price_range <= 2) maintain elite customer satisfaction (>= 4.0 rating) and solid vote confidence (>= 100 votes)?
-- Query 3.6: [find budget-friendly restaurants that offer high customer satisfaction. Retrieve restaurants where price_range <= 2, aggregate_rating >= 4.0, and votes >= 100. 
--            Return the restaurant name, city, cuisines, cost for two, rating, and vote count, ordered by rating and votes descending].
SELECT 
    restaurant_name,
    city,
    cuisines,
    average_cost_for_two,
    aggregate_rating,
    votes
FROM zomato_restaurants
WHERE price_range <= 2 
  AND aggregate_rating >= 4.0 
  AND votes >= 100
ORDER BY aggregate_rating DESC, votes DESC
LIMIT 15;


-- Phase 4: Database Views for Dashboard Ingestion -- 
-- Database Views for Power BI Reporting
-- View 1: City & Locality Performance Metrics
CREATE OR REPLACE VIEW view_city_performance AS
SELECT 
    city,
    country_code,
    COUNT(*) AS total_restaurants,
    ROUND(AVG(aggregate_rating), 2) AS avg_rating,
    SUM(votes) AS total_votes,
    ROUND(AVG(average_cost_for_two), 2) AS avg_cost
FROM zomato_restaurants
GROUP BY city, country_code;

-- View 2: Top Rated Outlier Restaurants per City
CREATE OR REPLACE VIEW view_top_city_outliers AS
WITH CityAverages AS (
    SELECT 
        restaurant_name,
        city,
        cuisines,
        aggregate_rating,
        votes,
        ROUND(AVG(aggregate_rating) OVER (PARTITION BY city), 2) AS city_avg_rating
    FROM zomato_restaurants
    WHERE is_rated = 1
)
SELECT 
    restaurant_name,
    city,
    cuisines,
    aggregate_rating,
    city_avg_rating,
    ROUND((aggregate_rating - city_avg_rating), 2) AS rating_diff,
    votes
FROM CityAverages
WHERE aggregate_rating >= (city_avg_rating + 1.0);