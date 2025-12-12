
 --Employee
--1 SubmitLeaveRequest
CREATE PROCEDURE SubmitLeaveRequest
    @EmployeeID INT,
    @LeaveTypeID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Duration INT;
    DECLARE @Entitlement DECIMAL(5,2);
    DECLARE @ManagerID INT;
    DECLARE @EmployeeName VARCHAR(101);
    DECLARE @LeaveType VARCHAR(50);

    --------------------------------------------------------
    -- Validate Employee
    --------------------------------------------------------
    SELECT 
        @EmployeeName = full_name,
        @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee' AS ConfirmationMessage;
        RETURN;
    END;

    --------------------------------------------------------
    -- Validate Leave Type
    --------------------------------------------------------
    SELECT @LeaveType = leave_type
    FROM [Leave]
    WHERE leave_id = @LeaveTypeID;

    IF @LeaveType IS NULL
    BEGIN
        SELECT 'Invalid leave type' AS ConfirmationMessage;
        RETURN;
    END;

    --------------------------------------------------------
    -- Validate Date Range
    --------------------------------------------------------
    SET @Duration = DATEDIFF(DAY, @StartDate, @EndDate) + 1;

    IF @Duration <= 0
    BEGIN
        SELECT 'Invalid date range' AS ConfirmationMessage;
        RETURN;
    END;

    --------------------------------------------------------
    -- Check for overlapping leave requests
    --------------------------------------------------------
    IF EXISTS (
        SELECT 1 
        FROM LeaveRequest
        WHERE employee_id = @EmployeeID
          AND status IN ('Pending', 'Approved')
          AND (
                @StartDate BETWEEN approval_timing 
                       AND DATEADD(DAY, duration - 1, approval_timing)
                OR
                @EndDate BETWEEN approval_timing 
                       AND DATEADD(DAY, duration - 1, approval_timing)
              )
    )
    BEGIN
        SELECT 'Overlapping leave request detected' AS ConfirmationMessage;
        RETURN;
    END;

    --------------------------------------------------------
    -- Validate Entitlement
    --------------------------------------------------------
    SELECT @Entitlement = entitlement
    FROM LeaveEntitlement
    WHERE employee_id = @EmployeeID 
      AND leave_type_id = @LeaveTypeID;

    IF @Entitlement IS NULL
    BEGIN
        SELECT 'No leave entitlement found for this leave type' AS ConfirmationMessage;
        RETURN;
    END;

    IF @Duration > @Entitlement
    BEGIN
        SELECT 'Insufficient leave balance. Requested: ' 
               + CAST(@Duration AS VARCHAR(10)) 
               + ', Available: ' + CAST(@Entitlement AS VARCHAR(10)) AS ConfirmationMessage;
        RETURN;
    END;

    --------------------------------------------------------
    -- Insert Leave Request
    --------------------------------------------------------
    INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, approval_timing, status)
    VALUES (@EmployeeID, @LeaveTypeID, @Reason, @Duration, NULL, 'Pending');

    --------------------------------------------------------
    -- Notify Manager
    --------------------------------------------------------
    IF @ManagerID IS NOT NULL
    BEGIN
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Employee ' + @EmployeeName + ' (ID ' + CAST(@EmployeeID AS VARCHAR(10)) 
            + ') submitted a ' + @LeaveType + ' leave request from ' 
            + CONVERT(VARCHAR(10), @StartDate, 120) + ' to ' 
            + CONVERT(VARCHAR(10), @EndDate, 120),
            'Normal',
            0,
            'Leave Request'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@ManagerID, @NotifID, 'Sent', GETDATE());
    END;

    --------------------------------------------------------
    -- Success Message
    --------------------------------------------------------
    SELECT 'Leave request submitted successfully' AS ConfirmationMessage;
END;
GO


-- 2 GetLeaveBalance
CREATE PROCEDURE GetLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------
    -- Validate employee exists
    ----------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    ----------------------------------------------------
    -- Calculate leave balance for each leave type
    ----------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        l.leave_type,
        le.entitlement 
            - ISNULL((
                SELECT SUM(duration)
                FROM LeaveRequest lr
                WHERE lr.employee_id = @EmployeeID
                  AND lr.leave_id = le.leave_type_id
                  AND lr.status = 'Approved'
            ), 0) AS remaining_days
    FROM Employee e
    INNER JOIN LeaveEntitlement le ON e.employee_id = le.employee_id
    INNER JOIN [Leave] l ON le.leave_type_id = l.leave_id
    WHERE e.employee_id = @EmployeeID;
END;
GO

