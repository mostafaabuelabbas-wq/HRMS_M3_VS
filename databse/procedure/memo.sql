USE HRMS;
GO

CREATE OR ALTER PROCEDURE GetEmployeeAttendanceHistory
    @EmployeeID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT 
        a.attendance_id,
        a.employee_id,
        e.first_name + ' ' + e.last_name AS full_name,
        a.shift_id,
        a.entry_time,
        a.exit_time,
        a.duration,
        a.login_method,
        a.logout_method,
        a.exception_id
    FROM Attendance a
    INNER JOIN Employee e ON a.employee_id = e.employee_id
    WHERE a.employee_id = @EmployeeID
      AND a.entry_time >= @StartDate
      AND a.entry_time < DATEADD(DAY, 1, @EndDate)
    ORDER BY a.entry_time DESC;
END;
GO



--
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-------------------------------------------------------------------------------
-- Stored Procedure: GetAttendanceAnalysis
-- Purpose: Returns detailed attendance analysis (Late, Early, Grace) based on raw data.
-- Logic: Fetches Shift, Actual, and Grace Period info. Calculation logic (grace logic) is mostly handled in App,
--        but this procedure gathers ALL necessary fields efficiently.
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE GetAttendanceAnalysis
    @Start DATETIME,
    @End DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Fetch Grace Period (Single Value) - We could return it or factor it in.
    -- For flexibility, let's keep the grace calculation partly in C# or fully here.
    -- To fix the bug properly and efficiently, let's do the "Raw Data" fetch here as requested by simple architecture.
    
    -- NOTE: The C# service was running TWO queries. 
    -- Query 1: Get Grace (Raw SQL) -> Failed
    -- Query 2: Get Data (Raw SQL) -> Failed
    -- We will combine everything into one Result Set or simply return the data needed.

    SELECT 
        a.employee_id, 
        e.first_name + ' ' + e.last_name AS employee_name, 
        d.department_name,
        CAST(ss.start_time AS TIME) as shift_start,
        CAST(ss.end_time AS TIME) as shift_end,
        CAST(a.entry_time AS TIME) as actual_in,
        CASE WHEN a.exit_time IS NOT NULL THEN CAST(a.exit_time AS TIME) ELSE NULL END as actual_out
    FROM Attendance a
    JOIN Employee e ON a.employee_id = e.employee_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    JOIN ShiftSchedule ss ON a.shift_id = ss.shift_id
    WHERE a.entry_time >= @Start AND a.entry_time < @End
    ORDER BY a.entry_time DESC;

END
GO

-------------------------------------------------------------------------------
-- Stored Procedure: GetLatenessGracePeriod
-- Purpose: Returns the current active grace period in minutes.
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE GetLatenessGracePeriod
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1 grace_period_mins 
    FROM LatenessPolicy lp
    JOIN PayrollPolicy pp ON lp.policy_id = pp.policy_id
    ORDER BY pp.effective_date DESC;
END
GO
