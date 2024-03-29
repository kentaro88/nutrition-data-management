/******************************

Authors     : Vikranth Ale,Kentaro Kato
Create date : 27th March,2019
Description : USDA National Nutritional Data
Data Source : https://ndb.nal.usda.gov/ndb/

******************************/
-- SETTING UP ENVIRONMENT 

-- TOPIC : ADDING INTEGRITY CONTRAINTS PRIMARY AND FOREIGN KEYS

-- QUERY 1

 ALTER TABLE [NutrientValues]
 DROP CONSTRAINT Nutrients_PK

 --1ms
SET STATISTICS TIME ON
SELECT *
	FROM NutrientValues 
	WHERE [Food code] = 55100080 OR [Food code]= 95201700
SET STATISTICS TIME OFF

ALTER TABLE [NutrientValues] 
ADD CONSTRAINT Nutrients_PK PRIMARY KEY ([Food code])

--O ms
SET STATISTICS TIME ON
SELECT *
	FROM NutrientValues 
	WHERE [Food code] = 55100080 OR [Food code]= 95201700
SET STATISTICS TIME OFF

 ALTER TABLE WWEIA_Information
 DROP CONSTRAINT WWEIA_PK

-- 4ms
SET STATISTICS TIME ON
SELECT DISTINCT N.[Food code],W.[WWEIA Category code],W.[WWEIA Category description]
	FROM NutrientValues N JOIN WWEIA_Information W 
	ON  N.[WWEIA Category code] = W.[WWEIA Category code]
	WHERE W.[WWEIA Category code] = 4208 OR W.[WWEIA Category code] = 8010
SET STATISTICS TIME OFF

ALTER TABLE WWEIA_Information 
ADD CONSTRAINT WWEIA_PK PRIMARY KEY ([WWEIA Category code])

-- 1ms
SET STATISTICS TIME ON
	SELECT DISTINCT N.[Food code],W.[WWEIA Category code],W.[WWEIA Category description]
	FROM NutrientValues N JOIN WWEIA_Information W 
	ON  N.[WWEIA Category code] = W.[WWEIA Category code]
	WHERE W.[WWEIA Category code] = 4208 OR W.[WWEIA Category code] = 8010
SET STATISTICS TIME OFF

ALTER TABLE [NutrientValues] 
ADD FOREIGN KEY ([WWEIA Category code]) REFERENCES [WWEIA_Information] ([WWEIA Category code])

ALTER TABLE Ingredients 
ADD FOREIGN KEY ([Food code]) REFERENCES [NutrientValues]([Food code])

ALTER TABLE PortionsAndWeights 
ADD FOREIGN KEY ([WWEIA Category code]) REFERENCES [WWEIA_Information] ([WWEIA Category code])

-- TOPIC : REWRITING SQL QUERIES WITHOUT CHANGING MEANING

-- QUERY 2

SELECT TOP 10 [Food code],[Main food description],[Iron (mg)]
	FROM NutrientValues 
	WHERE [Iron (mg)] IN ( SELECT MAX([Iron (mg)]) FROM NutrientValues)

-- ALTERNATIVE APPROACH

SELECT TOP 10 [Food code],[Main food description],[Iron (mg)]
	FROM NutrientValues 
	WHERE [Iron (mg)] = (SELECT MAX([Iron (mg)])
		  FROM NutrientValues);

-- FOODS THAT ARE HIGH IN BOTH CALORIES AND PROTEINS 

-- 21 SECONDS
SELECT DISTINCT F.ID,F.Description, F.Calories
	FROM Food F
	JOIN Protein P 
	ON F.ID = P.ID
	JOIN Carbohydrates C
	ON F.ID = C.ID
	OR P.ID = C.ID
	ORDER BY Calories DESC

-- OPTIMIZED QUERY 
-- 190 ms

SET STATISTICS TIME ON
GO
	SELECT DISTINCT F.ID,F.Description, F.Calories
		FROM Food F JOIN Protein P 
		ON F.ID = P.ID
UNION
	SELECT F.ID, F.Description,F.Calories
		FROM Food F JOIN Carbohydrates C
		ON F.ID = C.ID
		ORDER BY Calories DESC
GO
SET STATISTICS TIME OFF


-- TOPIC : ADDING NON-CLUSTERED AND CLUSTERED INDEXES TO THE TABLES

-- QUERY 3

-- RESULTS BEFORE CREATING INDEX --260ms

