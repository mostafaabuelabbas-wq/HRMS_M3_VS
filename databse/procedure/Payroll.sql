
--Payroll Officer
-- 1. GeneratePayroll done

CREATE PROCEDURE GeneratePayroll
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- 1. Validate input dates
    ---------------------------------------------------------
    IF @StartDate IS NULL OR @EndDate IS NULL
    BEGIN
        SELECT 'Error: Start and end dates are required.' AS Message;
        RETURN;
    END;

    IF @StartDate > @EndDate
    BEGIN
        SELECT 'Error: Start date cannot be after end date.' AS Message;
        RETURN;
    END;

    ---------------------------------------------------------
    -- 2. Generate payroll calculations
    ---------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        d.department_name,
        pg.grade_name,
        pg.min_salary AS base_amount,

        -----------------------------------------------------
        -- Taxes (simple demo formula: 10%)
        -----------------------------------------------------
        (pg.min_salary * 0.10) AS taxes,

        -----------------------------------------------------
        -- Additions/deductions during period
        -----------------------------------------------------
        ISNULL((
            SELECT SUM(ad.amount)
            FROM AllowanceDeduction ad
            WHERE ad.employee_id = e.employee_id
        ), 0) AS adjustments,

        -----------------------------------------------------
        -- Contributions (simple demo formula: 5%)
        -----------------------------------------------------
        (pg.min_salary * 0.05) AS contributions,

        -----------------------------------------------------
        -- actual_pay = base + adjustments
        -----------------------------------------------------
        (pg.min_salary 
            + ISNULL((SELECT SUM(ad.amount)
                      FROM AllowanceDeduction ad
                      WHERE ad.employee_id = e.employee_id),0)
        ) AS actual_pay,

        -----------------------------------------------------
        -- net_salary = actual_pay - taxes - contributions
        -----------------------------------------------------
        (
            (pg.min_salary 
                + ISNULL((SELECT SUM(ad.amount)
                        FROM AllowanceDeduction ad
                        WHERE ad.employee_id = e.employee_id),0)
            )
            - (pg.min_salary * 0.10)
            - (pg.min_salary * 0.05)
        ) AS net_salary,

        @StartDate AS period_start,
        @EndDate AS period_end,
        GETDATE() AS payment_date
    FROM Employee e
    INNER JOIN PayGrade pg ON e.pay_grade = pg.pay_grade_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE e.is_active = 1
      AND e.account_status = 'Active';
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
    @Amount DECIMAL(10,2),
    @Duration INT,
    @Timezone VARCHAR(20)
AS
BEGIN
    DECLARE @EmployeeID INT;

    -- Validate payroll record exists
    IF NOT EXISTS (SELECT 1 FROM Payroll WHERE payroll_id = @PayrollID)
    BEGIN
        SELECT 'Error: Payroll record not found' AS ConfirmationMessage;
        RETURN;
    END;

    -- Get employee assigned to this payroll record
    SELECT @EmployeeID = employee_id
    FROM Payroll
    WHERE payroll_id = @PayrollID;

    -- If an item of this type already exists → UPDATE it
    IF EXISTS (
        SELECT 1 
        FROM AllowanceDeduction
        WHERE payroll_id = @PayrollID AND type = @Type
    )
    BEGIN
        UPDATE AllowanceDeduction
        SET amount = @Amount,
            duration = @Duration,
            timezone = @Timezone,
            currency_code = 'USD'
        WHERE payroll_id = @PayrollID
          AND type = @Type;
    END
    ELSE
    BEGIN
        INSERT INTO AllowanceDeduction
            (payroll_id, employee_id, type, amount, currency_code, duration, timezone)
        VALUES
            (@PayrollID, @EmployeeID, @Type, @Amount, 'USD', @Duration, @Timezone);
    END

    SELECT 'Payroll item adjusted successfully' AS ConfirmationMessage;
END;
GO


/*
--before
SELECT ad_id, payroll_id, employee_id, type, amount, currency_code, duration, timezone
FROM AllowanceDeduction
WHERE payroll_id = 1;

EXEC AdjustPayrollItem
    @PayrollID = 1,
    @Type = 'Bonus',
    @Amount = 999,
    @Duration = 45,
    @Timezone = 'AST';

--after
SELECT ad_id, payroll_id, employee_id, type, amount, currency_code, duration, timezone
FROM AllowanceDeduction 
WHERE payroll_id = 1;
*/

