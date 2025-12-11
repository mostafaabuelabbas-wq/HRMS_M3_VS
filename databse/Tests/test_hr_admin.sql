/*

-- Check employee contract before creating a new one
SELECT employee_id, contract_id 
FROM Employee 
WHERE employee_id = 1;

-- List all existing contracts before
SELECT * FROM Contract ORDER BY contract_id;

-- Check subtype table before (FullTime example)
SELECT * FROM FullTimeContract ORDER BY contract_id;

EXEC CreateContract 
    @EmployeeID = 1,
    @Type = 'FullTime',
    @StartDate = '2025-01-01',
    @EndDate = '2025-12-31';

-- Employee should now reference new contract
SELECT employee_id, contract_id 
FROM Employee 
WHERE employee_id = 1;

-- New contract should exist
SELECT * FROM Contract WHERE contract_id = 4;

-- Subtype table must also contain new entry
SELECT * FROM FullTimeContract WHERE contract_id = 4;
*/
/*



-- 2 RenewContract
-- Before
SELECT * FROM Contract WHERE contract_id = 1;

-- Test RenewContract
EXEC RenewContract 1, '2026-01-01';

-- After
SELECT * FROM Contract WHERE contract_id = 1;
*/



-- 3 ApproveLeaveRequest
/*
-- Check the leave request before approval
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;   -- Example request (Sara’s Sick Leave)

-- Check subtype (VacationLeave) - should NOT change for sick leave
SELECT * FROM VacationLeave;

-- Check notifications before
SELECT * FROM Notification ORDER BY notification_id;

-- Check employee_notification before
SELECT * FROM Employee_Notification WHERE employee_id = 2;
EXEC ApproveLeaveRequest 
    @LeaveRequestID = 2,
    @ApproverID = 1,
    @Status = 'Approved';
    -- 1. Leave request should now be updated
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;

-- 2. Notification should now include the new message
SELECT TOP 1 * 
FROM Notification 
ORDER BY notification_id DESC;

-- 3. Employee_Notification should now have one row for employee 2
SELECT * 
FROM Employee_Notification
WHERE employee_id = 2;
*/


-- 4 AssignMission
/*
-- Check missions before
SELECT * FROM Mission ORDER BY mission_id;

-- Check notifications before
SELECT * FROM Notification ORDER BY notification_id;

-- Check employee notifications before
SELECT * FROM Employee_Notification WHERE employee_id = 2;   -- Example employee

EXEC AssignMission
    @EmployeeID = 2,
    @ManagerID = 1,
    @Destination = 'Dubai',
    @StartDate = '2025-01-10',
    @EndDate = '2025-01-15';


-- New mission should appear
SELECT TOP 1 * FROM Mission ORDER BY mission_id DESC;

-- New notification created
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

-- Notification assigned to employee
SELECT TOP 1 * 
FROM Employee_Notification 
WHERE employee_id = 2
ORDER BY delivered_at DESC;
*/

-- 5 ReviewReimbursement
/*
--before
SELECT reimbursement_id, employee_id, type, current_status, approval_date
FROM Reimbursement
WHERE reimbursement_id = 1;

SELECT * FROM Employee_Notification WHERE employee_id = 1;

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

EXEC ReviewReimbursement
    @ClaimID = 1,
    @ApproverID = 3,
    @Decision = 'Approved';

 -- Reimbursement must now be updated
SELECT reimbursement_id, employee_id, type, current_status, approval_date
FROM Reimbursement
WHERE reimbursement_id = 1;

-- Check the new notification
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

-- Confirm employee received the notification
SELECT TOP 1 *
FROM Employee_Notification
WHERE employee_id = 1
ORDER BY delivered_at DESC;
*/


-- 6 GetActiveContracts
/*
SELECT * FROM Contract;

SELECT employee_id, full_name, contract_id 
FROM Employee;

SELECT department_id, department_name 
FROM Department;

EXEC GetActiveContracts;
*/

-- 7 GetTeamByManager
/*
SELECT employee_id, full_name, manager_id, is_active
FROM Employee
ORDER BY employee_id;
SELECT * FROM Position;
SELECT * FROM Department;

EXEC GetTeamByManager @ManagerID = 1;
*/
/*
-- 8 UpdateLeavePolicy
--before
SELECT policy_id, name, eligibility_rules, notice_period
FROM LeavePolicy
WHERE policy_id = 1;

EXEC UpdateLeavePolicy
    @PolicyID = 1,
    @EligibilityRules = 'Minimum 2 years experience',
    @NoticePeriod = 30;

-- Check updated policy
SELECT policy_id, name, eligibility_rules, notice_period
FROM LeavePolicy
WHERE policy_id = 1;
*/

