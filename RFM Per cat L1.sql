USE [database]
GO

/****** Object:  StoredProcedure [customer].[Fill_CustomerRFMperCategoryLevel1]    Script Date:  ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*============================================================================= 
<Comment> 
	<ModeName>[customer].[Fill_CustomerRFMperCategoryLevel1]</ModeName> 
	<Author>Mohammed Torbati</Author> 
	<CreationDate></CreationDate> 
	<ModifyDate></ModifyDate> 
	<Description>CalCualate RFM BAsed On Category and Qcut method</Description> 
</Comment> 
=============================================================================*/
CREATE PROCEDURE [customer].[Fill_CustomerRFMperCategoryLevel1]

AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY

	EXEC DropAllTemp
	--truncate table 
	-------------------Product Category-------------------
	drop table if exists #product; --
		select  distinct ProductItemId,CategoryLeve1NameFa,CategoryLevel1
		into #product
		from [DimProductTable]
		where 1=1

	-------------------RFM_Values-------------------
	declare @date int
	select  @date= DateId
	from DimDate as d
	where d.Day_Lag=750
 


	drop table if exists #RFM_Values;
    SELECT
	   CategoryLevel1,
        c.CustomerID,
        DATEDIFF(day,
        CONVERT (DATE, convert (char (8), MAX (c.CartFinalizeDateId))),
                       CAST( GETDATE() AS Date )) AS Recency,
        COUNT (DISTINCT c.ID_Order) AS Frequency,
        SUM (c.NMV) AS Monetary
		into #RFM_Values
    FROM [Sales_order_item] c 
	inner join #product p on  p.ProductItemId=c.ID_Item
    WHERE 1=1
	AND c.CartFinalizeDateId >= @date   
	AND   orderStatus in (4)
    GROUP BY CategoryLevel1,c.CustomerID
	having  COUNT (DISTINCT c.ID_Order)>1 and  DATEDIFF(day,CONVERT (DATE, convert (char (8), MAX (c.CartFinalizeDateId))),CAST( GETDATE() AS Date )) < 370

	-------------------QUINTILES_Values-------------------
	drop table if exists #QUINTILES;
	SELECT distinct CategoryLevel1,
	   percentile_disc(0.02) within group (order by Recency)   OVER (partition by CategoryLevel1) as Recency_value_1_quin,
	   percentile_disc(0.13) within group (order by Recency)   OVER (partition by CategoryLevel1) as Recency_value_2_quin,
	   percentile_disc(0.25) within group (order by Recency)   OVER (partition by CategoryLevel1) as Recency_value_3_quin,
	   percentile_disc(0.5)  within group (order by Recency)   OVER (partition by CategoryLevel1) as Recency_value_4_quin,
	   percentile_disc(0.5)  within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_1_quin,
	   percentile_disc(0.75) within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_2_quin,
	   percentile_disc(0.87) within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_3_quin,
	   percentile_disc(0.98) within group (order by Monetary)  OVER (partition by CategoryLevel1) as monetary_value_4_quin,
	   percentile_disc(0.5)  within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_1_quin,
	   percentile_disc(0.75) within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_2_quin,
	   percentile_disc(0.87) within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_3_quin,
	   percentile_disc(0.98) within group (order by Frequency) OVER (partition by CategoryLevel1) as frequency_4_quin
		into #QUINTILES
	FROM #RFM_Values

	-------------------RFM_label-------------------
	drop table if exists #RFM_label;
	SELECT
	    r.CategoryLevel1,
	    CustomerID,
	    recency,
	    frequency,
	    Monetary,
	   (CASE WHEN r.Recency <= Recency_value_1_quin THEN 10
	      WHEN Recency > Recency_value_1_quin and Recency <= Recency_value_2_quin THEN 20
	      WHEN Recency > Recency_value_2_quin and Recency <= Recency_value_3_quin THEN 30
	      WHEN Recency > Recency_value_3_quin and Recency <= Recency_value_4_quin THEN 40
	     ELSE 50 END) AS RecencyId,
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
	   into #RFM_label
	FROM #RFM_Values r inner join  #QUINTILES q on r.CategoryLevel1 = q.CategoryLevel1
	ORDER BY recency DESC, frequency DESC, Monetary DESC;


	-------------------RFM_Final-------------------
	drop table if exists #RFM_Final;
	select rfm.*
	,CAST(CONCAT(CONCAT(r.RecencyScore, f.FrequencyScore), m.MonetaryScore) AS INT) RFM_Category_Id
	into #RFM_Final
	from #RFM_label rfm
	JOIN DimRecency r 	  ON rfm.RecencyId = r.RecencyId
	JOIN DimFrequency f   ON rfm.FrequencyId = f.FrequencyId
	JOIN DimMonetary m    ON rfm.MonetaryId = m.MonetaryId

	-------------------PrevRFM_Final-------------------
	drop table if exists #prevRFM_Final;
	select Distinct CustomerID,r.CategoryLevel1ID,r.RFM_Category_Id
	INTO #prevRFM_Final
	FROM [RFM_CategoryLevel1] r


	TRUNCATE TABLE [RFM_CategoryLevel1]
	INSERT INTO [RFM_CategoryLevel1]
                       ([DateID]
					   ,[CategoryLevel1ID]
                       ,[CustomerID]
                       ,[Last_Purchase]
                       ,[OrderCount]
                       ,[NMV]
                       ,[RecencyId]
                       ,[FrequencyId]
                       ,[MonetaryId]
					   ,[RFM_Category_Id]
					   ,[Prev_RFM_Category_Id]
                       )
    select convert(char(8),GETDATE(),112) as dateid,
			r.CategoryLevel1,
			r.CustomerID,
			r.Recency,
			r.Frequency,
			r.Monetary,
			r.RecencyId,
			r.frequencyId,
			r.monetaryId,
			r.RFM_Category_Id,
			pr.RFM_Category_Id
	from #RFM_Final r
	left join #prevRFM_Final pr on r.CategoryLevel1 = pr.CategoryLevel1ID and r.CustomerID = pr.CustomerID


	EXEC DropAllTemp
		END TRY
			
		BEGIN CATCH
			THROW ;
		END CATCH


END
GO


