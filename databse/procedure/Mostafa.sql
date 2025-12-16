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