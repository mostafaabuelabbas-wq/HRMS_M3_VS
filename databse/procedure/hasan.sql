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
    lr.request_id,
    l.leave_type,
    lr.duration,
    lr.status,
    lr.justification,
    lr.approval_timing,
    COUNT(ld.document_id) AS attachment_count  -- ✅ NEW LINE 1
FROM LeaveRequest lr
INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
LEFT JOIN LeaveDocument ld ON lr.request_id = ld.leave_request_id  -- ✅ NEW LINE 2
WHERE lr.employee_id = @EmployeeID
GROUP BY lr.request_id, l.leave_type, lr.duration, lr.status, lr.justification, lr.approval_timing  -- ✅ NEW LINE 3
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

GO

CREATE OR ALTER PROCEDURE GetLeaveConfiguration
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Joins Leave Types with their Policy (if it exists)
    -- matching on special_leave_type
    SELECT 
        l.leave_id,
        l.leave_type,
        l.leave_description,
        ISNULL(p.notice_period, 0) AS notice_period,
        ISNULL(p.eligibility_rules, 'All') AS eligibility_rules
    FROM [Leave] l
    LEFT JOIN LeavePolicy p ON l.leave_type = p.special_leave_type;
END;
GO