/*
-- 9 GetExpiringContracts
SELECT contract_id, type, end_date 
FROM Contract;

SELECT employee_id, full_name, contract_id 
FROM Employee;

SELECT department_id, department_name 
FROM Department;

EXEC GetExpiringContracts @DaysBefore = 400;
*/

/*
-- 10 AssignDepartmentHead
SELECT department_id, department_name, department_head_id
FROM Department
ORDER BY department_id;

SELECT employee_id, full_name
FROM Employee
ORDER BY employee_id;

EXEC AssignDepartmentHead 
    @DepartmentID = 2,
    @ManagerID = 1;
-- Check updated department head
SELECT department_id, department_name, department_head_id
FROM Department
WHERE department_id = 2;
*/

-- 11 CreateEmployeeProfile
/*
SELECT employee_id, full_name, email, department_id, position_id
FROM Employee
ORDER BY employee_id;

SELECT * FROM Position;
SELECT * FROM Department;

EXEC CreateEmployeeProfile
    @FirstName = 'John',
    @LastName = 'Doe',
    @DepartmentID = 2,
    @RoleID = 2,
    @HireDate = '2025-02-01',
    @Email = 'john.doe@example.com',
    @Phone = '0105555555',
    @NationalID = '29901011234567',
    @DateOfBirth = '1999-01-01',
    @CountryOfBirth = 'Egypt';


SELECT employee_id, first_name, last_name, country_of_birth, email, department_id, position_id
FROM Employee
WHERE email = 'john.doe@example.com';
*/
/*
-- 12 UpdateEmployeeProfile
SELECT employee_id, full_name, phone, email, address, employment_status
FROM Employee
WHERE employee_id = 2;

EXEC UpdateEmployeeProfile
    @EmployeeID = 2,
    @FieldName = 'phone',
    @NewValue = '01555555555';

SELECT employee_id, full_name, phone
FROM Employee
WHERE employee_id = 2;
*/

-- 13 SetProfileCompleteness
/*
SELECT employee_id, full_name, profile_completion
FROM Employee
WHERE employee_id = 1;

EXEC SetProfileCompleteness
    @EmployeeID = 1,
    @CompletenessPercentage = 100;

SELECT employee_id, full_name, profile_completion
FROM Employee
WHERE employee_id = 1;
*/

-- 14 GenerateProfileReport
/*
SELECT employee_id, full_name, department_id, employment_status, country_of_birth
FROM Employee;

SELECT department_id, department_name FROM Department;

EXEC GenerateProfileReport 
    @FilterField = 'department',
    @FilterValue = 'IT';

EXEC GenerateProfileReport 
    @FilterField = 'employment_status',
    @FilterValue = 'Full-time';

EXEC GenerateProfileReport 
    @FilterField = 'country_of_birth',
    @FilterValue = 'Egypt';

EXEC GenerateProfileReport 
    @FilterField = 'country_of_birth',
    @FilterValue = 'Egypt';
*/


-- 15 CreateShiftType
/*
SELECT shift_id, name, type, start_time, end_time, status
FROM ShiftSchedule;

EXEC CreateShiftType
     @ShiftID = NULL,
     @Name = 'Mission Shift',
     @Type = 'Mission',
     @Start_Time = '08:00',
     @End_Time = '18:00',
     @Break_Duration = 60,
     @Shift_Date = '2025-01-10',
     @Status = 'Active';

SELECT * FROM ShiftSchedule WHERE shift_id = 4;
*/


-- 17 AssignRotationalShift
/*
SELECT * FROM ShiftCycle;
SELECT * FROM ShiftCycleAssignment WHERE cycle_id = 1;

SELECT employee_id, full_name FROM Employee;

SELECT * FROM ShiftAssignment WHERE employee_id = 2;

EXEC AssignRotationalShift
    @EmployeeID = 2,
    @ShiftCycle = 1,
    @StartDate = '2025-01-01',
    @EndDate = '2025-12-31',
    @Status = 'Active';

SELECT *
FROM ShiftAssignment
WHERE employee_id = 2
ORDER BY assignment_id DESC;
*/

-- 18 NotifyShiftExpiry
/*
-- (Before)
SELECT * FROM Notification;
SELECT * FROM Employee_Notification WHERE employee_id = 2;

SELECT assignment_id, employee_id, end_date
FROM ShiftAssignment
WHERE assignment_id = 2;

EXEC NotifyShiftExpiry
    @EmployeeID = 2,
    @ShiftAssignmentID = 2,
    @ExpiryDate = '2024-06-30';

SELECT * FROM Notification ORDER BY notification_id DESC;

SELECT * FROM Employee_Notification 
WHERE employee_id = 2
ORDER BY delivered_at DESC;
*/

