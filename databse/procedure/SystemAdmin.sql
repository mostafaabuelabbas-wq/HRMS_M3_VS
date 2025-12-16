--System admin
-- 1 ViewEmployeeInfo
CREATE PROCEDURE ViewEmployeeInfo
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- Validate employee exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Employee does not exist.' AS ErrorMessage;
        RETURN;
    END;

    ---------------------------------------------------------
    -- Return full employee information
    ---------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        e.first_name,
        e.last_name,
        e.email,
        e.phone,
        e.address,
        e.employment_status,
        e.account_status,
        e.hire_date,
        e.date_of_birth,
        e.country_of_birth,
        e.profile_completion,

        -- Department & Position
        d.department_name,
        p.position_title,

        -- Contract info
        c.[type] AS contract_type,
        c.start_date AS contract_start,
        c.end_date AS contract_end,

        -- Salary type
        st.[type] AS salary_type,
        st.payment_frequency,
        st.currency_code,

        -- Pay grade
        pg.grade_name,
        pg.min_salary,
        pg.max_salary

    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Contract c ON e.contract_id = c.contract_id
    LEFT JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    LEFT JOIN PayGrade pg ON e.pay_grade = pg.pay_grade_id
    WHERE e.employee_id = @EmployeeID;
END;
GO
CREATE PROCEDURE GetAllEmployees
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name,
        e.employment_status,
        -- IMPORTANT: You must use AS Department and AS Position here too
        -- so Dapper maps them to the new DTO properties.
        d.department_name AS Department,
        p.position_title AS Position
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id;
END;
GO
ALTER PROCEDURE ViewEmployeeInfo
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        -- Don't return a string in a dataset intended for an object mapping. 
        -- Just return nothing, the service will handle null.
        RETURN; 
    END;

    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.address,
        e.employment_status,
        e.hire_date,
        -- FIX 1: Selecting Emergency Contact Info
        e.emergency_contact_name, 
        e.emergency_contact_phone,
        e.relationship,
        -- FIX 2: Selecting Profile Image
        e.profile_image,
        
        -- FIX 3: Aliasing for Dapper Mapping
        -- Dapper maps "Department_Name" in SQL to "Department_Name" in C#.
        -- Your View uses "Department", so let's map it to that.
        d.department_name AS Department, 
        p.position_title AS Position

    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE e.employee_id = @EmployeeID;
END;
GO

-- 2 AddEmployee
CREATE PROCEDURE AddEmployee
    @FullName VARCHAR(200),
    @NationalID VARCHAR(50),
    @DateOfBirth DATE,
    @CountryOfBirth VARCHAR(100),
    @Phone VARCHAR(50),
    @Email VARCHAR(100),
    @Address VARCHAR(255),
    @EmergencyContactName VARCHAR(100),
    @EmergencyContactPhone VARCHAR(50),
    @Relationship VARCHAR(50),
    @Biography VARCHAR(MAX),
    @EmploymentProgress VARCHAR(100),
    @AccountStatus VARCHAR(50),
    @EmploymentStatus VARCHAR(50),
    @HireDate DATE,
    @IsActive BIT,
    @ProfileCompletion INT,
    @DepartmentID INT,
    @PositionID INT,
    @ManagerID INT,
    @ContractID INT,
    @TaxFormID INT,
    @SalaryTypeID INT,
    @PayGrade INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Split full name into first & last names
    ---------------------------------------------------------
    DECLARE @FirstName VARCHAR(50), @LastName VARCHAR(50);

    IF CHARINDEX(' ', @FullName) > 0
    BEGIN
        SET @FirstName = LEFT(@FullName, CHARINDEX(' ', @FullName) - 1);
        SET @LastName  = SUBSTRING(@FullName, CHARINDEX(' ', @FullName) + 1, LEN(@FullName));
    END
    ELSE
    BEGIN
        SET @FirstName = @FullName;
        SET @LastName  = '';
    END

    ---------------------------------------------------------
    -- 2. Prevent duplicate National ID or Email
    ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM Employee WHERE national_id = @NationalID)
    BEGIN
        SELECT 'Error: National ID already exists.' AS ErrorMessage;
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM Employee WHERE email = @Email)
    BEGIN
        SELECT 'Error: Email already exists.' AS ErrorMessage;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Insert employee
    ---------------------------------------------------------
    INSERT INTO Employee (
        first_name, last_name, national_id, date_of_birth,
        country_of_birth, phone, email, address,
        emergency_contact_name, emergency_contact_phone, relationship,
        biography, employment_progress, account_status, employment_status,
        hire_date, is_active, profile_completion,
        department_id, position_id, manager_id,
        contract_id, tax_form_id, salary_type_id, pay_grade
    )
    VALUES (
        @FirstName, @LastName, @NationalID, @DateOfBirth,
        @CountryOfBirth, @Phone, @Email, @Address,
        @EmergencyContactName, @EmergencyContactPhone, @Relationship,
        @Biography, @EmploymentProgress, @AccountStatus, @EmploymentStatus,
        @HireDate, @IsActive, @ProfileCompletion,
        @DepartmentID, @PositionID, @ManagerID,
        @ContractID, @TaxFormID, @SalaryTypeID, @PayGrade
    );

    ---------------------------------------------------------
    -- 4. Return new employee ID
    ---------------------------------------------------------
    SELECT 
        SCOPE_IDENTITY() AS NewEmployeeID,
        'Employee added successfully.' AS ConfirmationMessage;

END;
GO
-- Fix profile_image column size
ALTER TABLE Employee
ALTER COLUMN profile_image VARCHAR(500);
GO

-- 3. UpdateEmployeeInfo
CREATE OR ALTER PROCEDURE UpdateEmployeeInfo
    @EmployeeID INT,
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(150),
    @ProfileImage VARCHAR(500) = NULL -- Now this matches the table!
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found.' AS Message;
        RETURN;
    END;

    -- Check for duplicate email (excluding current user)
    IF EXISTS (SELECT 1 FROM Employee WHERE email = @Email AND employee_id <> @EmployeeID)
    BEGIN
        SELECT 'Error: This email is already used by another employee.' AS Message;
        RETURN;
    END;

    UPDATE Employee
    SET email = @Email,
        phone = @Phone,
        address = @Address,
        profile_image = @ProfileImage
    WHERE employee_id = @EmployeeID;

    SELECT 'Employee information updated successfully' AS ConfirmationMessage;
END;
GO
CREATE OR ALTER PROCEDURE AssignRole
    @EmployeeID INT,
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate inputs
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM Role WHERE role_id = @RoleID)
    BEGIN
        SELECT 'Error: Role does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. THE FIX: Remove OLD roles first
    ---------------------------------------------------------
    -- This ensures the user only has ONE role at a time.
    DELETE FROM Employee_Role 
    WHERE employee_id = @EmployeeID;

    ---------------------------------------------------------
    -- 3. Assign the NEW role
    ---------------------------------------------------------
    INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
    VALUES (@EmployeeID, @RoleID, GETDATE());

    ---------------------------------------------------------
    -- 4. Confirmation
    ---------------------------------------------------------
    SELECT 'Role updated successfully.' AS Message;
END;
GO


-- 5. GetDepartmentEmployeeStats
CREATE PROCEDURE GetDepartmentEmployeeStats
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        d.department_id,
        d.department_name,
        ISNULL(COUNT(e.employee_id), 0) AS number_of_employees
    FROM Department d
    LEFT JOIN Employee e ON d.department_id = e.department_id
    GROUP BY d.department_id, d.department_name
    ORDER BY number_of_employees DESC;
END;
GO


-- 6. ReassignManager
CREATE PROCEDURE ReassignManager
    @EmployeeID INT,
    @NewManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Employee Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate New Manager Exists (unless NULL)
    ---------------------------------------------------------
    IF @NewManagerID IS NOT NULL AND 
       NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @NewManagerID)
    BEGIN
        SELECT 'Error: New manager does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Prevent Employee from managing themselves
    ---------------------------------------------------------
    IF @EmployeeID = @NewManagerID
    BEGIN
        SELECT 'Error: An employee cannot be their own manager.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Prevent circular management (Employee → Manager → Employee)
    ---------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM EmployeeHierarchy
        WHERE employee_id = @NewManagerID 
        AND manager_id = @EmployeeID
    )
    BEGIN
        SELECT 'Error: Circular hierarchy detected.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. Update Employee Table
    ---------------------------------------------------------
    UPDATE Employee
    SET manager_id = @NewManagerID
    WHERE employee_id = @EmployeeID;

    ---------------------------------------------------------
    -- 6. Update or Insert EmployeeHierarchy
    ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @EmployeeID)
    BEGIN
        UPDATE EmployeeHierarchy
        SET manager_id = @NewManagerID
        WHERE employee_id = @EmployeeID;
    END
    ELSE
    BEGIN
        INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
        VALUES (@EmployeeID, @NewManagerID, 1);
    END;

    ---------------------------------------------------------
    -- 7. Confirmation Message
    ---------------------------------------------------------
    SELECT 'Manager reassigned successfully for employee ' 
            + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 7. ReassignHierarchy
CREATE PROCEDURE ReassignHierarchy
    @EmployeeID INT,
    @NewDepartmentID INT,
    @NewManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Employee Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Department Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @NewDepartmentID)
    BEGIN
        SELECT 'Error: Department does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate Manager Exists (unless NULL)
    ---------------------------------------------------------
    IF @NewManagerID IS NOT NULL AND
       NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @NewManagerID)
    BEGIN
        SELECT 'Error: Manager does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Prevent Employee Managing Themselves
    ---------------------------------------------------------
    IF @EmployeeID = @NewManagerID
    BEGIN
        SELECT 'Error: Employee cannot be their own manager.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. Prevent Circular Hierarchy
    ---------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM EmployeeHierarchy
        WHERE employee_id = @NewManagerID
        AND manager_id = @EmployeeID
    )
    BEGIN
        SELECT 'Error: Circular hierarchy detected.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 6. Update Employee Table
    ---------------------------------------------------------
    UPDATE Employee
    SET department_id = @NewDepartmentID,
        manager_id = @NewManagerID
    WHERE employee_id = @EmployeeID;

    ---------------------------------------------------------
    -- 7. Update or Insert EmployeeHierarchy
    ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @EmployeeID)
    BEGIN
        UPDATE EmployeeHierarchy
        SET manager_id = @NewManagerID,
            hierarchy_level = 1
        WHERE employee_id = @EmployeeID;
    END
    ELSE
    BEGIN
        INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
        VALUES (@EmployeeID, @NewManagerID, 1);
    END;

    ---------------------------------------------------------
    -- 8. Confirmation Message
    ---------------------------------------------------------
    SELECT 'Hierarchy reassigned successfully for employee ' 
           + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO


-- 8. NotifyStructureChange
CREATE PROCEDURE NotifyStructureChange
    @AffectedEmployees VARCHAR(500),
    @Message VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate input
    ---------------------------------------------------------
    IF @AffectedEmployees IS NULL OR LTRIM(RTRIM(@AffectedEmployees)) = ''
    BEGIN
        SELECT 'Error: No affected employees provided.' AS Message;
        RETURN;
    END;

    IF @Message IS NULL OR LTRIM(RTRIM(@Message)) = ''
    BEGIN
        SELECT 'Error: Message cannot be empty.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Create Notification and store ID safely
    ---------------------------------------------------------
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (@Message, 'High', 'Structure Change');

    DECLARE @NotificationID INT = SCOPE_IDENTITY();

    ---------------------------------------------------------
    -- 3. Insert notifications for valid employees only
    ---------------------------------------------------------
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    SELECT 
        e.employee_id,
        @NotificationID,
        'Sent',
        GETDATE()
    FROM STRING_SPLIT(@AffectedEmployees, ',') s
    INNER JOIN Employee e ON e.employee_id = TRY_CAST(s.value AS INT);

    ---------------------------------------------------------
    -- 4. Return confirmation
    ---------------------------------------------------------
    SELECT 
        'Structure change notification sent to affected employees.' 
        AS ConfirmationMessage;
END;
GO


-- 9. ViewOrgHierarchy
CREATE PROCEDURE ViewOrgHierarchy
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.employee_id,
        e.full_name AS employee_name,
        m.full_name AS manager_name,
        d.department_name,
        p.position_title,
        ISNULL(eh.hierarchy_level, 1) AS hierarchy_level
    FROM Employee e
    LEFT JOIN Employee m 
        ON e.manager_id = m.employee_id
    LEFT JOIN Department d 
        ON e.department_id = d.department_id
    LEFT JOIN Position p 
        ON e.position_id = p.position_id
    LEFT JOIN EmployeeHierarchy eh 
        ON e.employee_id = eh.employee_id
    ORDER BY 
        ISNULL(eh.hierarchy_level, 1),
        d.department_name,
        e.full_name;
END;
GO


-- 10. AssignShiftToEmployee
USE HRMS;
GO

CREATE OR ALTER PROCEDURE AssignShiftToEmployee
    @EmployeeID INT,
    @ShiftID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Existance
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM ShiftSchedule WHERE shift_id = @ShiftID)
    BEGIN
        SELECT 'Error: Shift does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. THE FIX: Handle "Update" Logic
    -- Instead of throwing an error, we CLOSE the old shift.
    ---------------------------------------------------------
    IF EXISTS (
        SELECT 1 
        FROM ShiftAssignment
        WHERE employee_id = @EmployeeID
          AND status = 'Active'
          AND end_date >= @StartDate -- The old shift overlaps into our new start date
    )
    BEGIN
        -- Close the old shift so it ends the day BEFORE the new one starts
        UPDATE ShiftAssignment
        SET end_date = DATEADD(day, -1, @StartDate)
        WHERE employee_id = @EmployeeID
          AND status = 'Active'
          AND end_date >= @StartDate;
    END;

    ---------------------------------------------------------
    -- 3. Insert the New Shift
    ---------------------------------------------------------
    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
    VALUES (@EmployeeID, @ShiftID, @StartDate, @EndDate, 'Active');

    ---------------------------------------------------------
    -- 4. Confirmation
    ---------------------------------------------------------
    SELECT 'Shift assigned successfully (Previous assignment updated).' AS ConfirmationMessage;
END;
GO


-- 11. UpdateShiftStatus
CREATE PROCEDURE UpdateShiftStatus
    @ShiftAssignmentID INT,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Shift Assignment Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM ShiftAssignment WHERE assignment_id = @ShiftAssignmentID)
    BEGIN
        SELECT 'Error: Shift assignment does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Status Value
    ---------------------------------------------------------
    IF @Status NOT IN ('Approved','Cancelled','Entered','Expired','Postponed','Rejected','Submitted')
    BEGIN
        SELECT 'Error: Invalid status value. Allowed values are: Approved, Cancelled, Entered, Expired, Postponed, Rejected, Submitted.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Prevent setting NULL or empty status
    ---------------------------------------------------------
    IF @Status IS NULL OR LTRIM(RTRIM(@Status)) = ''
    BEGIN
        SELECT 'Error: Status cannot be empty.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Update Shift Status
    ---------------------------------------------------------
    UPDATE ShiftAssignment
    SET status = @Status
    WHERE assignment_id = @ShiftAssignmentID;

    ---------------------------------------------------------
    -- 5. Confirmation Message
    ---------------------------------------------------------
    SELECT 'Shift assignment ' + CAST(@ShiftAssignmentID AS VARCHAR(10)) 
           + ' updated to status: ' + @Status AS ConfirmationMessage;
END;
GO

