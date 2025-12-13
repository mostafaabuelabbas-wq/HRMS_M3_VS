
--Payroll Officer
-- 1. GeneratePayroll done

CREATE OR ALTER PROCEDURE GeneratePayroll
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRAN;

    ;WITH EligibleEmployees AS (
        SELECT 
            e.employee_id,
            pg.min_salary AS base_amount,
            ROUND(pg.min_salary * 0.10, 2) AS taxes
        FROM Employee e
        INNER JOIN PayGrade pg ON e.pay_grade = pg.pay_grade_id
        WHERE e.is_active = 1
          AND e.account_status = 'Active'
          AND NOT EXISTS (
                SELECT 1 
                FROM Payroll p
                WHERE p.employee_id = e.employee_id
                  AND p.period_start = @StartDate
                  AND p.period_end = @EndDate
            )
    )
    INSERT INTO Payroll (
        employee_id, period_start, period_end,
        base_amount, taxes, adjustments, contributions,
        actual_pay, net_salary, payment_date
    )
    OUTPUT INSERTED.*
    SELECT 
        employee_id,
        @StartDate,
        @EndDate,
        base_amount,
        taxes,
        0 AS adjustments,
        0 AS contributions,
        (base_amount - taxes) AS actual_pay,
        (base_amount - taxes) AS net_salary,
        GETDATE() AS payment_date
    FROM EligibleEmployees;

    COMMIT;
END;
GO


-- 2. AdjustPayrollItem done
-- ======================================================
-- Procedure: AdjustPayrollItem
-- Description: Add or modify allowances and deductions for an employee
-- ======================================================
CREATE OR ALTER PROCEDURE AdjustPayrollItem
    @PayrollID INT,
    @Type VARCHAR(50),
    @Amount DECIMAL(10,2),       -- positive = allowance, negative = deduction
    @Duration INT,               -- minutes
    @Timezone VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;

    -- 1. Validate payroll exists
    IF NOT EXISTS (SELECT 1 FROM Payroll WHERE payroll_id = @PayrollID)
    BEGIN
        ROLLBACK;
        SELECT 'Error: Payroll record not found' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @EmployeeID INT, @CurrencyCode VARCHAR(10);

    SELECT 
        @EmployeeID = employee_id
    FROM Payroll
    WHERE payroll_id = @PayrollID;

    -- Retrieve employee currency from SalaryType
    SELECT @CurrencyCode = st.currency_code
    FROM Employee e
    JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    WHERE e.employee_id = @EmployeeID;

    -- 2. Insert OR Update allowance/deduction
    IF EXISTS (
        SELECT 1
        FROM AllowanceDeduction
        WHERE payroll_id = @PayrollID
          AND LOWER(type) = LOWER(@Type)
    )
    BEGIN
        UPDATE AllowanceDeduction
        SET amount       = @Amount,
            duration     = @Duration,
            timezone     = @Timezone,
            currency_code = @CurrencyCode
        WHERE payroll_id = @PayrollID
          AND LOWER(type) = LOWER(@Type);
    END
    ELSE
    BEGIN
        INSERT INTO AllowanceDeduction
            (payroll_id, employee_id, type, amount, currency_code, duration, timezone)
        VALUES
            (@PayrollID, @EmployeeID, @Type, @Amount, @CurrencyCode, @Duration, @Timezone);
    END;

    -- 3. Recalculate totals
    DECLARE @Base DECIMAL(10,2),
            @Taxes DECIMAL(10,2),
            @Contrib DECIMAL(10,2),
            @Adj DECIMAL(10,2);

    SELECT 
        @Base = base_amount,
        @Taxes = taxes,
        @Contrib = contributions
    FROM Payroll
    WHERE payroll_id = @PayrollID;

    SELECT @Adj = SUM(amount)
    FROM AllowanceDeduction
    WHERE payroll_id = @PayrollID;

    SET @Adj = ISNULL(@Adj, 0);

    UPDATE Payroll
    SET adjustments = @Adj,
        actual_pay = @Base - @Taxes - @Contrib,
        net_salary = @Base + @Adj - @Taxes - @Contrib
    WHERE payroll_id = @PayrollID;

    COMMIT;

    SELECT 'Payroll item adjusted successfully' AS ConfirmationMessage;
END;
GO



-- 3. CalculateNetSalary
CREATE OR ALTER PROCEDURE CalculateNetSalary 
    @PayrollID INT,
    @NetSalary DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Base DECIMAL(10,2),
            @Taxes DECIMAL(10,2),
            @Contrib DECIMAL(10,2),
            @Adjust DECIMAL(10,2);

    -- Validate payroll exists
    IF NOT EXISTS (SELECT 1 FROM Payroll WHERE payroll_id = @PayrollID)
    BEGIN
        SET @NetSalary = NULL;
        SELECT 'Error: Payroll record not found' AS Message;
        RETURN;
    END;

    -- Get base payroll values
    SELECT 
        @Base = base_amount,
        @Taxes = taxes,
        @Contrib = contributions
    FROM Payroll
    WHERE payroll_id = @PayrollID;

    -- Get sum of allowances/deductions
    SELECT @Adjust = SUM(amount)
    FROM AllowanceDeduction
    WHERE payroll_id = @PayrollID;

    SET @Adjust = ISNULL(@Adjust, 0);
    SET @Base   = ISNULL(@Base,   0);
    SET @Taxes  = ISNULL(@Taxes,  0);
    SET @Contrib= ISNULL(@Contrib,0);

    -- Compute net salary
    SET @NetSalary = @Base + @Adjust - @Taxes - @Contrib;

    -- Optional: return it for direct SELECT output
    SELECT @NetSalary AS NetSalary;