-- 3 RecordAttendance
CREATE PROCEDURE RecordAttendance
    @EmployeeID INT,
    @ShiftID INT,
    @EntryTime TIME,
    @ExitTime TIME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EntryDateTime DATETIME;
    DECLARE @ExitDateTime DATETIME;
    DECLARE @ShiftDate DATE;

    -----------------------------------------------------------
    -- Validate employee exists
    -----------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------------
    -- Validate shift exists
    -----------------------------------------------------------
    SELECT @ShiftDate = shift_date FROM ShiftSchedule WHERE shift_id = @ShiftID;

    IF @ShiftDate IS NULL
    BEGIN
        SELECT 'Invalid shift ID' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------------
    -- Validate entry & exit times
    -----------------------------------------------------------
    IF @ExitTime <= @EntryTime
    BEGIN
        SELECT 'Exit time must be after entry time' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------------
    -- Build datetime values using the shift date
    -----------------------------------------------------------
    SET @EntryDateTime = DATEADD(DAY, 0, CAST(@ShiftDate AS DATETIME)) + CAST(@EntryTime AS DATETIME);
    SET @ExitDateTime  = DATEADD(DAY, 0, CAST(@ShiftDate AS DATETIME)) + CAST(@ExitTime AS DATETIME);

    -----------------------------------------------------------
    -- Prevent duplicate attendance
    -----------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM Attendance 
        WHERE employee_id = @EmployeeID
          AND shift_id = @ShiftID
    )
    BEGIN
        SELECT 'Attendance already recorded for this shift' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------------
    -- Insert Attendance Record
    -----------------------------------------------------------
    INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method, exception_id)
    VALUES (@EmployeeID, @ShiftID, @EntryDateTime, @ExitDateTime, 'Manual', 'Manual', NULL);

    SELECT 'Attendance recorded successfully' AS ConfirmationMessage;
END;
GO

-- 4 SubmitReimbursement
CREATE PROCEDURE SubmitReimbursement
    @EmployeeID INT,
    @ExpenseType VARCHAR(50),
    @Amount DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmployeeName VARCHAR(101);
    DECLARE @ManagerID INT;

    -----------------------------------------------------------
    -- Validate employee exists
    -----------------------------------------------------------
    SELECT @EmployeeName = full_name, @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------------
    -- Validate amount
    -----------------------------------------------------------
    IF @Amount <= 0
    BEGIN
        SELECT 'Amount must be greater than zero' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------------
    -- Insert reimbursement request
    -- (Amount stored safely in claim_type string due to schema limitation)
    -----------------------------------------------------------
    INSERT INTO Reimbursement (type, claim_type, approval_date, current_status, employee_id)
    VALUES (
        @ExpenseType,
        'Amount: ' + CAST(@Amount AS VARCHAR(20)),
        NULL,
        'Pending',
        @EmployeeID
    );

    -----------------------------------------------------------
    -- Notify Manager if available
    -----------------------------------------------------------
    IF @ManagerID IS NOT NULL
    BEGIN
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'New reimbursement submitted by ' + @EmployeeName 
            + ' (ID ' + CAST(@EmployeeID AS VARCHAR(10)) + ') for '
            + @ExpenseType + ' with amount ' + CAST(@Amount AS VARCHAR(20)),
            'Normal',
            0,
            'Reimbursement Request'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@ManagerID, @NotifID, 'Sent', GETDATE());
    END;

    -----------------------------------------------------------
    SELECT 'Reimbursement request submitted successfully' AS ConfirmationMessage;
END;
GO

--5 AddEmployeeSkill
CREATE PROCEDURE AddEmployeeSkill
    @EmployeeID INT,
    @SkillName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SkillID INT;

    ----------------------------------------------------------
    -- Validate Employee
    ----------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    ----------------------------------------------------------
    -- Find or Create Skill
    ----------------------------------------------------------
    SELECT @SkillID = skill_id 
    FROM Skill 
    WHERE LOWER(skill_name) = LOWER(@SkillName);

    IF @SkillID IS NULL
    BEGIN
        INSERT INTO Skill (skill_name, description)
        VALUES (@SkillName, @SkillName + ' skill');

        SET @SkillID = SCOPE_IDENTITY();
    END;

    ----------------------------------------------------------
    -- Check if employee already has the skill
    ----------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM Employee_Skill
        WHERE employee_id = @EmployeeID
          AND skill_id = @SkillID
    )
    BEGIN
        SELECT 'Skill already assigned to employee.' AS ConfirmationMessage;
        RETURN;
    END;

    ----------------------------------------------------------
    -- Insert skill for employee
    ----------------------------------------------------------
    INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
    VALUES (@EmployeeID, @SkillID, 'Beginner');

    SELECT 'Skill added successfully.' AS ConfirmationMessage;
