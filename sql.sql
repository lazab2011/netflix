SHOW CREATE TABLE netflix_raw;

-- Drop the table 
-- DROP TABLE netflix_raw;

-- Create the TABLE
-- At this stage, no PRIMARY KEY column is selected. May be added later
CREATE TABLE `netflix_raw` (
  `show_id` VARCHAR(10) NOT NULL,
  `type` VARCHAR(10) NULL,
  `title` VARCHAR(255) NULL,
  `director` VARCHAR(255),
  `cast` VARCHAR(1000),
  `country` VARCHAR(150),
  `date_added` VARCHAR(20),
  `release_year` INT,
  `rating` VARCHAR(10),
  `duration` VARCHAR(10),
  `listed_in` VARCHAR(100),
  `description` VARCHAR(500),
  PRIMARY KEY (`show_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Preview the empty table
SELECT * FROM netflix_raw;

# Check if non-English Characters are displayed

SELECT *
FROM netflix_raw
WHERE show_id = 's5023';

-- Check for Duplicates for each column
-- Check for duplicates in show_id
-- If ther are not any dupes, we will make this column the primary key and force a unique contrant here.
SELECT show_id, COUNT(*)
FROM netflix_raw
GROUP BY show_id
HAVING COUNT(*) > 1;

-- Check for duplicates in TITLE
-- If ther are not any dupes, we will make this column the primary key and force a unique contrant here.
SELECT nr.* 
FROM netflix_raw nr
JOIN(SELECT title, type, release_year
	FROM netflix_raw
	GROUP BY title, type, release_year
	HAVING COUNT(title) > 1
) dt on nr.title = dt.title
ORDER BY title;

---- EXCLUDE DUPLICATES
WITH cte as (SELECT *,
	ROW_NUMBER() OVER(PARTITION BY title, type ORDER BY show_id) as rn
FROM netflix_raw)
SELECT *
FROM cte
WHERE rn = 1;

select * from netflix_raw where director is null
-- --------------------------------------------- Create a director table-----------------------------------------------------
CREATE TEMPORARY TABLE numbers as (
SELECT 1 as n
UNION SELECT 2 as n
UNION SELECT 3 as n
UNION SELECT 4 as n
UNION SELECT 5 as n
UNION SELECT 6 as n
UNION SELECT 7 as n
UNION SELECT 8 as n
UNION SELECT 9 as n
UNION SELECT 10 as n
UNION SELECT 11 as n
UNION SELECT 12 as n
UNION SELECT 13 as n
);

CREATE TABLE director(
	show_id VARCHAR(10),
    person VARCHAR(200)
);

INSERT INTO director(show_id, person)
SELECT show_id, 
	TRIM(substring_index(substring_index(director, ',', n), ',', -1)) as person
FROM netflix_raw
JOIN numbers on CHAR_LENGTH(director) - CHAR_LENGTH(REPLACE(director, ',', '')) >= n-1;

select * from director;

-- Create the 'country' table
CREATE TABLE country(
	show_id VARCHAR(10),
    name VARCHAR(200)
);

INSERT INTO country(show_id, name)
SELECT show_id, 
	TRIM(substring_index(substring_index(country, ',', n), ',', -1)) as name
FROM netflix_raw
JOIN numbers on CHAR_LENGTH(country) - CHAR_LENGTH(REPLACE(country, ',', '')) >= n-1;

select * from country;

-- Create the 'cast' table;

CREATE TABLE stars(
	show_id VARCHAR(10),
    name VARCHAR(200)
);

INSERT INTO stars(show_id, name)
SELECT show_id, 
	TRIM(substring_index(substring_index(cast, ',', n), ',', -1)) as name
FROM netflix_raw
JOIN numbers on CHAR_LENGTH(cast) - CHAR_LENGTH(REPLACE(cast, ',', '')) >= n-1;

select * from stars;

-- Listed in 



SELECT * FROM netflix_raw;

-- Genre
CREATE TABLE genre(
	show_id VARCHAR(10),
    name VARCHAR(200)
);

INSERT INTO genre(show_id, name)
SELECT show_id, 
	TRIM(substring_index(substring_index(listed_in, ',', n), ',', -1)) as name
FROM netflix_raw
JOIN numbers on CHAR_LENGTH(listed_in) - CHAR_LENGTH(REPLACE(listed_in, ',', '')) >= n-1;

SELECT name
FROM genre;


-- convert the datatypes for the data that was added
-- step 1. Create a new TABLE with desired datatype
ALTER TABLE netflix_raw
ADD COLUMN date_added_new DATE;
-- UPDATE THE NEW COLUMN WITH THE UPDATED DATE FORMAT
SET SQL_SAFE_UPDATES = 0;
UPDATE netflix_raw
SET date_added_new = str_to_date(date_added, "%M%d,%Y")
WHERE show_id IS NOT NULL;
SET SQL_SAFE_UPDATES = 1;

-- drop the old date column
ALTER TABLE netflix_raw
DROP COLUMN date_added;

-- rename the column
ALTER TABLE netflix_raw
CHANGE COLUMN date_added_new date_added DATE;

-- Populate missing values in country and duration columns
-- We are making some assumptions here. We are assumning that missed country director is identifiable from other shows
-- Where the director is known and matches coutry
-- Below, we are going to map the missing countries to the country table using an assumption

INSERT INTO country
SELECT nr.show_id, m.name
FROM netflix_raw nr
INNER JOIN (
SELECT c.name, d.person
FROM country c
INNER JOIN director d ON c.show_id = d.show_id
GROUP BY c.name, d.person
) m ON nr.director = m.person
WHERE nr.country is NULL;

-- using the same queery as above, we are toing to map the missing duration fo movies
SET SQL_SAFE_UPDATES = 0;
UPDATE netflix_raw
SET duration = rating
WHERE duration IS NULL;
SET SQL_SAFE_UPDATES = 1;

-- Handle NULL vales in duration
-- create a new table with the cleaned data for analysis

CREATE TABLE netflix as 
WITH cte as (SELECT *,
	ROW_NUMBER() OVER(PARTITION BY title, type ORDER BY show_id) as rn
FROM netflix_raw
)
SELECT show_id, title, type, rating, case when duration is null  then rating else duration end as duration, release_year, date_added,  description
FROM cte;

select * from netflix;
/*  
For each director, count the number of movies and tv shows created by them in separate columns 
for directors who have created tv shows and movies both
*/

SELECT d.name, 
	COUNT(DISTINCT(CASE WHEN n.type = 'Movie' then n.show_id end)) as num_movies, 
    COUNT(DISTINCT(CASE WHEN n.type = 'TV Show' then n.show_id end)) as num_tvshows
FROM director d
INNER JOIN netflix n ON d.show_id = n.show_id
GROUP BY d.name
HAVING COUNT(DISTINCT(n.type)) > 1
-- ORDER BY distinct_type DESC;
SELECT * FROM NETFLIX
/*  
Which country has the most amount of commedy movies
*/
SELECT COUNT(DISTINCT(c.show_id)) as num_movies, c.name 
FROM country c
INNER JOIN genre g on g.show_id = c.show_id
INNER JOIN netflix n on n.show_id = c.show_id
WHERE g.name = "Comedies" and n.type = "Movie"
GROUP BY c.name
ORDER BY num_movies DESC
LIMIT 1;

/*  
fOR each year, as per added to Netflix, which director has maximum number of movies released.
*/
with cte as (
SELECT c.name country, d.name director, year(date_added ) date_year, COUNT(DISTINCT(n.show_id)) movie_count
FROM netflix n
INNER JOIN director d on d.show_id = n.show_id
INNER JOIN country c on c.show_id = n.show_id
WHERE type = 'Movie'
GROUP BY director, date_year, country
), cte2 as (
SELECT *, 
	ROW_NUMBER() over(partition by date_year ORDER BY movie_count DESC, director) as rn
FROM cte
)
SELECT * FROM cte2 WHERE rn = 1;


/*  
What is the average duration of movies in each genre?
*/
SELECT g.name as genre, AVG(CAST(REPLACE(n.duration, ' min', '') AS UNSIGNED)) average_duration
FROM netflix n
INNER JOIN genre g on g.show_id = n.show_id
WHERE type = 'Movie'
GROUP BY n.type, g.name
ORDER BY average_duration DESC;

/*  
Find a list of directors who have created horror and comediy movies both. 
Display director names along with the number of comedy and horror movies directed by them
*/
SELECT d.name, 
	COUNT(DISTINCT CASE when g.name = 'Comedies' then d.show_id end) AS num_of_comedy,
	COUNT(DISTINCT CASE when g.name = 'Horror Movies' then d.show_id end) AS num_of_horror
FROM director d
INNER JOIN genre g ON g.show_id = d.show_id
INNER JOIN netflix n ON n.show_id = d.show_id
WHERE n.type = 'Movie' AND g.name IN ('Comedies', 'Horror Movies')
GROUP BY d.name
HAVING COUNT(DISTINCT g.name) = 2
ORDER BY d.name;

-- Check the results 
select d.show_id, d.name AS name, g.name AS genre
from director d
INNER JOIN genre g ON g.show_id = d.show_id
where d.name = 'Poj Arnon'
ORDER BY genre

