CREATE OR ALTER PROCEDURE InsertLeaveDocument
    @LeaveRequestID INT,
    @FilePath VARCHAR(500)
AS
BEGIN
    INSERT INTO LeaveDocument (leave_request_id, file_path, uploaded_at)
    VALUES (@LeaveRequestID, @FilePath, GETDATE());
END;
GO

CREATE OR ALTER PROCEDURE GetLeaveHistory
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        lr.request_id AS RequestId,
        l.leave_type AS LeaveType,
        lr.justification AS Justification, -- Contains the dates
        lr.duration AS Duration,
        lr.status AS Status,
        lr.approval_timing AS ApprovalDate
    FROM LeaveRequest lr
    JOIN [Leave] l ON lr.leave_id = l.leave_id
    WHERE lr.employee_id = @EmployeeID
    ORDER BY lr.request_id DESC;
END;
GO




CREATE OR ALTER PROCEDURE GetLeaveTypes
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        leave_id, 
        leave_type 
    FROM [Leave]
    -- ✅ Logic: Exclude Holiday entirely (Calendar-based)
    -- Vacation, Sick, and Probation remain in the list
    WHERE leave_type NOT IN ('Holiday'); 
END;
GO


SELECT COUNT(*) FROM [Leave];



IF NOT EXISTS (SELECT 1 FROM [Leave])
BEGIN
    INSERT INTO [Leave] (leave_type, leave_description) VALUES ('Annual Vacation', 'Standard yearly vacation');
    INSERT INTO [Leave] (leave_type, leave_description) VALUES ('Sick Leave', 'Medical leave');
    INSERT INTO [Leave] (leave_type, leave_description) VALUES ('Maternity Leave', 'Parental leave');
END

-- 2. Give Employee ID 1 some balance (Data)
DECLARE @EmpID INT = 1; 

INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
SELECT @EmpID, leave_id, 30.00
FROM [Leave]
WHERE leave_id NOT IN (SELECT leave_type_id FROM LeaveEntitlement WHERE employee_id = @EmpID);

USE HRMS;
GO

-- 1. Give 30 days of entitlement to EVERY employee for EVERY leave type
-- This uses a CROSS JOIN to match every employee with every leave type
INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
SELECT e.employee_id, l.leave_id, 30.00
FROM Employee e
CROSS JOIN [Leave] l
WHERE NOT EXISTS (
    -- Only insert if they don't already have it
    SELECT 1 
    FROM LeaveEntitlement le 
    WHERE le.employee_id = e.employee_id 
    AND le.leave_type_id = l.leave_id
);

-- 2. Verify the data exists (Optional check)
SELECT TOP 10 e.full_name, l.leave_type, le.entitlement
FROM LeaveEntitlement le
JOIN Employee e ON le.employee_id = e.employee_id
JOIN [Leave] l ON le.leave_type_id = l.leave_id
ORDER BY e.employee_id;
GO