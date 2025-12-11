SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE HRMS;
SET NOCOUNT ON;



------------------------------------------------------------
-- 1. Currency
------------------------------------------------------------
INSERT INTO Currency (CurrencyCode, CurrencyName, ExchangeRate) VALUES
('EGP','Egyptian Pound',1.000000),
('USD','US Dollar',30.000000),
('EUR','Euro',33.000000);

------------------------------------------------------------
-- 2. Position
------------------------------------------------------------
INSERT INTO Position (position_title, responsibilities, status) VALUES
('HR Manager','Manage HR operations','Active'),
('Software Engineer','Develop and maintain systems','Active'),
('Accountant','Handle financial records','Active');

------------------------------------------------------------
-- 3. Role
------------------------------------------------------------
INSERT INTO Role (role_name, purpose) VALUES
('HRAdmin','HR Permissions'),
('PayrollOfficer','Handles payroll'),
('Employee','Standard access');

------------------------------------------------------------
-- 4. Skill
------------------------------------------------------------
INSERT INTO Skill (skill_name, description) VALUES
('SQL','Database skills'),
('Java','Backend development'),
('Excel','Spreadsheet analysis');

------------------------------------------------------------
-- 5. Verification
------------------------------------------------------------
INSERT INTO Verification (verification_type, issuer, issue_date, expiry_period) VALUES
('ID Check','Gov','2020-01-01',60),
('Degree Check','University','2018-06-01',120),
('Background Check','Agency','2022-01-01',36);

------------------------------------------------------------
-- 6. PayGrade
------------------------------------------------------------
INSERT INTO PayGrade (grade_name, min_salary, max_salary) VALUES
('Junior',7000,12000),
('Mid',12001,22000),
('Senior',22001,45000);

------------------------------------------------------------
-- 7. TaxForm
------------------------------------------------------------
INSERT INTO TaxForm (jurisdiction, validity_period, form_content) VALUES
('Egypt',12,'Local Tax Form'),
('USA',12,'W-2'),
('Germany',12,'DE Tax Form');

------------------------------------------------------------
-- 8. SalaryType
------------------------------------------------------------
INSERT INTO SalaryType ([type], payment_frequency, currency_code) VALUES
('Monthly','Monthly','EGP'),
('Hourly','Monthly','EGP'),
('Contract','Project','USD');

DECLARE @stype1 INT = (SELECT salary_type_id FROM SalaryType WHERE [type]='Monthly');
DECLARE @stype2 INT = (SELECT salary_type_id FROM SalaryType WHERE [type]='Hourly');
DECLARE @stype3 INT = (SELECT salary_type_id FROM SalaryType WHERE [type]='Contract');

------------------------------------------------------------
-- 9. Insurance
------------------------------------------------------------
INSERT INTO Insurance ([type], contribution_rate, coverage) VALUES
('Medical',5.0,'Basic'),
('Dental',1.5,'Standard'),
('Life',2.0,'Essential');

------------------------------------------------------------
-- 10. Contract
------------------------------------------------------------
INSERT INTO Contract ([type], start_date, end_date, current_state) VALUES
('FullTime','2024-01-01','2026-01-01','Active'),
('PartTime','2024-02-01','2024-08-01','Active'),
('Consultant','2024-03-01','2024-09-01','Active');

DECLARE @c1 INT = (SELECT contract_id FROM Contract WHERE [type]='FullTime');
DECLARE @c2 INT = (SELECT contract_id FROM Contract WHERE [type]='PartTime');
DECLARE @c3 INT = (SELECT contract_id FROM Contract WHERE [type]='Consultant');

------------------------------------------------------------
-- 11. Contract Subtypes
------------------------------------------------------------
INSERT INTO FullTimeContract (contract_id, leave_entitlement, insurance_eligibility, weekly_working_hours)
VALUES (@c1,21,1,40);

INSERT INTO PartTimeContract (contract_id, working_hours, hourly_rate)
VALUES (@c2,20,150);

INSERT INTO ConsultantContract (contract_id, project_scope, fees, payment_schedule)
VALUES (@c3,'API Integration',12000,'Monthly');

INSERT INTO InternshipContract (contract_id, mentoring, evaluation, stipend_related)
VALUES (@c2,'Learning program','Mid-term evaluation','200');