-- 3. CalculateNetSalary
CREATE OR ALTER PROCEDURE CalculateNetSalary 
    @PayrollID INT,
    @NetSalary DECIMAL(10,2) OUTPUT
AS
BEGIN
    DECLARE @Base DECIMAL(10,2),
            @Taxes DECIMAL(10,2),
            @Contrib DECIMAL(10,2),
            @Adjust DECIMAL(10,2);

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

    -- NULL -> 0
    SET @Adjust = ISNULL(@Adjust, 0);

    SET @NetSalary = @Base + @Adjust - @Taxes - @Contrib;
END;
GO
/*
SELECT *
FROM Payroll
WHERE payroll_id = 1;

SELECT *
FROM AllowanceDeduction
WHERE payroll_id = 1;

DECLARE @Net DECIMAL(10,2);
EXEC CalculateNetSalary @PayrollID = 1, @NetSalary = @Net OUTPUT;
SELECT @Net AS NetSalary;

SELECT *
FROM Payroll
WHERE payroll_id = 1;
*/


-- 4. ApplyPayrollPolicy
CREATE PROCEDURE ApplyPayrollPolicy
    @PolicyID INT,
    @PayrollID INT,
    @Type VARCHAR(20),
    @Description VARCHAR(50)
AS
BEGIN
    -- Validate policy
    IF NOT EXISTS (
        SELECT 1
        FROM PayrollPolicy
        WHERE policy_id = @PolicyID
          AND type = @Type
          AND description = @Description
    )
    BEGIN
        SELECT 'Error: Policy type or description does not match.' AS Message;
        RETURN;
    END;


    -- Prevent duplicates
    IF EXISTS (
        SELECT 1
        FROM PayrollPolicy_ID
        WHERE payroll_id = @PayrollID
          AND policy_id = @PolicyID
    )
    BEGIN
        SELECT 'Policy already applied to this payroll.' AS Message;
        RETURN;
    END;


    INSERT INTO PayrollPolicy_ID (payroll_id, policy_id)
    VALUES (@PayrollID, @PolicyID);

    SELECT 'Payroll policy applied successfully' AS ConfirmationMessage;
END;
GO
/*
--before


SELECT *
FROM PayrollPolicy_ID
WHERE payroll_id = 1;

EXEC ApplyPayrollPolicy
    @PolicyID = 1,
    @PayrollID = 1,
    @Type = 'General',
    @Description = 'General payroll rules';


--after

SELECT 
    pp.policy_id,
    pp.type,
    pp.description,
    ppid.payroll_id
FROM PayrollPolicy_ID ppid
JOIN PayrollPolicy pp
    ON ppid.policy_id = pp.policy_id
WHERE ppid.payroll_id = 1;
*/




-- 5. GetMonthlyPayrollSummary
CREATE PROCEDURE GetMonthlyPayrollSummary
    @Month INT,
    @Year INT
AS
SELECT SUM(net_salary) AS TotalSalaryExpenditure
FROM Payroll
WHERE MONTH(payment_date) = @Month
  AND YEAR(payment_date) = @Year;
GO
/*
EXEC GetMonthlyPayrollSummary 
     @Month = 3,
     @Year = 2024;
*/



-- 6. GetEmployeePayrollHistory
CREATE PROCEDURE GetEmployeePayrollHistory
    @EmployeeID INT
AS
BEGIN
SELECT *
FROM Payroll
WHERE employee_id = @EmployeeID
ORDER BY period_start;
END;
GO
/*
EXEC GetEmployeePayrollHistory @EmployeeID = 2;
*/
-- 8. GetBonusEligibleEmployees
CREATE PROCEDURE GetBonusEligibleEmployees
    @Eligibility_criteria VARCHAR(500)
AS
BEGIN
    SELECT 
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
    WHERE bp.eligibility_criteria = @Eligibility_criteria
        AND e.is_active = 1;
END;
GO
-- 9. UpdateSalaryType
CREATE PROCEDURE UpdateSalaryType
    @EmployeeID INT,
    @SalaryTypeID INT
