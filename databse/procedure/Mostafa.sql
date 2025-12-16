-- ============================================
-- Stored Procedure: InsertLeaveDocument
-- Description: Inserts a new leave document/attachment record
-- ============================================

CREATE OR ALTER PROCEDURE InsertLeaveDocument
    @LeaveRequestID INT,
    @FilePath VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate that the leave request exists
    IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
    BEGIN
        RAISERROR('Leave request does not exist.', 16, 1);
        RETURN;
    END;

    -- Insert the document record
    INSERT INTO LeaveDocument (leave_request_id, file_path, uploaded_at)
    VALUES (@LeaveRequestID, @FilePath, GETDATE());

    -- Return success message
    SELECT 'Document attached successfully' AS Message;
END;
GO


CREATE OR ALTER PROCEDURE GetAllLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        lr.request_id AS RequestId,
        lr.employee_id AS EmployeeId,
        e.full_name AS EmployeeName,
        l.leave_type AS LeaveType,
        lr.justification AS Justification,
        lr.duration AS Duration,
        lr.status AS Status,
        lr.approval_timing AS ApprovalTiming
    FROM LeaveRequest lr
    INNER JOIN Employee e ON lr.employee_id = e.employee_id
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    ORDER BY lr.request_id DESC;
END;
GO


CREATE OR ALTER PROCEDURE SendContractUpdateNotification
    @ContractID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmployeeID INT;
    DECLARE @Message VARCHAR(1000);
    DECLARE @NewNotificationID INT;

    -- 1. Find the employee who owns this contract
    --    (Using singular 'Contract' and 'contract_id'/'employee_id' as per schema)
    SELECT @EmployeeID = employee_id 
    FROM Contract 
    WHERE contract_id = @ContractID;

    -- 2. Only proceed if we found an employee
    IF @EmployeeID IS NOT NULL
    BEGIN
        SET @Message = 'Your contract details have been updated. Please review the changes.';

        -- 3. Insert into the main Notification table
        INSERT INTO Notification (message_content, [timestamp], urgency, read_status, notification_type)
        VALUES (@Message, GETDATE(), 'Medium', 0, 'ContractUpdate');

        -- 4. Get the ID of the notification we just created
        SET @NewNotificationID = SCOPE_IDENTITY();

        -- 5. Link it to the Employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NewNotificationID, 'Sent', GETDATE());
    END
END
GO


-- 1. Alter the Table to support BINARY images (VARBINARY)
-- FIX: Drop and Re-create to bypass conversion errors completely.
-- (Migration logic removed as you are rebuilding the schema)

-- 2. Update the Procedure to accept BINARY image
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

-- 3. Assign Role (Fixed: Single Role Enforcement)
CREATE OR ALTER PROCEDURE AssignRole
    @EmployeeID INT,
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate inputs
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM Role WHERE role_id = @RoleID)
    BEGIN
        SELECT 'Error: Role does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. THE FIX: Remove OLD roles first
    ---------------------------------------------------------
    -- This ensures the user only has ONE role at a time.
    DELETE FROM Employee_Role 
    WHERE employee_id = @EmployeeID;

    ---------------------------------------------------------
    -- 3. Assign the NEW role
    ---------------------------------------------------------
    INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
    VALUES (@EmployeeID, @RoleID, GETDATE());

    ---------------------------------------------------------
    -- 4. Confirmation
    ---------------------------------------------------------
    SELECT 'Role updated successfully.' AS Message;
END;
GO






---contracts
SET NOCOUNT ON;

DECLARE @EmpID INT;
DECLARE @RandVal FLOAT;
DECLARE @Type VARCHAR(50);
DECLARE @StartDate DATE = '2025-01-01';
DECLARE @EndDate DATE = '2030-01-01';
DECLARE @NewContractID INT;

-- 1. Initialize logic: Create a cursor for ALL employees
DECLARE emp_cursor CURSOR FOR 
SELECT employee_id FROM Employee;

OPEN emp_cursor;
FETCH NEXT FROM emp_cursor INTO @EmpID;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- 2. Determine Contract Type using Random Percentage
    SET @RandVal = RAND(); -- Returns 0.0 to 1.0

    IF @RandVal < 0.70       SET @Type = 'FullTime';   -- 70% chance
    ELSE IF @RandVal < 0.85  SET @Type = 'PartTime';   -- 15% chance
    ELSE IF @RandVal < 0.95  SET @Type = 'Internship'; -- 10% chance
    ELSE                     SET @Type = 'Consultant'; -- 5% chance

    -- 3. Create Basic Contract
    INSERT INTO Contract (type, start_date, end_date, current_state, employee_id)
    VALUES (@Type, @StartDate, @EndDate, 'Active', @EmpID);

    SET @NewContractID = SCOPE_IDENTITY();

    -- 4. Insert Subtype Details
    IF @Type = 'FullTime'
        INSERT INTO FullTimeContract (contract_id, leave_entitlement, insurance_eligibility, weekly_working_hours)
        VALUES (@NewContractID, 21, 1, 40);
        
    ELSE IF @Type = 'PartTime'
        INSERT INTO PartTimeContract (contract_id, working_hours, hourly_rate)
        VALUES (@NewContractID, 20, 150.00);
        
    ELSE IF @Type = 'Internship'
        INSERT INTO InternshipContract (contract_id, mentoring, evaluation, stipend_related)
        VALUES (@NewContractID, ' Assigned Mentor', 'Monthly Review', 'Paid Stipend');
        
    ELSE -- Consultant
        INSERT INTO ConsultantContract (contract_id, project_scope, fees, payment_schedule)
        VALUES (@NewContractID, 'Specialized Project', 5000.00, 'Milestone-based');

    -- 5. Link Contract to Employee
    UPDATE Employee 
    SET contract_id = @NewContractID 
    WHERE employee_id = @EmpID;

    FETCH NEXT FROM emp_cursor INTO @EmpID;
END

CLOSE emp_cursor;
DEALLOCATE emp_cursor;

-- 6. Verify Results
SELECT 
    c.type AS ContractType, 
    COUNT(*) AS TotalCount,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Employee) AS DECIMAL(5,2)) AS Percentage
FROM Contract c
GROUP BY c.type;