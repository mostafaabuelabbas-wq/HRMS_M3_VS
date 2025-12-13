USE HRMS
GO
--HR admin
CREATE PROCEDURE CreateContract
    @EmployeeID INT,
    @Type VARCHAR(50),
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 2. Validate dates
        IF (@StartDate >= @EndDate)
        BEGIN
            RAISERROR('StartDate must be earlier than EndDate.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 3. Insert base contract WITH employee_id
        INSERT INTO Contract (employee_id, type, start_date, end_date, current_state)
        VALUES (@EmployeeID, @Type, @StartDate, @EndDate, 'Active');

        DECLARE @NewContractID INT = SCOPE_IDENTITY();

        -- 4. Insert subtype details
        IF (@Type = 'FullTime')
            INSERT INTO FullTimeContract (contract_id, leave_entitlement, insurance_eligibility, weekly_working_hours)
            VALUES (@NewContractID, 21, 1, 40);

        ELSE IF (@Type = 'PartTime')
            INSERT INTO PartTimeContract (contract_id, working_hours, hourly_rate)
            VALUES (@NewContractID, 20, 150);

        ELSE IF (@Type = 'Consultant')
            INSERT INTO ConsultantContract (contract_id, project_scope, fees, payment_schedule)
            VALUES (@NewContractID, 'General Project', 0, 'Monthly');

        ELSE IF (@Type = 'Internship')
            INSERT INTO InternshipContract (contract_id, mentoring, evaluation, stipend_related)
            VALUES (@NewContractID, 'Mentoring Program', 'Evaluation', 'Stipend');

        ELSE
        BEGIN
            RAISERROR('Invalid contract type.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 5. Mark employee's previous contract INACTIVE
        UPDATE Contract
        SET current_state = 'Inactive'
        WHERE employee_id = @EmployeeID AND current_state = 'Active' AND contract_id <> @NewContractID;

        -- 6. Assign new contract as employee's current contract
        UPDATE Employee
        SET contract_id = @NewContractID
        WHERE employee_id = @EmployeeID;

        COMMIT TRANSACTION;

        SELECT 'Contract created successfully. ContractID = ' 
               + CAST(@NewContractID AS VARCHAR(10)) AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
--RenewContract
CREATE OR ALTER PROCEDURE RenewContract
    @ContractID INT,
    @NewEndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EmployeeID INT;
        DECLARE @Type VARCHAR(50);
        DECLARE @StartDate DATE;

        -- 1. Load data from the OLD contract
        SELECT 
            @EmployeeID = employee_id,
            @Type = type,
            @StartDate = start_date -- Keep original start date? Or use Today?
                                    -- Usually a renewal starts when the old one ends.
                                    -- For now, we keep your logic (extending the specific contract).
        FROM Contract
        WHERE contract_id = @ContractID;

        IF @EmployeeID IS NULL
        BEGIN
            RAISERROR('Contract not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 2. Validate dates
        IF (@NewEndDate <= @StartDate)
        BEGIN
            RAISERROR('New end date must be after the start date.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 3. Mark OLD contract as INACTIVE (History)
        UPDATE Contract
        SET current_state = 'Inactive'
        WHERE contract_id = @ContractID;

        -- 4. Create NEW contract (Active)
        INSERT INTO Contract (employee_id, type, start_date, end_date, current_state)
        VALUES (@EmployeeID, @Type, @StartDate, @NewEndDate, 'Active');

        DECLARE @NewContractID INT = SCOPE_IDENTITY();

        -- 5. Update employee to point to the NEW contract
        UPDATE Employee
        SET contract_id = @NewContractID
        WHERE employee_id = @EmployeeID;

        COMMIT TRANSACTION;

        -- Return the new ID so C# can redirect to the new details page
        SELECT @NewContractID AS NewContractID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 3  ApproveLeaveRequest
CREATE PROCEDURE ApproveLeaveRequest
    @LeaveRequestID INT,
    @ApproverID INT,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LeaveID INT;
        DECLARE @EmployeeID INT;
        DECLARE @LeaveType VARCHAR(50);

        -- Validate request exists
        IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate approver exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApproverID)
        BEGIN
            RAISERROR('Approver does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Fetch request data
        SELECT 
            @LeaveID = leave_id,
            @EmployeeID = employee_id
        FROM LeaveRequest
        WHERE request_id = @LeaveRequestID;

        -- Get leave type
        SELECT @LeaveType = leave_type
        FROM [Leave]
        WHERE leave_id = @LeaveID;

        -- Update request status
        UPDATE LeaveRequest
        SET status = @Status,
            approval_timing = GETDATE()
        WHERE request_id = @LeaveRequestID;

        -- Update subtype table IF Vacation leave
        IF @LeaveType = 'Vacation'
        BEGIN
            UPDATE VacationLeave
            SET approving_manager = @ApproverID
            WHERE leave_id = @LeaveID;
        END

        -- Create notification
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your leave request has been ' + @Status,
            'Medium',
            0,
            'Leave'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -- Assign notification to employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NotificationID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Leave request ' + @Status + ' successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 4 AssignMission
-- PROCEDURE: AssignMission
CREATE PROCEDURE AssignMission
    @EmployeeID INT,
    @ManagerID INT,
    @Destination VARCHAR(50),
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate manager exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate date range
        IF (@StartDate >= @EndDate)
        BEGIN
            RAISERROR('StartDate must be earlier than EndDate.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert mission
        INSERT INTO Mission (destination, start_date, end_date, status, employee_id, manager_id)
        VALUES (@Destination, @StartDate, @EndDate, 'Assigned', @EmployeeID, @ManagerID);

        -- Create notification
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'You have been assigned a mission to ' + @Destination +
            ' from ' + CONVERT(VARCHAR(10), @StartDate, 120) +
            ' to ' + CONVERT(VARCHAR(10), @EndDate, 120),
            'High',
            0,
            'Mission Assignment'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -- Assign notification to employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NotificationID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Mission assigned successfully to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 5 ReviewReimbursement
CREATE PROCEDURE ReviewReimbursement
    @ClaimID INT,
    @ApproverID INT,
    @Decision VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EmployeeID INT;
        DECLARE @Type VARCHAR(50);

        -- Validate reimbursement exists
        IF NOT EXISTS (SELECT 1 FROM Reimbursement WHERE reimbursement_id = @ClaimID)
        BEGIN
            RAISERROR('Reimbursement claim does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate approver exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApproverID)
        BEGIN
            RAISERROR('Approver does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Get employee and claim type
        SELECT 
            @EmployeeID = employee_id,
            @Type = type
        FROM Reimbursement
        WHERE reimbursement_id = @ClaimID;

        -- Update reimbursement
        UPDATE Reimbursement
        SET current_status = @Decision,
            approval_date = GETDATE()
        WHERE reimbursement_id = @ClaimID;

        -- Create notification
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your reimbursement claim for ' + @Type + ' has been ' + @Decision,
            'Medium',
            0,
            'Reimbursement'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -- Assign notification to employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NotificationID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Reimbursement claim ' + @Decision + ' successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO




-- 6 GetActiveContracts
-- PROCEDURE: GetActiveContracts
CREATE PROCEDURE GetActiveContracts
AS
BEGIN
    SET NOCOUNT ON;

    -- return all active contracts with employee & department data
    SELECT 
        c.contract_id,
        c.type,
        c.start_date,
        c.end_date,
        c.current_state,
        e.employee_id,
        e.full_name,
        e.department_id,
        d.department_name
    FROM Contract c
    INNER JOIN Employee e ON c.contract_id = e.contract_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE c.current_state = 'Active';
END;
GO

-- 7 GetTeamByManager
-- PROCEDURE: GetTeamByManager
CREATE OR ALTER PROCEDURE GetTeamByManager
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.employee_id,
        e.full_name,
        e.employment_status,
        
        -- FIX: Alias these to match EmployeeDto.cs
        d.department_name AS Department, 
        p.position_title AS Position,

        -- Optional: Include these if your view needs them later
        e.email,
        e.phone

    FROM Employee e
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE e.manager_id = @ManagerID 
      AND e.is_active = 1 -- Good check to keep
    ORDER BY e.full_name;
END;
GO


-- 8 UpdateLeavePolicy
-- PROCEDURE: UpdateLeavePolicy
CREATE PROCEDURE UpdateLeavePolicy
    @PolicyID INT,
    @EligibilityRules VARCHAR(200),
    @NoticePeriod INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate policy exists
        IF NOT EXISTS (SELECT 1 FROM LeavePolicy WHERE policy_id = @PolicyID)
        BEGIN
            RAISERROR('Leave policy does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update the policy
        UPDATE LeavePolicy
        SET eligibility_rules = @EligibilityRules,
            notice_period = @NoticePeriod
        WHERE policy_id = @PolicyID;

        COMMIT TRANSACTION;

        SELECT 'Leave policy updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 9 GetExpiringContracts
-- PROCEDURE: GetExpiringContracts
CREATE PROCEDURE GetExpiringContracts
    @DaysBefore INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Return contracts that will expire within the next @DaysBefore days
    SELECT 
        c.contract_id,
        c.type,
        c.start_date,
        c.end_date,
        e.employee_id,
        e.full_name,
        d.department_name,
        DATEDIFF(DAY, GETDATE(), c.end_date) AS days_until_expiration
    FROM Contract c
    INNER JOIN Employee e ON c.contract_id = e.contract_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE c.end_date > GETDATE()            -- must be in the future
      AND c.end_date <= DATEADD(DAY, @DaysBefore, GETDATE())
    ORDER BY c.end_date;
END;
GO

-- 10 AssignDepartmentHead
-- PROCEDURE: AssignDepartmentHead
CREATE PROCEDURE AssignDepartmentHead
    @DepartmentID INT,
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate department exists
        IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @DepartmentID)
        BEGIN
            RAISERROR('Department does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate manager exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager (employee) does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update department head
        UPDATE Department
        SET department_head_id = @ManagerID
        WHERE department_id = @DepartmentID;

        COMMIT TRANSACTION;

        SELECT 'Department head assigned successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 11 CreateEmployeeProfile
-- PROCEDURE: CreateEmployeeProfile
CREATE PROCEDURE CreateEmployeeProfile
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50),
    @DepartmentID INT,
    @RoleID INT,                -- maps to Position.position_id
    @HireDate DATE,
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @NationalID VARCHAR(50),
    @DateOfBirth DATE,
    @CountryOfBirth VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate department exists
        IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @DepartmentID)
        BEGIN
            RAISERROR('Department does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate position exists
        IF NOT EXISTS (SELECT 1 FROM Position WHERE position_id = @RoleID)
        BEGIN
            RAISERROR('Position (RoleID) does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate unique email
        IF EXISTS (SELECT 1 FROM Employee WHERE email = @Email)
        BEGIN
            RAISERROR('Email already exists for another employee.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert new employee profile
        INSERT INTO Employee (
            first_name,
            last_name,
            national_id,
            date_of_birth,
            country_of_birth,
            email,
            phone,
            department_id,
            position_id,
            hire_date,
            is_active,
            profile_completion,
            account_status,
            employment_status
        )
        VALUES (
            @FirstName,
            @LastName,
            @NationalID,
            @DateOfBirth,
            @CountryOfBirth,
            @Email,
            @Phone,
            @DepartmentID,
            @RoleID,
            @HireDate,
            1,                 -- active
            0,                 -- profile incomplete
            'Active',
            'Full-time'
        );

        DECLARE @NewEmployeeID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewEmployeeID AS EmployeeID,
            'Employee profile created successfully.' AS Message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO



-- 12 UpdateEmployeeProfile
-- PROCEDURE: UpdateEmployeeProfile
CREATE PROCEDURE UpdateEmployeeProfile
    @EmployeeID INT,
    @FieldName VARCHAR(50),
    @NewValue VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- VALID FIELD LIST (PREVENTS SQL INJECTION & INVALID COLUMN ERRORS)
        ----------------------------------------------------------------------
        DECLARE @AllowedFields TABLE (field_name VARCHAR(50));
        INSERT INTO @AllowedFields VALUES
            ('first_name'),
            ('last_name'),
            ('email'),
            ('phone'),
            ('address'),
            ('emergency_contact_name'),
            ('emergency_contact_phone'),
            ('biography'),
            ('employment_status'),
            ('account_status');

        IF NOT EXISTS (SELECT 1 FROM @AllowedFields WHERE field_name = @FieldName)
        BEGIN
            RAISERROR('Invalid or unauthorized field name.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- PREVENT DUPLICATE EMAILS
        ----------------------------------------------------------------------
        IF @FieldName = 'email'
        BEGIN
            IF EXISTS (SELECT 1 FROM Employee WHERE email = @NewValue AND employee_id <> @EmployeeID)
            BEGIN
                RAISERROR('Email already exists for another employee.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;
        END;

        ----------------------------------------------------------------------
        -- DYNAMIC SQL TO UPDATE ONLY VALID FIELD NAMES
        ----------------------------------------------------------------------
        DECLARE @SQL NVARCHAR(MAX) =
            N'UPDATE Employee SET ' + QUOTENAME(@FieldName) + N' = @Value WHERE employee_id = @ID';

        EXEC sys.sp_executesql 
            @SQL,
            N'@Value VARCHAR(255), @ID INT',
            @Value = @NewValue,
            @ID = @EmployeeID;

        COMMIT TRANSACTION;

        SELECT 'Employee profile updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 13 SetProfileCompleteness
-- PROCEDURE: SetProfileCompleteness
CREATE PROCEDURE SetProfileCompleteness
    @EmployeeID INT,
    @CompletenessPercentage INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate range (0–100)
        IF @CompletenessPercentage < 0 OR @CompletenessPercentage > 100
        BEGIN
            RAISERROR('Completeness percentage must be between 0 and 100.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update completeness
        UPDATE Employee
        SET profile_completion = @CompletenessPercentage
        WHERE employee_id = @EmployeeID;

        COMMIT TRANSACTION;

        SELECT 
            'Profile completeness updated to ' 
            + CAST(@CompletenessPercentage AS VARCHAR(10)) + '%' AS ConfirmationMessage,
            @CompletenessPercentage AS UpdatedCompleteness;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 14 GenerateProfileReport
-- PROCEDURE: GenerateProfileReport
CREATE PROCEDURE GenerateProfileReport
    @FilterField VARCHAR(50),
    @FilterValue VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------------------
    -- VALIDATION OF ALLOWED FILTER FIELDS (prevents SQL injection)
    --------------------------------------------------------------------
    DECLARE @Allowed TABLE (FieldName VARCHAR(50));
    INSERT INTO @Allowed VALUES
        ('department'),
        ('employment_status'),
        ('country_of_birth'),
        ('all');

    IF NOT EXISTS (SELECT 1 FROM @Allowed WHERE FieldName = @FilterField)
    BEGIN
        RAISERROR('Invalid filter field.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------------------
    -- RETURN ALL EMPLOYEES IF FILTER = 'all'
    --------------------------------------------------------------------
    IF @FilterField = 'all'
    BEGIN
        SELECT 
            e.employee_id,
            e.full_name,
            e.email,
            e.phone,
            e.country_of_birth,
            d.department_name,
            p.position_title,
            e.hire_date,
            e.employment_status
        FROM Employee e
        LEFT JOIN Department d ON e.department_id = d.department_id
        LEFT JOIN Position p ON e.position_id = p.position_id;
        
        RETURN;
    END;

    --------------------------------------------------------------------
    -- FILTER BY SPECIFIC FIELDS
    --------------------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.country_of_birth,
        d.department_name,
        p.position_title,
        e.hire_date,
        e.employment_status
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE 
        (@FilterField = 'department' AND d.department_name = @FilterValue)
        OR (@FilterField = 'employment_status' AND e.employment_status = @FilterValue)
        OR (@FilterField = 'country_of_birth' AND e.country_of_birth = @FilterValue);
END;
GO


-- 15 CreateShiftType
-- PROCEDURE: CreateShiftType


USE HRMS;
GO

CREATE OR ALTER PROCEDURE CreateShiftType
    @ShiftID INT OUTPUT,  -- <--- CRITICAL FIX: Added 'OUTPUT' keyword
    @Name VARCHAR(100),
    @Type VARCHAR(50),
    @Start_Time TIME,
    @End_Time TIME,
    @Break_Duration INT,
    @Shift_Date DATE,
    @Status VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- We do NOT check IF EXISTS because shift_id is Identity (Auto-generated).
        -- We simply insert the data.

        INSERT INTO ShiftSchedule
        (
            name,
            type,
            start_time,
            end_time,
            break_duration,
            shift_date,
            status
        )
        VALUES
        (
            @Name,
            @Type,
            @Start_Time,
            @End_Time,
            @Break_Duration,
            @Shift_Date,
            @Status
        );

        -- CRITICAL FIX: Assign the new ID to the Output parameter so C# gets it
        SET @ShiftID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        -- Throw the error so the C# website knows something failed
        THROW;
    END CATCH
END;
GO



-- 17 AssignRotationalShift
-- PROCEDURE: AssignRotationalShift
CREATE PROCEDURE AssignRotationalShift
    @EmployeeID INT,
    @ShiftCycle INT,
    @StartDate DATE,
    @EndDate DATE,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------------
        -- Validate employee exists
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Validate shift cycle exists
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftCycle WHERE cycle_id = @ShiftCycle)
        BEGIN
            RAISERROR('Shift cycle does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Validate cycle has shift assignments
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftCycleAssignment WHERE cycle_id = @ShiftCycle)
        BEGIN
            RAISERROR('Shift cycle has no assigned shifts.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Insert one record per shift in the cycle (Morning/Evening/Night…)
        ------------------------------------------------------------------
        INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
        SELECT 
            @EmployeeID,
            sca.shift_id,
            @StartDate,
            @EndDate,
            @Status
        FROM ShiftCycleAssignment sca
        WHERE sca.cycle_id = @ShiftCycle
        ORDER BY sca.order_number;

        ------------------------------------------------------------------
        -- Return confirmation
        ------------------------------------------------------------------
        SELECT 
            'Rotational shift assigned successfully to employee ' +
            CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 18 NotifyShiftExpiry
-- PROCEDURE: NotifyShiftExpiry
CREATE PROCEDURE NotifyShiftExpiry
    @EmployeeID INT,
    @ShiftAssignmentID INT,
    @ExpiryDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- Validate Employee
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Validate Shift Assignment
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftAssignment WHERE assignment_id = @ShiftAssignmentID)
        BEGIN
            RAISERROR('Shift assignment does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Create Notification
        ------------------------------------------------------------
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your shift assignment ID ' + CAST(@ShiftAssignmentID AS VARCHAR(20)) +
            ' is expiring on ' + CONVERT(VARCHAR(10), @ExpiryDate, 120),
            'High',
            0,
            'Shift Expiry'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        ------------------------------------------------------------
        -- Assign notification to employee
        ------------------------------------------------------------
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (
            @EmployeeID,
            @NotifID,
            'Pending',
            GETDATE()
        );

        COMMIT TRANSACTION;

        SELECT 'Shift expiry notification sent successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 19 DefineShortTimeRules
-- PROCEDURE: DefineShortTimeRules
CREATE PROCEDURE DefineShortTimeRules
    @RuleName VARCHAR(50),
    @LateMinutes INT,
    @EarlyLeaveMinutes INT,
    @PenaltyType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate rule name
        IF LEN(@RuleName) = 0
        BEGIN
            RAISERROR('Rule name cannot be empty.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate minutes
        IF @LateMinutes < 0 OR @EarlyLeaveMinutes < 0
        BEGIN
            RAISERROR('Minutes cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert into PayrollPolicy
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Short Time',
            @RuleName + ' - Late penalty after ' + CAST(@LateMinutes AS VARCHAR(10)) +
            ' mins, Early leave penalty after ' + CAST(@EarlyLeaveMinutes AS VARCHAR(10)) +
            ' mins. Penalty type: ' + @PenaltyType
        );

        DECLARE @NewPolicyID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewPolicyID AS PolicyID,
            'Short time rule defined successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 20 SetGracePeriod
-- PROCEDURE: SetGracePeriod
CREATE PROCEDURE SetGracePeriod
    @Minutes INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- Validate minutes
        ------------------------------------------------------------
        IF @Minutes < 0
        BEGIN
            RAISERROR('Grace minutes cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Insert into PayrollPolicy
        ------------------------------------------------------------
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Lateness',
            'Grace period: First ' + CAST(@Minutes AS VARCHAR(10)) +
            ' minutes of lateness tolerated'
        );

        DECLARE @PolicyID INT = SCOPE_IDENTITY();

        ------------------------------------------------------------
        -- Insert into LatenessPolicy (required by schema)
        ------------------------------------------------------------
        INSERT INTO LatenessPolicy (policy_id, grace_period_mins, deduction_rate)
        VALUES (
            @PolicyID,
            @Minutes,
            0.00   -- No deduction during grace period
        );

        COMMIT TRANSACTION;

        SELECT 
            @PolicyID AS PolicyID,
            'Grace period set successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 21 DefinePenaltyThreshold
-- PROCEDURE: DefinePenaltyThreshold
CREATE PROCEDURE DefinePenaltyThreshold
    @LateMinutes INT,
    @DeductionType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- VALIDATIONS
        ------------------------------------------------------------

        -- Late minutes cannot be negative
        IF @LateMinutes < 0
        BEGIN
            RAISERROR('LateMinutes cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Deduction type must not be empty
        IF LEN(@DeductionType) = 0
        BEGIN
            RAISERROR('DeductionType cannot be empty.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- 1. Insert into PayrollPolicy
        ------------------------------------------------------------
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Lateness Penalty',
            'Penalty threshold: Lateness over ' + CAST(@LateMinutes AS VARCHAR(10)) +
            ' minutes. Deduction type: ' + @DeductionType
        );

        DECLARE @PolicyID INT = SCOPE_IDENTITY();

        ------------------------------------------------------------
        -- 2. Insert into DeductionPolicy (linked to PayrollPolicy)
        ------------------------------------------------------------
        INSERT INTO DeductionPolicy (policy_id, deduction_reason, calculation_mode)
        VALUES (
            @PolicyID,
            @DeductionType,
            'LateMinutes>' + CAST(@LateMinutes AS VARCHAR(10))
        );

        ------------------------------------------------------------
        -- SUCCESS
        ------------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 
            @PolicyID AS PolicyID,
            'Penalty threshold defined successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 22 DefinePermissionLimits
-- PROCEDURE: DefinePermissionLimits
CREATE PROCEDURE DefinePermissionLimits
    @MinHours INT,
    @MaxHours INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------
        -- VALIDATION
        ----------------------------------------------------------

        -- Hours cannot be negative
        IF @MinHours < 0 OR @MaxHours < 0
        BEGIN
            RAISERROR('Hours cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Max must be >= Min
        IF @MaxHours < @MinHours
        BEGIN
            RAISERROR('MaxHours must be greater than or equal to MinHours.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------
        -- INSERT INTO PayrollPolicy
        ----------------------------------------------------------
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Permission Limits',
            'Permission limits: MinHours=' + CAST(@MinHours AS VARCHAR(10)) +
            ', MaxHours=' + CAST(@MaxHours AS VARCHAR(10))
        );

        DECLARE @NewPolicyID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewPolicyID AS PolicyID,
            'Permission limits defined successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 23 EscalatePendingRequests
-- PROCEDURE: EscalatePendingRequests
CREATE PROCEDURE EscalatePendingRequests
    @Deadline DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- VALIDATION
        -------------------------------------------------------
        IF @Deadline IS NULL
        BEGIN
            RAISERROR('Deadline cannot be NULL.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- ESCALATE LEAVE REQUESTS
        -------------------------------------------------------
        UPDATE LeaveRequest
        SET status = 'Escalated'
        WHERE status = 'Pending'
          AND (approval_timing IS NULL OR approval_timing < @Deadline);

        DECLARE @EscLeave INT = @@ROWCOUNT;

        -------------------------------------------------------
        -- ESCALATE ATTENDANCE CORRECTIONS
        -------------------------------------------------------
        UPDATE AttendanceCorrectionRequest
        SET status = 'Escalated'
        WHERE status = 'Pending'
          AND [date] < @Deadline;

        DECLARE @EscAttend INT = @@ROWCOUNT;

        -------------------------------------------------------
        -- ESCALATE REIMBURSEMENT CLAIMS
        -------------------------------------------------------
        UPDATE Reimbursement
        SET current_status = 'Escalated'
        WHERE current_status = 'Pending'
          AND (approval_date IS NULL OR approval_date < @Deadline);

        DECLARE @EscReimb INT = @@ROWCOUNT;

        -------------------------------------------------------
        -- FINAL OUTPUT
        -------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 
            'Pending requests escalated successfully' AS ConfirmationMessage,
            @EscLeave AS EscalatedLeaveRequests,
            @EscAttend AS EscalatedAttendanceCorrections,
            @EscReimb AS EscalatedReimbursements;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 24 LinkVacationToShift
-- PROCEDURE: LinkVacationToShift
CREATE PROCEDURE LinkVacationToShift
    @VacationPackageID INT,
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -----------------------------------------------------------
        -- 1. Validate Employee Exists
        -----------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------------
        -- 2. Get Vacation Leave Type ID
        -----------------------------------------------------------
        DECLARE @LeaveTypeID INT;

        SELECT TOP 1 @LeaveTypeID = leave_id
        FROM [Leave]
        WHERE leave_type LIKE '%Vacation%';

        IF @LeaveTypeID IS NULL
        BEGIN
            RAISERROR('Vacation leave type does not exist in the system.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------------
        -- 3. Create Leave Entitlement if not exists
        -----------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID
              AND leave_type_id = @LeaveTypeID
        )
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            VALUES (@EmployeeID, @LeaveTypeID, 0);
        END

        -----------------------------------------------------------
        -- 4. Link vacation package to employee SHIFTS
        -- Mark all shift assignments as 'Vacation' for the package
        -----------------------------------------------------------
        UPDATE ShiftAssignment
        SET status = 'Vacation'
        WHERE employee_id = @EmployeeID;

        -----------------------------------------------------------
        -- 5. Return Confirmation
        -----------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 'Vacation package linked to employee schedule successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO



-- 25 ConfigureLeavePolicies
-- PROCEDURE: ConfigureLeavePolicies
CREATE PROCEDURE ConfigureLeavePolicies
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------
        -- Check if default leave policy already exists
        ------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 
            FROM LeavePolicy 
            WHERE name = 'Default Leave Policy'
        )
        BEGIN
            INSERT INTO LeavePolicy 
                (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
            VALUES (
                'Default Leave Policy',
                'Standard leave configuration',
                'All employees eligible',
                7,
                'Standard',
                1
            );
        END

        COMMIT TRANSACTION;

        SELECT 
            'Leave policies configured successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO



-- 26 AuthenticateLeaveAdmin
-- PROCEDURE: AuthenticateLeaveAdmin
CREATE PROCEDURE AuthenticateLeaveAdmin
    @AdminID INT,
    @Password VARCHAR(100)   -- Provided for signature only, not used
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------
    -- 1. Validate employee exists
    -------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @AdminID)
    BEGIN
        SELECT 'Authentication failed: Employee does not exist.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------------
    -- 2. Validate employee is an HR Administrator
    -------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM HRAdministrator WHERE employee_id = @AdminID)
    BEGIN
        SELECT 'Authentication failed: Employee is not an HR Administrator.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------------
    -- 3. Successful authentication (role-based)
    -------------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        hr.approval_level,
        'Administrator authenticated successfully' AS Message
    FROM Employee e
    INNER JOIN HRAdministrator hr ON e.employee_id = hr.employee_id
    WHERE e.employee_id = @AdminID;
END;
GO

-- 27 ApplyLeaveConfiguration
CREATE PROCEDURE ApplyLeaveConfiguration
AS
BEGIN
    -- Apply vacation leave (21 days)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        vl.leave_id,
        21.00
    FROM Employee e
    CROSS JOIN VacationLeave vl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = vl.leave_id
    );

    -- Apply sick leave (10 days)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        sl.leave_id,
        10.00
    FROM Employee e
    CROSS JOIN SickLeave sl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = sl.leave_id
    );

    -- Apply probation leave (5 days)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        pl.leave_id,
        5.00
    FROM Employee e
    CROSS JOIN ProbationLeave pl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = pl.leave_id
    );

    -- Apply holiday leave (0 days - marked by calendar)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        hl.leave_id,
        0.00
    FROM Employee e
    CROSS JOIN HolidayLeave hl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = hl.leave_id
    );

    SELECT 'Leave configuration applied successfully' AS ConfirmationMessage;
END;
GO
-- 28 UpdateLeaveEntitlements
-- PROCEDURE: UpdateLeaveEntitlements
CREATE PROCEDURE UpdateLeaveEntitlements
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- Validate employee exists
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Get employee contract type safely
        ------------------------------------------------------------
        DECLARE @ContractType VARCHAR(50);

        SELECT @ContractType = c.type
        FROM Employee e
        LEFT JOIN Contract c ON e.contract_id = c.contract_id
        WHERE e.employee_id = @EmployeeID;

        ------------------------------------------------------------
        -- Remove existing entitlements
        ------------------------------------------------------------
        DELETE FROM LeaveEntitlement
        WHERE employee_id = @EmployeeID;

        ------------------------------------------------------------
        -- VACATION: FullTime = 21 days, PartTime = 10 days
        ------------------------------------------------------------
        IF @ContractType = 'FullTime'
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 21
            FROM VacationLeave;
        END
        ELSE IF @ContractType = 'PartTime'
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 10
            FROM VacationLeave;
        END

        ------------------------------------------------------------
        -- SICK: FullTime or PartTime → 10 days
        ------------------------------------------------------------
        IF @ContractType IN ('FullTime', 'PartTime')
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 10
            FROM SickLeave;
        END

        ------------------------------------------------------------
        -- PROBATION: employees hired within last 6 months
        ------------------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM Employee 
            WHERE employee_id = @EmployeeID
              AND DATEDIFF(MONTH, hire_date, GETDATE()) <= 6
        )
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 5
            FROM ProbationLeave;
        END

        ------------------------------------------------------------
        -- HOLIDAY: Everybody → 0 days
        ------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM HolidayLeave)
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 0
            FROM HolidayLeave;
        END

        COMMIT TRANSACTION;

        SELECT 'Leave entitlements updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


--29 ConfigureLeaveEligibility
CREATE PROCEDURE ConfigureLeaveEligibility
    @LeaveType VARCHAR(50),
    @MinTenure INT,
    @EmployeeType VARCHAR(50)
AS
BEGIN
    INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
    VALUES (
        @LeaveType + ' Eligibility Policy',
        'Eligibility configuration for ' + @LeaveType,
        'MinTenure=' + CAST(@MinTenure AS VARCHAR(10)) + ';EmployeeType=' + @EmployeeType,
        7,
        @LeaveType,
        1
    );

    SELECT 'Leave eligibility configured successfully' AS ConfirmationMessage;
END;
GO
-- 30 ManageLeaveTypes
-- PROCEDURE: ManageLeaveTypes
CREATE PROCEDURE ManageLeaveTypes
    @LeaveType VARCHAR(50),
    @Description VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------
        -- 1. Check if leave type already exists
        ------------------------------------------------------
        IF EXISTS (SELECT 1 FROM [Leave] WHERE leave_type = @LeaveType)
        BEGIN
            -- Update existing leave description
            UPDATE [Leave]
            SET leave_description = @Description
            WHERE leave_type = @LeaveType;

            COMMIT TRANSACTION;

            SELECT 'Leave type updated successfully' AS ConfirmationMessage;
            RETURN;
        END

        ------------------------------------------------------
        -- 2. Insert new leave type
        ------------------------------------------------------
        INSERT INTO [Leave] (leave_type, leave_description)
        VALUES (@LeaveType, @Description);

        COMMIT TRANSACTION;

        SELECT 'New leave type created successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 'Error: Leave type could not be created or updated.' AS ConfirmationMessage;
    END CATCH

END;
GO



-- 31 AssignLeaveEntitlement
-- PROCEDURE: AssignLeaveEntitlement
CREATE PROCEDURE AssignLeaveEntitlement
    @EmployeeID INT,
    @LeaveType VARCHAR(50),
    @Entitlement DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------
        -- 1. Validate employee exists
        ----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- 2. Validate leave type exists
        ----------------------------------------------------
        DECLARE @LeaveTypeID INT;
        SELECT @LeaveTypeID = leave_id FROM [Leave] WHERE leave_type = @LeaveType;

        IF @LeaveTypeID IS NULL
        BEGIN
            RAISERROR('Invalid leave type.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- 3. Update if entitlement exists
        ----------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID AND leave_type_id = @LeaveTypeID
        )
        BEGIN
            UPDATE LeaveEntitlement
            SET entitlement = @Entitlement
            WHERE employee_id = @EmployeeID AND leave_type_id = @LeaveTypeID;

            COMMIT TRANSACTION;

            SELECT 'Entitlement updated successfully.' AS ConfirmationMessage;
            RETURN;
        END;

        ----------------------------------------------------
        -- 4. Insert new entitlement
        ----------------------------------------------------
        INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
        VALUES (@EmployeeID, @LeaveTypeID, @Entitlement);

        COMMIT TRANSACTION;

        SELECT 'Entitlement assigned successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 32 ConfigureLeaveRules
-- PROCEDURE: ConfigureLeaveRules
CREATE PROCEDURE ConfigureLeaveRules
    @LeaveType VARCHAR(50),
    @MaxDuration INT,
    @NoticePeriod INT,
    @WorkflowType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------
        -- 1. Validate that LeaveType exists
        ----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM [Leave] WHERE leave_type = @LeaveType)
        BEGIN
            RAISERROR('Leave type does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- 2. Prevent duplicate rule creation
        ----------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM LeavePolicy
            WHERE special_leave_type = @LeaveType
              AND purpose LIKE 'Leave rules configuration%'
        )
        BEGIN
            RAISERROR('Rules for this leave type already exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- 3. Insert new rule
        ----------------------------------------------------
        INSERT INTO LeavePolicy
            (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
        VALUES (
            @LeaveType + ' Rules',
            'Leave rules configuration for ' + @LeaveType,
            'MaxDuration=' + CAST(@MaxDuration AS VARCHAR(10)) +
                ';WorkflowType=' + @WorkflowType,
            @NoticePeriod,
            @LeaveType,
            1
        );

        COMMIT TRANSACTION;

        SELECT 'Leave rules configured successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 33 ConfigureSpecialLeave
-- PROCEDURE: ConfigureSpecialLeave
CREATE PROCEDURE ConfigureSpecialLeave
    @LeaveType VARCHAR(50),
    @Rules VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- 1. Validate leave type exists
        -------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM [Leave] WHERE leave_type = @LeaveType)
        BEGIN
            RAISERROR('Leave type does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- 2. Prevent duplicate special-leave policy creation
        -------------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM LeavePolicy
            WHERE special_leave_type = @LeaveType
              AND purpose LIKE 'Special leave policy%'
        )
        BEGIN
            RAISERROR('A special leave policy for this type already exists.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- 3. Insert special leave policy
        -------------------------------------------------------
        INSERT INTO LeavePolicy
            (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
        VALUES (
            @LeaveType + ' Policy',
            'Special leave policy for ' + @LeaveType,
            @Rules,
            0,            -- special leaves have no notice period
            @LeaveType,
            0             -- does NOT reset yearly
        );

        COMMIT TRANSACTION;

        SELECT 'Special leave configured successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 34 SetLeaveYearRules
-- PROCEDURE: SetLeaveYearRules
CREATE PROCEDURE SetLeaveYearRules
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------
        -- 1. Validate Date Range
        ------------------------------------------------------
        IF @StartDate >= @EndDate
        BEGIN
            RAISERROR('Start date must be earlier than end date.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------
        -- 2. Prevent duplicate leave-year configuration
        ------------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM LeavePolicy
            WHERE name = 'Leave Year Configuration'
        )
        BEGIN
            RAISERROR('Leave year rules already exist. Update not allowed.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------
        -- 3. Insert the leave-year configuration
        ------------------------------------------------------
        INSERT INTO LeavePolicy
            (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
        VALUES (
            'Leave Year Configuration',
            'Defines the legal leave year period and reset rules',
            'StartDate=' + CAST(@StartDate AS VARCHAR(20)) + ';EndDate=' + CAST(@EndDate AS VARCHAR(20)),
            0,
            'Annual Reset',
            1
        );

        COMMIT TRANSACTION;

        SELECT 'Leave year rules set successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 35 AdjustLeaveBalance
-- PROCEDURE: AdjustLeaveBalance
CREATE PROCEDURE AdjustLeaveBalance
    @EmployeeID INT,
    @LeaveType VARCHAR(50),
    @Adjustment DECIMAL(5,2)
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
        -- Validate leave type exists
        --------------------------------------------------------
        DECLARE @LeaveTypeID INT;
        SELECT @LeaveTypeID = leave_id FROM [Leave] WHERE leave_type = @LeaveType;

        IF @LeaveTypeID IS NULL
        BEGIN
            RAISERROR('Invalid leave type.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        --------------------------------------------------------
        -- Validate entitlement exists
        --------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID
              AND leave_type_id = @LeaveTypeID
        )
        BEGIN
            RAISERROR('Employee does not have this leave entitlement.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        --------------------------------------------------------
        -- Apply the adjustment
        --------------------------------------------------------
        UPDATE LeaveEntitlement
        SET entitlement = entitlement + @Adjustment
        WHERE employee_id = @EmployeeID
          AND leave_type_id = @LeaveTypeID;

        COMMIT TRANSACTION;

        SELECT 'Leave balance adjusted successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 36 ManageLeaveRoles
-- PROCEDURE: ManageLeaveRoles
CREATE PROCEDURE ManageLeaveRoles
    @RoleID INT,
    @Permissions VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------
        -- 1. Validate role exists
        ----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Role WHERE role_id = @RoleID)
        BEGIN
            RAISERROR('Role does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------
        -- 2. Check if permission already exists
        ----------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM RolePermission
            WHERE role_id = @RoleID
              AND permission_name = 'Leave Management'
        )
        BEGIN
            -- Update existing permission
            UPDATE RolePermission
            SET allowed_action = @Permissions
            WHERE role_id = @RoleID
              AND permission_name = 'Leave Management';

            COMMIT TRANSACTION;
            SELECT 'Leave role permissions updated successfully' AS ConfirmationMessage;
            RETURN;
        END;

        ----------------------------------------------------
        -- 3. Insert new permission
        ----------------------------------------------------
        INSERT INTO RolePermission (role_id, permission_name, allowed_action)
        VALUES (@RoleID, 'Leave Management', @Permissions);

        COMMIT TRANSACTION;

        SELECT 'Leave role permissions created successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 37 FinalizeLeaveRequest
-- PROCEDURE: FinalizeLeaveRequest
CREATE PROCEDURE FinalizeLeaveRequest
    @LeaveRequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- 1. Validate leave request exists and is approved
        ---------------------------------------------------------
        DECLARE @EmployeeID INT;
        DECLARE @LeaveTypeID INT;
        DECLARE @Duration DECIMAL(5,2);
        DECLARE @Status VARCHAR(50);

        SELECT 
            @EmployeeID = employee_id,
            @LeaveTypeID = leave_id,
            @Duration = duration,
            @Status = status
        FROM LeaveRequest
        WHERE request_id = @LeaveRequestID;

        IF @EmployeeID IS NULL
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @Status <> 'Approved'
        BEGIN
            RAISERROR('Only approved requests can be finalized.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 2. Validate entitlement exists
        ---------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID
              AND leave_type_id = @LeaveTypeID
        )
        BEGIN
            RAISERROR('Employee does not have this leave entitlement.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 3. Validate leave balance is enough
        ---------------------------------------------------------
        IF (SELECT entitlement FROM LeaveEntitlement 
            WHERE employee_id = @EmployeeID 
              AND leave_type_id = @LeaveTypeID) < @Duration
        BEGIN
            RAISERROR('Insufficient leave balance.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 4. Finalize request
        ---------------------------------------------------------
        UPDATE LeaveRequest
        SET status = 'Finalized'
        WHERE request_id = @LeaveRequestID;

        ---------------------------------------------------------
        -- 5. Deduct entitlement
        ---------------------------------------------------------
        UPDATE LeaveEntitlement
        SET entitlement = entitlement - @Duration
        WHERE employee_id = @EmployeeID
          AND leave_type_id = @LeaveTypeID;

        COMMIT TRANSACTION;

        SELECT 'Leave request finalized successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 38 OverrideLeaveDecision
-- PROCEDURE: OverrideLeaveDecision
CREATE PROCEDURE OverrideLeaveDecision
    @LeaveRequestID INT,
    @Reason VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        --------------------------------------------------------
        -- 1. Validate request exists and retrieve required fields
        --------------------------------------------------------
        DECLARE @CurrentStatus VARCHAR(50);
        DECLARE @Justification VARCHAR(MAX);

        SELECT 
            @CurrentStatus = status,
            @Justification = justification
        FROM LeaveRequest
        WHERE request_id = @LeaveRequestID;

        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        --------------------------------------------------------
        -- 2. Only approved or rejected requests may be overridden
        --------------------------------------------------------
        IF @CurrentStatus NOT IN ('Approved', 'Rejected')
        BEGIN
            RAISERROR('Only Approved or Rejected requests can be overridden.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        --------------------------------------------------------
        -- 3. Ensure justification is not NULL
        --------------------------------------------------------
        SET @Justification = ISNULL(@Justification, '');

        --------------------------------------------------------
        -- 4. Perform the override logic
        --------------------------------------------------------
        IF @CurrentStatus = 'Rejected'
        BEGIN
            UPDATE LeaveRequest
            SET status = 'Approved - Override',
                justification = @Justification + ' | Override Reason: ' + @Reason
            WHERE request_id = @LeaveRequestID;
        END
        ELSE IF @CurrentStatus = 'Approved'
        BEGIN
            UPDATE LeaveRequest
            SET status = 'Rejected - Override',
                justification = @Justification + ' | Override Reason: ' + @Reason
            WHERE request_id = @LeaveRequestID;
        END;

        COMMIT TRANSACTION;

        SELECT 'Leave decision overridden successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 39 BulkProcessLeaveRequests
-- PROCEDURE: BulkProcessLeaveRequests
CREATE PROCEDURE BulkProcessLeaveRequests
    @LeaveRequestIDs VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        --------------------------------------------------------
        -- 1. Parse IDs safely
        --------------------------------------------------------
        IF @LeaveRequestIDs IS NULL OR LTRIM(RTRIM(@LeaveRequestIDs)) = ''
        BEGIN
            RAISERROR('No LeaveRequest IDs were provided.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        --------------------------------------------------------
        -- 2. Only approve requests that exist AND are still pending
        --------------------------------------------------------
        UPDATE LeaveRequest
        SET status = 'Approved',
            approval_timing = GETDATE()
        WHERE request_id IN (SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@LeaveRequestIDs, ','))
          AND status = 'Pending';

        --------------------------------------------------------
        -- 3. Return number of affected rows
        --------------------------------------------------------
        DECLARE @Count INT = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT 
            @Count AS ProcessedRequests,
            'Leave requests processed successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 40 VerifyMedicalLeave
-- PROCEDURE: VerifyMedicalLeave
CREATE PROCEDURE VerifyMedicalLeave
    @LeaveRequestID INT,
    @DocumentID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- 1. Validate leave request exists AND is sick leave
        ---------------------------------------------------------
        DECLARE @LeaveType VARCHAR(50);

        SELECT @LeaveType = L.leave_type
        FROM LeaveRequest LR
        JOIN [Leave] L ON LR.leave_id = L.leave_id
        WHERE LR.request_id = @LeaveRequestID;

        IF @LeaveType IS NULL
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @LeaveType <> 'Sick'
        BEGIN
            RAISERROR('Medical verification only applies to Sick Leave.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 2. Validate document exists and is linked to this request
        ---------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM LeaveDocument
            WHERE document_id = @DocumentID
              AND leave_request_id = @LeaveRequestID
        )
        BEGIN
            RAISERROR('Document does not match this leave request.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 3. Mark the document as verified
        ---------------------------------------------------------
        UPDATE LeaveDocument
        SET file_path = ISNULL(file_path, '') + ' | Verified'
        WHERE document_id = @DocumentID;

        ---------------------------------------------------------
        -- 4. Update leave request status
        ---------------------------------------------------------
        UPDATE LeaveRequest
        SET status = 'Approved - Document Verified',
            approval_timing = GETDATE()
        WHERE request_id = @LeaveRequestID;

        COMMIT TRANSACTION;

        SELECT 'Medical leave document verified successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 41 SyncLeaveBalances
-- PROCEDURE: SyncLeaveBalances
CREATE PROCEDURE SyncLeaveBalances
    @LeaveRequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- 1. Validate leave request exists and is approved/finalized
        ---------------------------------------------------------
        DECLARE @EmployeeID INT;
        DECLARE @LeaveTypeID INT;
        DECLARE @Duration DECIMAL(5,2);
        DECLARE @Status VARCHAR(50);

        SELECT 
            @EmployeeID = employee_id,
            @LeaveTypeID = leave_id,
            @Duration = duration,
            @Status = status
        FROM LeaveRequest
        WHERE request_id = @LeaveRequestID;

        IF @EmployeeID IS NULL
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @Status NOT IN ('Approved', 'Finalized', 'Approved - Document Verified')
        BEGIN
            RAISERROR('Leave balance can only be synced after approval.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 2. Prevent double deduction
        ---------------------------------------------------------
        IF @Status = 'Approved - Balance Updated'
        BEGIN
            RAISERROR('Leave balance already synced for this request.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 3. Validate entitlement exists and sufficient balance
        ---------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID
              AND leave_type_id = @LeaveTypeID
        )
        BEGIN
            RAISERROR('Employee does not have this leave entitlement.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF (SELECT entitlement FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID
              AND leave_type_id = @LeaveTypeID) < @Duration
        BEGIN
            RAISERROR('Insufficient leave balance.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 4. Deduct balance
        ---------------------------------------------------------
        UPDATE LeaveEntitlement
        SET entitlement = entitlement - @Duration
        WHERE employee_id = @EmployeeID
          AND leave_type_id = @LeaveTypeID;

        ---------------------------------------------------------
        -- 5. Update request status
        ---------------------------------------------------------
        UPDATE LeaveRequest
        SET status = 'Approved - Balance Updated'
        WHERE request_id = @LeaveRequestID;

        COMMIT TRANSACTION;

        SELECT 'Leave balances synced successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 42 ProcessLeaveCarryForward
-- PROCEDURE: ProcessLeaveCarryForward
CREATE PROCEDURE ProcessLeaveCarryForward
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------
        -- 1. Validate that leave policies exist
        ---------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM LeavePolicy)
        BEGIN
            RAISERROR('Leave policies are not configured.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------
        -- 2. Process carry-forward using policy + vacation rules
        ---------------------------------------------------------
        UPDATE le
        SET le.entitlement =
            CASE
                -------------------------------------------------------------------
                -- Case A: Leave type does not reset (reset_on_new_year = 0)
                -------------------------------------------------------------------
                WHEN lp.reset_on_new_year = 0 THEN le.entitlement

                -------------------------------------------------------------------
                -- Case B: Vacation leave with carry-over limit
                -------------------------------------------------------------------
                WHEN vl.carry_over_days IS NOT NULL AND le.entitlement > vl.carry_over_days
                    THEN vl.carry_over_days

                WHEN vl.carry_over_days IS NOT NULL
                    THEN le.entitlement

                -------------------------------------------------------------------
                -- Case C: Leave types that reset (reset_on_new_year = 1)
                -------------------------------------------------------------------
                WHEN lp.reset_on_new_year = 1 THEN 0

                -------------------------------------------------------------------
                -- Default: keep the same balance
                -------------------------------------------------------------------
                ELSE le.entitlement
            END
        FROM LeaveEntitlement le
        JOIN [Leave] l ON le.leave_type_id = l.leave_id
        LEFT JOIN VacationLeave vl ON l.leave_id = vl.leave_id
        LEFT JOIN LeavePolicy lp ON lp.special_leave_type = l.leave_type;

        ---------------------------------------------------------
        -- 3. Return confirmation
        ---------------------------------------------------------
        SELECT
            'Leave carry-forward processed for year ' 
            + CAST(@Year AS VARCHAR(10)) 
            + ' successfully' AS ConfirmationMessage;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 43 SyncLeaveToAttendance
-- PROCEDURE: SyncLeaveToAttendance
CREATE PROCEDURE SyncLeaveToAttendance
    @LeaveRequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------
        -- 1. Read request details
        ----------------------------------------------------------
        DECLARE @EmployeeID INT;
        DECLARE @LeaveType VARCHAR(50);
        DECLARE @Duration INT;
        DECLARE @Status VARCHAR(50);
        DECLARE @StartDate DATE;
        DECLARE @EndDate DATE;

        SELECT 
            @EmployeeID = lr.employee_id,
            @LeaveType = l.leave_type,
            @Duration = lr.duration,
            @Status = lr.status,
            @StartDate = lr.approval_timing,
            @EndDate = DATEADD(DAY, lr.duration - 1, lr.approval_timing)
        FROM LeaveRequest lr
        JOIN [Leave] l ON lr.leave_id = l.leave_id
        WHERE lr.request_id = @LeaveRequestID;

        ----------------------------------------------------------
        -- 2. Validate leave exists
        ----------------------------------------------------------
        IF @EmployeeID IS NULL
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------
        -- 3. Only approved/finalized leave syncs to attendance
        ----------------------------------------------------------
        IF @Status NOT IN ('Approved', 'Finalized', 'Approved - Balance Updated', 'Approved - Document Verified')
        BEGIN
            RAISERROR('Only approved or finalized leave can sync to attendance.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------
        -- 4. Loop through each leave day and insert exception
        ----------------------------------------------------------
        DECLARE @i INT = 0;
        DECLARE @CurrentDate DATE;

        WHILE @i < @Duration
        BEGIN
            SET @CurrentDate = DATEADD(DAY, @i, @StartDate);

            INSERT INTO [Exception] ([name], category, [date], status)
            VALUES (
                @LeaveType + ' Leave',
                'Leave',
                @CurrentDate,
                'Active'
            );

            DECLARE @ExceptionID INT = SCOPE_IDENTITY();

            INSERT INTO Employee_Exception (employee_id, exception_id)
            VALUES (@EmployeeID, @ExceptionID);

            SET @i = @i + 1;
        END;

        ----------------------------------------------------------
        -- 5. Return success
        ----------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 'Leave synced to attendance successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

--- 44 UpdateInsuranceBrackets
-- PROCEDURE: UpdateInsuranceBrackets
CREATE PROCEDURE UpdateInsuranceBrackets
    @BracketID INT,
    @NewMinSalary DECIMAL(10,2),
    @NewMaxSalary DECIMAL(10,2),
    @NewEmployeeContribution DECIMAL(5,2),
    @NewEmployerContribution DECIMAL(5,2),
    @UpdatedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------
        -- 1. Validate insurance bracket exists
        ------------------------------------------------------
        DECLARE @InsuranceType VARCHAR(50);

        SELECT @InsuranceType = [type]
        FROM Insurance
        WHERE insurance_id = @BracketID;

        IF @InsuranceType IS NULL
        BEGIN
            RAISERROR('Insurance bracket does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------
        -- 2. Validate updater exists
        ------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @UpdatedBy)
        BEGIN
            RAISERROR('UpdatedBy employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------
        -- 3. Update bracket details
        ------------------------------------------------------
        UPDATE Insurance
        SET contribution_rate = @NewEmployeeContribution,
            coverage = 'MinSalary=' + CAST(@NewMinSalary AS VARCHAR(20)) +
                       ';MaxSalary=' + CAST(@NewMaxSalary AS VARCHAR(20)) +
                       ';EmployerContribution=' + CAST(@NewEmployerContribution AS VARCHAR(20))
        WHERE insurance_id = @BracketID;

        ------------------------------------------------------
        -- 4. Create notification
        ------------------------------------------------------
        INSERT INTO Notification (message_content, urgency, notification_type)
        VALUES (
            'Insurance bracket ID ' + CAST(@BracketID AS VARCHAR(10)) + 
            ' (' + @InsuranceType + ') updated by Employee ID ' + CAST(@UpdatedBy AS VARCHAR(10)) +
            '. New salary range: ' + CAST(@NewMinSalary AS VARCHAR(20)) + ' - ' + CAST(@NewMaxSalary AS VARCHAR(20)) +
            '. Employee contribution: ' + CAST(@NewEmployeeContribution AS VARCHAR(20)) + 
            '%, Employer contribution: ' + CAST(@NewEmployerContribution AS VARCHAR(20)) + '%',
            'Medium',
            'Insurance Update'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        ------------------------------------------------------
        -- 5. Assign notification to employee
        ------------------------------------------------------
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@UpdatedBy, @NotificationID, 'Delivered', GETDATE());

        ------------------------------------------------------
        -- 6. Confirmation
        ------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 'Insurance bracket updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 45 ApprovePolicyUpdate
-- PROCEDURE: ApprovePolicyUpdate
CREATE OR ALTER PROCEDURE ApprovePolicyUpdate
    @PolicyID INT,
    @ApprovedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -----------------------------------------------------
        -- 1. Validate policy exists
        -----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM PayrollPolicy WHERE policy_id = @PolicyID)
        BEGIN
            RAISERROR('Policy ID does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------
        -- 2. Validate approver exists
        -----------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApprovedBy)
        BEGIN
            RAISERROR('Approving employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------
        -- 3. Update policy description with approval info
        -----------------------------------------------------
        UPDATE PayrollPolicy
        SET description = description 
                          + ' | Approved by Employee ' + CAST(@ApprovedBy AS VARCHAR(10))
                          + ' on ' + CONVERT(VARCHAR(10), GETDATE(), 120)
        WHERE policy_id = @PolicyID;

        -----------------------------------------------------
        -- 4. Create notification
        -----------------------------------------------------
        INSERT INTO Notification (message_content, urgency, notification_type)
        VALUES (
            'Payroll policy ID ' + CAST(@PolicyID AS VARCHAR(10)) 
            + ' has been approved by Employee ID ' + CAST(@ApprovedBy AS VARCHAR(10)),
            'High',
            'Policy Approval'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -----------------------------------------------------
        -- 5. Deliver notification to approver
        -----------------------------------------------------
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@ApprovedBy, @NotificationID, 'Delivered', GETDATE());

        -----------------------------------------------------
        -- 6. Return confirmation
        -----------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 'Policy update approved successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

 CREATE PROCEDURE GetIncompleteProfiles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.address,
        e.emergency_contact_name,
        e.emergency_contact_phone,
        e.department_id,
        d.department_name,
        e.position_id,
        p.position_title,
        e.profile_image,

        -- COUNT missing fields
        (CASE WHEN e.email IS NULL OR e.email = '' THEN 1 ELSE 0 END +
         CASE WHEN e.phone IS NULL OR e.phone = '' THEN 1 ELSE 0 END +
         CASE WHEN e.address IS NULL OR e.address = '' THEN 1 ELSE 0 END +
         CASE WHEN e.emergency_contact_name IS NULL OR e.emergency_contact_name = '' THEN 1 ELSE 0 END +
         CASE WHEN e.emergency_contact_phone IS NULL OR e.emergency_contact_phone = '' THEN 1 ELSE 0 END +
         CASE WHEN e.department_id IS NULL THEN 1 ELSE 0 END +
         CASE WHEN e.position_id IS NULL THEN 1 ELSE 0 END +
         CASE WHEN e.profile_image IS NULL THEN 1 ELSE 0 END)
         AS MissingCount
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    ORDER BY MissingCount DESC;
END;
GO

CREATE OR ALTER PROCEDURE GetEmployeeSimpleList
AS
BEGIN
    SET NOCOUNT ON;

    SELECT employee_id, full_name 
    FROM Employee
    -- Optional: Only show active employees who can actually have contracts
    -- WHERE is_active = 1 
    ORDER BY full_name;
END;
GO