------------------------------------------------------------
-- 12. Department
------------------------------------------------------------
INSERT INTO Department (department_name, purpose) VALUES
('HR','HR Operations'),
('IT','Technical Support'),
('Finance','Financial Operations');

DECLARE @d1 INT = (SELECT department_id FROM Department WHERE department_name='HR');
DECLARE @d2 INT = (SELECT department_id FROM Department WHERE department_name='IT');
DECLARE @d3 INT = (SELECT department_id FROM Department WHERE department_name='Finance');

------------------------------------------------------------
-- 13. Employee
------------------------------------------------------------
INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth,
    country_of_birth, phone, email, address, employment_progress,
    account_status, employment_status, hire_date, is_active,
    profile_completion, department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES
('Ahmed','Hassan','29311281234567','1999-03-05','Egypt',
 '01012345678','ahmed@example.com','Nasr City','Onboarding','Active','Full-time',
 '2024-02-01',1,95,@d1,1,NULL,@c1,1,@stype1,1),

('Sara','Adel','29801011234567','2000-01-01','Egypt',
 '01098765432','sara@example.com','Heliopolis','Active','Active','Part-time',
 '2024-03-01',1,90,@d2,2,NULL,@c2,2,@stype2,1),

('Mohamed','Ibrahim','29201011234500','1988-06-10','Egypt',
 '01122233344','mohamed@example.com','Maadi','Active','Active','Full-time',
 '2022-05-01',1,96,@d3,3,NULL,@c1,3,@stype1,2);

DECLARE @e1 INT = (SELECT employee_id FROM Employee WHERE email='ahmed@example.com');
DECLARE @e2 INT = (SELECT employee_id FROM Employee WHERE email='sara@example.com');
DECLARE @e3 INT = (SELECT employee_id FROM Employee WHERE email='mohamed@example.com');

-- Assign correct hierarchy
UPDATE Employee SET manager_id = NULL WHERE employee_id = @e1;  -- Ahmed has no manager
UPDATE Employee SET manager_id = @e1 WHERE employee_id = @e2;   -- Sara reports to Ahmed
UPDATE Employee SET manager_id = @e1 WHERE employee_id = @e3;   -- Mohamed reports to Ahmed

------------------------------------------------------------
-- 14. Employee Skill
------------------------------------------------------------
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level) VALUES
(@e1,1,'Advanced'),
(@e2,2,'Beginner'),
(@e3,3,'Intermediate');

------------------------------------------------------------
-- 15. Employee Verification
------------------------------------------------------------
INSERT INTO Employee_Verification (employee_id, verification_id) VALUES
(@e1,1),(@e2,2),(@e3,3);

------------------------------------------------------------
-- 16. Employee Role
------------------------------------------------------------
INSERT INTO Employee_Role (employee_id, role_id, assigned_date) VALUES
(@e1,1,'2024-01-01'),
(@e2,3,'2024-03-01'),
(@e3,2,'2023-01-01');

------------------------------------------------------------
-- 17. Additional Tables (Mission, Leave, Payroll, etc.)
------------------------------------------------------------
-- (Message trimmed for space—send “continue” to receive the remaining 60% of the script)
------------------------------------------------------------
-- 18. Mission (3 rows)
------------------------------------------------------------
INSERT INTO Mission (destination, start_date, end_date, status, employee_id, manager_id) VALUES
('Alexandria','2024-02-10','2024-02-12','Planned',@e1,NULL),
('Cairo','2024-03-05','2024-03-06','Completed',@e2,@e1),
('Giza','2024-04-10','2024-04-12','Planned',@e3,@e1);

------------------------------------------------------------
-- 19. Leave Types
------------------------------------------------------------
INSERT INTO [Leave] (leave_type, leave_description) VALUES
('Vacation','Annual paid leave'),
('Sick','Medical leave'),
('Probation','Probationary leave'),
('Holiday','Official public holiday'); 

DECLARE @lv1 INT = (SELECT leave_id FROM [Leave] WHERE leave_type='Vacation');
DECLARE @lv2 INT = (SELECT leave_id FROM [Leave] WHERE leave_type='Sick');
DECLARE @lv3 INT = (SELECT leave_id FROM [Leave] WHERE leave_type='Probation');
DECLARE @lvHoliday INT = (SELECT leave_id FROM [Leave] WHERE leave_type='Holiday');

