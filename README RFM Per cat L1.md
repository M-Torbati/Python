This stored procedure calculates RFM (Recency, Frequency, Monetary) based on customer's order history and the category of the product they purchased. The procedure uses percentile_disc function to define quintile cuts for the three RFM metrics.

Prerequisites
An existing database
Table [DimProductTable] with columns: ProductItemId, CategoryLeve1NameFa, CategoryLevel1
Table [Sales_order_item] with columns: CustomerID, ID_Order, ID_Item, CartFinalizeDateId, NMV, orderStatus
Table [DimDate] with columns: DateId, Day_Lag
Steps
Create the stored procedure [customer].[Fill_CustomerRFMperCategoryLevel1].
The procedure starts by setting NOCOUNT ON and creates a TRY block.
The procedure will run the stored procedure DropAllTemp to clear any existing temporary tables.
It creates a temporary table #product to store the distinct product items and their corresponding category information.
The procedure calculates the Recency, Frequency, and Monetary values for each customer and stores the result in the #RFM_Values temporary table.
The procedure defines quintile cuts for the Recency, Frequency, and Monetary values in a new temporary table #QUINTILES.
The procedure maps each customer's RFM metrics to a label based on the quintile cuts defined in the previous step and stores the result in the #RFM_label temporary table.
The procedure returns the result in the #RFM_label table.
Notes
The values of Recency, Frequency, and Monetary are calculated based on the customer's order history within the last two years (i.e., where c.CartFinalizeDateId >= @date).
The calculation of RFM label assumes that the customers with higher recency, frequency, and monetary values are more valuable.
The procedure uses percentile_disc function to define quintile cuts for the three RFM metrics.
Author
Mohammed Torbati