SET STATISTICS TIME ON
GO 
	SELECT [Food code], [WWEIA Category code],[Portion weight (g)] 
		FROM PortionsAndWeights
		WHERE [Portion weight (g)] > 100  and [Portion weight (g)] < 4500
GO
SET STATISTICS TIME OFF

-- NON-CLUSTERED INDEX

USE USDA_test;  
GO  
DROP TABLE IF EXISTS Portions_subtable;
SELECT [Food code],[WWEIA Category code],[Portion weight (g)]
	INTO Portions_subtable   --> creating new table
	FROM PortionsAndWeights
GO
DROP INDEX IF EXISTS IDX_PortionAndWeights_PortionIndex ON PortionsAndWeights;
	CREATE NONCLUSTERED INDEX IDX_PortionAndWeights_PortionIndex
		ON Portions_subtable ([Portion weight (g)])
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE=OFF, SORT_IN_TEMPDB=OFF);
GO

-- VERIFYING THE RESULTS  --165ms

SET STATISTICS TIME ON
GO 
	SELECT * FROM Portions_subtable
		WHERE [Portion weight (g)] > 100 AND [Portion weight (g)] < 4500 ;
GO
SET STATISTICS TIME OFF


-- ALTERNATIVELY YOU CAN CREATE FILTERED INDEXES
-- SPECIFYING THE 'WHERE' CONDITION IN THE STATEMENT

CREATE NONCLUSTERED INDEX Idx_PortionAndWeights_RangeIndex
	ON PortionsAndWeights([Portion weight (g)]) 
	WHERE [Portion weight (g)] > 100 and [Portion weight (g)] < 2000
	WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE=OFF, SORT_IN_TEMPDB=OFF);
GO

-- CREATING CLUSTERED INDEX MANUALLY (BY default created on defining a Primary key)

-- BEFORE CREATING CLUSTERED INDEX  --139 ms
SET STATISTICS TIME ON 
GO
	SELECT [Food code],[WWEIA Category code], [Energy (kcal)], [Protein (g)], [Sugars, total (g)], [Total Fat (g)]
		FROM NutrientValues
		WHERE [Energy (kcal)] > 100 AND [Energy (kcal)] < 700;
GO 
SET STATISTICS TIME OFF

-- CREATING CLUSTERED INDEX

USE USDA_test;  
GO  
DROP TABLE IF EXISTS Nutrients_subtable;
	SELECT [Food code],[WWEIA Category code], [Energy (kcal)], [Protein (g)], [Sugars, total (g)], [Total Fat (g)]
		INTO Nutrients_subtable
		FROM NutrientValues
GO
DROP INDEX IF EXISTS Idx_Nutrients_subtable_cIndex ON Nutrients_subtable ;

CREATE CLUSTERED INDEX Idx_Nutrients_subtable_cIndex  
	    ON Nutrients_subtable ([Energy (kcal)]);   
GO 

-- AFTER CLUSTERED INDEXING  --118ms

SET STATISTICS TIME ON 
GO
	SELECT [Food code],[WWEIA Category code], [Energy (kcal)], [Protein (g)], [Sugars, total (g)], [Total Fat (g)]
		FROM Nutrients_subtable
		WHERE [Energy (kcal)] > 100 AND [Energy (kcal)] < 700;
GO 
SET STATISTICS TIME OFF

-- TOPIC : MODIFYING THE SCHEMA OF DATABASE

--QUERY 4

-- CREATING A TEMPORARY SUBTABLE TO MODIFY SCHEMA
 
 GO
 DROP table IF EXISTS USDA.Food_TestTable;
 DROP SCHEMA IF EXISTS USDA ;
 GO
	SELECT *
		INTO Food_TestTable    -- CREATING A TEMPORARY SUBTABLE 
		FROM Food

 -- DEFINING NEW SCHEMA 'USDA'
 GO
 DROP SCHEMA IF EXISTS USDA;
 GO
 CREATE SCHEMA USDA
 GO
 ALTER SCHEMA USDA
 TRANSFER dbo.Food_TestTable
 GO
 SELECT * FROM USDA.Food_TestTable

ALTER TABLE USDA.Food_TestTable
ADD CONSTRAINT MY_PK PRIMARY KEY(ID)

-- MODIFYING SCHEMA BY ADDING CHECK CONSTRAINT ON PRIMARY KEY
ALTER TABLE USDA.Food_TestTable
ADD CONSTRAINT my_check CHECK( ID BETWEEN 1001 AND 100000)