AS
BEGIN
    UPDATE Employee
    SET salary_type_id = @SalaryTypeID
    WHERE employee_id = @EmployeeID;

    SELECT 'Salary type updated successfully' AS ConfirmationMessage;
END;
GO

-- 10. GetPayrollByDepartment
CREATE PROCEDURE GetPayrollByDepartment
    @DepartmentID INT,
    @Month INT,
    @Year INT
AS
BEGIN
    SELECT 
        e.department_id,
        d.department_name,
        COUNT(p.payroll_id) AS total_employees,
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
CREATE PROCEDURE ValidateAttendanceBeforePayroll
    @PayrollPeriodID INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM PayrollPeriod WHERE payroll_period_id = @PayrollPeriodID)
    BEGIN
        SELECT 'Error: Payroll period not found' AS Message;
        RETURN;
    END;

    SELECT 
        e.employee_id,
        e.full_name,
        e.department_id,
        a.attendance_id,
        a.entry_time,
        a.exit_time,
        a.exception_id
    FROM Attendance a
    INNER JOIN Employee e ON a.employee_id = e.employee_id
    INNER JOIN PayrollPeriod pp ON pp.payroll_period_id = @PayrollPeriodID
    WHERE (a.entry_time IS NULL OR a.exit_time IS NULL)
        AND CAST(a.entry_time AS DATE) BETWEEN pp.start_date AND pp.end_date;
END;
GO

-- 12. ComparePlannedVsActual
CREATE PROCEDURE SyncAttendanceToPayroll
    @SyncDate DATE
AS
BEGIN
    INSERT INTO AllowanceDeduction (payroll_id, employee_id, type, amount, duration, currency_code)
    SELECT 
        p.payroll_id,
        a.employee_id,
        'Attendance Adjustment',
        0.00,
        CAST(a.duration AS VARCHAR(50)),
        'USD'
    FROM Attendance a
    INNER JOIN Payroll p ON a.employee_id = p.employee_id
    WHERE CAST(a.entry_time AS DATE) = @SyncDate
        AND a.exit_time IS NOT NULL
        AND CAST(a.entry_time AS DATE) BETWEEN p.period_start AND p.period_end;

    SELECT 'Attendance synced to payroll successfully' AS ConfirmationMessage;
END;
GO
-- 13. SyncApprovedPermissionsToPayroll
CREATE PROCEDURE SyncApprovedPermissionsToPayroll
    @PayrollPeriodID INT
AS
BEGIN
    INSERT INTO AllowanceDeduction (payroll_id, employee_id, type, amount, duration, currency_code)
    SELECT 
        pp.payroll_id,
        lr.employee_id,
        'Leave Deduction',
        0.00,
        CAST(lr.duration AS VARCHAR(50)),
        'USD'
    FROM LeaveRequest lr
    INNER JOIN PayrollPeriod pp ON pp.payroll_period_id = @PayrollPeriodID
    WHERE lr.status = 'Approved'
        AND lr.approval_timing BETWEEN pp.start_date AND pp.end_date;

    SELECT 'Approved permissions synced to payroll successfully' AS ConfirmationMessage;
END;
GO
-- 14. ConfigurePayGrades
CREATE PROCEDURE ConfigurePayGrades
    @GradeName VARCHAR(50),
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2)
AS
INSERT INTO PayGrade (grade_name, min_salary, max_salary)
VALUES (@GradeName, @MinSalary, @MaxSalary);

PRINT 'Pay grade configured successfully';
GO

-- 15. ConfigureShiftAllowances
-- ======================================================
-- Procedure: ConfigureShiftAllowances
-- Description: Configure shift differentials and special allowances
-- ======================================================
CREATE PROCEDURE ConfigureShiftAllowances
    @ShiftType VARCHAR(50),
    @AllowanceName VARCHAR(50),
    @Amount DECIMAL(10,2)
AS
BEGIN
    INSERT INTO AllowanceDeduction (employee_id, type, amount, currency_code)
    SELECT 
        sa.employee_id,
        @AllowanceName,
        @Amount,
        'USD'
    FROM ShiftAssignment sa
    INNER JOIN ShiftSchedule ss ON sa.shift_id = ss.shift_id
    WHERE ss.type = @ShiftType
        AND sa.status = 'Active';

    SELECT 'Shift allowance configured successfully for ' + @ShiftType + ' shifts' AS ConfirmationMessage;