-- 19 DefineShortTimeRules
/*
SELECT policy_id, type, description
FROM PayrollPolicy
ORDER BY policy_id;

EXEC DefineShortTimeRules
    @RuleName = 'Minor Lateness Rule',
    @LateMinutes = 10,
    @EarlyLeaveMinutes = 5,
    @PenaltyType = 'Deduction';


SELECT policy_id, type, description
FROM PayrollPolicy
WHERE type = 'Short Time'
ORDER BY policy_id DESC;
*/

-- 20 SetGracePeriod
/*
SELECT policy_id, type, description
FROM PayrollPolicy
ORDER BY policy_id;

SELECT * FROM LatenessPolicy;

EXEC SetGracePeriod @Minutes = 15;

SELECT policy_id, type, description
FROM PayrollPolicy
WHERE type = 'Lateness'
ORDER BY policy_id DESC;

SELECT * FROM LatenessPolicy ORDER BY policy_id DESC;
*/


-- 21 DefinePenaltyThreshold
/*
SELECT policy_id, type, description
FROM PayrollPolicy
ORDER BY policy_id;

SELECT * FROM DeductionPolicy ORDER BY policy_id;

EXEC DefinePenaltyThreshold
    @LateMinutes = 15,
    @DeductionType = 'Half-Day Deduction';

SELECT policy_id, type, description
FROM PayrollPolicy
WHERE type = 'Lateness Penalty'
ORDER BY policy_id DESC;

SELECT *
FROM DeductionPolicy
ORDER BY policy_id DESC;
*/

-- 22 DefinePermissionLimits
/*
SELECT policy_id, type, description
FROM PayrollPolicy
ORDER BY policy_id;

EXEC DefinePermissionLimits
    @MinHours = 1,
    @MaxHours = 4;
SELECT policy_id, type, description
FROM PayrollPolicy
WHERE type = 'Permission Limits'
ORDER BY policy_id DESC;
*/

-- 23 EscalatePendingRequests (Before)
/*
SELECT request_id, status, approval_timing FROM LeaveRequest;
SELECT request_id, status, date FROM AttendanceCorrectionRequest;
SELECT reimbursement_id, current_status, approval_date FROM Reimbursement;

EXEC EscalatePendingRequests
    @Deadline = '2024-12-31';

SELECT request_id, status FROM LeaveRequest;
SELECT request_id, status FROM AttendanceCorrectionRequest;
SELECT reimbursement_id, current_status FROM Reimbursement;
*/

--24
/*
SELECT * FROM ShiftAssignment WHERE employee_id = 2;
SELECT * FROM LeaveEntitlement WHERE employee_id = 2;
SELECT * FROM [Leave];

EXEC LinkVacationToShift
    @VacationPackageID = 1,
    @EmployeeID = 2;

SELECT * FROM ShiftAssignment WHERE employee_id = 2;
SELECT * FROM LeaveEntitlement WHERE employee_id = 2;
*/
--25
/*
SELECT policy_id, name, purpose, notice_period
FROM LeavePolicy;

EXEC ConfigureLeavePolicies;

SELECT policy_id, name, purpose, eligibility_rules
FROM LeavePolicy
WHERE name = 'Default Leave Policy';
*/

-- 26 AuthenticateLeaveAdmin - BEFORE EXECUTE
/*
-- Check which employees exist
SELECT employee_id, full_name
FROM Employee;

-- Check who is an HR Administrator
SELECT * 
FROM HRAdministrator;

-- Check what roles employees have
SELECT er.employee_id, r.role_name
FROM Employee_Role er
JOIN Role r ON er.role_id = r.role_id;

EXEC AuthenticateLeaveAdmin 
     @AdminID = 1,
     @Password = 'anything';
*/


-- 27 ApplyLeaveConfiguration - BEFORE EXECUTE
/*
SELECT e.employee_id, e.full_name, le.leave_type_id, le.entitlement
FROM Employee e
LEFT JOIN LeaveEntitlement le ON e.employee_id = le.employee_id
ORDER BY e.employee_id, le.leave_type_id;

-- Check available leave types
SELECT * FROM VacationLeave;
SELECT * FROM SickLeave;
SELECT * FROM ProbationLeave;
SELECT * FROM HolidayLeave;

EXEC ApplyLeaveConfiguration;


 -- AFTER EXECUTE
SELECT e.employee_id, e.full_name, le.leave_type_id, le.entitlement
FROM Employee e
LEFT JOIN LeaveEntitlement le ON e.employee_id = le.employee_id
ORDER BY e.employee_id, le.leave_type_id;
*/

