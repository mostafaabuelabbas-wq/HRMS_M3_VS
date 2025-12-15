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