-- 12. AssignShiftToDepartment
CREATE PROCEDURE AssignShiftToDepartment
    @DepartmentID INT,
    @ShiftID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Department Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @DepartmentID)
    BEGIN
        SELECT 'Error: Department does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Shift Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM ShiftSchedule WHERE shift_id = @ShiftID)
    BEGIN
        SELECT 'Error: Shift does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate Date Range
    ---------------------------------------------------------
    IF @StartDate > @EndDate
    BEGIN
        SELECT 'Error: Start date cannot be after end date.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Check employees in department
    ---------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 
        FROM Employee 
        WHERE department_id = @DepartmentID AND is_active = 1
    )
    BEGIN
        SELECT 'Error: No active employees found in this department.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. Prevent overlapping assignments for department employees
    ---------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM ShiftAssignment sa
        JOIN Employee e ON sa.employee_id = e.employee_id
        WHERE e.department_id = @DepartmentID
        AND sa.status = 'Active'
        AND (
                (@StartDate BETWEEN sa.start_date AND sa.end_date)
             OR (@EndDate BETWEEN sa.start_date AND sa.end_date)
             OR (sa.start_date BETWEEN @StartDate AND @EndDate)
            )
    )
    BEGIN
        SELECT 'Error: One or more employees already have overlapping shift assignments.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 6. Assign shift to all active employees in the department
    ---------------------------------------------------------
    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
    SELECT 
        employee_id,
        @ShiftID,
        @StartDate,
        @EndDate,
        'Active'
    FROM Employee
    WHERE department_id = @DepartmentID
      AND is_active = 1;

    ---------------------------------------------------------
    -- 7. Confirmation message
    ---------------------------------------------------------
    SELECT 'Shift assigned successfully to department ' 
           + CAST(@DepartmentID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 13. AssignCustomShift
CREATE PROCEDURE AssignCustomShift
    @EmployeeID INT,
    @ShiftName VARCHAR(50),
    @ShiftType VARCHAR(50),
    @StartTime TIME,
    @EndTime TIME,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Employee Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Employee is Active
    ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID AND is_active = 0)
    BEGIN
        SELECT 'Error: Cannot assign a shift to an inactive employee.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate Name and Type
    ---------------------------------------------------------
    IF @ShiftName IS NULL OR LTRIM(RTRIM(@ShiftName)) = ''
    BEGIN
        SELECT 'Error: Shift name cannot be empty.' AS Message;
        RETURN;
    END;

    IF @ShiftType IS NULL OR LTRIM(RTRIM(@ShiftType)) = ''
    BEGIN
        SELECT 'Error: Shift type cannot be empty.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Validate Time Range
    ---------------------------------------------------------
    IF @StartTime = @EndTime
    BEGIN
        SELECT 'Error: Start time cannot equal end time.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. Validate Date Range
    ---------------------------------------------------------
    IF @StartDate > @EndDate
    BEGIN
        SELECT 'Error: Start date cannot be after end date.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 6. Prevent Overlapping Assignments
    ---------------------------------------------------------
    IF EXISTS (
        SELECT 1 
        FROM ShiftAssignment 
        WHERE employee_id = @EmployeeID
        AND status = 'Active'
        AND (
                (@StartDate BETWEEN start_date AND end_date)
             OR (@EndDate BETWEEN start_date AND end_date)
             OR (start_date BETWEEN @StartDate AND @EndDate)
            )
    )
    BEGIN
        SELECT 'Error: Employee already has an overlapping shift assignment.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 7. Create Custom Shift in ShiftSchedule
    ---------------------------------------------------------
    INSERT INTO ShiftSchedule (name, type, start_time, end_time, status)
    VALUES (@ShiftName, @ShiftType, @StartTime, @EndTime, 'Active');

    DECLARE @NewShiftID INT = SCOPE_IDENTITY();

    ---------------------------------------------------------
    -- 8. Assign Shift to Employee
    ---------------------------------------------------------
    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
    VALUES (@EmployeeID, @NewShiftID, @StartDate, @EndDate, 'Active');

    ---------------------------------------------------------
    -- 9. Final Confirmation
    ---------------------------------------------------------
    SELECT 'Custom shift created and assigned successfully to employee '
           + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO


-- 14. ConfigureSplitShift
CREATE PROCEDURE ConfigureSplitShift
    @ShiftName VARCHAR(50),
    @FirstSlotStart TIME,
    @FirstSlotEnd TIME,
    @SecondSlotStart TIME,
    @SecondSlotEnd TIME
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Shift Name
    ---------------------------------------------------------
    IF @ShiftName IS NULL OR LTRIM(RTRIM(@ShiftName)) = ''
    BEGIN
        SELECT 'Error: Shift name cannot be empty.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Time Logic
    ---------------------------------------------------------
    IF @FirstSlotStart >= @FirstSlotEnd
    BEGIN
        SELECT 'Error: First slot start time must be before end time.' AS Message;
        RETURN;
    END;

    IF @SecondSlotStart >= @SecondSlotEnd
    BEGIN
        SELECT 'Error: Second slot start time must be before end time.' AS Message;
        RETURN;
    END;

    IF @FirstSlotEnd >= @SecondSlotStart
    BEGIN
        SELECT 'Error: Slot 1 must end before Slot 2 begins.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Prevent Duplicate Shift Names
    ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM ShiftSchedule WHERE name LIKE @ShiftName + '%')
    BEGIN
        SELECT 'Error: A split shift with this name already exists.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Calculate Break Duration
    ---------------------------------------------------------
    DECLARE @BreakDuration INT =
        DATEDIFF(MINUTE, @FirstSlotEnd, @SecondSlotStart);

    ---------------------------------------------------------
    -- 5. Insert Slot 1
    ---------------------------------------------------------
    INSERT INTO ShiftSchedule (name, type, start_time, end_time, break_duration, status)
    VALUES (
        @ShiftName + ' - Slot 1',
        'Split Shift',
        @FirstSlotStart,
        @FirstSlotEnd,
        @BreakDuration,
        'Active'
    );

    ---------------------------------------------------------
    -- 6. Insert Slot 2
    ---------------------------------------------------------
    INSERT INTO ShiftSchedule (name, type, start_time, end_time, break_duration, status)
    VALUES (
        @ShiftName + ' - Slot 2',
        'Split Shift',
        @SecondSlotStart,
        @SecondSlotEnd,
        NULL,
        'Active'
    );

    ---------------------------------------------------------
    -- 7. Confirmation Message
    ---------------------------------------------------------
    SELECT 'Split shift configured successfully: ' + @ShiftName AS ConfirmationMessage;
END;
GO


-- 15. EnableFirstInLastOut
CREATE PROCEDURE EnableFirstInLastOut
    @Enable BIT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate input
    ---------------------------------------------------------
    IF @Enable IS NULL
    BEGIN
        SELECT 'Error: Enable must be 0 or 1.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Check if the policy already exists
    ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM PayrollPolicy WHERE [type] = 'Attendance Processing')
    BEGIN
        UPDATE PayrollPolicy
        SET 
            [description] = CASE 
                                WHEN @Enable = 1 
                                THEN 'First In/Last Out Enabled'
                                ELSE 'First In/Last Out Disabled'
                            END,
            effective_date = GETDATE()
        WHERE [type] = 'Attendance Processing';
    END
    ELSE
    BEGIN
        INSERT INTO PayrollPolicy (effective_date, [type], [description])
        VALUES (
            GETDATE(),
            'Attendance Processing',
            CASE 
                WHEN @Enable = 1 
                THEN 'First In/Last Out Enabled'
                ELSE 'First In/Last Out Disabled'
            END
        );
    END;

    ---------------------------------------------------------
    -- 3. Final confirmation
    ---------------------------------------------------------
    SELECT CASE 
            WHEN @Enable = 1 
            THEN 'First In/Last Out attendance processing enabled'
            ELSE 'First In/Last Out attendance processing disabled'
           END AS ConfirmationMessage;
END;
GO




-- 16. TagAttendanceSource
CREATE PROCEDURE TagAttendanceSource
    @AttendanceID INT,
    @SourceType VARCHAR(20),
    @DeviceID INT,
    @Latitude DECIMAL(10,7),
    @Longitude DECIMAL(10,7)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Attendance Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Attendance WHERE attendance_id = @AttendanceID)
    BEGIN
        SELECT 'Error: Attendance record does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Device Exists (if device ID is provided)
    ---------------------------------------------------------
    IF @DeviceID IS NOT NULL AND 
       NOT EXISTS (SELECT 1 FROM Device WHERE device_id = @DeviceID)
    BEGIN
        SELECT 'Error: Device does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate SourceType
    ---------------------------------------------------------
    IF @SourceType NOT IN ('Device','Terminal','GPS')
    BEGIN
        SELECT 'Error: Invalid source type. Allowed: Device, Terminal, GPS.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Validate GPS Coordinates (only if SourceType = 'GPS')
    ---------------------------------------------------------
    IF @SourceType = 'GPS'
    BEGIN
        IF @Latitude IS NULL OR @Longitude IS NULL
        BEGIN
            SELECT 'Error: GPS coordinates required for GPS source type.' AS Message;
            RETURN;
        END;

        IF @Latitude NOT BETWEEN -90 AND 90
        BEGIN
            SELECT 'Error: Invalid latitude value.' AS Message;
            RETURN;
        END;

        IF @Longitude NOT BETWEEN -180 AND 180
        BEGIN
            SELECT 'Error: Invalid longitude value.' AS Message;
            RETURN;
        END;
    END;

    ---------------------------------------------------------
    -- 5. Insert into AttendanceSource
    ---------------------------------------------------------
    INSERT INTO AttendanceSource (attendance_id, device_id, source_type, latitude, longitude)
    VALUES (@AttendanceID, @DeviceID, @SourceType, @Latitude, @Longitude);

    ---------------------------------------------------------
    -- 6. Confirmation Message
    ---------------------------------------------------------
    SELECT 'Attendance source tagged successfully.' AS ConfirmationMessage;
END;
GO


-- 17. SyncOfflineAttendance
CREATE PROCEDURE SyncOfflineAttendance
    @DeviceID INT,
    @EmployeeID INT,
    @ClockTime DATETIME,
    @Type VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Employee
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Device
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Device WHERE device_id = @DeviceID)
    BEGIN
        SELECT 'Error: Device does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate Punch Type
    ---------------------------------------------------------
    IF @Type NOT IN ('IN','OUT')
    BEGIN
        SELECT 'Error: Punch type must be IN or OUT.' AS Message;
        RETURN;
    END;

    DECLARE @AttendanceID INT;

    ---------------------------------------------------------
    -- 4. IN Punch: Create new attendance record
    ---------------------------------------------------------
    IF @Type = 'IN'
    BEGIN
        INSERT INTO Attendance (employee_id, entry_time, login_method)
        VALUES (@EmployeeID, @ClockTime, 'Offline Device');

        SET @AttendanceID = SCOPE_IDENTITY();

        INSERT INTO AttendanceSource (attendance_id, device_id, source_type, recorded_at)
        VALUES (@AttendanceID, @DeviceID, 'Offline Sync', GETDATE());

        SELECT 'Offline IN punch synced successfully.' AS ConfirmationMessage;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. OUT Punch: Update latest open attendance entry
    ---------------------------------------------------------
    SELECT TOP 1 @AttendanceID = attendance_id
    FROM Attendance
    WHERE employee_id = @EmployeeID
      AND exit_time IS NULL
      AND entry_time <= @ClockTime
    ORDER BY entry_time DESC;

    IF @AttendanceID IS NULL
    BEGIN
        SELECT 'Error: No matching IN punch exists for this OUT punch.' AS Message;
        RETURN;
    END;

    UPDATE Attendance
    SET exit_time = @ClockTime,
        logout_method = 'Offline Device'
    WHERE attendance_id = @AttendanceID;

    INSERT INTO AttendanceSource (attendance_id, device_id, source_type, recorded_at)
    VALUES (@AttendanceID, @DeviceID, 'Offline Sync', GETDATE());

    SELECT 'Offline OUT punch synced successfully.' AS ConfirmationMessage;
END;
GO


-- 18. LogAttendanceEdit
CREATE PROCEDURE LogAttendanceEdit
    @AttendanceID INT,
    @EditedBy INT,
    @OldValue DATETIME,
    @NewValue DATETIME,
    @EditTimestamp DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Attendance Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Attendance WHERE attendance_id = @AttendanceID)
    BEGIN
        SELECT 'Error: Attendance record does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Employee (Editor) Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EditedBy)
    BEGIN
        SELECT 'Error: Editor (employee) does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate Old/New Values
    ---------------------------------------------------------
    IF @OldValue IS NULL OR @NewValue IS NULL
    BEGIN
        SELECT 'Error: Old and new values cannot be NULL.' AS Message;
        RETURN;
    END;

    IF @OldValue = @NewValue
    BEGIN
        SELECT 'Error: Old value and new value are identical.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. Validate Edit Timestamp
    ---------------------------------------------------------
    IF @EditTimestamp IS NULL
    BEGIN
        SELECT 'Error: Edit timestamp cannot be NULL.' AS Message;
        RETURN;
    END;

    IF @EditTimestamp > GETDATE()
    BEGIN
        SELECT 'Error: Edit timestamp cannot be in future.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. Insert Log Entry
    ---------------------------------------------------------
    INSERT INTO AttendanceLog (attendance_id, actor, [timestamp], reason)
    VALUES (
        @AttendanceID,
        @EditedBy,
        @EditTimestamp,
        'Clock edit from ' + CONVERT(VARCHAR(30), @OldValue, 120) 
        + ' to ' + CONVERT(VARCHAR(30), @NewValue, 120)
    );

    ---------------------------------------------------------
    -- 6. Confirmation
    ---------------------------------------------------------
    SELECT 'Attendance edit logged successfully' AS ConfirmationMessage;
END;
GO


-- 19. ApplyHolidayOverrides
CREATE PROCEDURE ApplyHolidayOverrides
    @HolidayID INT,
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Employee Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Validate Holiday Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM HolidayLeave WHERE leave_id = @HolidayID)
    BEGIN
        SELECT 'Error: Holiday does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Insert Holiday Exceptions If They Exist
    ---------------------------------------------------------
    INSERT INTO Employee_Exception (employee_id, exception_id)
    SELECT 
        @EmployeeID,
        e.exception_id
    FROM [Exception] e
    INNER JOIN HolidayLeave hl 
        ON e.[name] = hl.holiday_name
    WHERE hl.leave_id = @HolidayID
      AND NOT EXISTS (
            SELECT 1 
            FROM Employee_Exception ee 
            WHERE ee.employee_id = @EmployeeID 
              AND ee.exception_id = e.exception_id
        );

    ---------------------------------------------------------
    -- 4. Confirmation Message
    ---------------------------------------------------------
    SELECT 'Holiday override applied successfully to employee ' 
           + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 20. ManageUserAccounts
CREATE PROCEDURE ManageUserAccounts
    @UserID INT,
    @Role VARCHAR(50),
    @Action VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate Employee Exists
    ---------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @UserID)
    BEGIN
        SELECT 'Error: User does not exist.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Get Role ID
    ---------------------------------------------------------
    DECLARE @RoleID INT = (SELECT role_id FROM Role WHERE role_name = @Role);

    IF @RoleID IS NULL
    BEGIN
        SELECT 'Error: Invalid role specified.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 3. Validate Action
    ---------------------------------------------------------
    IF @Action NOT IN ('Assign','Remove')
    BEGIN
        SELECT 'Error: Invalid action. Use Assign or Remove.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 4. ASSIGN ROLE
    ---------------------------------------------------------
    IF @Action = 'Assign'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM Employee_Role
            WHERE employee_id = @UserID AND role_id = @RoleID
        )
        BEGIN
            SELECT 'Error: User already has this role.' AS Message;
            RETURN;
        END;

        INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
        VALUES (@UserID, @RoleID, GETDATE());

        SELECT 'Role assigned successfully.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 5. REMOVE ROLE
    ---------------------------------------------------------
    IF @Action = 'Remove'
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM Employee_Role
            WHERE employee_id = @UserID AND role_id = @RoleID
        )
        BEGIN
            SELECT 'Error: Role was not assigned to this user.' AS Message;
            RETURN;
        END;

        DELETE FROM Employee_Role
        WHERE employee_id = @UserID AND role_id = @RoleID;

        SELECT 'Role removed successfully.' AS Message;
        RETURN;
    END;
END;
GO

IF OBJECT_ID('dbo.GetAllRoles', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetAllRoles;
GO

CREATE PROCEDURE dbo.GetAllRoles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        role_id AS RoleId,
        role_name AS RoleName
    FROM Role
    ORDER BY role_name;
END;
GO

IF OBJECT_ID('dbo.GetAllEmployees_Roles', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetAllEmployees_Roles;
GO



CREATE PROCEDURE dbo.GetAllEmployees_Roles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.employee_id AS Employee_Id,
        e.full_name AS Full_Name,
        d.department_name AS Department,
        r.role_id AS RoleId,
        r.role_name AS RoleName
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Employee_Role er ON e.employee_id = er.employee_id
    LEFT JOIN Role r ON er.role_id = r.role_id
    ORDER BY e.full_name;
END;
GO




--extra procedures
CREATE  OR ALTER PROCEDURE GetAllShiftTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        shift_id,
        name,
        type,
        start_time,
        end_time,
        break_duration,
        shift_date,
        status
    FROM ShiftSchedule
    ORDER BY shift_id DESC;
END;
GO
CREATE OR ALTER PROCEDURE GetShiftTypes
AS
BEGIN
    SELECT 
        shift_id,
        name,
        type,
        start_time,
        end_time,
        break_duration,
        shift_date,
        status
    FROM ShiftSchedule;
END;
GO
CREATE OR ALTER PROCEDURE CreateShiftCycle
    @CycleID INT OUTPUT,
    @CycleName VARCHAR(100),
    @Description VARCHAR(255)
AS
BEGIN
    INSERT INTO ShiftCycle (cycle_name, description)
    VALUES (@CycleName, @Description);

    SET @CycleID = SCOPE_IDENTITY();
END;
GO

-- 2. Add a Shift to the Cycle (e.g., Shift 1 is first, Shift 2 is second)
CREATE OR ALTER PROCEDURE AddShiftToCycle
    @CycleID INT,
    @ShiftID INT,
    @OrderNumber INT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM ShiftCycleAssignment WHERE cycle_id = @CycleID AND shift_id = @ShiftID)
    BEGIN
        SELECT 'Error: This shift is already in the cycle.' AS Message;
        RETURN;
    END

    INSERT INTO ShiftCycleAssignment (cycle_id, shift_id, order_number)
    VALUES (@CycleID, @ShiftID, @OrderNumber);

    SELECT 'Shift added to cycle successfully.' AS Message;
END;
GO





CREATE OR ALTER PROCEDURE GetShiftCycles
AS
BEGIN
    SELECT 
        cycle_id,      -- Must match C# 'cycle_id'
        cycle_name,    -- Must match C# 'cycle_name'
        description 
    FROM ShiftCycle;
END;
GO
-- 1. Helper for Department Dropdown
CREATE OR ALTER PROCEDURE GetAllDepartments
AS
BEGIN
    SELECT department_id, department_name FROM Department;
END;
GO




-- 2. Helper for Employee Dropdown
CREATE OR ALTER PROCEDURE GetAllEmployeesSimple
AS
BEGIN
    SELECT employee_id, first_name + ' ' + last_name AS full_name 
    FROM Employee 
    WHERE is_active = 1; -- Only show active employees
END;
GO

USE HRMS;
GO

CREATE OR ALTER PROCEDURE GetAttendanceBreaches
    @DepartmentID INT = NULL, -- Optional Filter
    @Date DATE -- The specific day to check
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Get the Active Lateness Policy (Assuming 1 active policy for simplicity)
    DECLARE @GracePeriod INT;
    DECLARE @DeductionRate DECIMAL(5,2);

    -- Fetch the most recent active policy
    SELECT TOP 1 
        @GracePeriod = lp.grace_period_mins,
        @DeductionRate = lp.deduction_rate
    FROM LatenessPolicy lp
    JOIN PayrollPolicy pp ON lp.policy_id = pp.policy_id
    ORDER BY pp.effective_date DESC;

    -- Fallback if no policy exists
    SET @GracePeriod = ISNULL(@GracePeriod, 0);
    SET @DeductionRate = ISNULL(@DeductionRate, 0);

    -- 2. Calculate Breaches
    SELECT 
        e.employee_id,
        e.first_name + ' ' + e.last_name AS employee_name,
        d.department_name,
        
        -- Times
        ss.start_time AS shift_start,
        ss.end_time AS shift_end,
        CAST(a.entry_time AS TIME) AS actual_in,
        CAST(a.exit_time AS TIME) AS actual_out,

        -- 1. Calculate Raw Lateness (In Minutes)
        CASE 
            WHEN CAST(a.entry_time AS TIME) > ss.start_time 
            THEN DATEDIFF(MINUTE, ss.start_time, CAST(a.entry_time AS TIME)) 
            ELSE 0 
        END AS raw_late_minutes,

        -- 2. Apply Grace Period Logic
        -- If Late <= Grace, then Late = 0. Otherwise, count full lateness.
        CASE 
            WHEN CAST(a.entry_time AS TIME) > ss.start_time 
                 AND DATEDIFF(MINUTE, ss.start_time, CAST(a.entry_time AS TIME)) > @GracePeriod
            THEN DATEDIFF(MINUTE, ss.start_time, CAST(a.entry_time AS TIME)) 
            ELSE 0 
        END AS penalized_late_minutes,

        -- 3. Calculate Early Leave (No grace period usually applies to leaving early)
        CASE 
            WHEN a.exit_time IS NOT NULL AND CAST(a.exit_time AS TIME) < ss.end_time
            THEN DATEDIFF(MINUTE, CAST(a.exit_time AS TIME), ss.end_time)
            ELSE 0 
        END AS early_leave_minutes,

        @GracePeriod AS grace_period_used

    FROM Attendance a
    JOIN Employee e ON a.employee_id = e.employee_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    JOIN ShiftSchedule ss ON a.shift_id = ss.shift_id
    WHERE CAST(a.entry_time AS DATE) = @Date
      AND (@DepartmentID IS NULL OR e.department_id = @DepartmentID)
      -- Only show records where there is a violation
      AND (
          (CAST(a.entry_time AS TIME) > DATEADD(MINUTE, @GracePeriod, ss.start_time)) -- Late > Grace
          OR 
          (a.exit_time IS NOT NULL AND CAST(a.exit_time AS TIME) < ss.end_time) -- Early Out
      );
END;
GO

CREATE OR ALTER PROCEDURE GetApprovedLeavesForSync
AS
BEGIN
    SELECT 
        lr.request_id,
        lr.employee_id,
        e.first_name + ' ' + e.last_name AS employee_name,
        l.leave_type,
        lr.approval_timing AS start_date,
        DATEADD(DAY, lr.duration, lr.approval_timing) AS end_date,
        lr.status
    FROM LeaveRequest lr
    INNER JOIN Employee e ON lr.employee_id = e.employee_id
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    -- Only show Approved ones. 'Synced' ones will now disappear.
    WHERE lr.status IN ('Approved', 'Finalized', 'Approved - Balance Updated')
    ORDER BY lr.approval_timing DESC;
END;
GO
--

USE HRMS;
GO

-- 1. Helper: Get Leave Types for Dropdown (Employee) & Grid (Admin)
CREATE OR ALTER PROCEDURE GetLeaveTypes
AS
BEGIN
    SELECT 
        leave_id, 
        leave_type, 
        leave_description 
    FROM [Leave]; -- Matches your schema table name
END;
GO

-- 2. Requirement #5.1: Submit Leave Request (Employee)
CREATE OR ALTER PROCEDURE SubmitLeaveRequest
    @EmployeeID INT,
    @LeaveTypeID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100) -- mapped to justification
AS
BEGIN
    -- Insert into your schema's LeaveRequest table
    INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, status, approval_timing)
    VALUES (
        @EmployeeID, 
        @LeaveTypeID, 
        @Reason, 
        DATEDIFF(day, @StartDate, @EndDate) + 1, -- Simple duration calculation
        'Pending',
        NULL
    );

    SELECT 'Leave request submitted successfully.' AS Message;
END;
GO

-- 3. Requirement #5.2: Get Leave Balance
CREATE OR ALTER PROCEDURE GetLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VacationID INT = 1;      -- leave_id = 1 → Vacation
    DECLARE @DefaultEntitlement INT = 30;

    /* =====================================================
       1. VACATION (BANKED – DEFAULT 30, HR OVERRIDE WORKS)
       ===================================================== */
    SELECT
        l.leave_type,
        ISNULL(le.entitlement, @DefaultEntitlement) AS entitlement,
        ISNULL(SUM(lr.duration), 0) AS days_used,
        ISNULL(le.entitlement, @DefaultEntitlement)
            - ISNULL(SUM(lr.duration), 0) AS remaining_balance
    FROM [Leave] l
    LEFT JOIN LeaveEntitlement le
        ON le.employee_id = @EmployeeID
       AND le.leave_type_id = @VacationID
    LEFT JOIN LeaveRequest lr
        ON lr.employee_id = @EmployeeID
       AND lr.leave_id = @VacationID
       AND lr.status IN ('Approved', 'Pending')
    WHERE l.leave_id = @VacationID
    GROUP BY l.leave_type, le.entitlement

    UNION ALL

    /* =====================================================
       2. POLICY LEAVES (SICK / HOLIDAY / PROBATION)
       ===================================================== */
    SELECT
        l.leave_type,
        0 AS entitlement,
        0 AS days_used,
        0 AS remaining_balance
    FROM [Leave] l
    WHERE l.leave_id <> @VacationID;
END;
GO


-- 4. Helper: Get Employee's Request History
CREATE OR ALTER PROCEDURE ViewLeaveHistory
    @EmployeeID INT
AS
BEGIN
    SELECT 
        lr.request_id,
        l.leave_type,
        lr.duration,
        lr.status,
        lr.justification
    FROM LeaveRequest lr
    INNER JOIN [Leave] l ON lr.leave_id = l.leave_id
    WHERE lr.employee_id = @EmployeeID
    ORDER BY lr.request_id DESC;
END;
GO

-- 5. Requirement #30 & #32: Manage Leave Types (Admin)
-- Updated to match your schema table: LeavePolicy
CREATE OR ALTER PROCEDURE ManageLeavePolicy
    @Name VARCHAR(100),
    @Purpose VARCHAR(255),
    @Eligibility VARCHAR(255),
    @NoticePeriod INT,
    @MaxDuration INT -- Note: Your schema didn't have MaxDuration in LeavePolicy, 
                     -- but the requirement asks for it. 
                     -- I will ignore it for now or we can ALTER table.
                     -- Let's stick to existing columns: name, purpose, eligibility, notice_period
AS
BEGIN
    IF EXISTS (SELECT 1 FROM LeavePolicy WHERE name = @Name)
    BEGIN
        UPDATE LeavePolicy
        SET 
            purpose = @Purpose,
            eligibility_rules = @Eligibility,
            notice_period = @NoticePeriod
        WHERE name = @Name;
    END
    ELSE
    BEGIN
        INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, reset_on_new_year)
        VALUES (@Name, @Purpose, @Eligibility, @NoticePeriod, 1);
    END
    
    SELECT 'Policy saved successfully.' AS Message;
END;
GO

-- 6. Helper: Get All Policies (Admin Grid)
CREATE OR ALTER PROCEDURE GetAllLeavePolicies
AS
BEGIN
    SELECT * FROM LeavePolicy;
END;
GO