INSERT INTO VacationLeave (leave_id, carry_over_days, approving_manager)
VALUES (@lv1,5,@e1);

INSERT INTO SickLeave (leave_id, medical_cert_required, physician_id)
VALUES (@lv2,1,@e3);

INSERT INTO ProbationLeave (leave_id, eligibility_start_date, probation_period)
VALUES (@lv3,'2024-01-01',90);

INSERT INTO HolidayLeave (leave_id, holiday_name, official_recognition, regional_scope)
VALUES
(@lvHoliday, 'New Year''s Day', 'Official', 'National');
------------------------------------------------------------
-- 20. Leave Policies (3 rows)
------------------------------------------------------------
INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
VALUES
('Standard Policy','General leave rules','1 year tenure',14,'Vacation',1),
('Sick Policy','Medical leave rules','Doctor certificate',2,'Sick',0),
('Probation Policy','Rules for new employees','None',0,'Probation',0);

------------------------------------------------------------
-- 21. Leave Request (3 rows)
------------------------------------------------------------
INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, approval_timing, status)
VALUES
(@e1,@lv1,'Family trip',5,'2024-05-01','Approved'),
(@e2,@lv2,'High fever',2,'2024-06-01','Pending'),
(@e3,@lv3,'New hire probation',1,'2024-04-01','Approved');

DECLARE @lr1 INT = (SELECT request_id FROM LeaveRequest WHERE employee_id=@e1);
DECLARE @lr2 INT = (SELECT request_id FROM LeaveRequest WHERE employee_id=@e2);

------------------------------------------------------------
-- 22. Leave Entitlement
------------------------------------------------------------
INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement) VALUES
(@e1,@lv1,21),
(@e2,@lv2,10),
(@e3,@lv1,15);

------------------------------------------------------------
-- 23. Leave Documents
------------------------------------------------------------
INSERT INTO LeaveDocument (leave_request_id, file_path)
VALUES
(@lr1,'docs/vac_req_ahmed.pdf'),
(@lr2,'docs/sick_req_sara.pdf');

------------------------------------------------------------
-- 24. Shift Schedule (3 rows)
------------------------------------------------------------
INSERT INTO ShiftSchedule (name, type, start_time, end_time, break_duration, shift_date, status)
VALUES
('Morning','Fixed','09:00','17:00',60,'2024-02-05','Active'),
('Evening','Fixed','14:00','22:00',60,'2024-02-05','Active'),
('Night','Fixed','22:00','06:00',45,NULL,'Active');

DECLARE @s1 INT = (SELECT shift_id FROM ShiftSchedule WHERE name='Morning');
DECLARE @s2 INT = (SELECT shift_id FROM ShiftSchedule WHERE name='Evening');

------------------------------------------------------------
-- 25. Exceptions
------------------------------------------------------------
INSERT INTO [Exception] ([name], category, [date], status) VALUES
('Missed Punch','Attendance','2024-02-05','Open'),
('Device Failure','System','2024-03-01','Resolved'),
('Late Arrival','Attendance','2024-02-06','Open');

DECLARE @ex1 INT = (SELECT exception_id FROM [Exception] WHERE [name]='Missed Punch');

------------------------------------------------------------
-- 26. Attendance (3 rows)
------------------------------------------------------------
INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method, exception_id)
VALUES
(@e1,@s1,'2024-02-05 09:01','2024-02-05 17:02','Device','Device',NULL),
(@e2,@s1,'2024-02-05 09:10','2024-02-05 17:00','Device','Device',@ex1),
(@e3,@s2,'2024-02-05 14:05','2024-02-05 22:05','Manual','Device',NULL);

DECLARE @a1 INT = (SELECT attendance_id FROM Attendance WHERE employee_id=@e1);
DECLARE @a2 INT = (SELECT attendance_id FROM Attendance WHERE employee_id=@e2);

------------------------------------------------------------
-- 27. Attendance Log
------------------------------------------------------------
INSERT INTO AttendanceLog (attendance_id, actor, [timestamp], reason) VALUES
(@a1,@e1,GETDATE(),'Normal punch'),
(@a2,@e2,GETDATE(),'Corrected punch');

