-- ==========================================================
-- FIX SCRIPT: RUN THIS ENTIRE FILE IN YOUR SQL DATABASE
-- ==========================================================

-- 1. Clear invalid text data from the profile_image column
--    (This prevents "Implicit conversion" errors)
UPDATE Employee 
SET profile_image = NULL; 
GO

-- 2. Change the column type to allow large images (Binary Data)
ALTER TABLE Employee 
ALTER COLUMN profile_image VARBINARY(MAX);
GO

-- 3. Update the Stored Procedure to accept large images
CREATE OR ALTER PROCEDURE UpdateEmployeeInfo
    @EmployeeID INT,
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(150),
    @ProfileImage VARBINARY(MAX) = NULL -- Updated to MAX
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found.' AS Message;
        RETURN;
    END;

    -- Check for duplicate email (excluding current user)
    IF EXISTS (SELECT 1 FROM Employee WHERE email = @Email AND employee_id <> @EmployeeID)
    BEGIN
        SELECT 'Error: This email is already used by another employee.' AS Message;
        RETURN;
    END;

    UPDATE Employee
    SET email = @Email,
        phone = @Phone,
        address = @Address,
        profile_image = @ProfileImage
    WHERE employee_id = @EmployeeID;

    SELECT 'Employee information updated successfully' AS ConfirmationMessage;
END;
GO

-- 4. Check that it worked
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Employee' AND COLUMN_NAME = 'profile_image';
GO