END;
GO


--6 ViewAssignedShifts
CREATE PROCEDURE ViewAssignedShifts
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------
    -- Validate Employee
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    ------------------------------------------------------
    -- Get Assigned Shifts
    ------------------------------------------------------
    SELECT 
        sa.assignment_id,
        sa.start_date,
        sa.end_date,
        sa.status AS assignment_status,
        ss.shift_id,
        ss.name AS shift_name,
        ss.type AS shift_type,
        ss.start_time,
        ss.end_time,
        ss.break_duration,
        ss.shift_date,
        ss.status AS shift_status
    FROM ShiftAssignment sa
    INNER JOIN ShiftSchedule ss ON sa.shift_id = ss.shift_id
    WHERE sa.employee_id = @EmployeeID
    ORDER BY sa.start_date DESC, ss.start_time;
END;
GO

--7 ViewMyContracts
CREATE PROCEDURE ViewMyContracts
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Retrieve ALL contracts for this employee
    -------------------------------------------------------
    SELECT 
        c.contract_id,
        c.type AS contract_type,
        c.start_date,
        c.end_date,
        c.current_state,

        -- Full-time details
        ftc.leave_entitlement,
        ftc.insurance_eligibility,
        ftc.weekly_working_hours,

        -- Part-time details
        ptc.working_hours AS part_time_hours,
        ptc.hourly_rate,

        -- Consultant details
        cc.project_scope,
        cc.fees,
        cc.payment_schedule,

        -- Internship details
        ic.mentoring,
        ic.evaluation,
        ic.stipend_related
    FROM Contract c
    INNER JOIN Employee e ON e.contract_id = c.contract_id
    LEFT JOIN FullTimeContract ftc ON c.contract_id = ftc.contract_id
    LEFT JOIN PartTimeContract ptc ON c.contract_id = ptc.contract_id
    LEFT JOIN ConsultantContract cc ON c.contract_id = cc.contract_id
    LEFT JOIN InternshipContract ic ON c.contract_id = ic.contract_id
    WHERE e.employee_id = @EmployeeID
    ORDER BY c.start_date DESC;
END;
GO



-- 8. ViewMyPayroll
CREATE PROCEDURE ViewMyPayroll
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Return payroll history
    -------------------------------------------------------
    SELECT 
        payroll_id,
        taxes,
        period_start,
        period_end,
        base_amount,
        adjustments,
        contributions,
        actual_pay,
        net_salary,
        payment_date
    FROM Payroll
    WHERE employee_id = @EmployeeID
    ORDER BY period_end DESC;
END;
GO


-- 9. UpdatePersonalDetails
CREATE PROCEDURE UpdatePersonalDetails
    @EmployeeID INT,
    @Phone VARCHAR(20),
    @Address VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    -------------------------------------------------------
    -- Update fields
    -------------------------------------------------------
    UPDATE Employee
    SET 
        phone = @Phone,
        address = @Address
    WHERE employee_id = @EmployeeID;

    SELECT 'Personal details updated successfully' AS ConfirmationMessage;
END;
GO



-- 10. ViewMyMissions
CREATE PROCEDURE ViewMyMissions
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Return mission list
    -------------------------------------------------------
    SELECT 
        m.mission_id,
        m.destination,
        m.start_date,
        m.end_date,
        m.status,
        mgr.full_name AS manager_name
    FROM Mission m
    LEFT JOIN Employee mgr ON m.manager_id = mgr.employee_id
    WHERE m.employee_id = @EmployeeID
    ORDER BY m.start_date DESC;
END;
GO


-- 11. ViewEmployeeProfile
CREATE PROCEDURE ViewEmployeeProfile
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Return full employee profile
    -------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.address,
        e.date_of_birth,
        e.country_of_birth,
        e.hire_date,
        e.employment_status,
        e.account_status,
        e.profile_completion,

        d.department_name,
        p.position_title,

        c.type AS contract_type,
        c.start_date AS contract_start_date,
        c.end_date AS contract_end_date,
        c.current_state AS contract_state,

        st.type AS salary_type
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Contract c ON e.contract_id = c.contract_id
    LEFT JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    WHERE e.employee_id = @EmployeeID;
END;
GO


-- 12. UpdateContactInformation
CREATE PROCEDURE UpdateContactInformation
    @EmployeeID INT,
    @RequestType VARCHAR(50),
    @NewValue VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    -------------------------------------------------------
    -- Normalize request type
    -------------------------------------------------------
    SET @RequestType = LOWER(@RequestType);

    -------------------------------------------------------
    -- Validate request type
    -------------------------------------------------------
    IF @RequestType NOT IN ('phone', 'address')
    BEGIN
        SELECT 'Invalid request type. Allowed: Phone or Address.' AS ConfirmationMessage;
        RETURN;
    END;

    -------------------------------------------------------
    -- Apply update
    -------------------------------------------------------
    UPDATE Employee
    SET 
        phone   = CASE WHEN @RequestType = 'phone' THEN @NewValue ELSE phone END,
        address = CASE WHEN @RequestType = 'address' THEN @NewValue ELSE address END
    WHERE employee_id = @EmployeeID;

    -------------------------------------------------------
    SELECT 'Contact information updated successfully' AS ConfirmationMessage;
END;
GO



-- 13. ViewEmploymentTimeline
CREATE PROCEDURE ViewEmploymentTimeline
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Return available timeline info
    -- (Schema does NOT track past promotions/transfers,
    -- so timeline = current state + hire date + contract info.)
    -------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        e.hire_date AS hire_date,
        d.department_name AS current_department,
        p.position_title AS current_position,
        e.employment_status,
        c.start_date AS contract_start_date,
        c.end_date AS contract_end_date,
        c.type AS contract_type,
        c.current_state AS contract_state
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Contract c ON e.contract_id = c.contract_id
    WHERE e.employee_id = @EmployeeID;
END;
GO


-- 14. UpdateEmergencyContact
CREATE PROCEDURE UpdateEmergencyContact
    @EmployeeID INT,
    @ContactName VARCHAR(100),
    @Relation VARCHAR(50),
    @Phone VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate contact fields
    -------------------------------------------------------
    IF (@ContactName IS NULL OR LTRIM(RTRIM(@ContactName)) = '')
    BEGIN
        SELECT 'Contact name cannot be empty' AS ConfirmationMessage;
        RETURN;
    END;

    IF (@Relation IS NULL OR LTRIM(RTRIM(@Relation)) = '')
    BEGIN
        SELECT 'Relation cannot be empty' AS ConfirmationMessage;
        RETURN;
    END;

    IF (@Phone IS NULL OR LTRIM(RTRIM(@Phone)) = '')
    BEGIN
        SELECT 'Phone number cannot be empty' AS ConfirmationMessage;
        RETURN;
    END;

    -------------------------------------------------------
    -- Update emergency contact
    -------------------------------------------------------
    UPDATE Employee
    SET 
        emergency_contact_name  = @ContactName,
        relationship            = @Relation,
        emergency_contact_phone = @Phone
    WHERE employee_id = @EmployeeID;

    SELECT 'Emergency contact updated successfully' AS ConfirmationMessage;
END;
GO


-- 15. RequestHRDocument
CREATE PROCEDURE RequestHRDocument
    @EmployeeID INT,
    @DocumentType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmployeeName VARCHAR(150);

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    SELECT @EmployeeName = full_name
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee ID' AS ConfirmationMessage;
        RETURN;
    END;

    -------------------------------------------------------
    -- Create notification for HR
    -------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'HR document request from ' + @EmployeeName 
        + ' (Employee ID: ' + CAST(@EmployeeID AS VARCHAR(10)) 
        + ') for document type: ' + @DocumentType,
        'Medium',
        0,
        'HRDocument'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    -------------------------------------------------------
    -- Assign notification to HR Administrator(s)
    -------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    SELECT employee_id, @NotifID, 'Sent', GETDATE()
    FROM HRAdministrator;

    -------------------------------------------------------
    SELECT 'HR document request submitted successfully' AS ConfirmationMessage;
END;
GO



-- 16. NotifyProfileUpdate
CREATE PROCEDURE NotifyProfileUpdate
    @EmployeeID INT,
    @notificationType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmployeeName VARCHAR(150);

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    SELECT @EmployeeName = full_name
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Insert notification
    -------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'Profile update: ' + @notificationType + 
        ' for employee ' + @EmployeeName + 
        ' (ID ' + CAST(@EmployeeID AS VARCHAR(10)) + ')',
        'Normal',
        0,
        'ProfileUpdate'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    -------------------------------------------------------
    -- Link notification to employee
    -------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@EmployeeID, @NotifID, 'Sent', GETDATE());

    -------------------------------------------------------
    SELECT 'Notification sent successfully' AS Message;
END;
GO

-- 17. LogFlexibleAttendance
CREATE PROCEDURE LogFlexibleAttendance
    @EmployeeID INT,
    @Date DATE,
    @CheckIn TIME,
    @CheckOut TIME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EntryDT DATETIME;
    DECLARE @ExitDT DATETIME;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate check-in/out times
    -------------------------------------------------------
    IF (@CheckOut <= @CheckIn)
    BEGIN
        SELECT 'Check-out time must be after check-in time.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Build proper DATETIME values
    -------------------------------------------------------
    SET @EntryDT = DATEADD(SECOND, DATEPART(SECOND, @CheckIn),
                 DATEADD(MINUTE, DATEPART(MINUTE, @CheckIn),
                 DATEADD(HOUR,   DATEPART(HOUR,   @CheckIn),
                 CAST(@Date AS DATETIME))));

    SET @ExitDT  = DATEADD(SECOND, DATEPART(SECOND, @CheckOut),
                 DATEADD(MINUTE, DATEPART(MINUTE, @CheckOut),
                 DATEADD(HOUR,   DATEPART(HOUR,   @CheckOut),
                 CAST(@Date AS DATETIME))));

    -------------------------------------------------------
    -- Prevent duplicate attendance for same employee/date
    -------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM Attendance
        WHERE employee_id = @EmployeeID
          AND CAST(entry_time AS DATE) = @Date
    )
    BEGIN
        SELECT 'Attendance already logged for this date.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Insert flexible attendance
    -------------------------------------------------------
    INSERT INTO Attendance (employee_id, entry_time, exit_time, login_method, logout_method)
    VALUES (@EmployeeID, @EntryDT, @ExitDT, 'Flexible', 'Flexible');

    -------------------------------------------------------
    -- Return calculated total hours
    -------------------------------------------------------
    SELECT 
        'Attendance logged successfully' AS Message,
        DATEDIFF(MINUTE, @EntryDT, @ExitDT) / 60.0 AS TotalHours;
END;
GO

 --18. NotifyMissedPunch
CREATE PROCEDURE NotifyMissedPunch
    @EmployeeID INT,
    @Date DATE
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Insert notification (correct schema)
    -------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'You have a missed punch on ' + CONVERT(VARCHAR(10), @Date, 120) 
            + '. Please submit an attendance correction request.',
        'High',
        0,
        'MissedPunch'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    -------------------------------------------------------
    -- Link notification to employee
    -------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@EmployeeID, @NotifID, 'Sent', GETDATE());

    SELECT 'Notification sent for missed punch on ' + CONVERT(VARCHAR(10), @Date, 120) AS Message;
END;
GO


-- 19. RecordMultiplePunches
CREATE PROCEDURE RecordMultiplePunches
    @EmployeeID INT,
    @ClockInOutTime DATETIME,
    @Type VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate punch type
    -------------------------------------------------------
    IF @Type NOT IN ('ClockIn', 'ClockOut')
    BEGIN
        SELECT 'Invalid punch type. Use ClockIn or ClockOut.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Handle ClockOut (close the most recent open session)
    -------------------------------------------------------
    IF @Type = 'ClockOut'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM Attendance
            WHERE employee_id = @EmployeeID
              AND exit_time IS NULL
              AND CAST(entry_time AS DATE) = CAST(@ClockInOutTime AS DATE)
        )
        BEGIN
            UPDATE Attendance
            SET exit_time = @ClockInOutTime,
                logout_method = 'ClockOut'
            WHERE attendance_id = (
                SELECT TOP 1 attendance_id
                FROM Attendance
                WHERE employee_id = @EmployeeID
                  AND exit_time IS NULL
                ORDER BY entry_time DESC
            );

            INSERT INTO AttendanceLog (attendance_id, actor, reason)
            SELECT TOP 1 attendance_id, @EmployeeID, 'ClockOut punch'
            FROM Attendance
            WHERE employee_id = @EmployeeID
            ORDER BY attendance_id DESC;

            SELECT 'Clock-out recorded successfully.' AS Message;
            RETURN;
        END;

        SELECT 'No open session to clock out from.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Handle ClockIn (create a new attendance session)
    -------------------------------------------------------
    IF @Type = 'ClockIn'
    BEGIN
        -- Prevent two open sessions at once
        IF EXISTS (
            SELECT 1 FROM Attendance
            WHERE employee_id = @EmployeeID
              AND exit_time IS NULL
        )
        BEGIN
            SELECT 'Cannot clock in: previous session still open.' AS Message;
            RETURN;
        END;

        INSERT INTO Attendance (employee_id, entry_time, login_method)
        VALUES (@EmployeeID, @ClockInOutTime, 'ClockIn');

        DECLARE @NewID INT = SCOPE_IDENTITY();

        INSERT INTO AttendanceLog (attendance_id, actor, reason)
        VALUES (@NewID, @EmployeeID, 'ClockIn punch');

        SELECT 'Clock-in recorded successfully.' AS Message;
        RETURN;
    END;
END;
GO


-- 20. SubmitCorrectionRequest
CREATE PROCEDURE SubmitCorrectionRequest
    @EmployeeID INT,
    @Date DATE,
    @CorrectionType VARCHAR(50),
    @Reason VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ManagerID INT;

    -------------------------------------------------------
    -- Validate employee
    -------------------------------------------------------
    SELECT @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @ManagerID IS NULL
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Insert correction request
    -------------------------------------------------------
    INSERT INTO AttendanceCorrectionRequest
        (employee_id, date, correction_type, reason, status)
    VALUES
        (@EmployeeID, @Date, @CorrectionType, @Reason, 'Pending');

    DECLARE @RequestID INT = SCOPE_IDENTITY();

    -------------------------------------------------------
    -- Notify manager
    -------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'Correction request submitted (ID: ' + CAST(@RequestID AS VARCHAR(10)) +
        ') by Employee ID ' + CAST(@EmployeeID AS VARCHAR(10)),
        'Normal',
        0,
        'CorrectionRequest'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@ManagerID, @NotifID, 'Sent', GETDATE());

    SELECT 'Correction request submitted successfully.' AS Message;
END;
GO


-- 21. ViewRequestStatus
CREATE PROCEDURE ViewRequestStatus
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Return all request statuses
    -------------------------------------------------------
    SELECT 
        request_id,
        date,
        correction_type,
        reason,
        status,
        recorded_by
    FROM AttendanceCorrectionRequest
    WHERE employee_id = @EmployeeID
    ORDER BY request_id DESC;
END;
GO

-- 23. AttachLeaveDocuments
CREATE PROCEDURE AttachLeaveDocuments
    @LeaveRequestID INT,
    @FilePath VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate request exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
    BEGIN
        SELECT 'Invalid leave request ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate file path
    -------------------------------------------------------
    IF @FilePath IS NULL OR LTRIM(RTRIM(@FilePath)) = ''
    BEGIN
        SELECT 'File path cannot be empty' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Insert document record
    -------------------------------------------------------
    INSERT INTO LeaveDocument (leave_request_id, file_path, uploaded_at)
    VALUES (@LeaveRequestID, @FilePath, GETDATE());

    SELECT 'Document attached successfully' AS Message;
END;
GO


-- 24. ModifyLeaveRequest
CREATE PROCEDURE ModifyLeaveRequest
    @LeaveRequestID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Status VARCHAR(20);

    -------------------------------------------------------
    -- Validate request exists
    -------------------------------------------------------
    SELECT @Status = status
    FROM LeaveRequest 
    WHERE request_id = @LeaveRequestID;

    IF @Status IS NULL
    BEGIN
        SELECT 'Invalid leave request ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Only pending requests may be modified
    -------------------------------------------------------
    IF @Status <> 'Pending'
    BEGIN
        SELECT 'Only pending leave requests can be modified.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate date range
    -------------------------------------------------------
    IF @EndDate < @StartDate
    BEGIN
        SELECT 'End date must be after start date.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Update request
    -------------------------------------------------------
    UPDATE LeaveRequest
    SET justification = @Reason,
        duration = DATEDIFF(DAY, @StartDate, @EndDate) + 1
    WHERE request_id = @LeaveRequestID;

    SELECT 'Leave request updated successfully.' AS Message;
END;
GO


-- 25. CancelLeaveRequest
CREATE PROCEDURE CancelLeaveRequest
    @LeaveRequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Status VARCHAR(20);
    DECLARE @EmployeeID INT;
    DECLARE @ManagerID INT;

    -------------------------------------------------------
    -- Validate request exists
    -------------------------------------------------------
    SELECT @Status = status,
           @EmployeeID = employee_id
    FROM LeaveRequest
    WHERE request_id = @LeaveRequestID;

    IF @Status IS NULL
    BEGIN
        SELECT 'Invalid leave request ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Only pending requests may be canceled
    -------------------------------------------------------
    IF @Status <> 'Pending'
    BEGIN
        SELECT 'Only pending leave requests can be cancelled.' AS Message;
        RETURN;
    END;

    SELECT @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    -------------------------------------------------------
    -- Cancel the request
    -------------------------------------------------------
    UPDATE LeaveRequest
    SET status = 'Cancelled'
    WHERE request_id = @LeaveRequestID;

    -------------------------------------------------------
    -- Notify manager
    -------------------------------------------------------
    IF @ManagerID IS NOT NULL
    BEGIN
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Leave request ID ' + CAST(@LeaveRequestID AS VARCHAR(10)) + ' has been cancelled.',
            'Normal',
            0,
            'LeaveCancellation'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@ManagerID, @NotifID, 'Sent', GETDATE());
    END;

    SELECT 'Leave request cancelled successfully.' AS Message;
END;
GO


-- 26. ViewLeaveBalance
CREATE PROCEDURE ViewLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate Employee
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid Employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Return remaining balance by leave type
    -------------------------------------------------------
    SELECT 
        l.leave_type,
        le.entitlement 
            - ISNULL((
                SELECT SUM(duration)
                FROM LeaveRequest lr
                WHERE lr.employee_id = @EmployeeID
                  AND lr.leave_id = le.leave_type_id
                  AND lr.status = 'Approved'
            ), 0) AS remaining_days,
        le.entitlement AS total_entitlement
    FROM LeaveEntitlement le
    JOIN [Leave] l ON le.leave_type_id = l.leave_id
    WHERE le.employee_id = @EmployeeID;
END;
GO

-- 27. ViewLeaveHistory
CREATE PROCEDURE ViewLeaveHistory
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate employee
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Invalid employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Show sorted history
    -------------------------------------------------------
    SELECT 
        lr.request_id,
        l.leave_type,
        lr.justification,
        lr.duration,
        lr.approval_timing,
        lr.status
    FROM LeaveRequest lr
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    WHERE lr.employee_id = @EmployeeID
    ORDER BY lr.request_id DESC;
END;
GO

--28. SubmitLeaveAfterAbsence
CREATE PROCEDURE SubmitLeaveAfterAbsence
    @EmployeeID INT,
    @LeaveTypeID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmployeeName VARCHAR(100), @ManagerID INT;
    DECLARE @Duration INT;

    -------------------------------------------------------
    -- Validate employee
    -------------------------------------------------------
    SELECT @EmployeeName = full_name, @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee ID' AS Message; 
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate leave type
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM [Leave] WHERE leave_id = @LeaveTypeID)
    BEGIN
        SELECT 'Invalid leave type ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate dates
    -------------------------------------------------------
    IF @EndDate < @StartDate
    BEGIN
        SELECT 'End date must be after start date' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Ensure date is in the PAST (because this is AFTER absence)
    -------------------------------------------------------
    IF @StartDate > GETDATE()
    BEGIN
        SELECT 'This type of leave request is only allowed for past dates.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Calculate duration
    -------------------------------------------------------
    SET @Duration = DATEDIFF(DAY, @StartDate, @EndDate) + 1;

    -------------------------------------------------------
    -- Insert leave request
    -------------------------------------------------------
    INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, approval_timing, status)
    VALUES (@EmployeeID, @LeaveTypeID, @Reason, @Duration, NULL, 'Pending');

    -------------------------------------------------------
    -- Notify manager
    -------------------------------------------------------
    IF @ManagerID IS NOT NULL
    BEGIN
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'After-absence leave submitted by ' + @EmployeeName 
            + ' for dates ' + CONVERT(VARCHAR(10), @StartDate, 120)
            + ' to ' + CONVERT(VARCHAR(10), @EndDate, 120),
            'Normal',
            0,
            'LeaveAfterAbsence'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@ManagerID, @NotifID, 'Sent', GETDATE());
    END;

    SELECT 'Leave after absence submitted successfully.' AS Message;
END;
GO


--29. NotifyLeaveStatusChange
CREATE PROCEDURE NotifyLeaveStatusChange
    @EmployeeID INT,
    @RequestID INT,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ValidEmployee INT;
    DECLARE @ValidRequest INT;

    -------------------------------------------------------
    -- Validate employee exists
    -------------------------------------------------------
    SELECT @ValidEmployee = employee_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    IF @ValidEmployee IS NULL
    BEGIN
        SELECT 'Invalid Employee ID' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate request exists and belongs to employee
    -------------------------------------------------------
    SELECT @ValidRequest = request_id
    FROM LeaveRequest
    WHERE request_id = @RequestID
      AND employee_id = @EmployeeID;

    IF @ValidRequest IS NULL
    BEGIN
        SELECT 'Invalid Request ID for this employee' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Validate status change type
    -------------------------------------------------------
    IF @Status NOT IN ('Approved', 'Rejected', 'Returned', 'Modified')
    BEGIN
        SELECT 'Invalid status type' AS Message;
        RETURN;
    END;

    -------------------------------------------------------
    -- Insert notification entry
    -------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'Your leave request #' + CAST(@RequestID AS VARCHAR(10)) + ' has been ' + @Status,
        'Medium',
        0,
        'LeaveStatus'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    -------------------------------------------------------
    -- Assign notification to employee
    -------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@EmployeeID, @NotifID, 'Sent', GETDATE());

    -------------------------------------------------------
    -- Confirmation
    -------------------------------------------------------
    SELECT 'Leave status notification sent successfully.' AS Message;
END;
GO



-- GetAllContracts: returns all contracts with employee info + subtype details where available

CREATE PROCEDURE GetAllContracts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.contract_id AS ContractId,
        e.employee_id AS EmployeeId,
        e.full_name AS FullName,

        c.type,
        c.start_date AS StartDate,
        c.end_date AS EndDate,
        c.current_state AS CurrentState,

        -- DAYS REMAINING
        DATEDIFF(DAY, GETDATE(), c.end_date) AS DaysRemaining,

        -- CONTRACT STATUS
        CASE 
            WHEN c.end_date < GETDATE() THEN 'Expired'
            WHEN DATEDIFF(DAY, GETDATE(), c.end_date) <= 30 THEN 'Expiring Soon'
            ELSE 'Active'
        END AS ContractStatus

    FROM Contract c
    INNER JOIN Employee e ON e.contract_id = c.contract_id
    ORDER BY c.end_date ASC;
END;

GO

GO
-- GetEmployeeContracts: all contracts for a given employee (history)
CREATE PROCEDURE GetEmployeeContracts
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.contract_id,
        c.type,
        c.start_date,
        c.end_date,
        c.current_state,
        -- subtype fields
        ft.leave_entitlement AS ft_leave_entitlement,
        ft.insurance_eligibility AS ft_insurance_eligibility,
        ft.weekly_working_hours AS ft_weekly_hours,
        pt.working_hours AS pt_working_hours,
        pt.hourly_rate AS pt_hourly_rate,
        con.project_scope AS consultant_project_scope,
        con.fees AS consultant_fees,
        con.payment_schedule AS consultant_payment_schedule,
        it.mentoring AS internship_mentoring,
        it.evaluation AS internship_evaluation,
        it.stipend_related AS internship_stipend
    FROM Contract c
    INNER JOIN Employee e ON e.contract_id = c.contract_id OR e.employee_id = @EmployeeID
    LEFT JOIN FullTimeContract ft ON ft.contract_id = c.contract_id
    LEFT JOIN PartTimeContract pt ON pt.contract_id = c.contract_id
    LEFT JOIN ConsultantContract con ON con.contract_id = c.contract_id
    LEFT JOIN InternshipContract it ON it.contract_id = c.contract_id
    WHERE e.employee_id = @EmployeeID
    ORDER BY c.start_date DESC;
END;
GO

-- GetContractDetails: full details for a single contract (admin/details page)
CREATE PROCEDURE GetContractDetails
    @ContractID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.contract_id,
        c.type,
        c.start_date,
        c.end_date,
        c.current_state,
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.position_id,
        p.position_title,
        e.department_id,
        d.department_name,
        ft.leave_entitlement AS ft_leave_entitlement,
        ft.insurance_eligibility AS ft_insurance_eligibility,
        ft.weekly_working_hours AS ft_weekly_hours,
        pt.working_hours AS pt_working_hours,
        pt.hourly_rate AS pt_hourly_rate,
        con.project_scope AS consultant_project_scope,
        con.fees AS consultant_fees,
        con.payment_schedule AS consultant_payment_schedule,
        it.mentoring AS internship_mentoring,
        it.evaluation AS internship_evaluation,
        it.stipend_related AS internship_stipend
    FROM Contract c
    LEFT JOIN Employee e ON e.contract_id = c.contract_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN FullTimeContract ft ON ft.contract_id = c.contract_id
    LEFT JOIN PartTimeContract pt ON pt.contract_id = c.contract_id
    LEFT JOIN ConsultantContract con ON con.contract_id = c.contract_id
    LEFT JOIN InternshipContract it ON it.contract_id = c.contract_id
    WHERE c.contract_id = @ContractID;
END;
GO

-- UpdateContract: update core contract fields (HR Admin)
CREATE PROCEDURE UpdateContract
    @ContractID INT,
    @Type VARCHAR(50),
    @StartDate DATE,
    @EndDate DATE,
    @CurrentState VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Contract WHERE contract_id = @ContractID)
    BEGIN
        SELECT 'Contract not found' AS Message;
        RETURN;
    END;

    UPDATE Contract
    SET
        type = @Type,
        start_date = @StartDate,
        end_date = @EndDate,
        current_state = @CurrentState
    WHERE contract_id = @ContractID;

    SELECT 'Updated' AS Message;
END;
GO