------------------------------------------------------------
-- 28. Attendance Correction Request
------------------------------------------------------------
INSERT INTO AttendanceCorrectionRequest (employee_id, [date], correction_type, reason, status, recorded_by)
VALUES
(@e2,'2024-02-05','ClockInCorrection','Missed punch','Pending',@e1),
(@e3,'2024-02-06','ClockOutCorrection','Left early','Approved',@e3);

------------------------------------------------------------
-- 29. Employee Exception
------------------------------------------------------------
INSERT INTO Employee_Exception (employee_id, exception_id)
VALUES (@e2,@ex1);

------------------------------------------------------------
-- 30. Shift Assignment
------------------------------------------------------------
INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
VALUES
(@e1,@s1,'2024-01-01','2024-12-31','Active'),
(@e2,@s2,'2024-01-01','2024-06-30','Active');

------------------------------------------------------------
-- 31. Payroll (3 rows)
------------------------------------------------------------
INSERT INTO Payroll (employee_id, taxes, period_start, period_end, base_amount, adjustments,
                     contributions, actual_pay, net_salary, payment_date)
VALUES
(@e1,1500,'2024-02-01','2024-02-28',15000,500,300,14800,13500,'2024-03-01'),
(@e2,800,'2024-02-01','2024-02-28',8000,0,100,7800,6900,'2024-03-01'),
(@e3,2000,'2024-02-01','2024-02-28',25000,900,500,24500,22000,'2024-03-01');

DECLARE @p1 INT = (SELECT payroll_id FROM Payroll WHERE employee_id=@e1);

------------------------------------------------------------
-- 32. Allowance/Deductions
------------------------------------------------------------
INSERT INTO AllowanceDeduction (payroll_id, employee_id, type, amount, currency_code, duration, timezone)
VALUES
(@p1,@e1,'Transport',200,'EGP','Monthly','EET'),
(NULL,@e2,'Phone',50,'EGP','Monthly','EET'),
(NULL,@e3,'Housing',1500,'EGP','Monthly','EET');

------------------------------------------------------------
-- 33. Salary Type Specializations
------------------------------------------------------------
INSERT INTO HourlySalaryType (salary_type_id, hourly_rate, max_monthly_hours)
VALUES (@stype2,120,160);

INSERT INTO MonthlySalaryType (salary_type_id, tax_rule, contribution_scheme)
VALUES (@stype1,'StandardTax','StandardContribution');

INSERT INTO ContractSalaryType (salary_type_id, contract_value, installment_details)
VALUES (@stype3,30000,'3 installments');

------------------------------------------------------------
-- 34. Payroll Policy
------------------------------------------------------------
INSERT INTO PayrollPolicy (effective_date, type, description) VALUES
('2024-01-01','General','General payroll rules'),
('2024-01-01','Overtime','Overtime multipliers'),
('2024-01-01','Deductions','Deduction rules');

DECLARE @pp1 INT = (SELECT policy_id FROM PayrollPolicy WHERE type='General');

INSERT INTO OvertimePolicy (policy_id, weekday_rate_multiplier, weekend_rate_multiplier, max_hours_per_month)
VALUES (@pp1,1.25,1.50,40);

INSERT INTO LatenessPolicy (policy_id, grace_period_mins, deduction_rate)
VALUES (@pp1,10,0.05);

INSERT INTO BonusPolicy (policy_id, bonus_type, eligibility_criteria)
VALUES (@pp1,'Performance','Based on rating');

INSERT INTO DeductionPolicy (policy_id, deduction_reason, calculation_mode)
VALUES (@pp1,'Tardiness','Proportional');

INSERT INTO PayrollPolicy_ID (payroll_id, policy_id)
VALUES (@p1,@pp1);

INSERT INTO Payroll_Log (payroll_id, actor, modification_type)
VALUES (@p1,@e1,'Initial Run');

INSERT INTO PayrollPeriod (payroll_id, start_date, end_date, status)
VALUES (@p1,'2024-02-01','2024-02-28','Closed');

