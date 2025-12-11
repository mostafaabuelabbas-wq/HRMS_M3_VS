--Line Manager

-- 1. ReviewLeaveRequest
CREATE PROCEDURE ReviewLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT,
    @Decision VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- Validate Leave Request Exists
        ---------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- Validate Manager Exists
        ---------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- Update Leave Request Status + Timestamp
        ---------------------------------------------------------
        UPDATE LeaveRequest
        SET status = @Decision,
            approval_timing = GETDATE()
        WHERE request_id = @LeaveRequestID;

        ---------------------------------------------------------
        -- REQUIRED OUTPUT (EXACT FORMAT)
        ---------------------------------------------------------
        SELECT 
            @LeaveRequestID AS LeaveRequestID,
            @ManagerID AS ManagerID,
            @Decision AS Decision;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 2. AssignShift

-- PROCEDURE: AssignShift
CREATE PROCEDURE AssignShift
    @EmployeeID INT,
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -----------------------------------------------------
        -- Validate employee exists
        -----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------
        -- Validate shift exists
        -----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftSchedule WHERE shift_id = @ShiftID)
        BEGIN
            RAISERROR('Shift ID does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------
        -- Insert new active shift assignment
        -- Schema requires: employee_id, shift_id, start_date, end_date, status
        -----------------------------------------------------
        INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
        VALUES (
            @EmployeeID,
            @ShiftID,
            GETDATE(),         -- Start now
            NULL,              -- No end date specified in user story
            'Active'
        );

        COMMIT TRANSACTION;

        SELECT 'Shift assigned successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 3. ViewTeamAttendance
-- ViewTeamAttendance
-- PROCEDURE: ViewTeamAttendance
CREATE PROCEDURE ViewTeamAttendance
    @ManagerID INT,
    @DateRangeStart DATE,
    @DateRangeEnd DATE
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------------------
    -- Validate manager exists
    -----------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    -----------------------------------------------------
    -- Validate date range
    -----------------------------------------------------
    IF @DateRangeEnd < @DateRangeStart
    BEGIN
        RAISERROR('End date must be greater than or equal to start date.', 16, 1);
        RETURN;
    END;

    -----------------------------------------------------
    -- Return attendance for all employees managed by manager_id
    -----------------------------------------------------
    SELECT 
        a.attendance_id,
        a.employee_id,
        e.full_name,
        a.shift_id,
        a.entry_time,
        a.exit_time,
        a.duration,
        a.login_method,
        a.logout_method,
        a.exception_id
    FROM Attendance a
    INNER JOIN Employee e ON a.employee_id = e.employee_id
    WHERE e.manager_id = @ManagerID
      AND a.entry_time >= @DateRangeStart
      AND a.entry_time < DATEADD(DAY, 1, @DateRangeEnd)   -- include entire last day
    ORDER BY a.entry_time;
END;
GO



-- 4. SendTeamNotification
-- SendTeamNotification
-- PROCEDURE: SendTeamNotification
CREATE PROCEDURE SendTeamNotification
    @ManagerID INT,
    @MessageContent VARCHAR(255),
    @UrgencyLevel VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- Validate manager exists
        ---------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- Validate team exists
        ---------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE manager_id = @ManagerID)
        BEGIN
            RAISERROR('Manager has no team members.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- Create notification (MUST include read_status)
        ---------------------------------------------------------
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            @MessageContent,
            @UrgencyLevel,
            0,                      -- unread
            'Team Notification'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        ---------------------------------------------------------
        -- Insert one row per team member
        ---------------------------------------------------------
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        SELECT 
            employee_id,
            @NotifID,
            'Pending',
            GETDATE()
        FROM Employee
        WHERE manager_id = @ManagerID;

        ---------------------------------------------------------
        -- Return confirmation
        ---------------------------------------------------------
        SELECT 'Team notification sent successfully' AS ConfirmationMessage;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 5. ApproveMissionCompletion

-- PROCEDURE: ApproveMissionCompletion
CREATE PROCEDURE ApproveMissionCompletion
    @MissionID INT,
    @ManagerID INT,
    @Remarks VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- Validate mission exists and is owned by this manager
        ---------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 
            FROM Mission 
            WHERE mission_id = @MissionID 
              AND manager_id = @ManagerID
        )
        BEGIN
            RAISERROR('Mission not found or manager not authorized.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- Update mission status
        ---------------------------------------------------------
        UPDATE Mission
        SET status = 'Completed'
        WHERE mission_id = @MissionID;

        ---------------------------------------------------------
        -- Optional: Log remarks (if Remarks table existed, but it does not)
        -- For now, remarks are returned only in output, per MS2 requirement.
        ---------------------------------------------------------

        COMMIT TRANSACTION;

        ---------------------------------------------------------
        -- OUTPUT (exactly as MIL2 requires)
        ---------------------------------------------------------
        SELECT 
            'Mission completed successfully' AS ConfirmationMessage,
            @Remarks AS Remarks;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 6. RequestReplacement

-- PROCEDURE: RequestReplacement
CREATE PROCEDURE RequestReplacement
    @EmployeeID INT,
    @Reason VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        --------------------------------------------------------
        -- Validate employee exists
        --------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        --------------------------------------------------------
        -- Create notification (must include read_status)
        --------------------------------------------------------
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Replacement needed for Employee ID: ' + CAST(@EmployeeID AS VARCHAR(10))
            + '. Reason: ' + @Reason,
            'High',
            0,                 -- unread
            'Replacement Request'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        --------------------------------------------------------
        -- Send notification to all HR Administrators
        --------------------------------------------------------
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        SELECT 
            employee_id,
            @NotifID,
            'Pending',
            GETDATE()
        FROM HRAdministrator;  -- All HR admins receive the alert

        --------------------------------------------------------
        -- MS2 required output
        --------------------------------------------------------
        SELECT 
            'Replacement request submitted successfully' AS ConfirmationMessage,
            @Reason AS Reason;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 7. ViewDepartmentSummary

-- PROCEDURE: ViewDepartmentSummary
CREATE PROCEDURE ViewDepartmentSummary
    @DepartmentID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate department exists
    IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @DepartmentID)
    BEGIN
        RAISERROR('Department does not exist.', 16, 1);
        RETURN;
    END;

    SELECT 
        @DepartmentID AS DepartmentID,
        COUNT(DISTINCT e.employee_id) AS EmployeeCount,
        COUNT(DISTINCT m.mission_id) AS ActiveProjects
    FROM Department d
    LEFT JOIN Employee e 
        ON d.department_id = e.department_id
    LEFT JOIN Mission m 
        ON e.employee_id = m.employee_id
       AND LTRIM(RTRIM(LOWER(m.status))) IN ('planned')   -- THIS IS THE FIX
    WHERE d.department_id = @DepartmentID;
END;
GO

GO
-- 8. ReassignShift
-- ReassignShift
-- PROCEDURE: ReassignShift
CREATE PROCEDURE ReassignShift
    @EmployeeID INT,
    @OldShiftID INT,
    @NewShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- Validate employee exists
        -------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- Validate the old shift assignment exists and is active
        -------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM ShiftAssignment
            WHERE employee_id = @EmployeeID
              AND shift_id = @OldShiftID
              AND status = 'Active'
        )
        BEGIN
            RAISERROR('Old shift assignment does not exist or is not active.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- Validate new shift exists in ShiftSchedule
        -------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftSchedule WHERE shift_id = @NewShiftID)
        BEGIN
            RAISERROR('New shift does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- Update (reassign) the shift
        -------------------------------------------------------
        UPDATE ShiftAssignment
        SET shift_id = @NewShiftID
        WHERE employee_id = @EmployeeID
          AND shift_id = @OldShiftID
          AND status = 'Active';

        -------------------------------------------------------
        -- Success output
        -------------------------------------------------------
        SELECT 
            'Shift reassigned successfully' AS ConfirmationMessage,
            @EmployeeID AS EmployeeID,
            @OldShiftID AS OldShiftID,
            @NewShiftID AS NewShiftID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 9. GetPendingLeaveRequests-- GetPendingLeaveRequests
-- PROCEDURE: GetPendingLeaveRequests
CREATE PROCEDURE GetPendingLeaveRequests
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------
    -- Validate manager exists
    ----------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    ----------------------------------------------------
    -- Retrieve pending leave requests
    ----------------------------------------------------
    SELECT 
        lr.request_id,
        lr.employee_id,
        e.full_name AS EmployeeName,
        lr.leave_id,
        l.leave_type AS LeaveType,
        lr.justification,
        lr.duration,
        lr.approval_timing,
        lr.status
    FROM LeaveRequest lr
    INNER JOIN Employee e ON lr.employee_id = e.employee_id
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    WHERE e.manager_id = @ManagerID
      AND lr.status = 'Pending'
    ORDER BY lr.request_id;
END;
GO

-- 10. GetTeamStatistics
-- GetTeamStatistics
-- PROCEDURE: GetTeamStatistics
CREATE PROCEDURE GetTeamStatistics
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate manager exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    -------------------------------------------------------
    -- Retrieve team-level statistics
    -------------------------------------------------------
    SELECT 
        COUNT(e.employee_id) AS TeamSize,
        (
            SELECT AVG(p2.base_amount)
            FROM Payroll p2
            WHERE p2.employee_id IN (
                SELECT employee_id FROM Employee WHERE manager_id = @ManagerID
            )
        ) AS AverageSalary,
        COUNT(e.employee_id) AS SpanOfControl,  -- same as TeamSize
        @ManagerID AS ManagerID
    FROM Employee e
    WHERE e.manager_id = @ManagerID;
END;
GO


-- 11. ViewTeamProfiles
-- ViewTeamProfiles
-- PROCEDURE: ViewTeamProfiles
CREATE PROCEDURE ViewTeamProfiles
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate manager exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    -------------------------------------------------------
    -- Return basic team member profiles
    -------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.hire_date,
        e.employment_status,
        d.department_name,
        p.position_title
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE e.manager_id = @ManagerID
    ORDER BY e.full_name;
END;
GO


-- 12. GetTeamSummary-- GetTeamSummary
-- PROCEDURE: GetTeamSummary
CREATE PROCEDURE GetTeamSummary
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate manager exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    -------------------------------------------------------
    -- Return team summary grouped by role and department
    -------------------------------------------------------
    SELECT 
        ISNULL(r.role_name, 'Unassigned') AS RoleName,
        ISNULL(d.department_name, 'Unknown Department') AS DepartmentName,
        COUNT(DISTINCT e.employee_id) AS EmployeeCount,
        AVG(DATEDIFF(DAY, e.hire_date, GETDATE()) / 365.0) AS AverageTenureYears
    FROM Employee e
    LEFT JOIN Employee_Role er ON e.employee_id = er.employee_id
    LEFT JOIN Role r ON er.role_id = r.role_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE e.manager_id = @ManagerID
    GROUP BY r.role_name, d.department_name
    ORDER BY RoleName, DepartmentName;
END;
GO

-- 13. FilterTeamProfiles
-- FilterTeamProfiles
-- PROCEDURE: FilterTeamProfiles
CREATE PROCEDURE FilterTeamProfiles
    @ManagerID INT,
    @Skill VARCHAR(50),
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate manager exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    -------------------------------------------------------
    -- Retrieve filtered profiles
    -------------------------------------------------------
    SELECT DISTINCT
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        d.department_name,
        p.position_title,
        e.hire_date,
        e.employment_status
    FROM Employee e
    LEFT JOIN Employee_Skill es ON e.employee_id = es.employee_id
    LEFT JOIN Skill s ON es.skill_id = s.skill_id
    LEFT JOIN Employee_Role er ON e.employee_id = er.employee_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE e.manager_id = @ManagerID
      AND (
            (@Skill IS NOT NULL AND s.skill_name = @Skill)
            OR
            (@RoleID IS NOT NULL AND er.role_id = @RoleID)
          )
    ORDER BY e.full_name;
END;
GO

-- 14. ViewTeamCertifications
-- ViewTeamCertifications
-- PROCEDURE: ViewTeamCertifications
CREATE PROCEDURE ViewTeamCertifications
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------
    -- Validate manager exists
    -------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    -------------------------------------------------------
    -- Return combined skills + certifications for all team members
    -------------------------------------------------------
    SELECT DISTINCT
        e.employee_id,
        e.full_name,
        ISNULL(s.skill_name, 'No Skill') AS SkillName,
        ISNULL(es.proficiency_level, '-') AS Proficiency,
        ISNULL(v.verification_type, 'No Certification') AS Certification,
        v.issuer,
        v.issue_date,
        v.expiry_period
    FROM Employee e
    LEFT JOIN Employee_Skill es ON e.employee_id = es.employee_id
    LEFT JOIN Skill s ON es.skill_id = s.skill_id
    LEFT JOIN Employee_Verification ev ON e.employee_id = ev.employee_id
    LEFT JOIN Verification v ON ev.verification_id = v.verification_id
    WHERE e.manager_id = @ManagerID
    ORDER BY e.full_name, SkillName, Certification;
END;
GO


-- 15. AddManagerNotes check visible to hr
-- AddManagerNotes
-- PROCEDURE: AddManagerNotes
CREATE PROCEDURE AddManagerNotes
    @EmployeeID INT,
    @ManagerID INT,
    @Note VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- Validate employee exists
        -------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- Validate manager exists
        -------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- Ensure manager is actually the employee’s manager
        -------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 
            FROM Employee 
            WHERE employee_id = @EmployeeID 
              AND manager_id = @ManagerID
        )
        BEGIN
            RAISERROR('Manager is not authorized to add notes for this employee.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- Insert manager note
        -------------------------------------------------------
        INSERT INTO ManagerNotes (employee_id, manager_id, note_content, created_at)
        VALUES (@EmployeeID, @ManagerID, @Note, GETDATE());

        -------------------------------------------------------
        -- Success message
        -------------------------------------------------------
        SELECT 
            'Manager note added successfully' AS Message,
            @EmployeeID AS EmployeeID,
            @ManagerID AS ManagerID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO-- 16. RecordManualAttendance
CREATE PROCEDURE RecordManualAttendance
    @EmployeeID INT,
    @Date DATE,
    @ClockIn TIME,
    @ClockOut TIME,
    @Reason VARCHAR(200),
    @RecordedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------
        -- Validate employee exists
        ----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- Validate recorder exists
        ----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @RecordedBy)
        BEGIN
            RAISERROR('Recorder (RecordedBy) does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- Validate time range
        ----------------------------------------------------
        IF @ClockOut <= @ClockIn
        BEGIN
            RAISERROR('Clock-out time must be after clock-in time.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- Insert attendance
        ----------------------------------------------------
        DECLARE @EntryTime DATETIME = CAST(@Date AS DATETIME) + CAST(@ClockIn AS DATETIME);
        DECLARE @ExitTime DATETIME = CAST(@Date AS DATETIME) + CAST(@ClockOut AS DATETIME);

        INSERT INTO Attendance (employee_id, entry_time, exit_time, login_method, logout_method)
        VALUES (@EmployeeID, @EntryTime, @ExitTime, 'Manual Entry', 'Manual Entry');

        DECLARE @AttendanceID INT = SCOPE_IDENTITY();

        ----------------------------------------------------
        -- Insert audit log
        ----------------------------------------------------
        INSERT INTO AttendanceLog (attendance_id, actor, timestamp, reason)
        VALUES (@AttendanceID, @RecordedBy, GETDATE(), @Reason);

        ----------------------------------------------------
        -- Output
        ----------------------------------------------------
        SELECT 'Manual attendance recorded successfully with audit trail' AS Message;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- 17. ReviewMissedPunches
CREATE PROCEDURE ReviewMissedPunches
    @ManagerID INT,
    @Date DATE
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------
    -- Validate manager exists
    ----------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    ----------------------------------------------------
    -- Retrieve missed punch exceptions for team
    ----------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        ex.exception_id,
        ex.name AS ExceptionName,
        ex.category,
        ex.date,
        ex.status
    FROM [Exception] ex
    INNER JOIN Employee e ON ex.exception_id IN (
        SELECT exception_id FROM Employee_Exception WHERE employee_id = e.employee_id
    )
    WHERE e.manager_id = @ManagerID
      AND ex.category = 'Attendance'
      AND ex.date = @Date
      AND ex.status = 'Open'
    ORDER BY e.full_name;
END;
GO

-- 18. ApproveTimeRequest
-- ApproveTimeRequest (Fixed to avoid NULL attendance_id violation)
CREATE PROCEDURE ApproveTimeRequest
    @RequestID INT,
    @ManagerID INT,
    @Decision VARCHAR(20),
    @Comments VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------
        -- Validate request exists
        ----------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM AttendanceCorrectionRequest WHERE request_id = @RequestID
        )
        BEGIN
            RAISERROR('Request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- Validate decision
        ----------------------------------------------------
        IF @Decision NOT IN ('Approved', 'Rejected')
        BEGIN
            RAISERROR('Decision must be Approved or Rejected.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- Validate manager authorization
        ----------------------------------------------------
        IF NOT EXISTS (
            SELECT 1
            FROM AttendanceCorrectionRequest acr
            INNER JOIN Employee e ON acr.employee_id = e.employee_id
            WHERE acr.request_id = @RequestID
              AND e.manager_id = @ManagerID
        )
        BEGIN
            RAISERROR('Manager is not authorized to approve this request.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- Update request
        ----------------------------------------------------
        UPDATE AttendanceCorrectionRequest
        SET status = @Decision
        WHERE request_id = @RequestID;

        ----------------------------------------------------
        -- Insert log ONLY IF there is a related attendance_id
        ----------------------------------------------------
        DECLARE @AttendanceID INT = (
            SELECT TOP 1 attendance_id
            FROM Attendance
            WHERE employee_id = (SELECT employee_id FROM AttendanceCorrectionRequest WHERE request_id = @RequestID)
            ORDER BY attendance_id DESC
        );

        IF @AttendanceID IS NOT NULL
        BEGIN
            INSERT INTO AttendanceLog (attendance_id, actor, timestamp, reason)
            VALUES (
                @AttendanceID,
                @ManagerID,
                GETDATE(),
                'Time request ' + @Decision + ': ' + @Comments
            );
        END;

        ----------------------------------------------------
        -- Output
        ----------------------------------------------------
        SELECT 
            'Time request processed successfully' AS ConfirmationMessage,
            @Decision AS Decision,
            @Comments AS Comments;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 19. ViewLeaveRequest
-- 19. ViewLeaveRequest
CREATE PROCEDURE ViewLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------
    -- Check that the leave request exists
    --------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
    BEGIN
        RAISERROR('Leave request does not exist.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------
    -- Validate manager authorization
    --------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM LeaveRequest lr
        INNER JOIN Employee e ON lr.employee_id = e.employee_id
        WHERE lr.request_id = @LeaveRequestID
          AND e.manager_id = @ManagerID
    )
    BEGIN
        RAISERROR('You are not authorized to view this leave request.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------
    -- Return leave request details
    --------------------------------------------------------
    SELECT 
        lr.request_id,
        lr.employee_id,
        e.full_name,
        lr.leave_id,
        l.leave_type,
        lr.justification,
        lr.duration,
        lr.approval_timing,
        lr.status
    FROM LeaveRequest lr
    INNER JOIN Employee e ON lr.employee_id = e.employee_id
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    WHERE lr.request_id = @LeaveRequestID;
END;
GO



-- 20. ApproveLeaveRequest
CREATE PROCEDURE ApproveLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------
    -- Validate that the request exists
    --------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
    BEGIN
        RAISERROR('Leave request does not exist.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------
    -- Validate that this manager is allowed to approve this request
    --------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM LeaveRequest lr
        INNER JOIN Employee e ON lr.employee_id = e.employee_id
        WHERE lr.request_id = @LeaveRequestID
          AND e.manager_id = @ManagerID
    )
    BEGIN
        RAISERROR('You are not authorized to approve this leave request.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------
    -- Approve the request
    --------------------------------------------------------
    UPDATE LeaveRequest
    SET status = 'Approved',
        approval_timing = GETDATE()
    WHERE request_id = @LeaveRequestID;

    --------------------------------------------------------
    -- Notify employee
    --------------------------------------------------------
    DECLARE @EmployeeID INT = (SELECT employee_id FROM LeaveRequest WHERE request_id = @LeaveRequestID);

    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('Your leave request has been approved.', 'Normal', 'Leave');

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@EmployeeID, @NotifID, 'Sent', GETDATE());

    --------------------------------------------------------
    SELECT 'Leave request approved successfully' AS ConfirmationMessage;
END;
GO



-- 21. RejectLeaveRequest
-- 21. RejectLeaveRequest
CREATE PROCEDURE RejectLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT,
    @Reason VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------
    -- Validate that the leave request exists
    --------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
    BEGIN
        RAISERROR('Leave request does not exist.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------
    -- Validate that this manager is authorized
    --------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM LeaveRequest lr
        INNER JOIN Employee e ON lr.employee_id = e.employee_id
        WHERE lr.request_id = @LeaveRequestID
          AND e.manager_id = @ManagerID
    )
    BEGIN
        RAISERROR('You are not authorized to reject this leave request.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------
    -- Reject the request
    --------------------------------------------------------
    UPDATE LeaveRequest
    SET status = 'Rejected',
        approval_timing = GETDATE()
    WHERE request_id = @LeaveRequestID;

    --------------------------------------------------------
    -- Notify employee
    --------------------------------------------------------
    DECLARE @EmployeeID INT = (SELECT employee_id FROM LeaveRequest WHERE request_id = @LeaveRequestID);

    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('Your leave request has been rejected. Reason: ' + @Reason, 'Normal', 'Leave');

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@EmployeeID, @NotifID, 'Sent', GETDATE());

    --------------------------------------------------------
    SELECT 'Leave request rejected successfully' AS ConfirmationMessage,
           @Reason AS RejectionReason;
END;
GO


-- 22. DelegateLeaveApproval
CREATE PROCEDURE DelegateLeaveApproval
    @ManagerID INT,
    @DelegateID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------
    -- Validate manager exists
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    ------------------------------------------------------
    -- Validate delegate exists
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @DelegateID)
    BEGIN
        RAISERROR('Delegate employee does not exist.', 16, 1);
        RETURN;
    END;

    ------------------------------------------------------
    -- Create delegation notification
    ------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'Manager ID ' + CAST(@ManagerID AS VARCHAR(10)) +
        ' has delegated leave approval authority to Employee ID ' + CAST(@DelegateID AS VARCHAR(10)) +
        ' from ' + CONVERT(VARCHAR(10), @StartDate, 120) +
        ' to ' + CONVERT(VARCHAR(10), @EndDate, 120),
        'High',
        0,
        'Delegation Notice'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    ------------------------------------------------------
    -- Deliver notification to delegate
    ------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@DelegateID, @NotifID, 'Sent', GETDATE());

    ------------------------------------------------------
    SELECT 'Leave approval authority delegated successfully.' AS ConfirmationMessage,
           @DelegateID AS DelegateID,
           @StartDate AS StartDate,
           @EndDate AS EndDate;
END;
GO

--- 23. FlagIrregularLeave
CREATE PROCEDURE FlagIrregularLeave
    @EmployeeID INT,
    @ManagerID INT,
    @PatternDescription VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------
    -- Validate employee exists
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        RAISERROR('Employee does not exist.', 16, 1);
        RETURN;
    END;

    ------------------------------------------------------
    -- Validate manager exists
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    ------------------------------------------------------
    -- Create notification
    ------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'Irregular leave pattern flagged for Employee ID ' + CAST(@EmployeeID AS VARCHAR(10)) +
        '. Pattern: ' + @PatternDescription +
        '. Flagged by Manager ID ' + CAST(@ManagerID AS VARCHAR(10)),
        'Medium',
        0,
        'Leave Pattern Alert'
    );

    DECLARE @NID INT = SCOPE_IDENTITY();

    ------------------------------------------------------
    -- Deliver to HR admin(s)
    ------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    SELECT employee_id, @NID, 'Sent', GETDATE()
    FROM HRAdministrator;

    SELECT 'Irregular leave pattern flagged successfully.' AS ConfirmationMessage;
END;
GO


-- 24. NotifyNewLeaveRequest
CREATE PROCEDURE NotifyNewLeaveRequest
    @ManagerID INT,
    @RequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------
    -- Validate manager exists
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
    BEGIN
        RAISERROR('Manager does not exist.', 16, 1);
        RETURN;
    END;

    ------------------------------------------------------
    -- Validate request exists
    ------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @RequestID)
    BEGIN
        RAISERROR('Leave request does not exist.', 16, 1);
        RETURN;
    END;

    ------------------------------------------------------
    -- Create notification
    ------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, read_status, notification_type)
    VALUES (
        'A new leave request (ID ' + CAST(@RequestID AS VARCHAR(10)) +
        ') has been assigned to you for review.',
        'High',
        0,
        'Leave Request Assignment'
    );

    DECLARE @NotifID INT = SCOPE_IDENTITY();

    ------------------------------------------------------
    -- Deliver to manager
    ------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@ManagerID, @NotifID, 'Sent', GETDATE());

    SELECT 
        'New leave request ID ' + CAST(@RequestID AS VARCHAR(10)) +
        ' assigned to manager successfully.' AS NotificationMessage;
END;
GO
