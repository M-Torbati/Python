USE [database]
GO

/****** Object:  StoredProcedure [customer].[Fill_CustomerRFMperCategory]    Script Date:  ******/

--/*============================================================================= 
--<Comment> 
--	<ModeName>[customer].[Fill_CustomerRFMperCategoryLevelOne]</ModeName> 
--	<Author>Mohammed Torbati</Author> 
--	<CreationDate></CreationDate>  
--	<ModifyDate></ModifyDate> 
--	<Description>CalCualate RFM BAsed On Category and Qcut method</Description> 
--</Comment> 
--=============================================================================*/
CREATE PROCEDURE [customer].[Fill_CustomerRFMperCategory]

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	EXEC DropAllTemp
	-------------------ProductItem-------------------
	drop table if exists #ProductItemId; --
		select  distinct ProductItemId,
		CategoryLeve1Name,CategoryLevel1,
		CategoryLevel2Name,CategoryLevel2,
		Leaf_Name,Leaf
		into #ProductItemId
		from [DimProductTable] b 
		where 1=1

	------------------sales ----------------------------
	declare @date int
	select  @date= DateId
	from DimDate as d
	where d.Day_Lag=750
 
	
    drop table if exists #sales;
    SELECT
        c.CustomerID,
		c.CartFinalizeDateId,
        c.ID_Order,
        c.NMV ,
		c.ID_Item
		into #sales
    FROM [Sales_order_item] c 
	inner join #ProductItemId p on  p.ProductItemId=c.ProductItemId
    WHERE 1=1
	AND c.CartFinalizeDateId >= @date   
	AND   orderStatus in (4)
  -- 1:10 
 	-------------------#sales_categorylevel1-------------------

	drop table if exists #sales_categorylevel1;
	with  sales_categorylevel1  as ( 
    SELECT
	   CategoryLevel1,
        c.CustomerID,
        DATEDIFF(day,
        CONVERT (DATE, convert (char (8), MAX (c.CartFinalizeDateId))),
                       CAST( GETDATE() AS Date )) AS Recency,
        COUNT (DISTINCT c.ID_Order) AS Frequency,
        SUM (c.NMV) AS Monetary
    FROM #sales c  
	inner join #ProductItemId p on  p.ProductItemId=c.ID_Item
    WHERE 1=1
    GROUP BY CategoryLevel1,c.CustomerID) 
	select * 
	into #sales_categorylevel1
	from sales_categorylevel1	
	where     Frequency>1 AND  Recency < 370
 
 -----------------------#sales_categorylevel2--------------------------
  

 	drop table if exists #sales_categorylevel2;
    with  sales_categorylevel2  as ( 
	SELECT
	   CategoryLevel2,
        c.CustomerID,
        DATEDIFF(day,
        CONVERT (DATE, convert (char (8), MAX (c.CartFinalizeDateId))),
                       CAST( GETDATE() AS Date )) AS Recency,
        COUNT (DISTINCT c.ID_Order) AS Frequency,
        SUM (c.NMV) AS Monetary
		
    FROM #sales c  
	inner join #ProductItemId p on  p.ProductItemId=c.ID_Item
    WHERE 1=1
    GROUP BY CategoryLevel2,c.CustomerID ) 
	select * 
	into #sales_categorylevel2
	from sales_categorylevel2
	where     Frequency>1 AND  Recency < 370 

 -----------------------#sales_Leaf--------------------------

	drop table if exists #sales_Leaf;
	with  sales_Leaf  as ( 
	SELECT
	Leaf,
	c.CustomerID,
	DATEDIFF(day,
	CONVERT (DATE, convert (char (8), MAX (c.CartFinalizeDateId))),
					CAST( GETDATE() AS Date )) AS Recency,
	COUNT (DISTINCT c.ID_Order) AS Frequency,
	SUM (c.NMV) AS Monetary

	FROM #sales c  
	inner join #ProductItemId p on  p.ProductItemId=c.ID_Item
	WHERE 1=1
	GROUP BY Leaf,c.CustomerID)

	select *
	into #sales_Leaf
	from sales_Leaf
	where     Frequency>1 AND  Recency < 370 

	------------------------------------------------------
	drop table if exists  #sales;
	------------------------------------------------------
 
	-------------------QUINTILES_Values-------------------
	drop table if exists #sales_categorylevel1_QUINTILES;
	SELECT distinct CategoryLevel1,
	   percentile_disc(0.5)  within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_1_quin,
	   percentile_disc(0.75) within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_2_quin,
	   percentile_disc(0.87) within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_3_quin,
	   percentile_disc(0.98) within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_4_quin,
	   percentile_disc(0.5)  within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_1_quin,
	   percentile_disc(0.75) within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_2_quin,
	   percentile_disc(0.87) within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_3_quin,
	   percentile_disc(0.98) within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_4_quin
		into #sales_categorylevel1_QUINTILES
	FROM #sales_categorylevel1


		drop table if exists #sales_categorylevel2_QUINTILES;
	SELECT distinct CategoryLevel2,
	   percentile_disc(0.5)  within group (order by Monetary)  OVER (partition by CategoryLevel2) as monetary_value_1_quin,
	   percentile_disc(0.75) within group (order by Monetary)  OVER (partition by CategoryLevel2) as monetary_value_2_quin,
	   percentile_disc(0.87) within group (order by Monetary)  OVER (partition by CategoryLevel2) as monetary_value_3_quin,
	   percentile_disc(0.98) within group (order by Monetary)  OVER (partition by CategoryLevel2) as monetary_value_4_quin,
	   percentile_disc(0.5)  within group (order by Frequency) OVER (partition by CategoryLevel2) as frequency_1_quin,
	   percentile_disc(0.75) within group (order by Frequency) OVER (partition by CategoryLevel2) as frequency_2_quin,
	   percentile_disc(0.87) within group (order by Frequency) OVER (partition by CategoryLevel2) as frequency_3_quin,
	   percentile_disc(0.98) within group (order by Frequency) OVER (partition by CategoryLevel2) as frequency_4_quin
		into #sales_categorylevel2_QUINTILES
	FROM #sales_categorylevel2


	 drop table if exists #sales_Leaf_QUINTILES;
	SELECT distinct Leaf,
	   percentile_disc(0.5)  within group (order by Monetary)  OVER (partition by Leaf) as monetary_value_1_quin,
	   percentile_disc(0.75) within group (order by Monetary)  OVER (partition by Leaf) as monetary_value_2_quin,
	   percentile_disc(0.87) within group (order by Monetary)  OVER (partition by Leaf) as monetary_value_3_quin,
	   percentile_disc(0.98) within group (order by Monetary)  OVER (partition by Leaf) as monetary_value_4_quin,
	   percentile_disc(0.5)  within group (order by Frequency) OVER (partition by Leaf) as frequency_1_quin,
	   percentile_disc(0.75) within group (order by Frequency) OVER (partition by Leaf) as frequency_2_quin,
	   percentile_disc(0.87) within group (order by Frequency) OVER (partition by Leaf) as frequency_3_quin,
	   percentile_disc(0.98) within group (order by Frequency) OVER (partition by Leaf) as frequency_4_quin
		into #sales_Leaf_QUINTILES
	FROM #sales_Leaf

	-------------------RFM_label_categorylevel1-------------------
	drop table if exists #RFM_label_categorylevel1;
	SELECT
	    r.CategoryLevel1,
	    CustomerID,
	    recency,
	    frequency,
	    Monetary,
	  CASE		
			WHEN Recency <= 30 THEN 10
			WHEN Recency <= 60 THEN 20
			WHEN Recency <= 90 THEN 30
			WHEN Recency <= 120 THEN 40
			ELSE 50
		END AS RecencyId,
	       (CASE WHEN r.frequency <= frequency_1_quin THEN 10
	   WHEN frequency > frequency_1_quin and frequency <= frequency_2_quin THEN 20
	   WHEN frequency > frequency_2_quin and frequency <= frequency_3_quin THEN 30
	   WHEN frequency > frequency_3_quin and frequency <= frequency_4_quin THEN 40
	   ELSE 50 END) "frequencyId",
	     (CASE WHEN Monetary <= monetary_value_1_quin THEN 10
	   WHEN Monetary > monetary_value_1_quin and Monetary <= monetary_value_2_quin THEN 20
	   WHEN Monetary > monetary_value_2_quin and Monetary <= monetary_value_3_quin THEN 30
	   WHEN Monetary > monetary_value_3_quin and Monetary <= monetary_value_4_quin THEN 40
	   ELSE 50 END) "monetaryId"
	   into #RFM_label_categorylevel1
	FROM #sales_categorylevel1    r inner join  #sales_categorylevel1_QUINTILES q on r.CategoryLevel1 = q.CategoryLevel1
	ORDER BY recency DESC, frequency DESC, Monetary DESC;


		-------------------RFM_label_categorylevel2-------------------
	drop table if exists #RFM_label_categorylevel2;
	SELECT
	    r.CategoryLevel2,
	    CustomerID,
	    recency,
	    frequency,
	    Monetary,
	  CASE		
			WHEN Recency <= 30 THEN 10
			WHEN Recency <= 60 THEN 20
			WHEN Recency <= 90 THEN 30
			WHEN Recency <= 120 THEN 40
			ELSE 50
		END AS RecencyId,
	       (CASE WHEN r.frequency <= frequency_1_quin THEN 10
	   WHEN frequency > frequency_1_quin and frequency <= frequency_2_quin THEN 20
	   WHEN frequency > frequency_2_quin and frequency <= frequency_3_quin THEN 30
	   WHEN frequency > frequency_3_quin and frequency <= frequency_4_quin THEN 40
	   ELSE 50 END) "frequencyId",
	     (CASE WHEN Monetary <= monetary_value_1_quin THEN 10
	   WHEN Monetary > monetary_value_1_quin and Monetary <= monetary_value_2_quin THEN 20
	   WHEN Monetary > monetary_value_2_quin and Monetary <= monetary_value_3_quin THEN 30
	   WHEN Monetary > monetary_value_3_quin and Monetary <= monetary_value_4_quin THEN 40
	   ELSE 50 END) "monetaryId"
	   into #RFM_label_categorylevel2
	FROM #sales_categorylevel2    r inner join  #sales_categorylevel2_QUINTILES q on r.CategoryLevel2 = q.CategoryLevel2
	ORDER BY recency DESC, frequency DESC, Monetary DESC;


		-------------------RFM_label_Content_Leaf-------------------
	drop table if exists #RFM_label_Content_Leaf;
	SELECT
	    r.Leaf,
	    CustomerID,
	    recency,
	    frequency,
	    Monetary,
	  CASE		
			WHEN Recency <= 30 THEN 10
			WHEN Recency <= 60 THEN 20
			WHEN Recency <= 90 THEN 30
			WHEN Recency <= 120 THEN 40
			ELSE 50
		END AS RecencyId,
	       (CASE WHEN r.frequency <= frequency_1_quin THEN 10
	   WHEN frequency > frequency_1_quin and frequency <= frequency_2_quin THEN 20
	   WHEN frequency > frequency_2_quin and frequency <= frequency_3_quin THEN 30
	   WHEN frequency > frequency_3_quin and frequency <= frequency_4_quin THEN 40
	   ELSE 50 END) "frequencyId",
	     (CASE WHEN Monetary <= monetary_value_1_quin THEN 10
	   WHEN Monetary > monetary_value_1_quin and Monetary <= monetary_value_2_quin THEN 20
	   WHEN Monetary > monetary_value_2_quin and Monetary <= monetary_value_3_quin THEN 30
	   WHEN Monetary > monetary_value_3_quin and Monetary <= monetary_value_4_quin THEN 40
	   ELSE 50 END) "monetaryId"
	   into #RFM_label_Content_Leaf
	FROM #sales_Leaf    r inner join  #sales_Leaf_QUINTILES q on r.Leaf = q.Leaf
	ORDER BY recency DESC, frequency DESC, Monetary DESC;


		------------------------------------
	drop table if exists #sales_categorylevel1
	drop table if exists #sales_categorylevel2
	drop table if exists #sales_Leaf

	-------------------RFM_Final-------------------

 
	drop table if exists #RFM_Final;
	select  details_id , brand_id , CustomerID , Frequency, rfm.frequencyId ,rfm.Monetary ,rfm.monetaryId ,rfm.Recency ,rfm.RecencyId
   ,[type],CAST(CONCAT(CONCAT(r.RecencyScore, f.FrequencyScore), m.MonetaryScore) AS INT) RFM_Category_Id ,ROW_NUMBER() OVER (ORDER BY CustomerID) row_num 
	into #RFM_Final
	from (	
	select  rfm.CategoryLevel1  details_id, -1 as brand_id,rfm.CustomerID ,rfm.Frequency,rfm.frequencyId ,rfm.Monetary ,rfm.monetaryId ,rfm.Recency ,rfm.RecencyId
	,1 as  [type] ---categorylevel1
	from #RFM_label_categorylevel1 rfm	
	union 
	select  CategoryLevel2 details_id ,-1 as brand_id,rfm.CustomerID ,rfm.Frequency,rfm.frequencyId ,rfm.Monetary ,rfm.monetaryId ,rfm.Recency ,rfm.RecencyId
	,2 as  [type] --categorylevel2
	from #RFM_label_categorylevel2 rfm
	union 
	 select  rfm.C2_Content_Leaf details_id,-1 as brand_id ,rfm.CustomerID ,rfm.Frequency,rfm.frequencyId ,rfm.Monetary ,rfm.monetaryId ,rfm.Recency ,rfm.RecencyId
	,3 as  [type] -- Content_Leaf
	from #RFM_label_Content_Leaf rfm
	) as rfm
	JOIN DimRecency r 	  ON rfm.RecencyId = r.RecencyId
	JOIN DimFrequency f   ON rfm.FrequencyId = f.FrequencyId
	JOIN DimMonetary m    ON rfm.MonetaryId = m.MonetaryId


	-------------------PrevRFM_Final-------------------
 

	drop table if exists #prevRFM_Final;
	select Distinct customer_id,r.details_id,r.RFM_category_id,[type_id],recency_id,frequency_id,monetary_id
	INTO #prevRFM_Final
	FROM [RFM_details] r

	TRUNCATE TABLE [RFM_details];
	declare @getdate int 
	set @getdate =convert(char(8),GETDATE(),112)  
	
	DECLARE @i int =0
	declare @rw  bigint =(select max(row_num) from #RFM_Final)
	WHILE 1=1
	BEGIN

 
	INSERT INTO [RFM_details]
                       ([date_Id]
					   ,[type_id]
					   ,[details_id]
                       ,[customer_id]
                       ,[last_purchase]
                       ,[order_count]
                       ,[NMV]
                       ,[recency_id]
                       ,[frequency_id]
                       ,[monetary_id]
					   ,[RFM_category_id]
					   ,[prev_RFM_category_id]
					   ,[prev_recency_id]
					   ,[prev_frequency_id]
					   ,[prev_monetary_id]
                       )
    select  @getdate as [date_Id],
			r.type as  [type_id],
			r.details_id   as [details_id],
			r.CustomerID       as [customer_id],
			r.Recency          as [last_purchase],
			r.Frequency        as [order_count],
			r.Monetary         as [NMV],
			r.RecencyId        as [recency_id],
			r.frequencyId      as [frequency_id],
			r.monetaryId       as [monetary_id],
			r.RFM_Category_Id  as [RFM_category_id],
			pr.RFM_category_id as [prev_RFM_category_id],
			pr.recency_id       as [prev_recency_id],
			pr.frequency_id     as [prev_frequency_id],
			pr.monetary_id      as [prev_monetary_id]
		from #RFM_Final r
			left join #prevRFM_Final pr on r.details_id = pr.details_id and r.CustomerID = pr.customer_id and r.[type] = pr.[type_id]
		where r.row_num >= @i and  r.row_num  < @i + 4000000
		if @@ROWCOUNT =0 break else 
		SET @i = @i + 4000000
		continue 
END	
	EXEC DropAllTemp
		END TRY
			
		BEGIN CATCH
			THROW ;
		END CATCH
END
GO