-- 28 UpdateLeaveEntitlements - BEFORE EXECUTE
/*
SELECT employee_id, full_name, contract_id
FROM Employee
ORDER BY employee_id;

SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2;  -- Example: testing employee 2 (Sara)

EXEC UpdateLeaveEntitlements @EmployeeID = 2;
-- AFTER EXECUTE

SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2
ORDER BY leave_type_id;
*/

/*
SELECT policy_id, name, eligibility_rules, special_leave_type
FROM LeavePolicy
ORDER BY policy_id;

EXEC ConfigureLeaveEligibility
    @LeaveType = 'Vacation',
    @MinTenure = 12,
    @EmployeeType = 'FullTime';

SELECT policy_id, name, eligibility_rules, special_leave_type
FROM LeavePolicy
WHERE special_leave_type = 'Vacation'
ORDER BY policy_id DESC;
*/

-- 30 ManageLeaveTypes - BEFORE EXECUTE
/*
SELECT leave_id, leave_type, leave_description
FROM [Leave]
ORDER BY leave_id;

EXEC ManageLeaveTypes
    @LeaveType = 'Marriage',
    @Description = 'Paid leave for marriage events';

-- AFTER EXECUTE
SELECT leave_id, leave_type, leave_description
FROM [Leave]
ORDER BY leave_id;
*/

/*
-- 31 AssignLeaveEntitlement - BEFORE EXECUTE
SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2;

EXEC AssignLeaveEntitlement
     @EmployeeID = 2,
     @LeaveType = 'Vacation',
     @Entitlement = 15.00;

-- AFTER EXECUTE
SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2;
*/
--32
/*
SELECT policy_id, name, eligibility_rules, notice_period, special_leave_type
FROM LeavePolicy
ORDER BY policy_id;

EXEC ConfigureLeaveRules
    @LeaveType = 'Vacation',
    @MaxDuration = 30,
    @NoticePeriod = 7,
    @WorkflowType = 'ManagerApproval';

SELECT policy_id, name, eligibility_rules, notice_period, special_leave_type
FROM LeavePolicy
WHERE special_leave_type = 'Vacation'
ORDER BY policy_id DESC;
*/

--33 ConfigureSpecialLeave
/*
SELECT policy_id, name, eligibility_rules, notice_period, special_leave_type
FROM LeavePolicy
ORDER BY policy_id;

EXEC ManageLeaveTypes
    @LeaveType = 'Bereavement',
    @Description = 'Leave for family loss events';

EXEC ConfigureSpecialLeave
     @LeaveType = 'Bereavement',
     @Rules = 'Max 5 days; Manager approval required';

SELECT policy_id, name, eligibility_rules, special_leave_type
FROM LeavePolicy
WHERE special_leave_type = 'Bereavement';
*/
--34 SetLeaveYearRules
/*
SELECT policy_id, name, eligibility_rules, special_leave_type
FROM LeavePolicy
ORDER BY policy_id;

EXEC SetLeaveYearRules
    @StartDate = '2025-01-01',
    @EndDate = '2025-12-31';

SELECT policy_id, name, eligibility_rules, special_leave_type
FROM LeavePolicy
WHERE name = 'Leave Year Configuration';
*/


-- 35 AdjustLeaveBalance - BEFORE EXECUTE
/*
SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2;
EXEC AssignLeaveEntitlement
     @EmployeeID = 2,
     @LeaveType = 'Vacation',
     @Entitlement = 15.00;

EXEC AdjustLeaveBalance
    @EmployeeID = 2,
    @LeaveType = 'Vacation',
    @Adjustment = -2.00;

SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2;
*/

-- 36 ManageLeaveRoles - BEFORE EXECUTE
/*
SELECT * FROM Role;

SELECT role_id, permission_name, allowed_action
FROM RolePermission
ORDER BY role_id;

EXEC ManageLeaveRoles
    @RoleID = 1,
    @Permissions = 'Approve,Reject,Edit';

SELECT role_id, permission_name, allowed_action
FROM RolePermission
WHERE role_id = 1;
*/
--37 FinalizeLeaveRequest
/*
SELECT request_id, employee_id, leave_id, duration, status
FROM LeaveRequest
WHERE request_id = 2;

EXEC ApproveLeaveRequest
    @LeaveRequestID = 2,
    @ApproverID = 1,
    @Status = 'Approved';

EXEC FinalizeLeaveRequest @LeaveRequestID = 2;

SELECT request_id, status
FROM LeaveRequest
WHERE request_id = 2;
*/