END;
GO



-- 4. ApplyPayrollPolicy
CREATE OR ALTER PROCEDURE ApplyPayrollPolicy
    @PolicyID INT,
    @PayrollID INT,
    @Type VARCHAR(20),
    @Description VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validate payroll exists
    IF NOT EXISTS (SELECT 1 FROM Payroll WHERE payroll_id = @PayrollID)
    BEGIN
        SELECT 'Error: Payroll record not found' AS ConfirmationMessage;
        RETURN;
    END;

    -- 2. Validate policy exists
    IF NOT EXISTS (SELECT 1 FROM PayrollPolicy WHERE policy_id = @PolicyID)
    BEGIN
        SELECT 'Error: Policy not found' AS ConfirmationMessage;
        RETURN;
    END;

    -- 3. Prevent duplicate application
    IF EXISTS (
        SELECT 1
        FROM PayrollPolicy_ID
        WHERE payroll_id = @PayrollID
          AND policy_id = @PolicyID
    )
    BEGIN
        SELECT 'Policy already applied to this payroll.' AS ConfirmationMessage;
        RETURN;
    END;

    -- 4. Apply policy
    INSERT INTO PayrollPolicy_ID (payroll_id, policy_id)
    VALUES (@PayrollID, @PolicyID);

    SELECT 'Payroll policy applied successfully' AS ConfirmationMessage;
END;
GO


-- 5. GetMonthlyPayrollSummary
CREATE OR ALTER PROCEDURE GetMonthlyPayrollSummary
    @Month INT,
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT SUM(net_salary) AS TotalSalaryExpenditure
    FROM Payroll
    WHERE MONTH(payment_date) = @Month
      AND YEAR(payment_date) = @Year;
END;
GO



-- 6. GetEmployeePayrollHistory
CREATE OR ALTER PROCEDURE GetEmployeePayrollHistory
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT payroll_id, employee_id, period_start, period_end,
           base_amount, taxes, adjustments, contributions,
           actual_pay, net_salary, payment_date
    FROM Payroll
    WHERE employee_id = @EmployeeID
    ORDER BY period_start;
END;
GO

-- 8. GetBonusEligibleEmployees
CREATE OR ALTER PROCEDURE GetBonusEligibleEmployees
    @Eligibility_criteria VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        e.employee_id,
        e.full_name,
        e.department_id,
        e.position_id,
        e.hire_date,
        e.employment_status
    FROM Employee e
    INNER JOIN Payroll p ON e.employee_id = p.employee_id
    INNER JOIN PayrollPolicy_ID ppi ON p.payroll_id = ppi.payroll_id
    INNER JOIN BonusPolicy bp ON ppi.policy_id = bp.policy_id
    WHERE bp.eligibility_criteria LIKE '%' + @Eligibility_criteria + '%'
      AND e.is_active = 1;
END;
GO


-- 9. UpdateSalaryType
CREATE OR ALTER PROCEDURE UpdateSalaryType
    @EmployeeID INT,
    @SalaryTypeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validate employee exists
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found' AS ConfirmationMessage;
        RETURN;
    END;

    -- 2. Validate salary type exists
    IF NOT EXISTS (SELECT 1 FROM SalaryType WHERE salary_type_id = @SalaryTypeID)
    BEGIN
        SELECT 'Error: Salary type not found' AS ConfirmationMessage;
        RETURN;
    END;

    -- 3. Update salary type
    UPDATE Employee
    SET salary_type_id = @SalaryTypeID
    WHERE employee_id = @EmployeeID;

    SELECT 'Salary type updated successfully' AS ConfirmationMessage;
END;
GO

-- 10. GetPayrollByDepartment
CREATE OR ALTER PROCEDURE GetPayrollByDepartment
    @DepartmentID INT,
    @Month INT,
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.department_id,
        d.department_name,
        COUNT(DISTINCT p.employee_id) AS total_employees,
        SUM(p.base_amount) AS total_base_amount,
        SUM(p.adjustments) AS total_adjustments,
        SUM(p.taxes) AS total_taxes,
        SUM(p.contributions) AS total_contributions,
        SUM(p.net_salary) AS total_net_salary
    FROM Payroll p
    INNER JOIN Employee e ON p.employee_id = e.employee_id
    INNER JOIN Department d ON e.department_id = d.department_id
    WHERE e.department_id = @DepartmentID
      AND MONTH(p.period_start) = @Month
      AND YEAR(p.period_start) = @Year
    GROUP BY e.department_id, d.department_name;
END;
GO


-- 11. ValidateAttendanceBeforePayroll
CREATE OR ALTER PROCEDURE ValidateAttendanceBeforePayroll
    @PayrollPeriodID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate payroll period exists
    IF NOT EXISTS (SELECT 1 FROM PayrollPeriod WHERE payroll_period_id = @PayrollPeriodID)
    BEGIN
        SELECT 'Error: Payroll period not found' AS Message;
        RETURN;
    END;

    -- Get period boundaries
    DECLARE @StartDate DATE, @EndDate DATE;

    SELECT 
        @StartDate = start_date,
        @EndDate   = end_date
    FROM PayrollPeriod
    WHERE payroll_period_id = @PayrollPeriodID;

    -- Return unresolved punches
    SELECT 
        e.employee_id,
        e.full_name,
        e.department_id,
        a.attendance_id,
        a.entry_time,
        a.exit_time,
        a.exception_id
    FROM Attendance a
    JOIN Employee e ON a.employee_id = e.employee_id
    WHERE 
        -- Missing punch
        (a.entry_time IS NULL OR a.exit_time IS NULL)
        -- Attendance date inside payroll period (use COALESCE to support NULLs)
        AND CAST(COALESCE(a.entry_time, a.exit_time) AS DATE) 
            BETWEEN @StartDate AND @EndDate;
