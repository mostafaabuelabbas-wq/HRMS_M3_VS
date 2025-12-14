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