-- VERIFYING THE CHECK CONSTRAINT (VIOLATING)
INSERT INTO USDA.Food_TestTable VALUES(999,'SPICY.FOOD.CLOVE',320,18,26,0.07,32)
INSERT INTO USDA.Food_TestTable VALUES(111000,'SPICY.FOOD.ANISEED',321,16,15,0.02,46)


-- QUERY 5
-- TOPIC : VIEWS

-- QUERY WITHOUT VIEW
-- TIME : 3.3 seconds

SET STATISTICS TIME ON
GO
DROP TABLE IF EXISTS MainIngredientCode;
GO
	SELECT F.ID,F.Description AS Main, I.[Ingredient code],I.[Nutrient code],I.[Nutrient description],IG.[Ingredient description],
	IG.[Ingredient weight],FB.[Additional food description],N.[Energy (kcal)]+N.[Protein (g)]+N.[Carbohydrate (g)]+N.[Total Fat (g)] AS TotalNutrition,
	PW.[Portion weight (g)]
		INTO MainIngredientCode
		FROM Food F 
		JOIN IngredientNutrientValues I ON F.ID = I.[Ingredient code]
		JOIN Ingredients IG             ON I.[Ingredient code] = IG.[Ingredient code]
		JOIN FoodsAndBeverages FB       ON IG.[Food code] = FB.[Food code]
		JOIN NutrientValues N           ON FB.[Food code] = N.[Food code]
		JOIN PortionsAndWeights PW      ON N.[Food code]  = PW.[Food code]
		WHERE I.[Ingredient code] BETWEEN 1001 AND 9999;
GO
	SELECT * FROM MainIngredientCode
GO
SET STATISTICS TIME OFF

-- DROP TABLE MainIngredient

-- QUERY WITH VIEW
-- TIME : 1 ms 

SET STATISTICS TIME ON 
GO
DROP VIEW IF EXISTS MainViewIngredient;
GO
CREATE VIEW MainViewIngredient
AS
	SELECT F.ID,F.Description AS Main, I.[Ingredient code],I.[Nutrient code],I.[Nutrient description],IG.[Ingredient description],
	IG.[Ingredient weight],FB.[Additional food description],N.[Energy (kcal)]+N.[Protein (g)]+N.[Carbohydrate (g)]+N.[Total Fat (g)] AS TotalNutrition,
	PW.[Portion weight (g)]
		FROM Food F 
		JOIN IngredientNutrientValues I ON F.ID = I.[Ingredient code]
		JOIN Ingredients IG             ON I.[Ingredient code] = IG.[Ingredient code]
		JOIN FoodsAndBeverages FB       ON IG.[Food code] = FB.[Food code]
		JOIN NutrientValues N           ON FB.[Food code] = N.[Food code]
		JOIN PortionsAndWeights PW      ON N.[Food code]  = PW.[Food code]
		WHERE I.[Ingredient code] BETWEEN 1001 AND 9999;
GO            
SELECT * FROM MainViewIngredient;
GO
SET STATISTICS TIME OFF


-- QUERY WITHOUT VIEW 
-- TIME : 56 ms
-- DIVIDE THE MAIN FOOD WITH PROTEIN AND CALORIES INFORMATION

SET STATISTICS TIME ON
GO
DROP TABLE IF EXISTS MainIngredient;
GO
SELECT food.ID, SUBSTRING(Description,1,ABS(CHARINDEX(',', Description)-1)) AS Main, Protein, Calories
	INTO MainIngredient
	FROM Food JOIN Protein
	ON Food.ID = Protein.ID;
GO
	SELECT * FROM MainIngredient
GO
SET STATISTICS TIME OFF

-- QUERY WITH VIEW
-- TIME : 3 ms 

SET STATISTICS TIME ON 
GO
DROP VIEW IF EXISTS MainFood;
GO
CREATE VIEW MainFood --3ms
AS
	SELECT food.ID, SUBSTRING(Description,1,ABS(CHARINDEX(',', Description)-1)) AS Main, Protein, Calories
	FROM Food JOIN Protein
	ON Food.ID = Protein.ID;
GO            
SELECT * FROM MainFood;
GO
SET STATISTICS TIME OFF

/* CONCLUSION : FROM THE USAGE OF ABOVE INTEGRITY CONSTRAINTS,INDEXES AND VIEWS , IT IS NOTICED THAT THE PERFORMANCE 
                OF THE SYSTEM CAN BE IMPROVED EFFICIENTLY */