END;
GO

-- 12. SyncAttendanceToPayroll
CREATE OR ALTER PROCEDURE SyncAttendanceToPayroll
    @SyncDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AllowanceDeduction (
        payroll_id,
        employee_id,
        type,
        amount,
        duration,
        currency_code
    )
    SELECT
        p.payroll_id,
        a.employee_id,
        'Attendance Adjustment',
        0.00,
        '1 Day',  -- No duration column exists, so store a simple tag
        st.currency_code
    FROM Attendance a
    INNER JOIN Employee e ON a.employee_id = e.employee_id
    INNER JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    INNER JOIN Payroll p 
        ON p.employee_id = a.employee_id
        AND @SyncDate BETWEEN p.period_start AND p.period_end
    WHERE 
        CAST(COALESCE(a.entry_time, a.exit_time) AS DATE) = @SyncDate
        AND a.exit_time IS NOT NULL; -- ensures attendance record is valid

    SELECT 'Attendance synced to payroll successfully' AS ConfirmationMessage;
END;
GO


-- 13. SyncApprovedPermissionsToPayroll
CREATE OR ALTER PROCEDURE SyncApprovedPermissionsToPayroll
    @PayrollPeriodID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate payroll period exists
    IF NOT EXISTS (SELECT 1 FROM PayrollPeriod WHERE payroll_period_id = @PayrollPeriodID)
    BEGIN
        SELECT 'Error: Payroll period not found' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @StartDate DATE, @EndDate DATE;

    SELECT @StartDate = start_date, @EndDate = end_date
    FROM PayrollPeriod
    WHERE payroll_period_id = @PayrollPeriodID;

    -- Insert leave-related deductions
    INSERT INTO AllowanceDeduction (
        payroll_id,
        employee_id,
        type,
        amount,
        duration,
        currency_code
    )
    SELECT 
        p.payroll_id,
        lr.employee_id,
        'Leave Deduction',
        0.00,
        lr.duration,
        st.currency_code
    FROM LeaveRequest lr
    JOIN Employee e ON lr.employee_id = e.employee_id
    JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    JOIN Payroll p ON p.employee_id = lr.employee_id
                  AND @StartDate BETWEEN p.period_start AND p.period_end
    WHERE lr.status = 'Approved'
      AND lr.approval_timing BETWEEN @StartDate AND @EndDate;

    SELECT 'Approved permissions synced to payroll successfully' AS ConfirmationMessage;
END;
GO


-- 14. ConfigurePayGrades
CREATE PROCEDURE ConfigurePayGrades
    @GradeName VARCHAR(50),
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate salary range
    IF (@MinSalary >= @MaxSalary)
    BEGIN
        SELECT 'Error: Minimum salary must be less than maximum salary.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent duplicate grade names
    IF EXISTS (SELECT 1 FROM PayGrade WHERE grade_name = @GradeName)
    BEGIN
        SELECT 'Error: Pay grade already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert new pay grade
    INSERT INTO PayGrade (grade_name, min_salary, max_salary)
    VALUES (@GradeName, @MinSalary, @MaxSalary);

    SELECT 'Pay grade configured successfully' AS ConfirmationMessage;
END;
GO

-- 15. ConfigureShiftAllowances
CREATE PROCEDURE ConfigureShiftAllowances
    @ShiftType VARCHAR(50),
    @AllowanceName VARCHAR(50),
    @Amount DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AllowanceDeduction (
        payroll_id,
        employee_id,
        type,
        amount,
        currency_code,
        duration,
        timezone
    )
    SELECT 
        p.payroll_id,
        sa.employee_id,
        @AllowanceName,
        @Amount,
        st.currency_code,
        'Shift',
        'System'
    FROM ShiftAssignment sa
    INNER JOIN ShiftSchedule ss ON sa.shift_id = ss.shift_id
    INNER JOIN Employee e ON sa.employee_id = e.employee_id
    INNER JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    INNER JOIN Payroll p ON p.employee_id = sa.employee_id
    WHERE ss.type = @ShiftType
      AND sa.status = 'Active';

    SELECT 'Shift allowance configured successfully for ' + @ShiftType + ' shifts' 
           AS ConfirmationMessage;
END;
GO


-- 16. EnableMultiCurrencyPayroll
CREATE PROCEDURE EnableMultiCurrencyPayroll
    @CurrencyCode VARCHAR(10),
    @ExchangeRate DECIMAL(10,4)
AS
BEGIN
    SET NOCOUNT ON;

    -- If currency exists, update it
    IF EXISTS (SELECT 1 FROM Currency WHERE CurrencyCode = @CurrencyCode)
    BEGIN
        UPDATE Currency
        SET ExchangeRate = @ExchangeRate,
            LastUpdated = GETDATE()
        WHERE CurrencyCode = @CurrencyCode;

        SELECT 'Currency exchange rate updated' AS ConfirmationMessage;
        RETURN;
    END;

    -- Otherwise insert new currency
    INSERT INTO Currency (CurrencyCode, CurrencyName, ExchangeRate, CreatedDate, LastUpdated)
    VALUES (@CurrencyCode, @CurrencyCode, @ExchangeRate, GETDATE(), GETDATE());

    SELECT 'Currency added and multi-currency enabled for ' + @CurrencyCode AS ConfirmationMessage;
END;
GO


-- 17. ManageTaxRules
CREATE PROCEDURE ManageTaxRules
    @TaxRuleName VARCHAR(50),
    @CountryCode VARCHAR(10),
    @Rate DECIMAL(5,2),
    @Exemption DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate rate
    IF (@Rate < 0 OR @Rate > 100)
    BEGIN
        SELECT 'Error: Tax rate must be between 0 and 100.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate exemption
    IF (@Exemption < 0)
    BEGIN
        SELECT 'Error: Exemption amount cannot be negative.' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @Content NVARCHAR(MAX);
    SET @Content = @TaxRuleName 
                   + ': Rate=' + CAST(@Rate AS VARCHAR(10)) 
                   + '%, Exemption=' + CAST(@Exemption AS VARCHAR(20));

    -- If a rule already exists for country → UPDATE it
    IF EXISTS (SELECT 1 FROM TaxForm WHERE jurisdiction = @CountryCode)
    BEGIN
        UPDATE TaxForm
        SET form_content = @Content
        WHERE jurisdiction = @CountryCode;

        SELECT 'Tax rule updated successfully' AS ConfirmationMessage;
        RETURN;
    END;

    -- Otherwise INSERT new tax rule
    INSERT INTO TaxForm (jurisdiction, form_content)
    VALUES (@CountryCode, @Content);

    SELECT 'Tax rule created successfully' AS ConfirmationMessage;
END;
GO


-- 18. ApprovePayrollConfigChanges  
CREATE PROCEDURE ApprovePayrollConfigChanges
    @ConfigID INT,
    @ApproverID INT,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate approver exists
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApproverID)
    BEGIN
        SELECT 'Error: Approver not found.' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @RoleID INT;

    -- Get approver role (pick primary if multiple)
    SELECT TOP 1 @RoleID = role_id
    FROM Employee_Role
    WHERE employee_id = @ApproverID
    ORDER BY assigned_date DESC;

    IF @RoleID IS NULL
    BEGIN
        SELECT 'Error: Approver has no assigned role.' AS ConfirmationMessage;
        RETURN;
    END;

    -- CASE 1: Workflow exists → update it
    IF EXISTS (SELECT 1 FROM ApprovalWorkflow WHERE workflow_id = @ConfigID)
    BEGIN
        UPDATE ApprovalWorkflow
        SET status = @Status
        WHERE workflow_id = @ConfigID;

        SELECT 'Payroll configuration change ' + @Status AS ConfirmationMessage;
        RETURN;
    END;

    -- CASE 2: Workflow does NOT exist → create a new one
    INSERT INTO ApprovalWorkflow (workflow_type, threshold_amount, approver_role, created_by, status)
    VALUES ('Payroll Config', NULL, @RoleID, @ApproverID, @Status);

    SELECT 'Payroll configuration approval created with status: ' + @Status AS ConfirmationMessage;
END;
GO


-- 19. ConfigureSigningBonus
CREATE PROCEDURE ConfigureSigningBonus
    @EmployeeID INT,
    @BonusAmount DECIMAL(10,2),
    @EffectiveDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate employee
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate amount
    IF @BonusAmount <= 0
    BEGIN
        SELECT 'Error: Bonus amount must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @CurrencyCode VARCHAR(10),
            @PayrollID INT;

    -- Get employee currency
    SELECT TOP 1 @CurrencyCode = st.currency_code
    FROM Employee e
    JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    WHERE e.employee_id = @EmployeeID;

    -- Get payroll record active during EffectiveDate
    SELECT TOP 1 @PayrollID = payroll_id
    FROM Payroll
    WHERE employee_id = @EmployeeID
      AND @EffectiveDate BETWEEN period_start AND period_end;

    -- Insert standalone bonus if no payroll exists yet
    IF @PayrollID IS NULL
        SET @PayrollID = NULL;

    -- Insert signing bonus
    INSERT INTO AllowanceDeduction (
        payroll_id,
        employee_id,
        type,
        amount,
        currency_code,
        duration,
        timezone
    )
    VALUES (
        @PayrollID,
        @EmployeeID,
        'Signing Bonus',
        @BonusAmount,
        @CurrencyCode,
        'One-time',
        'System'
    );

    SELECT 'Signing bonus configured successfully for employee ' 
           + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO


-- 20. ConfigureTerminationBenefits  
CREATE PROCEDURE ConfigureTerminationBenefits
    @EmployeeID INT,
    @CompensationAmount DECIMAL(10,2),
    @EffectiveDate DATE,
    @Reason VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate employee exists
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found.' AS ConfirmationMessage;
        RETURN;
    END;

    IF @CompensationAmount <= 0
    BEGIN
        SELECT 'Error: Compensation amount must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @ContractID INT,
            @PayrollID INT,
            @CurrencyCode VARCHAR(10);

    -- Get contract for termination record
    SELECT @ContractID = contract_id
    FROM Employee
    WHERE employee_id = @EmployeeID;

    -- Insert termination details
    INSERT INTO Termination (date, reason, contract_id)
    VALUES (@EffectiveDate, @Reason, @ContractID);

    -- Get employee currency
    SELECT @CurrencyCode = st.currency_code
    FROM Employee e
    JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    WHERE e.employee_id = @EmployeeID;

    -- Determine payroll record if exists
    SELECT TOP 1 @PayrollID = payroll_id
    FROM Payroll
    WHERE employee_id = @EmployeeID
      AND @EffectiveDate BETWEEN period_start AND period_end;

    -- Insert compensation as allowance/deduction
    INSERT INTO AllowanceDeduction (
        payroll_id,
        employee_id,
        type,
        amount,
        currency_code,
        duration,
        timezone
    )
    VALUES (
        @PayrollID,                -- NULL if no matching payroll exists
        @EmployeeID,
        'Termination Compensation',
        @CompensationAmount,
        @CurrencyCode,
        'One-time',
        'System'
    );

    SELECT 'Termination benefits configured successfully for employee ' 
           + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO


-- 21. ConfigureInsuranceBrackets
CREATE PROCEDURE ConfigureInsuranceBrackets
    @InsuranceType VARCHAR(50),
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2),
    @EmployeeContribution DECIMAL(5,2),
    @EmployerContribution DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate salary range
    IF (@MinSalary >= @MaxSalary)
    BEGIN
        SELECT 'Error: Minimum salary must be less than maximum salary.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate contribution percentages
    IF (@EmployeeContribution < 0 OR @EmployeeContribution > 100)
    BEGIN
        SELECT 'Error: Employee contribution must be between 0 and 100.' AS ConfirmationMessage;
        RETURN;
    END;

    IF (@EmployerContribution < 0 OR @EmployerContribution > 100)
    BEGIN
        SELECT 'Error: Employer contribution must be between 0 and 100.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent defining duplicate insurance types
    IF EXISTS (SELECT 1 FROM Insurance WHERE type = @InsuranceType)
    BEGIN
        SELECT 'Error: Insurance type already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Build coverage description
    DECLARE @Coverage VARCHAR(200);
    SET @Coverage = 'Salary Range: ' + CAST(@MinSalary AS VARCHAR(20)) 
                    + ' - ' + CAST(@MaxSalary AS VARCHAR(20))
                    + ' | Employer: ' + CAST(@EmployerContribution AS VARCHAR(10)) + '%';

    -- Insert insurance bracket
    INSERT INTO Insurance (type, contribution_rate, coverage)
    VALUES (
        @InsuranceType,
        @EmployeeContribution,
        @Coverage
    );

    SELECT 'Insurance bracket configured successfully for ' + @InsuranceType AS ConfirmationMessage;
END;
GO


-- 22. UpdateInsuranceBrackets
CREATE PROCEDURE UpdateInsuranceBrackets
    @BracketID INT,
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2),
    @EmployeeContribution DECIMAL(5,2),
    @EmployerContribution DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate bracket exists
    IF NOT EXISTS (SELECT 1 FROM Insurance WHERE insurance_id = @BracketID)
    BEGIN
        SELECT 'Error: Insurance bracket not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate salary range
    IF (@MinSalary >= @MaxSalary)
    BEGIN
        SELECT 'Error: Minimum salary must be less than maximum salary.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate contribution percentages
    IF (@EmployeeContribution < 0 OR @EmployeeContribution > 100)
    BEGIN
        SELECT 'Error: Employee contribution must be between 0 and 100.' AS ConfirmationMessage;
        RETURN;
    END;

    IF (@EmployerContribution < 0 OR @EmployerContribution > 100)
    BEGIN
        SELECT 'Error: Employer contribution must be between 0 and 100.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Build coverage text
    DECLARE @Coverage VARCHAR(200);
    SET @Coverage = 
        'Salary Range: ' + CAST(@MinSalary AS VARCHAR(20)) +
        ' - ' + CAST(@MaxSalary AS VARCHAR(20)) +
        ' | Employer: ' + CAST(@EmployerContribution AS VARCHAR(10)) + '%';

    -- Update the bracket
    UPDATE Insurance
    SET contribution_rate = @EmployeeContribution,
        coverage = @Coverage
    WHERE insurance_id = @BracketID;

    SELECT 'Insurance bracket updated successfully' AS ConfirmationMessage;
END;
GO


-- 23. ConfigurePayrollPolicies
CREATE PROCEDURE ConfigurePayrollPolicies
    @PolicyType VARCHAR(50),
    @PolicyDetails NVARCHAR(MAX),
    @EffectiveDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate effective date
    IF @EffectiveDate IS NULL
    BEGIN
        SELECT 'Error: Effective date is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate policy type
    IF @PolicyType IS NULL OR LTRIM(RTRIM(@PolicyType)) = ''
    BEGIN
        SELECT 'Error: Policy type is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent duplicate policies with same type and date
    IF EXISTS (
        SELECT 1 FROM PayrollPolicy
        WHERE [type] = @PolicyType
          AND effective_date = @EffectiveDate
    )
    BEGIN
        SELECT 'Error: A payroll policy for this type and date already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert new policy
    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (@EffectiveDate, @PolicyType, @PolicyDetails);

    SELECT 'Payroll policy created successfully' AS ConfirmationMessage;
END;
GO


-- 24. DefinePayGrades
CREATE PROCEDURE DefinePayGrades
    @GradeName VARCHAR(50),
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2),
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate grade name
    IF (@GradeName IS NULL OR LTRIM(RTRIM(@GradeName)) = '')
    BEGIN
        SELECT 'Error: Grade name is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate salary range
    IF (@MinSalary >= @MaxSalary)
    BEGIN
        SELECT 'Error: Minimum salary must be less than maximum salary.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate CreatedBy
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @CreatedBy)
    BEGIN
        SELECT 'Error: CreatedBy employee does not exist.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent duplicates
    IF EXISTS (SELECT 1 FROM PayGrade WHERE grade_name = @GradeName)
    BEGIN
        SELECT 'Error: Pay grade already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert Pay Grade
    INSERT INTO PayGrade (grade_name, min_salary, max_salary)
    VALUES (@GradeName, @MinSalary, @MaxSalary);

    -- Get ANY valid payroll_id (most recent)
    DECLARE @ValidPayrollID INT;
    SELECT TOP 1 @ValidPayrollID = payroll_id
    FROM Payroll
    ORDER BY payroll_id DESC;

    -- Safety check
    IF @ValidPayrollID IS NULL
    BEGIN
        SELECT 'Error: No payroll records exist, cannot insert log due to schema constraint.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert log with VALID payroll_id
    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (@ValidPayrollID, @CreatedBy, 'Pay Grade Defined: ' + @GradeName);

    SELECT 'Pay grade defined successfully: ' + @GradeName AS ConfirmationMessage;
END;
GO


-- 25. ConfigureEscalationWorkflow
CREATE PROCEDURE ConfigureEscalationWorkflow
    @ThresholdAmount DECIMAL(10,2),
    @ApproverRole VARCHAR(50),
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate threshold amount
    IF @ThresholdAmount <= 0
    BEGIN
        SELECT 'Error: Threshold amount must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate approver role exists
    IF NOT EXISTS (SELECT 1 FROM Role WHERE role_name = @ApproverRole)
    BEGIN
        SELECT 'Error: Approver role not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate CreatedBy exists
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @CreatedBy)
    BEGIN
        SELECT 'Error: CreatedBy employee does not exist.' AS ConfirmationMessage;
        RETURN;
    END;

    DECLARE @RoleID INT;
    SELECT @RoleID = role_id FROM Role WHERE role_name = @ApproverRole;

    -- Prevent duplicate workflows for same role & threshold
    IF EXISTS (
        SELECT 1 FROM ApprovalWorkflow
        WHERE workflow_type = 'Payroll Escalation'
          AND approver_role = @RoleID
          AND threshold_amount = @ThresholdAmount
    )
    BEGIN
        SELECT 'Error: This escalation workflow is already defined.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert escalation workflow
    INSERT INTO ApprovalWorkflow (workflow_type, threshold_amount, approver_role, created_by, status)
    VALUES ('Payroll Escalation', @ThresholdAmount, @RoleID, @CreatedBy, 'Active');

    SELECT 'Escalation workflow configured successfully for threshold ' 
           + CAST(@ThresholdAmount AS VARCHAR(20)) AS ConfirmationMessage;
END;
GO


-- 26. DefinePayType
CREATE PROCEDURE DefinePayType
    @EmployeeID INT,
    @PayType VARCHAR(50),
    @EffectiveDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalaryTypeID INT,
            @CurrencyCode VARCHAR(10),
            @ValidPayrollID INT;

    -- Validate employee exists
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Employee not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate pay type
    IF (@PayType IS NULL OR LTRIM(RTRIM(@PayType)) = '')
    BEGIN
        SELECT 'Error: Pay type is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate EffectiveDate
    IF @EffectiveDate IS NULL
    BEGIN
        SELECT 'Error: Effective date is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Get employee's existing currency
    SELECT TOP 1 @CurrencyCode = st.currency_code
    FROM Employee e
    JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    WHERE e.employee_id = @EmployeeID;

    IF @CurrencyCode IS NULL
        SET @CurrencyCode = 'USD'; -- fallback, but normally won't happen

    -- Check if pay type exists
    IF EXISTS (SELECT 1 FROM SalaryType WHERE type = @PayType)
    BEGIN
        SELECT @SalaryTypeID = salary_type_id FROM SalaryType WHERE type = @PayType;
    END
    ELSE
    BEGIN
        INSERT INTO SalaryType (type, payment_frequency, currency_code)
        VALUES (@PayType, 'Standard', @CurrencyCode);

        SET @SalaryTypeID = SCOPE_IDENTITY();
    END;

    -- Assign pay type to employee
    UPDATE Employee
    SET salary_type_id = @SalaryTypeID
    WHERE employee_id = @EmployeeID;

    -- Get valid payroll ID for logging (cannot insert NULL due to FK)
    SELECT TOP 1 @ValidPayrollID = payroll_id
    FROM Payroll
    ORDER BY payroll_id DESC;

    IF @ValidPayrollID IS NOT NULL
    BEGIN
        INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
        VALUES (
            @ValidPayrollID,
            @EmployeeID,
            'Pay Type Changed to ' + @PayType + ' (Effective ' + CAST(@EffectiveDate AS VARCHAR(20)) + ')'
        );
    END;

    SELECT 'Pay type defined successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO


-- 27. ConfigureOvertimeRules
CREATE PROCEDURE ConfigureOvertimeRules
    @DayType VARCHAR(20),
    @Multiplier DECIMAL(3,2),
    @HoursPerMonth INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyID INT;

    -- Validate DayType
    IF (@DayType NOT IN ('Weekday', 'Weekend'))
    BEGIN
        SELECT 'Error: DayType must be either Weekday or Weekend.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate multiplier
    IF (@Multiplier <= 0)
    BEGIN
        SELECT 'Error: Multiplier must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate hours
    IF (@HoursPerMonth <= 0)
    BEGIN
        SELECT 'Error: HoursPerMonth must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent duplication
    IF EXISTS (
        SELECT 1 FROM OvertimePolicy op
        JOIN PayrollPolicy pp ON op.policy_id = pp.policy_id
        WHERE pp.type = 'Overtime'
          AND pp.description LIKE '%DayType: ' + @DayType + '%'
          AND (
                (op.weekday_rate_multiplier = @Multiplier AND @DayType = 'Weekday') OR
                (op.weekend_rate_multiplier = @Multiplier AND @DayType = 'Weekend')
              )
    )
    BEGIN
        SELECT 'Error: This overtime rule already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert new payroll policy
    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (GETDATE(), 'Overtime', 'DayType: ' + @DayType + ' | Multiplier: ' + CAST(@Multiplier AS VARCHAR(10)));

    SET @PolicyID = SCOPE_IDENTITY();

    -- Insert overtime rule
    INSERT INTO OvertimePolicy (policy_id, weekday_rate_multiplier, weekend_rate_multiplier, max_hours_per_month)
    VALUES (
        @PolicyID,
        CASE WHEN @DayType = 'Weekday' THEN @Multiplier ELSE 1.0 END,
        CASE WHEN @DayType = 'Weekend' THEN @Multiplier ELSE 1.5 END,
        @HoursPerMonth
    );

    SELECT 'Overtime rule configured successfully for ' + @DayType AS ConfirmationMessage;
END;
GO


-- 28. ConfigureShiftAllowance  (DUMMY – prefer to model in schema first)
CREATE PROCEDURE ConfigureShiftAllowance
    @ShiftType VARCHAR(20),
    @AllowanceAmount DECIMAL(10,2),
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate ShiftType
    IF (@ShiftType IS NULL OR LTRIM(RTRIM(@ShiftType)) = '')
    BEGIN
        SELECT 'Error: ShiftType is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate Amount
    IF (@AllowanceAmount <= 0)
    BEGIN
        SELECT 'Error: Allowance amount must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate CreatedBy
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @CreatedBy)
    BEGIN
        SELECT 'Error: CreatedBy employee does not exist.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent duplicate policy
    IF EXISTS (
        SELECT 1 FROM PayrollPolicy
        WHERE [type] = 'Shift Allowance'
        AND [description] = @ShiftType + ' Shift: ' + CAST(@AllowanceAmount AS VARCHAR(20)) + ' allowance'
    )
    BEGIN
        SELECT 'Error: This shift allowance policy already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert policy
    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (
        GETDATE(),
        'Shift Allowance',
        @ShiftType + ' Shift: ' + CAST(@AllowanceAmount AS VARCHAR(20)) + ' allowance'
    );

    DECLARE @PolicyID INT = SCOPE_IDENTITY();

    -- Get valid payroll_id for logging
    DECLARE @ValidPayrollID INT;
    SELECT TOP 1 @ValidPayrollID = payroll_id
    FROM Payroll
    ORDER BY payroll_id DESC;

    IF @ValidPayrollID IS NULL
    BEGIN
        SELECT 'Error: No payroll records exist. Cannot log the operation.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert log
    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (
        @ValidPayrollID,
        @CreatedBy,
        'Shift Allowance Policy Created: ' + @ShiftType
    );

    SELECT 'Shift allowance policy configured successfully for ' + @ShiftType + ' shifts.' AS ConfirmationMessage;
END;
GO


-- 30. ConfigureSigningBonusPolicy
CREATE PROCEDURE ConfigureSigningBonusPolicy
    @BonusType VARCHAR(50),
    @Amount DECIMAL(10,2),
    @EligibilityCriteria NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyID INT,
            @ValidPayrollID INT;

    -- Validate BonusType
    IF (@BonusType IS NULL OR LTRIM(RTRIM(@BonusType)) = '')
    BEGIN
        SELECT 'Error: Bonus type is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate Amount
    IF (@Amount <= 0)
    BEGIN
        SELECT 'Error: Amount must be greater than zero.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate EligibilityCriteria
    IF (@EligibilityCriteria IS NULL OR LTRIM(RTRIM(@EligibilityCriteria)) = '')
    BEGIN
        SELECT 'Error: Eligibility criteria is required.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent duplicate signing bonus policies
    IF EXISTS (
        SELECT 1
        FROM PayrollPolicy
        WHERE [type] = 'Signing Bonus'
          AND [description] = @BonusType + ': ' + CAST(@Amount AS VARCHAR(20))
    )
    BEGIN
        SELECT 'Error: This signing bonus policy already exists.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Insert main payroll policy record
    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (GETDATE(), 'Signing Bonus', @BonusType + ': ' + CAST(@Amount AS VARCHAR(20)));

    SET @PolicyID = SCOPE_IDENTITY();

    -- Insert into BonusPolicy table
    INSERT INTO BonusPolicy (policy_id, bonus_type, eligibility_criteria)
    VALUES (@PolicyID, @BonusType, @EligibilityCriteria);

    -- Get a valid payroll_id for logging
    SELECT TOP 1 @ValidPayrollID = payroll_id
    FROM Payroll
    ORDER BY payroll_id DESC;

    IF @ValidPayrollID IS NOT NULL
    BEGIN
        INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
        VALUES (
            @ValidPayrollID,
            NULL,     -- No employee is making the request; this is a config-level change
            'Signing Bonus Policy Created: ' + @BonusType
        );
    END;

    SELECT 'Signing bonus policy configured successfully for ' + @BonusType AS ConfirmationMessage;
END;
GO


-- 32. GenerateTaxStatement
CREATE PROCEDURE GenerateTaxStatement
    @EmployeeID INT,
    @TaxYear INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.employee_id,
        e.full_name,
        @TaxYear AS tax_year,

        -- Payroll-based totals (correct)
        (
            SELECT SUM(base_amount)
            FROM Payroll
            WHERE employee_id = @EmployeeID
              AND YEAR(period_start) = @TaxYear
        ) AS total_gross_income,

        (
            SELECT SUM(adjustments)
            FROM Payroll
            WHERE employee_id = @EmployeeID
              AND YEAR(period_start) = @TaxYear
        ) AS total_adjustments,

        (
            SELECT SUM(taxes)
            FROM Payroll
            WHERE employee_id = @EmployeeID
              AND YEAR(period_start) = @TaxYear
        ) AS total_taxes_paid,

        (
            SELECT SUM(contributions)
            FROM Payroll
            WHERE employee_id = @EmployeeID
              AND YEAR(period_start) = @TaxYear
        ) AS total_contributions,

        (
            SELECT SUM(net_salary)
            FROM Payroll
            WHERE employee_id = @EmployeeID
              AND YEAR(period_start) = @TaxYear
        ) AS total_net_income,

        -- Allowances/deductions correctly filtered by payroll_id
        (
            SELECT SUM(ad.amount)
            FROM AllowanceDeduction ad
            JOIN Payroll p ON ad.payroll_id = p.payroll_id
            WHERE p.employee_id = @EmployeeID
              AND YEAR(p.period_start) = @TaxYear
        ) AS total_allowances_deductions,

        tf.jurisdiction,
        tf.form_content AS tax_form_details
    FROM Employee e
    LEFT JOIN TaxForm tf ON e.tax_form_id = tf.tax_form_id
    WHERE e.employee_id = @EmployeeID;
END;
GO


-- 33. ApprovePayrollConfiguration  (recheck)
CREATE PROCEDURE ApprovePayrollConfiguration
    @ConfigID INT,
    @ApprovedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ValidPayrollID INT;

    -- Validate configuration record
    IF NOT EXISTS (SELECT 1 FROM ApprovalWorkflow WHERE workflow_id = @ConfigID)
    BEGIN
        SELECT 'Error: Configuration not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Prevent re-approvals
    IF EXISTS (
        SELECT 1 FROM ApprovalWorkflow 
        WHERE workflow_id = @ConfigID
          AND status = 'Approved'
    )
    BEGIN
        SELECT 'Error: Configuration already approved.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Validate Approver
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApprovedBy)
    BEGIN
        SELECT 'Error: Approver not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Approve configuration
    UPDATE ApprovalWorkflow
    SET status = 'Approved'
    WHERE workflow_id = @ConfigID;

    -- Get valid payroll_id for logging
    SELECT TOP 1 @ValidPayrollID = payroll_id
    FROM Payroll
    ORDER BY payroll_id DESC;

    IF @ValidPayrollID IS NULL
    BEGIN
        SELECT 'Error: No payroll records exist for logging.' AS ConfirmationMessage;
        RETURN;
    END;

    -- Log approval
    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (
        @ValidPayrollID,
        @ApprovedBy,
        'Payroll Configuration Approved (ConfigID = ' + CAST(@ConfigID AS VARCHAR(10)) + ')'
    );

    SELECT 'Payroll configuration approved successfully.' AS ConfirmationMessage;
END;
GO


-- 34. ModifyPastPayroll
CREATE PROCEDURE ModifyPastPayroll
    @PayrollRunID INT,
    @EmployeeID INT,
    @FieldName VARCHAR(50),
    @NewValue DECIMAL(10,2),
    @ModifiedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------------------
    -- Validate payroll record exists
    -----------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM Payroll 
        WHERE payroll_id = @PayrollRunID 
          AND employee_id = @EmployeeID
    )
    BEGIN
        SELECT 'Error: Payroll record not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------
    -- Validate modifier exists
    -----------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM Employee WHERE employee_id = @ModifiedBy
    )
    BEGIN
        SELECT 'Error: ModifiedBy employee not found.' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------
    -- Validate NewValue
    -----------------------------------------------------
    IF @NewValue < 0
    BEGIN
        SELECT 'Error: New value cannot be negative.' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------
    -- Normalize field name (case-insensitive)
    -----------------------------------------------------
    SET @FieldName = LOWER(LTRIM(RTRIM(@FieldName)));

    -----------------------------------------------------
    -- Validate field name
    -----------------------------------------------------
    IF @FieldName NOT IN (
        'base_amount', 'adjustments', 'taxes', 
        'contributions', 'actual_pay', 'net_salary'
    )
    BEGIN
        SELECT 'Error: Invalid field name.' AS ConfirmationMessage;
        RETURN;
    END;

    -----------------------------------------------------
    -- Perform update dynamically and safely
    -----------------------------------------------------
    IF @FieldName = 'base_amount'
        UPDATE Payroll SET base_amount = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;

    ELSE IF @FieldName = 'adjustments'
        UPDATE Payroll SET adjustments = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;

    ELSE IF @FieldName = 'taxes'
        UPDATE Payroll SET taxes = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;

    ELSE IF @FieldName = 'contributions'
        UPDATE Payroll SET contributions = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;

    ELSE IF @FieldName = 'actual_pay'
        UPDATE Payroll SET actual_pay = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;

    ELSE IF @FieldName = 'net_salary'
        UPDATE Payroll SET net_salary = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;

    -----------------------------------------------------
    -- Insert log entry
    -----------------------------------------------------
    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (
        @PayrollRunID,
        @ModifiedBy,
        'Modified ' + @FieldName + ' to ' + CAST(@NewValue AS VARCHAR(20))
    );

    -----------------------------------------------------
    -- Return success
    -----------------------------------------------------
    SELECT 'Payroll entry modified successfully for employee ' 
            + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO
