USE HRMS;
GO

-- 1. DROP CONSTRAINTS (Crucial Step: Remove anything locking the column)
DECLARE @ConstraintName nvarchar(200)
SELECT @ConstraintName = Name FROM sys.default_constraints 
WHERE parent_object_id = OBJECT_ID('Employee') 
AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Employee') AND name = 'profile_image')

IF @ConstraintName IS NOT NULL
BEGIN
    PRINT 'Dropping constraint: ' + @ConstraintName
    EXEC('ALTER TABLE Employee DROP CONSTRAINT ' + @ConstraintName)
END
GO

-- 2. DROP THE COLUMN ENTIRELY (The Nuclear Option - Guaranteed to work)
IF EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'profile_image' AND Object_ID = Object_ID(N'Employee'))
BEGIN
    PRINT 'Dropping old profile_image column...'
    ALTER TABLE Employee DROP COLUMN profile_image;
END
GO

-- 3. RE-ADD THE COLUMN WITH CORRECT TYPE
PRINT 'Adding new profile_image column (VARBINARY(MAX))...'
ALTER TABLE Employee ADD profile_image VARBINARY(MAX);
GO

-- 4. UPDATE STORED PROCEDURE (To match the new column)
PRINT 'Updating Insert/Update Procedure...'
GO

CREATE OR ALTER PROCEDURE UpdateEmployeeInfo
    @EmployeeID INT,
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(150),
    @ProfileImage VARBINARY(MAX) = NULL 
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found.' AS Message;
        RETURN;
    END

    UPDATE Employee
    SET email = @Email,
        phone = @Phone,
        address = @Address,
        profile_image = @ProfileImage
    WHERE employee_id = @EmployeeID;

    SELECT 'Employee information updated successfully' AS ConfirmationMessage;
END;
GO

-- 5. VERIFICATION
SELECT 'SUCCESS! Column recreated.' as Status, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Employee' AND COLUMN_NAME = 'profile_image';
GO