END;
GO
-- 16. EnableMultiCurrencyPayroll
CREATE PROCEDURE EnableMultiCurrencyPayroll
    @CurrencyCode VARCHAR(10),
    @ExchangeRate DECIMAL(10,4)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Currency WHERE CurrencyCode = @CurrencyCode)
    BEGIN
        UPDATE Currency
        SET ExchangeRate = @ExchangeRate, LastUpdated = GETDATE()
        WHERE CurrencyCode = @CurrencyCode;

        SELECT 'Currency exchange rate updated' AS ConfirmationMessage;
    END
    ELSE
    BEGIN
        INSERT INTO Currency (CurrencyCode, CurrencyName, ExchangeRate, CreatedDate, LastUpdated)
        VALUES (@CurrencyCode, @CurrencyCode, @ExchangeRate, GETDATE(), GETDATE());

        SELECT 'Currency added and multi-currency enabled for ' + @CurrencyCode AS ConfirmationMessage;
    END;
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
    INSERT INTO TaxForm (jurisdiction, form_content)
    VALUES (@CountryCode, @TaxRuleName + ': Rate=' + CAST(@Rate AS VARCHAR(10)) + '%, Exemption=' + CAST(@Exemption AS VARCHAR(20)));

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
    IF EXISTS (SELECT 1 FROM ApprovalWorkflow WHERE workflow_id = @ConfigID)
    BEGIN
        UPDATE ApprovalWorkflow
        SET status = @Status
        WHERE workflow_id = @ConfigID;

        SELECT 'Payroll configuration change ' + @Status AS ConfirmationMessage;
    END
    ELSE
    BEGIN
        INSERT INTO ApprovalWorkflow (workflow_type, approver_role, created_by, status)
        SELECT 
            'Payroll Config',
            er.role_id,
            @ApproverID,
            @Status
        FROM Employee_Role er
        WHERE er.employee_id = @ApproverID;

        SELECT 'Payroll configuration approval created with status: ' + @Status AS ConfirmationMessage;
    END;
END;
GO
-- 19. ConfigureSigningBonus
CREATE PROCEDURE ConfigureSigningBonus
    @EmployeeID INT,
    @BonusAmount DECIMAL(10,2),
    @EffectiveDate DATE
AS
BEGIN
    INSERT INTO AllowanceDeduction (employee_id, type, amount, currency_code)
    VALUES (@EmployeeID, 'Signing Bonus', @BonusAmount, 'USD');

    SELECT 'Signing bonus configured successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
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
    INSERT INTO Termination (date, reason, contract_id)
    SELECT 
        @EffectiveDate,
        @Reason,
        e.contract_id
    FROM Employee e
    WHERE e.employee_id = @EmployeeID;

    INSERT INTO AllowanceDeduction (employee_id, type, amount, currency_code)
    VALUES (@EmployeeID, 'Termination Compensation', @CompensationAmount, 'USD');

    SELECT 'Termination benefits configured successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
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
    INSERT INTO Insurance (type, contribution_rate, coverage)
    VALUES (
        @InsuranceType, 
        @EmployeeContribution,
        'Salary Range: ' + CAST(@MinSalary AS VARCHAR(20)) + ' - ' + CAST(@MaxSalary AS VARCHAR(20)) + ' | Employer: ' + CAST(@EmployerContribution AS VARCHAR(10)) + '%'
    );

    SELECT 'Insurance bracket configured successfully for ' + @InsuranceType AS ConfirmationMessage;
END;
GO

-- 22. UpdateInsuranceBrackets
CREATE OR ALTER PROCEDURE UpdateInsuranceBrackets
    @BracketID INT,
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2),
    @EmployeeContribution DECIMAL(5,2),
    @EmployerContribution DECIMAL(5,2)
AS
BEGIN
    UPDATE Insurance
    SET contribution_rate = @EmployeeContribution,
        coverage = 'Salary Range: ' + CAST(@MinSalary AS VARCHAR(20)) + ' - ' + CAST(@MaxSalary AS VARCHAR(20)) + ' | Employer: ' + CAST(@EmployerContribution AS VARCHAR(10)) + '%'
    WHERE insurance_id = @BracketID;

    SELECT 'Insurance bracket updated successfully' AS ConfirmationMessage;