--38 OverrideLeaveDecision
/*
SELECT request_id, status, justification
FROM LeaveRequest
WHERE request_id = 1;   -- or any ID you want to test

EXEC OverrideLeaveDecision
    @LeaveRequestID = 1,
    @Reason = 'HR reviewed supporting documents and reversed the manager decision.';

SELECT request_id, status, justification
FROM LeaveRequest
WHERE request_id = 1;
*/
--30 BulkProcessLeaveRequests
/*
SELECT request_id, employee_id, status
FROM LeaveRequest
WHERE status = 'Pending';

EXEC BulkProcessLeaveRequests
     @LeaveRequestIDs = '2';

SELECT request_id, employee_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;
*/
--40 VerifyMedicalLeave
/*
SELECT request_id, leave_id, status
FROM LeaveRequest
WHERE request_id = 2;   -- example

SELECT l.leave_type
FROM LeaveRequest lr
JOIN [Leave] l ON lr.leave_id = l.leave_id
WHERE lr.request_id = 2;

SELECT * FROM LeaveDocument
WHERE leave_request_id = 2;

EXEC VerifyMedicalLeave
    @LeaveRequestID = 2,
    @DocumentID = 2;

SELECT * FROM LeaveDocument WHERE document_id = 2;
*/
--41 SyncLeaveBalances
/*
SELECT request_id, employee_id, leave_id, duration, status
FROM LeaveRequest
WHERE request_id = 2;

SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2 AND leave_type_id = 2;

EXEC ApproveLeaveRequest 
    @LeaveRequestID = 2,
    @ApproverID = 1,
    @Status = 'Approved';
EXEC SyncLeaveBalances @LeaveRequestID = 2;

SELECT employee_id, leave_type_id, entitlement
FROM LeaveEntitlement
WHERE employee_id = 2 AND leave_type_id = 2;
*/

--42 ProcessLeaveCarryForward
/*
SELECT e.employee_id, le.leave_type_id, l.leave_type, le.entitlement
FROM LeaveEntitlement le
JOIN [Leave] l ON le.leave_type_id = l.leave_id
JOIN Employee e ON e.employee_id = le.employee_id
ORDER BY e.employee_id, le.leave_type_id;

SELECT * FROM VacationLeave;

SELECT special_leave_type, reset_on_new_year
FROM LeavePolicy;

EXEC ProcessLeaveCarryForward @Year = 2025;

SELECT e.employee_id, e.full_name, l.leave_type, le.entitlement
FROM LeaveEntitlement le
JOIN [Leave] l ON le.leave_type_id = l.leave_id
JOIN Employee e ON e.employee_id = le.employee_id
ORDER BY e.employee_id, le.leave_type_id;
*/

--43 SyncLeaveToAttendance
/*
SELECT request_id, employee_id, duration, approval_timing, status
FROM LeaveRequest
WHERE request_id = 2;

SELECT * FROM [Exception];

SELECT * FROM Employee_Exception WHERE employee_id = 2;
EXEC ApproveLeaveRequest
     @LeaveRequestID = 2,
     @ApproverID = 1,
     @Status = 'Approved';

EXEC SyncLeaveToAttendance @LeaveRequestID = 2;

SELECT *
FROM Employee_Exception
WHERE employee_id = 2;
*/
--44 UpdateInsuranceBrackets
/*
SELECT insurance_id, type, contribution_rate, coverage
FROM Insurance
WHERE insurance_id = 1;   -- example

SELECT * FROM Notification ORDER BY notification_id;

SELECT * FROM Employee_Notification;

EXEC UpdateInsuranceBrackets
    @BracketID = 1,
    @NewMinSalary = 8000,
    @NewMaxSalary = 20000,
    @NewEmployeeContribution = 5.5,
    @NewEmployerContribution = 7.0,
    @UpdatedBy = 1;

SELECT insurance_id, type, contribution_rate, coverage
FROM Insurance
WHERE insurance_id = 1;

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

SELECT TOP 1 * 
FROM Employee_Notification
WHERE employee_id = 1
ORDER BY delivered_at DESC;
*/

--45 ApprovePolicyUpdate
/*
SELECT policy_id, type, description
FROM PayrollPolicy
WHERE policy_id = 1;

SELECT * FROM Notification ORDER BY notification_id;

SELECT * FROM Employee_Notification;

EXEC ApprovePolicyUpdate
    @PolicyID = 1,
    @ApprovedBy = 1;

SELECT policy_id, type, description
FROM PayrollPolicy
WHERE policy_id = 1;

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

SELECT * 
FROM Employee_Notification
WHERE employee_id = 1
ORDER BY delivered_at DESC;
*/
