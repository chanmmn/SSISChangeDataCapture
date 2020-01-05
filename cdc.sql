http://www.mattmasson.com/2011/12/cdc-in-ssis-for-sql-server-2012-2/
USE [CDCTest]
GO

SELECT * INTO DimCustomer_CDC
FROM [AdventureWorksDW2012].[dbo].[DimCustomer]
WHERE CustomerKey < 11500

USE [CDCTest]
GO

EXEC sys.sp_cdc_enable_db
GO

-- add a primary key to the DimCustomer_CDC table so we can enable support for net changes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DimCustomer_CDC]') AND name = N'PK_DimCustomer_CDC')
  ALTER TABLE [dbo].[DimCustomer_CDC] ADD CONSTRAINT [PK_DimCustomer_CDC] PRIMARY KEY CLUSTERED
(
    [CustomerKey] ASC
)
GO

EXEC sys.sp_cdc_enable_table
@source_schema = N'dbo',
@source_name = N'DimCustomer_CDC',
@role_name = N'cdc_admin',
@supports_net_changes = 1

GO

SELECT TOP 0 * INTO DimCustomer_Destination
FROM DimCustomer_CDC

SELECT * FROM cdc_states

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[stg_DimCustomer_UPDATES]') AND type in (N'U'))
BEGIN
   SELECT TOP 0 * INTO stg_DimCustomer_UPDATES
   FROM DimCustomer_Destination
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[stg_DimCustomer_DELETES]') AND type in (N'U'))
BEGIN
   SELECT TOP 0 * INTO stg_DimCustomer_DELETES
   FROM DimCustomer_Destination
END

--
-- These queries go into the incremental load package, and do not need to be run directly
--

-- batch update
UPDATE dest
SET
    dest.FirstName = stg.FirstName,
    dest.MiddleName = stg.MiddleName,
    dest.LastName = stg.LastName,
    dest.YearlyIncome = stg.YearlyIncome
FROM
    [DimCustomer_Destination] dest,
    [stg_DimCustomer_UPDATES] stg
WHERE
    stg.[CustomerKey] = dest.[CustomerKey]

-- batch delete
DELETE FROM [DimCustomer_Destination]
  WHERE[CustomerKey] IN
(
    SELECT [CustomerKey]
    FROM [dbo].[stg_DimCustomer_DELETES]
)

USE [CDCTest]
GO

-- Transfer the remaining customer rows
SET IDENTITY_INSERT DimCustomer_CDC ON

INSERT INTO DimCustomer_CDC
(
       CustomerKey, GeographyKey, CustomerAlternateKey, Title, FirstName,
       MiddleName, LastName, NameStyle, BirthDate, MaritalStatus,
       Suffix, Gender, EmailAddress, YearlyIncome, TotalChildren,
       NumberChildrenAtHome, EnglishEducation, SpanishEducation,
       FrenchEducation, EnglishOccupation, SpanishOccupation,
       FrenchOccupation, HouseOwnerFlag, NumberCarsOwned, AddressLine1,
       AddressLine2, Phone, DateFirstPurchase, CommuteDistance
)
SELECT CustomerKey, GeographyKey, CustomerAlternateKey, Title, FirstName,
       MiddleName, LastName, NameStyle, BirthDate, MaritalStatus,
       Suffix, Gender, EmailAddress, YearlyIncome, TotalChildren,
       NumberChildrenAtHome, EnglishEducation, SpanishEducation,
       FrenchEducation, EnglishOccupation, SpanishOccupation,
       FrenchOccupation, HouseOwnerFlag, NumberCarsOwned, AddressLine1,
       AddressLine2, Phone, DateFirstPurchase, CommuteDistance
FROM [AdventureWorksDW2012].[dbo].[DimCustomer]
WHERE CustomerKey > 29479

SET IDENTITY_INSERT DimCustomer_CDC OFF
GO

-- give 10 people a raise
UPDATE DimCustomer_CDC
SET
    YearlyIncome = YearlyIncome + 10
WHERE
    CustomerKey > 11000 AND CustomerKey < 11010

GO

SELECT * FROM [AdventureWorksDW2012].[dbo].[DimCustomer] order by CustomerKey
