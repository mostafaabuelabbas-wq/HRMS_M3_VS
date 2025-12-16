-- SQL Script to Remove 'Mostafa Mohamed' from 'Mohamed Amr's Team
-- It sets the manager_id of the employee to NULL

DECLARE @ManagerName VARCHAR(100) = 'Mohamed Amr';
DECLARE @EmployeeName VARCHAR(100) = 'Mostafa Mohamed';

DECLARE @ManagerID INT;
DECLARE @EmployeeID INT;

-- 1. Find Manager ID
SELECT @ManagerID = employee_id 
FROM Employee 
WHERE full_name LIKE @ManagerName + '%'; -- simple wildcards

-- 2. Find Employee ID
SELECT @EmployeeID = employee_id 
FROM Employee 
WHERE full_name LIKE @EmployeeName + '%';

-- 3. Validation & Update
IF @ManagerID IS NULL
BEGIN
    PRINT 'Error: Manager ' + @ManagerName + ' not found.';
END
ELSE IF @EmployeeID IS NULL
BEGIN
    PRINT 'Error: Employee ' + @EmployeeName + ' not found.';
END
ELSE
BEGIN
    -- Check if they are actually linked currently
    IF EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID AND manager_id = @ManagerID)
    BEGIN
        UPDATE Employee
        SET manager_id = NULL
        WHERE employee_id = @EmployeeID;

        PRINT 'Success: ' + @EmployeeName + ' has been removed from ' + @ManagerName + '''s team.';
    END
    ELSE
    BEGIN
        PRINT 'Notice: ' + @EmployeeName + ' is not currently assigned to ' + @ManagerName + '.';
    END
END
GO