END;
GO

-- 23. ConfigurePayrollPolicies
CREATE PROCEDURE ConfigurePayrollPolicies
    @PolicyType VARCHAR(50),
    @PolicyDetails NVARCHAR(MAX),
    @CreatedBy INT
AS
INSERT INTO PayrollPolicy (effective_date, [type], [description])
VALUES (GETDATE(), @PolicyType, @PolicyDetails);

PRINT 'Payroll policy created';
GO

-- 24. DefinePayGrades
CREATE PROCEDURE DefinePayGrades
    @GradeName VARCHAR(50),
    @MinSalary DECIMAL(10,2),
    @MaxSalary DECIMAL(10,2),
    @CreatedBy INT
AS
BEGIN
    INSERT INTO PayGrade (grade_name, min_salary, max_salary)
    VALUES (@GradeName, @MinSalary, @MaxSalary);

    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (NULL, @CreatedBy, 'Pay Grade Defined: ' + @GradeName);

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
    IF EXISTS (SELECT 1 FROM Role WHERE role_name = @ApproverRole)
    BEGIN
        INSERT INTO ApprovalWorkflow (workflow_type, threshold_amount, approver_role, created_by, status)
        SELECT 
            'Payroll Escalation',
            @ThresholdAmount,
            r.role_id,
            @CreatedBy,
            'Active'
        FROM Role r
        WHERE r.role_name = @ApproverRole;

        SELECT 'Escalation workflow configured successfully for amounts exceeding ' + CAST(@ThresholdAmount AS VARCHAR(20)) AS ConfirmationMessage;
    END
    ELSE
    BEGIN
        SELECT 'Error: Approver role not found' AS ConfirmationMessage;
    END
END;
GO
-- 26. DefinePayType
CREATE PROCEDURE DefinePayType
    @EmployeeID INT,
    @PayType VARCHAR(50),
    @EffectiveDate DATE
AS
BEGIN
    DECLARE @SalaryTypeID INT;

    IF EXISTS (SELECT 1 FROM SalaryType WHERE type = @PayType)
    BEGIN
        SELECT @SalaryTypeID = salary_type_id FROM SalaryType WHERE type = @PayType;
        
        UPDATE Employee
        SET salary_type_id = @SalaryTypeID
        WHERE employee_id = @EmployeeID;

        SELECT 'Pay type defined successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
    END
    ELSE
    BEGIN
        INSERT INTO SalaryType (type, payment_frequency, currency_code)
        VALUES (@PayType, 'Standard', 'USD');

        SET @SalaryTypeID = SCOPE_IDENTITY();
        
        UPDATE Employee
        SET salary_type_id = @SalaryTypeID
        WHERE employee_id = @EmployeeID;

        SELECT 'New pay type created and assigned to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
    END
END;
GO

-- 27. ConfigureOvertimeRules
CREATE PROCEDURE ConfigureOvertimeRules
    @DayType VARCHAR(20),
    @Multiplier DECIMAL(3,2),
    @HoursPerMonth INT
AS
BEGIN
    DECLARE @PolicyID INT;

    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (GETDATE(), 'Overtime', 'DayType: ' + @DayType + ' | Multiplier: ' + CAST(@Multiplier AS VARCHAR(10)));

    SET @PolicyID = SCOPE_IDENTITY();

    INSERT INTO OvertimePolicy (policy_id, weekday_rate_multiplier, weekend_rate_multiplier, max_hours_per_month)
    VALUES (
        @PolicyID,
        CASE WHEN @DayType = 'Weekday' THEN @Multiplier ELSE 1.0 END,
        CASE WHEN @DayType = 'Weekend' THEN @Multiplier ELSE 1.5 END,
        @HoursPerMonth);

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
    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (
        GETDATE(), 
        'Shift Allowance',
        @ShiftType + ' Shift: ' + CAST(@AllowanceAmount AS VARCHAR(20)) + ' allowance'
    );

    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (NULL, @CreatedBy, 'Shift Allowance Policy Created: ' + @ShiftType);

    SELECT 'Shift allowance policy configured successfully for ' + @ShiftType + ' shifts' AS ConfirmationMessage;
