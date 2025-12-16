-- SAFE TEST DATA FOR TIME RULES & PENALTIES (MILESTONE 3 demo)
-- Run this script to populate "Today's" attendance with meaningful scenarios.
-- It avoids duplicates by checking existence first.

USE HRMS;
GO

SET NOCOUNT ON;

-- 1. Get IDs for Test Employees (Using Email Lookup for safety)
DECLARE @Emp1 INT = (SELECT TOP 1 employee_id FROM Employee WHERE email = 'omar.hussein@company.com'); -- Junior SE
DECLARE @Emp2 INT = (SELECT TOP 1 employee_id FROM Employee WHERE email = 'kareem.nasser@company.com'); -- Senior SE
DECLARE @Emp3 INT = (SELECT TOP 1 employee_id FROM Employee WHERE email = 'aly.sami@company.com'); -- QA
DECLARE @Emp4 INT = (SELECT TOP 1 employee_id FROM Employee WHERE email = 'yara.khaled@company.com'); -- Analyst

-- Fallback if specific emails not found (use any active employees)
IF @Emp1 IS NULL SET @Emp1 = (SELECT TOP 1 employee_id FROM Employee WHERE employee_id = 8);
IF @Emp2 IS NULL SET @Emp2 = (SELECT TOP 1 employee_id FROM Employee WHERE employee_id = 9);
IF @Emp3 IS NULL SET @Emp3 = (SELECT TOP 1 employee_id FROM Employee WHERE employee_id = 10);
IF @Emp4 IS NULL SET @Emp4 = (SELECT TOP 1 employee_id FROM Employee WHERE employee_id = 11);

-- 2. Get Shift ID (Morning Shift 09:00 - 17:00)
DECLARE @MorningShift INT = (SELECT TOP 1 shift_id FROM ShiftSchedule WHERE name = 'Morning');

-- 3. Define Today's Date base (09:00 AM)
DECLARE @TodayStart DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME);
-- 9:00 AM
DECLARE @ShiftStart DATETIME = DATEADD(HOUR, 9, @TodayStart);
-- 5:00 PM
DECLARE @ShiftEnd DATETIME = DATEADD(HOUR, 17, @TodayStart);

------------------------------------------------------------
-- SCENARIO A: ON TIME (Perfect Attendance)
-- Employee: Omar
-- In: 08:55, Out: 17:05
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Attendance WHERE employee_id = @Emp1 AND CAST(entry_time AS DATE) = CAST(GETDATE() AS DATE))
BEGIN
    INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method)
    VALUES (
        @Emp1, 
        @MorningShift, 
        DATEADD(MINUTE, -5, @ShiftStart), -- 08:55
        DATEADD(MINUTE, 5, @ShiftEnd),    -- 17:05
        'Device', 'Device'
    );
    PRINT 'Inserted Scenario A: On Time (Omar)';
END

------------------------------------------------------------
-- SCENARIO B: LATE BUT WITHIN GRACE (Grace = 10 mins usually)
-- Employee: Kareem
-- In: 09:08 (Late by 8 mins, Safe), Out: 17:00
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Attendance WHERE employee_id = @Emp2 AND CAST(entry_time AS DATE) = CAST(GETDATE() AS DATE))
BEGIN
    INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method)
    VALUES (
        @Emp2, 
        @MorningShift, 
        DATEADD(MINUTE, 8, @ShiftStart),  -- 09:08
        @ShiftEnd,                        -- 17:00
        'Device', 'Device'
    );
    PRINT 'Inserted Scenario B: Late in Grace (Kareem)';
END

------------------------------------------------------------
-- SCENARIO C: LATE BEYOND GRACE (Penalty Applied)
-- Employee: Aly
-- In: 09:20 (Late by 20 mins -> Full Penalty), Out: 17:00
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Attendance WHERE employee_id = @Emp3 AND CAST(entry_time AS DATE) = CAST(GETDATE() AS DATE))
BEGIN
    INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method)
    VALUES (
        @Emp3, 
        @MorningShift, 
        DATEADD(MINUTE, 20, @ShiftStart), -- 09:20
        @ShiftEnd,                        -- 17:00
        'Device', 'Device'
    );
    PRINT 'Inserted Scenario C: Late Penalty (Aly)';
END

------------------------------------------------------------
-- SCENARIO D: EARLY EXIT (Short Time)
-- Employee: Yara
-- In: 09:00, Out: 16:30 (Early by 30 mins)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Attendance WHERE employee_id = @Emp4 AND CAST(entry_time AS DATE) = CAST(GETDATE() AS DATE))
BEGIN
    INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method)
    VALUES (
        @Emp4, 
        @MorningShift, 
        @ShiftStart,                      -- 09:00
        DATEADD(MINUTE, -30, @ShiftEnd),  -- 16:30
        'Device', 'Device'
    );
    PRINT 'Inserted Scenario D: Early Exit (Yara)';
END

GO