------------------------------------------------------------
-- 35. Notification + Employee Notification
------------------------------------------------------------
INSERT INTO Notification (message_content, urgency, read_status, notification_type)
VALUES
('Payroll ready','Normal',0,'Payroll'),
('Leave approved','Normal',0,'Leave'),
('System update','Low',0,'System');

DECLARE @n1 INT = (SELECT notification_id FROM Notification WHERE message_content='Payroll ready');

INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
VALUES
(@e1,@n1,'Delivered',GETDATE());

------------------------------------------------------------
-- 36. EmployeeHierarchy
------------------------------------------------------------
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
VALUES
(@e1,NULL,1),
(@e2,@e1,2),
(@e3,@e1,2);

------------------------------------------------------------
-- 37. Devices + AttendanceSource
------------------------------------------------------------
INSERT INTO Device (device_type, terminal_id, latitude, longitude, employee_id)
VALUES
('Biometric','TERM-001',30.0444,31.2357,@e1),
('Mobile','MOB-010',30.0123,31.2000,@e2),
('Biometric','TERM-002',29.9753,31.1376,NULL);

DECLARE @dev1 INT = (SELECT device_id FROM Device WHERE terminal_id='TERM-001');

INSERT INTO AttendanceSource (attendance_id, device_id, source_type, latitude, longitude)
VALUES
(@a1,@dev1,'Biometric',30.0444,31.2357),
(@a2,@dev1,'Biometric',30.0444,31.2357);

------------------------------------------------------------
-- 38. ShiftCycle
------------------------------------------------------------
INSERT INTO ShiftCycle (cycle_name, description)
VALUES
('Weekday Morning','Morning rotations'),
('Rotational','Full rotation cycle');

DECLARE @cycle1 INT = (SELECT cycle_id FROM ShiftCycle WHERE cycle_name='Weekday Morning');

INSERT INTO ShiftCycleAssignment (cycle_id, shift_id, order_number)
VALUES
(@cycle1,@s1,1),
(@cycle1,@s2,2);

------------------------------------------------------------
-- 39. Approval Workflow
------------------------------------------------------------
INSERT INTO ApprovalWorkflow (workflow_type, threshold_amount, approver_role, created_by, status)
VALUES
('LeaveApproval',1000,@e1,@e1,'Active'),
('PayrollApproval',5000,2,@e1,'Active');

DECLARE @wf1 INT = (SELECT workflow_id FROM ApprovalWorkflow WHERE workflow_type='LeaveApproval');

INSERT INTO ApprovalWorkflowStep (workflow_id, step_number, role_id, action_required)
VALUES
(@wf1,1,1,'Manager Approval'),
(@wf1,2,2,'Payroll Officer Review');

------------------------------------------------------------
-- 40. Management Roles
------------------------------------------------------------
INSERT INTO ManagerNotes (employee_id, manager_id, note_content)
VALUES
(@e2,@e1,'Good performance'),
(@e3,@e1,'Needs improvement');

INSERT INTO HRAdministrator (employee_id, approval_level, record_access_scope, document_validation_rights)
VALUES (@e1,2,'All','1');

INSERT INTO SystemAdministrator (employee_id, system_privilege_level, configurable_fields, audit_visibility_scope)
VALUES (@e2,5,'Users,Roles','All');

INSERT INTO PayrollSpecialist (employee_id, assigned_region, processing_frequency, last_processed_period)
VALUES (@e3,'Egypt','Monthly','2024-02-01');

INSERT INTO LineManager (employee_id, team_size, supervised_departments, approval_limit)
VALUES (@e1,5,'HR,IT',10000);

------------------------------------------------------------
-- Done
------------------------------------------------------------
  
-- extra insertion Reimbursement
INSERT INTO Reimbursement (type, claim_type, approval_date, current_status, employee_id)
VALUES
    ('Travel', 'Taxi', NULL, 'Pending', 1),      -- Ahmed
    ('Medical', 'Clinic', NULL, 'Pending', 2),   -- Sara
    ('Training', 'Course Fee', NULL, 'Pending', 3); -- Mohamed

-- another separated insert (valid)
INSERT INTO Reimbursement (type, claim_type, approval_date, current_status, employee_id)
VALUES
    ('Training', 'Course Fee', NULL, 'Pending', 3); -- Mohamed



