END;
GO

-- 30. ConfigureSigningBonusPolicy
CREATE PROCEDURE ConfigureSigningBonusPolicy
    @BonusType VARCHAR(50),
    @Amount DECIMAL(10,2),
    @EligibilityCriteria NVARCHAR(MAX)
AS
BEGIN
    DECLARE @PolicyID INT;

    INSERT INTO PayrollPolicy (effective_date, [type], [description])
    VALUES (GETDATE(), 'Signing Bonus', @BonusType + ': ' + CAST(@Amount AS VARCHAR(20)));

    SET @PolicyID = SCOPE_IDENTITY();

    INSERT INTO BonusPolicy (policy_id, bonus_type, eligibility_criteria)
    VALUES (@PolicyID, @BonusType, @EligibilityCriteria);

    SELECT 'Signing bonus policy configured successfully for ' + @BonusType AS ConfirmationMessage;
END;
GO

-- 32. GenerateTaxStatement
CREATE PROCEDURE GenerateTaxStatement
    @EmployeeID INT,
    @TaxYear INT
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name,
        @TaxYear AS tax_year,
        SUM(p.base_amount) AS total_gross_income,
        SUM(p.adjustments) AS total_adjustments,
        SUM(p.taxes) AS total_taxes_paid,
        SUM(p.contributions) AS total_contributions,
        SUM(p.net_salary) AS total_net_income,
        ISNULL(SUM(ad.amount), 0) AS total_allowances_deductions,
        tf.jurisdiction,
        tf.form_content AS tax_form_details
    FROM Employee e
    INNER JOIN Payroll p ON e.employee_id = p.employee_id
    LEFT JOIN TaxForm tf ON e.tax_form_id = tf.tax_form_id
    LEFT JOIN AllowanceDeduction ad ON e.employee_id = ad.employee_id
    WHERE e.employee_id = @EmployeeID
        AND YEAR(p.period_start) = @TaxYear
    GROUP BY e.employee_id, e.full_name, tf.jurisdiction, tf.form_content;
END;
GO
-- 33. ApprovePayrollConfiguration  (recheck)
CREATE PROCEDURE ApprovePayrollConfiguration
    @ConfigID INT,
    @ApprovedBy INT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM ApprovalWorkflow WHERE workflow_id = @ConfigID)
    BEGIN
        UPDATE ApprovalWorkflow
        SET status = 'Approved'
        WHERE workflow_id = @ConfigID;

        INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
        VALUES (NULL, @ApprovedBy, 'Configuration Approved: ConfigID ' + CAST(@ConfigID AS VARCHAR(10)));

        SELECT 'Payroll configuration approved successfully' AS ConfirmationMessage;
    END
    ELSE
    BEGIN
        SELECT 'Error: Configuration not found' AS ConfirmationMessage;
    END
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
    IF NOT EXISTS (SELECT 1 FROM Payroll WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID)
    BEGIN
        SELECT 'Error: Payroll record not found' AS ConfirmationMessage;
        RETURN;
    END;

    IF @FieldName = 'base_amount'
    BEGIN
        UPDATE Payroll SET base_amount = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;
    END
    ELSE IF @FieldName = 'adjustments'
    BEGIN
        UPDATE Payroll SET adjustments = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;
    END
    ELSE IF @FieldName = 'taxes'
    BEGIN
        UPDATE Payroll SET taxes = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;
    END
    ELSE IF @FieldName = 'contributions'
    BEGIN
        UPDATE Payroll SET contributions = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;
    END
    ELSE IF @FieldName = 'actual_pay'
    BEGIN
        UPDATE Payroll SET actual_pay = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;
    END
    ELSE IF @FieldName = 'net_salary'
    BEGIN
        UPDATE Payroll SET net_salary = @NewValue WHERE payroll_id = @PayrollRunID AND employee_id = @EmployeeID;
    END
    ELSE
    BEGIN
        SELECT 'Error: Invalid field name' AS ConfirmationMessage;
        RETURN;
    END;

    INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
    VALUES (@PayrollRunID, @ModifiedBy, 'Modified ' + @FieldName + ' to ' + CAST(@NewValue AS VARCHAR(20)));

    SELECT 'Payroll entry modified successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO
