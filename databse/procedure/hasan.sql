
-- 1. Schema Changes FIRST
-- ManagerNotes
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[ManagerNotes]') AND name = 'is_archived')
BEGIN
    ALTER TABLE ManagerNotes
    ADD is_archived BIT DEFAULT 0;
END
GO

-- LeavePolicy
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[LeavePolicy]') AND name = 'max_duration')
BEGIN
    ALTER TABLE LeavePolicy
    ADD max_duration INT DEFAULT 30;
END
GO


-- 2. Procedures

-- InsertLeaveDocument
CREATE OR ALTER PROCEDURE InsertLeaveDocument
    @LeaveRequestID INT,
    @FilePath VARCHAR(500)
AS
BEGIN
    INSERT INTO LeaveDocument (leave_request_id, file_path, uploaded_at)
    VALUES (@LeaveRequestID, @FilePath, GETDATE());
END;
GO

-- GetLeaveHistory
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
        -- ✅ Added Attachment Count
        COUNT(ld.document_id) AS attachment_count
    FROM LeaveRequest lr
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    -- ✅ Join Documents to count them
    LEFT JOIN LeaveDocument ld ON lr.request_id = ld.leave_request_id
    WHERE lr.employee_id = @EmployeeID
    -- ✅ Group By required for COUNT aggregate
    GROUP BY lr.request_id, l.leave_type, lr.duration, lr.status, lr.justification, lr.approval_timing
    ORDER BY lr.request_id DESC;
END;
GO

-- GetLeaveTypes
CREATE OR ALTER PROCEDURE GetLeaveTypes
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        leave_id, 
        leave_type 
    FROM [Leave]
    WHERE leave_type NOT IN ('Holiday'); 
END;
GO

-- GetLeaveConfiguration
CREATE OR ALTER PROCEDURE GetLeaveConfiguration
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        l.leave_id,
        l.leave_type,
        l.leave_description,
        ISNULL(p.notice_period, 0) AS notice_period,
        ISNULL(p.max_duration, 0) AS max_duration,
        ISNULL(p.eligibility_rules, 'All') AS eligibility_rules
    FROM [Leave] l
    LEFT JOIN LeavePolicy p ON l.leave_type = p.special_leave_type;
END;
GO

-- ArchiveManagerNote
CREATE OR ALTER PROCEDURE ArchiveManagerNote
    @NoteID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ManagerNotes
    SET is_archived = 1
    WHERE note_id = @NoteID;

    SELECT 'Flag archived successfully' AS ConfirmationMessage;
END;
GO

-- FIX: GetLeaveBalance to include Override status
CREATE OR ALTER PROCEDURE GetLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- CTE to gather raw data
    WITH RawBalance AS (
        SELECT 
            l.leave_id,
            l.leave_type,
            ISNULL(le.entitlement, 0) AS raw_entitlement,
             -- Approved Usage (Include Override)
            ISNULL((SELECT SUM(duration) 
                    FROM LeaveRequest 
                    WHERE employee_id = @EmployeeID 
                      AND leave_id = l.leave_id 
                      AND (status = 'Approved' OR status LIKE 'Approved%')), 0) AS used,
            -- Pending Usage
            ISNULL((SELECT SUM(duration) 
                    FROM LeaveRequest 
                    WHERE employee_id = @EmployeeID 
                      AND leave_id = l.leave_id 
                      AND status = 'Pending'), 0) AS pending
        FROM [Leave] l
        LEFT JOIN LeaveEntitlement le ON l.leave_id = le.leave_type_id AND le.employee_id = @EmployeeID
    )
    SELECT
        leave_type,
        
        -- Categorization (String-based)
        CASE 
            WHEN leave_type = 'Vacation' THEN 'Annual'
            WHEN leave_type = 'Sick' THEN 'Entitled'
            ELSE 'Policy'
        END AS category,

        -- Entitlement Logic (Vacation Default 30, Policy 0)
        CASE 
            WHEN leave_type = 'Vacation' AND raw_entitlement = 0 THEN 30.00 
            WHEN leave_type IN ('Vacation', 'Sick') THEN raw_entitlement
            ELSE 0 
        END AS entitlement,

        -- Usage (Always show real usage)
        used AS days_used,
        pending AS days_pending,

        -- Remaining Logic (Entitlement - Used)
        CASE 
            WHEN leave_type = 'Vacation' AND raw_entitlement = 0 THEN 30.00 - used
            WHEN leave_type IN ('Vacation', 'Sick') THEN raw_entitlement - used
            ELSE 0 
        END AS remaining_balance

    FROM RawBalance
END;
GO


-- Fix SyncLeaveToAttendance syntax and logic
CREATE OR ALTER PROCEDURE SyncLeaveToAttendance
    @LeaveRequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Read Request Details
        DECLARE @EmployeeID INT, @LeaveType VARCHAR(50), @Duration INT, 
                @Status VARCHAR(50), @Justification VARCHAR(255), @StartDate DATE;

        SELECT 
            @EmployeeID = lr.employee_id,
            @LeaveType = l.leave_type,
            @Duration = lr.duration,
            @Status = lr.status,
            @Justification = lr.justification
        FROM LeaveRequest lr
        JOIN [Leave] l ON lr.leave_id = l.leave_id
        WHERE lr.request_id = @LeaveRequestID;

        -- 2. Validations
        IF @EmployeeID IS NULL
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Status NOT IN ('Approved', 'Finalized', 'Approved - Balance Updated', 'Approved - Override')
        BEGIN
            RAISERROR('Only approved leaves can be synced.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 3. PARSE START DATE from Justification
        -- Format expected: "... (From: YYYY-MM-DD To: ...)"
        DECLARE @FromIndex INT = CHARINDEX('(From: ', @Justification);
        
        IF @FromIndex > 0
        BEGIN
            DECLARE @DateStr VARCHAR(10) = SUBSTRING(@Justification, @FromIndex + 7, 10);
            -- FIX: Use TRY_CAST in IF condition
            IF TRY_CAST(@DateStr AS DATE) IS NOT NULL
            BEGIN
                SET @StartDate = CAST(@DateStr AS DATE);
            END
        END
        
        IF @StartDate IS NULL
        BEGIN
             -- Fallback: Use Approval Timing if parsing fails (Legacy support)
             SELECT @StartDate = approval_timing FROM LeaveRequest WHERE request_id = @LeaveRequestID;
        END

        IF @StartDate IS NULL
        BEGIN
            RAISERROR('Could not determine start date from justification.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 4. LOOP: Process Each Day
        DECLARE @i INT = 0;
        DECLARE @CurrentDate DATE;
        DECLARE @ShiftID INT;
        DECLARE @ShiftStart TIME;
        DECLARE @ShiftEnd TIME;
        DECLARE @ExceptionID INT;

        WHILE @i < @Duration
        BEGIN
            SET @CurrentDate = DATEADD(DAY, @i, @StartDate);

            --------------------------------------------------------
            -- STEP 1: Create the Exception (The Reason)
            --------------------------------------------------------
            INSERT INTO [Exception] ([name], category, [date], status)
            VALUES (
                @LeaveType + ' Leave', 
                'Leave', 
                @CurrentDate, 
                'Approved'
            );

            -- Capture the ID of the new Exception
            SET @ExceptionID = SCOPE_IDENTITY();

            --------------------------------------------------------
            -- STEP 2: Find Shift Details (To fill Attendance times)
            --------------------------------------------------------
            SELECT TOP 1 
                @ShiftID = s.shift_id,
                @ShiftStart = s.start_time,
                @ShiftEnd = s.end_time
            FROM ShiftAssignment sa
            JOIN ShiftSchedule s ON sa.shift_id = s.shift_id
            WHERE sa.employee_id = @EmployeeID
              AND sa.status = 'Active'
              AND @CurrentDate BETWEEN sa.start_date AND sa.end_date;

            --------------------------------------------------------
            -- STEP 3: Create Attendance Record (The Daily Truth)
            -- AND Link it to the Exception (Step 4)
            --------------------------------------------------------
            IF @ShiftID IS NOT NULL
            BEGIN
                INSERT INTO Attendance (
                    employee_id, 
                    shift_id, 
                    entry_time, 
                    exit_time, 
                    login_method, 
                    logout_method,
                    exception_id -- <--- LINKING HERE
                )
                VALUES (
                    @EmployeeID,
                    @ShiftID,
                    CAST(@CurrentDate AS DATETIME) + CAST(@ShiftStart AS DATETIME), 
                    CAST(@CurrentDate AS DATETIME) + CAST(@ShiftEnd AS DATETIME),
                    'LeaveSync', 
                    'LeaveSync',
                    @ExceptionID -- The ID from Step 1
                );
            END
            ELSE
            BEGIN
                -- Fallback if no shift assigned (still record the leave)
                INSERT INTO Attendance (
                    employee_id, 
                    entry_time, 
                    login_method,
                    exception_id
                )
                VALUES (
                    @EmployeeID, 
                    CAST(@CurrentDate AS DATETIME), 
                    'LeaveSync',
                    @ExceptionID
                );
            END

            -- Also link via Employee_Exception table for redundancy/history
            INSERT INTO Employee_Exception (employee_id, exception_id)
            VALUES (@EmployeeID, @ExceptionID);

            SET @i = @i + 1;
        END;

        --------------------------------------------------------
        -- STEP 5: Finalize Status
        --------------------------------------------------------
        -- Only update status if it is NOT 'Approved - Override' (preserve the Override tag)
        IF @Status NOT IN ('Approved - Override')
        BEGIN
            UPDATE LeaveRequest
            SET status = 'Synced'
            WHERE request_id = @LeaveRequestID;
        END

        COMMIT TRANSACTION;

        SELECT 'Leave successfully synced to Attendance with Exceptions.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Fix OverrideLeaveDecision (Add parameters + Logic)
CREATE OR ALTER PROCEDURE OverrideLeaveDecision
    @LeaveRequestID INT,
    @NewStatus VARCHAR(20), -- 'Approved' or 'Rejected'
    @Reason VARCHAR(200),
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate Request
        DECLARE @CurrentStatus VARCHAR(50);
        DECLARE @Justification VARCHAR(MAX);
        DECLARE @EmployeeID INT;

        SELECT 
            @CurrentStatus = status,
            @Justification = justification,
            @EmployeeID = employee_id
        FROM LeaveRequest
        WHERE request_id = @LeaveRequestID;

        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR('Leave request not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 2. Update Status
        DECLARE @FinalStatus VARCHAR(50);
        
        IF @NewStatus = 'Approved'
        BEGIN
            SET @FinalStatus = 'Approved - Override';
            UPDATE LeaveRequest
            SET status = @FinalStatus,
                justification = @Justification + ' | Override Reason: ' + @Reason,
                approval_timing = GETDATE()
            WHERE request_id = @LeaveRequestID;
        END
        ELSE
        BEGIN
            SET @FinalStatus = 'Rejected - Override';
            UPDATE LeaveRequest
            SET status = @FinalStatus,
                justification = @Justification + ' | Override Reason: ' + @Reason,
                approval_timing = GETDATE()
            WHERE request_id = @LeaveRequestID;
        END

        -- 3. Sync Attendance (Only if Approved)
        IF @NewStatus = 'Approved'
        BEGIN
            -- Call the Sync Procedure (now handles 'Approved - Override')
            EXEC SyncLeaveToAttendance @LeaveRequestID;
        END

        -- 4. Notify Employee
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES ('Your leave request #' + CAST(@LeaveRequestID AS VARCHAR) + ' has been overridden to: ' + @NewStatus + '.', 'High', 0, 'LeaveOverride');
        
        DECLARE @NID INT = SCOPE_IDENTITY();
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Leave overridden successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- PROCEDURE: GetAllLeaveRequests
CREATE OR ALTER PROCEDURE GetAllLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 100
        lr.request_id,
        lr.employee_id,
        e.full_name AS employee_name,
        l.leave_type,
        lr.duration,
        lr.status,
        lr.approval_timing AS start_date
    FROM LeaveRequest lr
    JOIN Employee e ON lr.employee_id = e.employee_id
    JOIN [Leave] l ON lr.leave_id = l.leave_id
    ORDER BY lr.request_id DESC;
END;
GO

-- PROCEDURE: GetLeaveRequestDetail
CREATE OR ALTER PROCEDURE GetLeaveRequestDetail
    @RequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        lr.request_id, 
        lr.employee_id, 
        e.full_name as employee_name, 
        l.leave_type, 
        lr.justification, 
        lr.duration, 
        lr.status, 
        lr.approval_timing
    FROM LeaveRequest lr
    JOIN Employee e ON lr.employee_id = e.employee_id
    JOIN [Leave] l ON lr.leave_id = l.leave_id
    WHERE lr.request_id = @RequestID;
END;
GO


-- UPDATED: ApproveLeaveRequest to sync with Attendance
CREATE OR ALTER PROCEDURE ApproveLeaveRequest
    @LeaveRequestID INT,
    @ApproverID INT,
    @Status VARCHAR(20) = 'Approved'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate Request exists
        IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
        BEGIN
            RAISERROR('Leave request not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 2. Update Status
        UPDATE LeaveRequest
        SET status = @Status,
            approval_timing = GETDATE()
        WHERE request_id = @LeaveRequestID;

        -- 3. Notify Employee (Log to Notification table)
        DECLARE @EmployeeID INT;
        SELECT @EmployeeID = employee_id FROM LeaveRequest WHERE request_id = @LeaveRequestID;

        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your leave request #' + CAST(@LeaveRequestID AS VARCHAR) + ' has been ' + @Status + '.',
            'Medium',
            0,
            'LeaveStatus'
        );

        DECLARE @NID INT = SCOPE_IDENTITY();

        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NID, 'Sent', GETDATE());

        -- 4. SYNC TO ATTENDANCE (Critical Step Added)
        -- Only sync if status is Approved (to avoid issues if this SP is used for other states)
        IF @Status = 'Approved'
        BEGIN
            -- We call the sync procedure. 
            -- Note: SyncLeaveToAttendance handles its own transaction logic. 
            -- Since we are already in a transaction, it will be a nested transaction.
            -- If it fails/rolls back, it will roll back everything.
            EXEC SyncLeaveToAttendance @LeaveRequestID;
        END

        COMMIT TRANSACTION;

        SELECT 'Leave request ' + @Status + ' successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- FIX: GetLeaveBalance to force Probation/Holiday as Policy
CREATE OR ALTER PROCEDURE GetLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- CTE to gather raw data
    WITH RawBalance AS (
        SELECT 
            l.leave_id,
            l.leave_type,
            ISNULL(le.entitlement, 0) AS raw_entitlement,
             -- Approved Usage (Include Override)
            ISNULL((SELECT SUM(duration) 
                    FROM LeaveRequest 
                    WHERE employee_id = @EmployeeID 
                      AND leave_id = l.leave_id 
                      AND (status = 'Approved' OR status LIKE 'Approved%')), 0) AS used,
            -- Pending Usage
            ISNULL((SELECT SUM(duration) 
                    FROM LeaveRequest 
                    WHERE employee_id = @EmployeeID 
                      AND leave_id = l.leave_id 
                      AND status = 'Pending'), 0) AS pending
        FROM [Leave] l
        LEFT JOIN LeaveEntitlement le ON l.leave_id = le.leave_type_id AND le.employee_id = @EmployeeID
        WHERE l.leave_type NOT IN ('Holiday') -- Assuming Holiday is handled or filtered here, but adding explicit case below just in case
    )
    SELECT
        leave_type,
        
        -- DYNAMIC CATEGORIZATION
        CASE 
            WHEN leave_type = 'Vacation' THEN 'Annual'
            -- EXPLICIT EXCLUSION: Probation and Holiday are ALWAYS Policy based, regardless of data
            WHEN leave_type IN ('Probation', 'Holiday') THEN 'Policy'
            -- Logic: If it has entitlement assigned OR is strictly 'Sick', treat as Entitled.
            WHEN raw_entitlement > 0 OR leave_type = 'Sick' THEN 'Entitled'
            ELSE 'Policy'
        END AS category,

        -- Entitlement Logic (Probation/Holiday -> 0)
        CASE 
            WHEN leave_type IN ('Probation', 'Holiday') THEN 0
            WHEN leave_type = 'Vacation' AND raw_entitlement = 0 THEN 30.00 
            WHEN (raw_entitlement > 0 OR leave_type = 'Sick') THEN raw_entitlement
            ELSE 0 
        END AS entitlement,

        -- Usage (Always show real usage)
        days_used = used,
        days_pending = pending,

        -- Remaining Logic (Entitlement - Used)
        CASE 
            WHEN leave_type IN ('Probation', 'Holiday') THEN 0
            WHEN leave_type = 'Vacation' AND raw_entitlement = 0 THEN 30.00 - used
            WHEN (raw_entitlement > 0 OR leave_type = 'Sick') THEN raw_entitlement - used
            ELSE 0 
        END AS remaining_balance

    FROM RawBalance
END;
GO

-- FIX: GetLeaveBalance to include Override status AND Dynamic Categorization
CREATE OR ALTER PROCEDURE GetLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- CTE to gather raw data
    WITH RawBalance AS (
        SELECT 
            l.leave_id,
            l.leave_type,
            ISNULL(le.entitlement, 0) AS raw_entitlement,
             -- Approved Usage (Include Override)
            ISNULL((SELECT SUM(duration) 
                    FROM LeaveRequest 
                    WHERE employee_id = @EmployeeID 
                      AND leave_id = l.leave_id 
                      AND (status = 'Approved' OR status LIKE 'Approved%')), 0) AS used,
            -- Pending Usage
            ISNULL((SELECT SUM(duration) 
                    FROM LeaveRequest 
                    WHERE employee_id = @EmployeeID 
                      AND leave_id = l.leave_id 
                      AND status = 'Pending'), 0) AS pending
        FROM [Leave] l
        LEFT JOIN LeaveEntitlement le ON l.leave_id = le.leave_type_id AND le.employee_id = @EmployeeID
        WHERE l.leave_type NOT IN ('Holiday') -- Assuming Holiday is always policy based and listed separately or not shown here logic
    )
    SELECT
        leave_type,
        
        -- DYNAMIC CATEGORIZATION
        CASE 
            WHEN leave_type = 'Vacation' THEN 'Annual'
            -- Logic: If it has entitlement assigned OR is strictly 'Sick', treat as Entitled.
            -- This moves "non-special" but entitled policies to "Other Entitled Leaves"
            WHEN raw_entitlement > 0 OR leave_type = 'Sick' THEN 'Entitled'
            ELSE 'Policy'
        END AS category,

        -- Entitlement Logic (Vacation Default 30, Policy 0)
        CASE 
            WHEN leave_type = 'Vacation' AND raw_entitlement = 0 THEN 30.00 
            WHEN (raw_entitlement > 0 OR leave_type = 'Sick') THEN raw_entitlement
            ELSE 0 
        END AS entitlement,

        -- Usage (Always show real usage)
        days_used = used,
        days_pending = pending,

        -- Remaining Logic (Entitlement - Used)
        CASE 
            WHEN leave_type = 'Vacation' AND raw_entitlement = 0 THEN 30.00 - used
            WHEN (raw_entitlement > 0 OR leave_type = 'Sick') THEN raw_entitlement - used
            ELSE 0 
        END AS remaining_balance

    FROM RawBalance
END;
GO


-- UPDATED: ConfigureLeaveRules to include Eligibility Rules
CREATE OR ALTER PROCEDURE ConfigureLeaveRules
    @LeaveType VARCHAR(50),
    @MaxDuration INT,
    @NoticePeriod INT,
    @WorkflowType VARCHAR(50),
    @EligibilityRules VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if a policy row exists for this leave type
    IF EXISTS (SELECT 1 FROM LeavePolicy WHERE special_leave_type = @LeaveType)
    BEGIN
        -- UPDATE existing row
        UPDATE LeavePolicy
        SET notice_period = @NoticePeriod,
            max_duration = @MaxDuration,
            eligibility_rules = @EligibilityRules,
            -- Update purpose to be a description or workflow related
            purpose = 'Policy for ' + @LeaveType + '. Workflow: ' + @WorkflowType
        WHERE special_leave_type = @LeaveType;
    END
    ELSE
    BEGIN
        -- INSERT new row
        INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year, max_duration)
        VALUES (
            @LeaveType + ' Policy',
            'Policy for ' + @LeaveType + '. Workflow: ' + @WorkflowType,
            ISNULL(@EligibilityRules, 'All'),
            @NoticePeriod,
            @LeaveType,
            1,
            @MaxDuration
        );
    END

    SELECT 'Leave rules configured successfully' AS ConfirmationMessage;
END;
GO

-- UPDATED: GetLeaveTypes to return Eligibility Rules
CREATE OR ALTER PROCEDURE GetLeaveTypes
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        l.leave_id, 
        l.leave_type,
        ISNULL(p.eligibility_rules, 'All') AS eligibility_rules
    FROM [Leave] l
    LEFT JOIN LeavePolicy p ON l.leave_type = p.special_leave_type
    WHERE l.leave_type NOT IN ('Holiday'); 
END;
GO




