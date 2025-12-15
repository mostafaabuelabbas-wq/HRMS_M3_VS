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




------------------------------------------------------------
-- 0. ADDITIONAL ROLES (Option 1 confirmed)
------------------------------------------------------------
INSERT INTO Role (role_name, purpose) VALUES
('Manager','Manages teams and approves workflows'),
('SystemAdmin','System-wide administration');

------------------------------------------------------------
-- 0. ADDITIONAL POSITIONS (12 positions)
------------------------------------------------------------
INSERT INTO Position (position_title, responsibilities, status) VALUES
('Project Manager','Lead projects, coordinate teams','Active'),
('HR Specialist','Employee relations, HR operations','Active'),
('Team Leader','Oversee team tasks and performance','Active'),
('Payroll Specialist','Manage payroll processing','Active'),
('Junior Software Engineer','Assist development, testing, maintenance','Active'),
('Senior Software Engineer','Advanced development, system architecture','Active'),
('QA Engineer','Test software quality and stability','Active'),
('IT Support Engineer','Provide IT support and troubleshooting','Active'),
('Data Analyst','Analyze datasets and generate reports','Active'),
('HR Coordinator','Support HR operations and admin tasks','Active'),
('Finance Officer','Manage financial transactions and reports','Active'),
('Administrative Assistant','Provide clerical and admin support','Active');

------------------------------------------------------------
-- SECTION 1 — INSERT 4 SPECIAL EMPLOYEES (FULL DETAILS)
------------------------------------------------------------

------------------------------------------------------------
-- FETCH REQUIRED IDS (SAFE LOOKUPS)
------------------------------------------------------------
DECLARE @pos_PM INT  = (SELECT TOP 1 position_id FROM Position WHERE position_title='Project Manager');
DECLARE @pos_HRS INT = (SELECT TOP 1 position_id FROM Position WHERE position_title='HR Specialist');
DECLARE @pos_TL INT  = (SELECT TOP 1 position_id FROM Position WHERE position_title='Team Lead');
DECLARE @pos_PS INT  = (SELECT TOP 1 position_id FROM Position WHERE position_title='Payroll Specialist');

DECLARE @role_HRAdmin INT     = (SELECT TOP 1 role_id FROM Role WHERE role_name='HRAdmin');
DECLARE @role_Payroll INT     = (SELECT TOP 1 role_id FROM Role WHERE role_name='PayrollOfficer');
DECLARE @role_Employee INT    = (SELECT TOP 1 role_id FROM Role WHERE role_name='Employee');
DECLARE @role_Manager INT     = (SELECT TOP 1 role_id FROM Role WHERE role_name='Manager');
DECLARE @role_SystemAdmin INT = (SELECT TOP 1 role_id FROM Role WHERE role_name='SystemAdmin');

DECLARE @dHR INT  = (SELECT TOP 1 department_id FROM Department WHERE department_name='HR');
DECLARE @dIT INT  = (SELECT TOP 1 department_id FROM Department WHERE department_name='IT');
DECLARE @dFIN INT = (SELECT TOP 1 department_id FROM Department WHERE department_name='Finance');

DECLARE @tfEgypt INT = (SELECT TOP 1 tax_form_id FROM TaxForm WHERE jurisdiction='Egypt');

DECLARE @stypeMonthly INT = (SELECT TOP 1 salary_type_id FROM SalaryType WHERE [type]='Monthly');
DECLARE @cFull INT = (SELECT TOP 1 contract_id FROM Contract WHERE [type]='FullTime');

------------------------------------------------------------
-- 1. SPECIAL EMPLOYEE — MOSTAFA MOHAMED (SYSTEM ADMIN)
------------------------------------------------------------
INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth, country_of_birth,
    phone, email, address, employment_progress, account_status,
    employment_status, hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES (
    'Mostafa','Mohamed','29001011230001','1990-01-01','Egypt',
    '01050000001','mostafa.mohamed@company.com','Nasr City',
    'Active','Active','Full-time','2023-01-15',1,
    100,@dIT,@pos_PM,NULL,
    @cFull,@tfEgypt,@stypeMonthly,3
);

DECLARE @e4 INT = SCOPE_IDENTITY();

-- Role
INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
VALUES (@e4, @role_SystemAdmin, GETDATE());

-- Skill
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
VALUES (@e4, 1, 'Expert');

-- Verification
INSERT INTO Employee_Verification (employee_id, verification_id)
VALUES (@e4, 1);

------------------------------------------------------------
-- 2. SPECIAL EMPLOYEE — HASAN MAHMOUD (HR ADMIN)
------------------------------------------------------------
INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth, country_of_birth,
    phone, email, address, employment_progress, account_status,
    employment_status, hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES (
    'Hasan','Mahmoud','29102021230002','1991-02-05','Egypt',
    '01050000002','hasan.mahmoud@company.com','Heliopolis',
    'Active','Active','Full-time','2023-02-10',1,
    95,@dHR,@pos_HRS,@e4,
    @cFull,@tfEgypt,@stypeMonthly,2
);

DECLARE @e5 INT = SCOPE_IDENTITY();

-- Role
INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
VALUES (@e5, @role_HRAdmin, GETDATE());

-- Skill
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
VALUES (@e5, 3, 'Advanced');

-- Verification
INSERT INTO Employee_Verification (employee_id, verification_id)
VALUES (@e5, 2);

------------------------------------------------------------
-- 3. SPECIAL EMPLOYEE — MOHAMED AMR (MANAGER)
------------------------------------------------------------
INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth, country_of_birth,
    phone, email, address, employment_progress, account_status,
    employment_status, hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES (
    'Mohamed','Amr','28903031230003','1989-03-10','Egypt',
    '01050000003','mohamed.amr@company.com','Maadi',
    'Active','Active','Full-time','2023-03-01',1,
    93,@dIT,@pos_TL,@e4,
    @cFull,@tfEgypt,@stypeMonthly,3
);

DECLARE @e6 INT = SCOPE_IDENTITY();

-- Role
INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
VALUES (@e6, @role_Manager, GETDATE());

-- Skill
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
VALUES (@e6, 2, 'Advanced');

-- Verification
INSERT INTO Employee_Verification (employee_id, verification_id)
VALUES (@e6, 3);

------------------------------------------------------------
-- 4. SPECIAL EMPLOYEE — YOUSSEF AHMED (PAYROLL OFFICER)
------------------------------------------------------------
INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth, country_of_birth,
    phone, email, address, employment_progress, account_status,
    employment_status, hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES (
    'Youssef','Ahmed','29504041230004','1995-04-12','Egypt',
    '01050000004','youssef.ahmed@company.com','Giza',
    'Active','Active','Full-time','2023-04-01',1,
    90,@dFIN,@pos_PS,@e6,
    @cFull,@tfEgypt,@stypeMonthly,2
);

DECLARE @e7 INT = SCOPE_IDENTITY();

-- Role
INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
VALUES (@e7, @role_Payroll, GETDATE());

-- Skill
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
VALUES (@e7, 3, 'Intermediate');

-- Verification
INSERT INTO Employee_Verification (employee_id, verification_id)
VALUES (@e7, 1);

------------------------------------------------------------
-- SPECIAL EMPLOYEES — HIERARCHY
------------------------------------------------------------
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
VALUES
(@e4, NULL, 1),   -- Mostafa top-level
(@e5, @e4, 2),     -- Hasan → Mostafa
(@e6, @e4, 2),     -- Amr → Mostafa
(@e7, @e6, 3);     -- Youssef → Amr

------------------------------------------------------------
-- SIMPLE MISSIONS (LIKE YOUR BASE FORMAT)
------------------------------------------------------------
INSERT INTO Mission (destination, start_date, end_date, status, employee_id, manager_id)
VALUES
('Dubai','2024-01-10','2024-01-12','Completed',@e4,NULL),
('Cairo','2024-02-05','2024-02-06','Planned',@e5,@e4),
('Alexandria','2024-03-01','2024-03-03','Completed',@e6,@e4),
('Giza','2024-03-10','2024-03-11','Planned',@e7,@e6);

GO
------------------------------------------------------------
-- SECTION 2 — INSERT 50 REALISTIC EMPLOYEES
------------------------------------------------------------

------------------------------------------------------------
-- SAFE LOOKUPS FOR EMPLOYEE INSERTS
------------------------------------------------------------
-- SAFE LOOKUPS FOR EMPLOYEE INSERTS
DECLARE @dIT INT  = (SELECT TOP 1 department_id FROM Department WHERE department_name='IT');
DECLARE @dHR INT  = (SELECT TOP 1 department_id FROM Department WHERE department_name='HR');
DECLARE @dFIN INT = (SELECT TOP 1 department_id FROM Department WHERE department_name='Finance');

DECLARE @pos_JuniorSE INT  = (SELECT TOP 1 position_id FROM Position WHERE position_title='Junior Software Engineer');
DECLARE @pos_SeniorSE INT  = (SELECT TOP 1 position_id FROM Position WHERE position_title='Senior Software Engineer');
DECLARE @pos_QA INT        = (SELECT TOP 1 position_id FROM Position WHERE position_title='QA Engineer');
DECLARE @pos_ITSupport INT = (SELECT TOP 1 position_id FROM Position WHERE position_title='IT Support Engineer');
DECLARE @pos_Analyst INT   = (SELECT TOP 1 position_id FROM Position WHERE position_title='Data Analyst');

DECLARE @pos_HRS INT     = (SELECT TOP 1 position_id FROM Position WHERE position_title='HR Specialist');
DECLARE @pos_HRCoord INT = (SELECT TOP 1 position_id FROM Position WHERE position_title='HR Coordinator');

DECLARE @pos_Finance INT = (SELECT TOP 1 position_id FROM Position WHERE position_title='Finance Officer');
DECLARE @pos_Admin INT   = (SELECT TOP 1 position_id FROM Position WHERE position_title='Administrative Assistant');

DECLARE @tfEgypt INT      = (SELECT TOP 1 tax_form_id FROM TaxForm WHERE jurisdiction='Egypt');
DECLARE @stypeMonthly INT = (SELECT TOP 1 salary_type_id FROM SalaryType WHERE type='Monthly');
DECLARE @cFull INT        = (SELECT TOP 1 contract_id FROM Contract WHERE type='FullTime');

------------------------------------------------------------
-- INSERT IT EMPLOYEES (FIRST 10 OF 30)
------------------------------------------------------------
INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth,
    country_of_birth, phone, email, address,
    employment_progress, account_status, employment_status,
    hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES
('Omar','Hussein','29501011234521','1995-01-10','Egypt',
 '01060000001','omar.hussein@company.com','Nasr City',
 'Active','Active','Full-time','2023-05-10',1,92,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Kareem','Nasser','29402021234522','1994-02-15','Egypt',
 '01060000002','kareem.nasser@company.com','Maadi',
 'Active','Active','Full-time','2023-04-03',1,90,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Aly','Sami','29603031234523','1996-03-20','Egypt',
 '01060000003','aly.sami@company.com','Heliopolis',
 'Active','Active','Full-time','2023-06-01',1,89,
 @dIT,@pos_QA,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Yara','Khaled','29704041234524','1997-04-22','Egypt',
 '01060000004','yara.khaled@company.com','Giza',
 'Active','Active','Full-time','2023-07-11',1,94,
 @dIT,@pos_Analyst,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Hana','Maged','29805051234525','1998-05-05','Egypt',
 '01060000005','hana.maged@company.com','New Cairo',
 'Active','Active','Full-time','2023-03-15',1,91,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Adham','Fouad','29506061234526','1995-06-17','Egypt',
 '01060000006','adham.fouad@company.com','6th October',
 'Active','Active','Full-time','2023-02-12',1,93,
 @dIT,@pos_ITSupport,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Ziad','Maher','29507071234527','1995-07-02','Egypt',
 '01060000007','ziad.maher@company.com','Nasr City',
 'Active','Active','Full-time','2023-08-10',1,95,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Layla','Yassin','29708081234528','1997-08-11','Egypt',
 '01060000008','layla.yassin@company.com','Heliopolis',
 'Active','Active','Full-time','2023-09-12',1,96,
 @dIT,@pos_Analyst,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Tarek','Gamal','29409091234529','1994-09-05','Egypt',
 '01060000009','tarek.gamal@company.com','Nasr City',
 'Active','Active','Full-time','2023-01-19',1,88,
 @dIT,@pos_QA,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Nour','Samir','29610101234530','1996-10-27','Egypt',
 '01060000010','nour.samir@company.com','Maadi',
 'Active','Active','Full-time','2023-06-22',1,90,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1);

------------------------------------------------------------
-- SECTION 2 — INSERT IT EMPLOYEES (11–20 of 30)
------------------------------------------------------------

INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth,
    country_of_birth, phone, email, address,
    employment_progress, account_status, employment_status,
    hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES
('Rana','Fathy','29711111234531','1997-11-12','Egypt',
 '01060000011','rana.fathy@company.com','Giza',
 'Active','Active','Full-time','2023-08-14',1,92,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Salma','Yousef','29812121234532','1998-12-21','Egypt',
 '01060000012','salma.yousef@company.com','Nasr City',
 'Active','Active','Full-time','2023-05-14',1,93,
 @dIT,@pos_QA,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Hossam','Reda','29402221234533','1994-02-15','Egypt',
 '01060000013','hossam.reda@company.com','Heliopolis',
 'Active','Active','Full-time','2023-02-17',1,94,
 @dIT,@pos_ITSupport,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Eman','Sabry','29603331234534','1996-03-22','Egypt',
 '01060000014','eman.sabry@company.com','New Cairo',
 'Active','Active','Full-time','2023-09-09',1,95,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Farah','Ayman','29704441234535','1997-04-03','Egypt',
 '01060000015','farah.ayman@company.com','Maadi',
 'Active','Active','Full-time','2023-01-30',1,88,
 @dIT,@pos_Analyst,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Samy','Lotfy','29305551234536','1993-05-10','Egypt',
 '01060000016','samy.lotfy@company.com','Nasr City',
 'Active','Active','Full-time','2023-04-11',1,92,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Nada','Adel','29906661234537','1999-06-19','Egypt',
 '01060000017','nada.adel@company.com','Giza',
 'Active','Active','Full-time','2023-03-21',1,93,
 @dIT,@pos_QA,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Mina','Karam','29507771234538','1995-07-18','Egypt',
 '01060000018','mina.karam@company.com','Heliopolis',
 'Active','Active','Full-time','2023-07-07',1,91,
 @dIT,@pos_ITSupport,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Ramy','Ashraf','29408881234539','1994-08-08','Egypt',
 '01060000019','ramy.ashraf@company.com','Nasr City',
 'Active','Active','Full-time','2023-05-13',1,92,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Sahar','Tarek','29709991234540','1997-09-09','Egypt',
 '01060000020','sahar.tarek@company.com','Giza',
 'Active','Active','Full-time','2023-10-05',1,94,
 @dIT,@pos_Analyst,NULL,@cFull,@tfEgypt,@stypeMonthly,2);

------------------------------------------------------------
-- SECTION 2 — INSERT IT EMPLOYEES (21–30 of 30)
------------------------------------------------------------

INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth,
    country_of_birth, phone, email, address,
    employment_progress, account_status, employment_status,
    hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES
('Islam','Fathi','29510101234541','1995-10-21','Egypt',
 '01060000021','islam.fathi@company.com','New Cairo',
 'Active','Active','Full-time','2023-11-01',1,93,
 @dIT,@pos_QA,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Sherif','Gad','29311211234542','1993-11-22','Egypt',
 '01060000022','sherif.gad@company.com','6th October',
 'Active','Active','Full-time','2023-06-26',1,95,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Dalia','Hany','29802021234543','1998-02-14','Egypt',
 '01060000023','dalia.hany@company.com','Maadi',
 'Active','Active','Full-time','2023-04-17',1,93,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Mariam','Saleh','29703031234544','1997-03-15','Egypt',
 '01060000024','mariam.saleh@company.com','Heliopolis',
 'Active','Active','Full-time','2023-03-18',1,96,
 @dIT,@pos_Analyst,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Bassem','Shawky','29504041234545','1995-04-07','Egypt',
 '01060000025','bassem.shawky@company.com','Nasr City',
 'Active','Active','Full-time','2023-10-11',1,95,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Rashed','Omar','29605051234546','1996-05-09','Egypt',
 '01060000026','rashed.omar@company.com','Giza',
 'Active','Active','Full-time','2023-02-19',1,91,
 @dIT,@pos_JuniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Noha','Emad','29806061234547','1998-06-03','Egypt',
 '01060000027','noha.emad@company.com','New Cairo',
 'Active','Active','Full-time','2023-07-15',1,94,
 @dIT,@pos_QA,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Mustafa','Sharaf','29707071234548','1997-07-08','Egypt',
 '01060000028','mustafa.sharaf@company.com','6th October',
 'Active','Active','Full-time','2023-08-22',1,97,
 @dIT,@pos_SeniorSE,NULL,@cFull,@tfEgypt,@stypeMonthly,3),

('Rita','Boulos','29908081234549','1999-08-21','Egypt',
 '01060000029','rita.boulos@company.com','Heliopolis',
 'Active','Active','Full-time','2023-09-30',1,92,
 @dIT,@pos_Analyst,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Youssef','Adel','29809091234550','1998-09-25','Egypt',
 '01060000030','youssef.adel@company.com','Giza',
 'Active','Active','Full-time','2023-10-14',1,91,
 @dIT,@pos_ITSupport,NULL,@cFull,@tfEgypt,@stypeMonthly,1);

------------------------------------------------------------
-- SECTION 2 — INSERT HR EMPLOYEES (10 Employees)
------------------------------------------------------------

INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth,
    country_of_birth, phone, email, address,
    employment_progress, account_status, employment_status,
    hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES
('Rania','Mostafa','29601111234551','1996-01-10','Egypt',
 '01070000001','rania.mostafa@company.com','Nasr City',
 'Active','Active','Full-time','2023-05-10',1,94,
 @dHR,@pos_HRS,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Menna','Hassan','29702221234552','1997-02-17','Egypt',
 '01070000002','menna.hassan@company.com','Heliopolis',
 'Active','Active','Full-time','2023-03-01',1,92,
 @dHR,@pos_HRCoord,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Huda','Farouk','29803331234553','1998-03-19','Egypt',
 '01070000003','huda.farouk@company.com','Maadi',
 'Active','Active','Full-time','2023-07-22',1,95,
 @dHR,@pos_HRS,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Nadine','Ossama','29904441234554','1999-04-18','Egypt',
 '01070000004','nadine.ossama@company.com','Giza',
 'Active','Active','Full-time','2023-04-05',1,90,
 @dHR,@pos_HRCoord,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Reem','Shaker','29705551234555','1997-05-21','Egypt',
 '01070000005','reem.shaker@company.com','New Cairo',
 'Active','Active','Full-time','2023-06-19',1,93,
 @dHR,@pos_HRS,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Aya','Nabil','29806661234556','1998-06-09','Egypt',
 '01070000006','aya.nabil@company.com','Heliopolis',
 'Active','Active','Full-time','2023-05-25',1,91,
 @dHR,@pos_HRCoord,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Jana','Khalifa','29907771234557','1999-07-07','Egypt',
 '01070000007','jana.khalifa@company.com','Nasr City',
 'Active','Active','Full-time','2023-10-01',1,92,
 @dHR,@pos_HRS,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Fares','Lotfy','29608881234558','1996-08-18','Egypt',
 '01070000008','fares.lotfy@company.com','New Cairo',
 'Active','Active','Full-time','2023-03-30',1,94,
 @dHR,@pos_HRCoord,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('May','Gaber','29809991234559','1998-09-12','Egypt',
 '01070000009','may.gaber@company.com','Giza',
 'Active','Active','Full-time','2023-02-22',1,96,
 @dHR,@pos_HRS,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Nourhan','Ehab','29710101234560','1997-10-20','Egypt',
 '01070000010','nourhan.ehab@company.com','Maadi',
 'Active','Active','Full-time','2023-01-10',1,93,
 @dHR,@pos_HRCoord,NULL,@cFull,@tfEgypt,@stypeMonthly,1);

------------------------------------------------------------
-- SECTION 2 — INSERT FINANCE EMPLOYEES (10 Employees)
------------------------------------------------------------

INSERT INTO Employee (
    first_name, last_name, national_id, date_of_birth,
    country_of_birth, phone, email, address,
    employment_progress, account_status, employment_status,
    hire_date, is_active, profile_completion,
    department_id, position_id, manager_id,
    contract_id, tax_form_id, salary_type_id, pay_grade
)
VALUES
('Ayman','Fekry','29601111234561','1996-01-11','Egypt',
 '01080000001','ayman.fekry@company.com','Nasr City',
 'Active','Active','Full-time','2023-04-10',1,94,
 @dFIN,@pos_Finance,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Dina','Saad','29702221234562','1997-02-21','Egypt',
 '01080000002','dina.saad@company.com','Heliopolis',
 'Active','Active','Full-time','2023-03-22',1,93,
 @dFIN,@pos_Admin,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Hesham','Badawy','29503331234563','1995-03-30','Egypt',
 '01080000003','hesham.badawy@company.com','Giza',
 'Active','Active','Full-time','2023-05-02',1,92,
 @dFIN,@pos_Finance,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Lama','Gad','29804441234564','1998-04-05','Egypt',
 '01080000004','lama.gad@company.com','New Cairo',
 'Active','Active','Full-time','2023-06-12',1,91,
 @dFIN,@pos_Admin,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Shadi','Raouf','29405551234565','1994-05-16','Egypt',
 '01080000005','shadi.raouf@company.com','Maadi',
 'Active','Active','Full-time','2023-01-10',1,93,
 @dFIN,@pos_Finance,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Rana','Halim','29806661234566','1998-06-13','Egypt',
 '01080000006','rana.halim@company.com','Heliopolis',
 'Active','Active','Full-time','2023-02-18',1,90,
 @dFIN,@pos_Admin,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Omar','Khalaf','29507771234567','1995-07-08','Egypt',
 '01080000007','omar.khalaf@company.com','Nasr City',
 'Active','Active','Full-time','2023-07-20',1,95,
 @dFIN,@pos_Finance,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Marina','Sami','29608881234568','1996-08-29','Egypt',
 '01080000008','marina.sami@company.com','New Cairo',
 'Active','Active','Full-time','2023-03-09',1,93,
 @dFIN,@pos_Admin,NULL,@cFull,@tfEgypt,@stypeMonthly,1),

('Tamer','Zakaria','29709991234569','1997-09-07','Egypt',
 '01080000009','tamer.zakaria@company.com','Giza',
 'Active','Active','Full-time','2023-10-18',1,95,
 @dFIN,@pos_Finance,NULL,@cFull,@tfEgypt,@stypeMonthly,2),

('Rita','Shenouda','29810101234570','1998-10-01','Egypt',
 '01080000010','rita.shenouda@company.com','Maadi',
 'Active','Active','Full-time','2023-02-07',1,92,
 @dFIN,@pos_Admin,NULL,@cFull,@tfEgypt,@stypeMonthly,1);
GO

GO
------------------------------------------------------------
-- SECTION 3 — PART A
-- Assign Role + Skills + Verification to 50 new employees
------------------------------------------------------------

-- Fetch Employee role (Standard)
DECLARE @roleEmployee INT = (SELECT TOP 1 role_id FROM Role WHERE role_name='Employee');

------------------------------------------------------------
-- Assign "Employee" role to all new employees (IDs >= 8)
------------------------------------------------------------
INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
SELECT employee_id, @roleEmployee, GETDATE()
FROM Employee
WHERE employee_id >= 8;

------------------------------------------------------------
-- Assign rotating SKILLS to all employees >= 8
-- 1 = SQL, 2 = Java, 3 = Excel
------------------------------------------------------------
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
SELECT employee_id,
       CASE 
           WHEN employee_id % 3 = 1 THEN 1  -- SQL
           WHEN employee_id % 3 = 2 THEN 2  -- Java
           ELSE 3                           -- Excel
       END,
       CASE 
           WHEN employee_id % 3 = 1 THEN 'Intermediate'
           WHEN employee_id % 3 = 2 THEN 'Advanced'
           ELSE 'Beginner'
       END
FROM Employee
WHERE employee_id >= 8;

------------------------------------------------------------
-- Assign rotating VERIFICATIONS to all new employees
-- 1 = ID Check, 2 = Degree Check, 3 = Background Check
------------------------------------------------------------
INSERT INTO Employee_Verification (employee_id, verification_id)
SELECT employee_id,
       CASE 
           WHEN employee_id % 3 = 1 THEN 1
           WHEN employee_id % 3 = 2 THEN 2
           ELSE 3
       END
FROM Employee
WHERE employee_id >= 8;
------------------------------------------------------------
-- SECTION 3 — PART B: EmployeeHierarchy
------------------------------------------------------------
DECLARE @Mostafa INT = (SELECT employee_id FROM Employee WHERE email='mostafa.mohamed@company.com');
DECLARE @Hasan   INT = (SELECT employee_id FROM Employee WHERE email='hasan.mahmoud@company.com');
DECLARE @Amr     INT = (SELECT employee_id FROM Employee WHERE email='mohamed.amr@company.com');
DECLARE @Youssef INT = (SELECT employee_id FROM Employee WHERE email='youssef.ahmed@company.com');

-- IT → Manager Amr
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Amr, 3
FROM Employee
WHERE employee_id BETWEEN 8 AND 37;

-- HR → Hasan
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Hasan, 3
FROM Employee
WHERE employee_id BETWEEN 38 AND 47;

-- Finance → Youssef
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Youssef, 3
FROM Employee
WHERE employee_id BETWEEN 48 AND 57;

------------------------------------------------------------
-- SECTION 3 — PART C: ShiftAssignment
------------------------------------------------------------
DECLARE @sMorning INT = (SELECT TOP 1 shift_id FROM ShiftSchedule WHERE name='Morning');
DECLARE @sEvening INT = (SELECT TOP 1 shift_id FROM ShiftSchedule WHERE name='Evening');

-- IT employees (8–37)
INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
SELECT employee_id,
       CASE WHEN employee_id % 2 = 0 THEN @sMorning ELSE @sEvening END,
       '2024-01-01','2024-12-31','Active'
FROM Employee
WHERE employee_id BETWEEN 8 AND 37;

-- HR employees
INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
SELECT employee_id, @sMorning,
       '2024-01-01','2024-12-31','Active'
FROM Employee
WHERE employee_id BETWEEN 38 AND 47;

-- Finance employees
INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
SELECT employee_id, @sMorning,
       '2024-01-01','2024-12-31','Active'
FROM Employee
WHERE employee_id BETWEEN 48 AND 57;

------------------------------------------------------------
-- SECTION 3 — PART D: Attendance & Logs
------------------------------------------------------------

INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method, exception_id)
SELECT employee_id,
       CASE WHEN employee_id % 2 = 0 THEN @sMorning ELSE @sEvening END,
       DATEADD(MINUTE, employee_id % 5, '2024-02-05 09:00'),
       DATEADD(MINUTE, employee_id % 7, '2024-02-05 17:00'),
       'Device','Device',NULL
FROM Employee
WHERE employee_id >= 8;

-- Attendance Logs
INSERT INTO AttendanceLog (attendance_id, actor, timestamp, reason)
SELECT attendance_id, employee_id, GETDATE(), 'Auto log'
FROM Attendance
WHERE employee_id >= 8;

------------------------------------------------------------
-- SECTION 3 — PART E: Leave Requests + Entitlement
------------------------------------------------------------

DECLARE @lvVacation INT = (SELECT TOP 1 leave_id FROM [Leave] WHERE leave_type='Vacation');
DECLARE @lvSick INT     = (SELECT TOP 1 leave_id FROM [Leave] WHERE leave_type='Sick');

INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, approval_timing, status)
SELECT employee_id,
       CASE WHEN employee_id % 2 = 0 THEN @lvVacation ELSE @lvSick END,
       'Auto generated request',
       CASE WHEN employee_id % 2 = 0 THEN 3 ELSE 1 END,
       '2024-04-10',
       CASE WHEN employee_id % 2 = 0 THEN 'Approved' ELSE 'Pending' END
FROM Employee
WHERE employee_id >= 8;

INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
SELECT employee_id, @lvVacation, 21 FROM Employee WHERE employee_id >= 8;

INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
SELECT employee_id, @lvSick, 10 FROM Employee WHERE employee_id >= 8;

------------------------------------------------------------
-- SECTION 3 — PART F: Payroll + Allowances
------------------------------------------------------------

INSERT INTO Payroll (employee_id, taxes, period_start, period_end, base_amount, adjustments,
                     contributions, actual_pay, net_salary, payment_date)
SELECT employee_id,
       1000 + (employee_id % 7) * 100,
       '2024-02-01','2024-02-28',
       12000 + (employee_id % 5) * 2000,
       (employee_id % 3) * 200,
       (employee_id % 4) * 100,
       12000 + (employee_id % 5) * 2000,
       12000 + (employee_id % 5) * 2000 - 500,
       '2024-03-01'
FROM Employee
WHERE employee_id >= 8;

-- Allowances
INSERT INTO AllowanceDeduction (payroll_id, employee_id, type, amount, currency_code, duration, timezone)
SELECT p.payroll_id, e.employee_id,
       CASE 
           WHEN e.employee_id % 3 = 0 THEN 'Transport'
           WHEN e.employee_id % 3 = 1 THEN 'Phone'
           ELSE 'Housing'
       END,
       CASE 
           WHEN e.employee_id % 3 = 0 THEN 300
           WHEN e.employee_id % 3 = 1 THEN 100
           ELSE 1500
       END,
       'EGP','Monthly','EET'
FROM Payroll p
JOIN Employee e ON p.employee_id = e.employee_id
WHERE e.employee_id >= 8;

------------------------------------------------------------
-- SECTION 3 — PART G: Devices + AttendanceSource
------------------------------------------------------------
INSERT INTO Device (device_type, terminal_id, latitude, longitude, employee_id)
SELECT 'Biometric', CONCAT('TERM-', employee_id), 30.0 + (employee_id % 10), 31.0 + (employee_id % 10), employee_id
FROM Employee
WHERE employee_id >= 8;

INSERT INTO AttendanceSource (attendance_id, device_id, source_type, latitude, longitude)
SELECT A.attendance_id, D.device_id, 'Biometric', D.latitude, D.longitude
FROM Attendance A
JOIN Device D ON D.employee_id = A.employee_id
WHERE A.employee_id >= 8;
GO
------------------------------------------------------------
-- CUSTOM MANAGER ASSIGNMENTS (UPGRADED)
-- Ensures proper variable declarations & hierarchy expansion
------------------------------------------------------------

-- Re-fetch special employees (variables lost after GO)
DECLARE @e4 INT = (SELECT employee_id FROM Employee WHERE email='mostafa.mohamed@company.com');
DECLARE @e5 INT = (SELECT employee_id FROM Employee WHERE email='hasan.mahmoud@company.com');
DECLARE @e6 INT = (SELECT employee_id FROM Employee WHERE email='mohamed.amr@company.com');
DECLARE @e7 INT = (SELECT employee_id FROM Employee WHERE email='youssef.ahmed@company.com');

DECLARE @Mostafa INT = @e4;
DECLARE @Hasan   INT = @e5;
DECLARE @Amr     INT = @e6;
DECLARE @Youssef INT = @e7;

------------------------------------------------------------
-- 1. Mohamed Amr (Manager) → Assign 15 IT Employees
------------------------------------------------------------
;WITH Top15IT AS (
    SELECT TOP 15 employee_id
    FROM Employee
    WHERE department_id = (SELECT department_id FROM Department WHERE department_name='IT')
      AND employee_id >= 8
    ORDER BY employee_id
)
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Amr, 3
FROM Top15IT
WHERE NOT EXISTS (
    SELECT 1 FROM EmployeeHierarchy h WHERE h.employee_id = Top15IT.employee_id
);

------------------------------------------------------------
-- 2. Hasan manages ALL HR employees, except special employees
------------------------------------------------------------
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Hasan, 3
FROM Employee
WHERE department_id = (SELECT department_id FROM Department WHERE department_name='HR')
  AND employee_id NOT IN (@e4, @e5, @e6, @e7)  -- exclude special people
  AND NOT EXISTS (
      SELECT 1 FROM EmployeeHierarchy h WHERE h.employee_id = Employee.employee_id
  );

------------------------------------------------------------
-- 3. Youssef manages ALL Finance employees except himself
------------------------------------------------------------
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Youssef, 3
FROM Employee
WHERE department_id = (SELECT department_id FROM Department WHERE department_name='Finance')
  AND employee_id NOT IN (@e4, @e5, @e6, @e7)
  AND NOT EXISTS (
      SELECT 1 FROM EmployeeHierarchy h WHERE h.employee_id = Employee.employee_id
  );

------------------------------------------------------------
-- 4. Mostafa manages ALL special managers (only if missing)
------------------------------------------------------------
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT @e5, @Mostafa, 2
WHERE NOT EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @e5);

INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT @e6, @Mostafa, 2
WHERE NOT EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @e6);

INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT @e7, @Mostafa, 2
WHERE NOT EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @e7);
GO

------------------------------------------------------------
-- REBUILD DEPARTMENT MANAGERS HIERARCHY (CLEAN + SAFE)
------------------------------------------------------------

-- Re-fetch special employees (lost after GO)
DECLARE @Mostafa INT = (SELECT employee_id FROM Employee WHERE email='mostafa.mohamed@company.com');
DECLARE @Amr INT     = (SELECT employee_id FROM Employee WHERE email='mohamed.amr@company.com');

-- NEW HR Manager
DECLARE @HRMgr INT = (SELECT employee_id FROM Employee WHERE email='aya.nabil@company.com');

-- NEW Finance Manager
DECLARE @FinMgr INT = (SELECT employee_id FROM Employee WHERE email='omar.khalaf@company.com');

-- Existing Managers
DECLARE @Hasan INT = (SELECT employee_id FROM Employee WHERE email='hasan.mahmoud@company.com');
DECLARE @Youssef INT = (SELECT employee_id FROM Employee WHERE email='youssef.ahmed@company.com');

------------------------------------------------------------
-- 1️⃣ CLEAN: REMOVE hierarchy rows for HR and Finance employees
--    (We will rebuild them cleanly)
------------------------------------------------------------
DELETE FROM EmployeeHierarchy
WHERE employee_id IN (
    SELECT employee_id FROM Employee
    WHERE department_id IN (
        SELECT department_id FROM Department WHERE department_name IN ('HR','Finance')
    )
)
AND employee_id NOT IN (@Mostafa, @Amr); -- keep special top-level

------------------------------------------------------------
-- 2️⃣ HR DEPARTMENT → AyaNabil is the Manager
------------------------------------------------------------
-- Assign Aya under Mostafa
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT @HRMgr, @Mostafa, 2
WHERE NOT EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @HRMgr);

-- Assign all HR employees under Aya
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @HRMgr, 3
FROM Employee
WHERE department_id = (SELECT department_id FROM Department WHERE department_name='HR')
  AND employee_id <> @HRMgr;

------------------------------------------------------------
-- 3️⃣ Finance DEPARTMENT → Omar Khalaf is the Manager
------------------------------------------------------------
-- Assign Omar under Mostafa
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT @FinMgr, @Mostafa, 2
WHERE NOT EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @FinMgr);

-- Assign all Finance employees under Omar
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @FinMgr, 3
FROM Employee
WHERE department_id = (SELECT department_id FROM Department WHERE department_name='Finance')
  AND employee_id <> @FinMgr;

------------------------------------------------------------
-- 4️⃣ IT DEPARTMENT → Amr remains the Manager
------------------------------------------------------------
-- Ensure Amr is under Mostafa
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT @Amr, @Mostafa, 2
WHERE NOT EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @Amr);

-- Reassign ALL IT employees properly under Amr
DELETE FROM EmployeeHierarchy
WHERE employee_id IN (
    SELECT employee_id FROM Employee
    WHERE department_id = (SELECT department_id FROM Department WHERE department_name='IT')
)
AND employee_id <> @Amr;

INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Amr, 3
FROM Employee
WHERE department_id = (SELECT department_id FROM Department WHERE department_name='IT')
  AND employee_id <> @Amr;

GO
------------------------------------------------------------
-- SECTION 4 — FINAL VALIDATION & INDEXES
------------------------------------------------------------

PRINT 'Starting final validation...';


------------------------------------------------------------
-- VALIDATION 1: Ensure all employees have a role
------------------------------------------------------------
DECLARE @roleEmployee INT = (SELECT TOP 1 role_id FROM Role WHERE role_name='Employee');

INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
SELECT e.employee_id, @roleEmployee, GETDATE()
FROM Employee e
WHERE NOT EXISTS (
    SELECT 1 FROM Employee_Role er WHERE er.employee_id = e.employee_id
);

PRINT '✓ Role validation complete';


------------------------------------------------------------
-- VALIDATION 2: Ensure all employees have at least 1 skill
------------------------------------------------------------
INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
SELECT e.employee_id, 3, 'Beginner'
FROM Employee e
WHERE NOT EXISTS (
    SELECT 1 FROM Employee_Skill es WHERE es.employee_id = e.employee_id
);

PRINT '✓ Skill validation complete';


------------------------------------------------------------
-- VALIDATION 3: Ensure all employees have at least 1 verification
------------------------------------------------------------
INSERT INTO Employee_Verification (employee_id, verification_id)
SELECT e.employee_id, 1
FROM Employee e
WHERE NOT EXISTS (
    SELECT 1 FROM Employee_Verification ev WHERE ev.employee_id = e.employee_id
);

PRINT '✓ Verification validation complete';


------------------------------------------------------------
-- VALIDATION 4: Ensure all employees have a hierarchy row
------------------------------------------------------------
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT e.employee_id, NULL, 1
FROM Employee e
WHERE NOT EXISTS (
    SELECT 1 FROM EmployeeHierarchy h WHERE h.employee_id = e.employee_id
);

PRINT '✓ Hierarchy validation complete';


------------------------------------------------------------
-- PERFORMANCE INDEXES
-- These help your Milestone 3 UI run MUCH faster
------------------------------------------------------------

-- Lookup / login / filtering
CREATE INDEX idx_employee_email ON Employee(email);
CREATE INDEX idx_employee_department ON Employee(department_id);
CREATE INDEX idx_employee_position ON Employee(position_id);

-- Payroll performance
CREATE INDEX idx_payroll_employee ON Payroll(employee_id);

-- Attendance performance
CREATE INDEX idx_attendance_employee ON Attendance(employee_id);
CREATE INDEX idx_attendance_shift ON Attendance(shift_id);

-- Leave performance
CREATE INDEX idx_leave_employee ON LeaveRequest(employee_id);
CREATE INDEX idx_leave_leaveid ON LeaveRequest(leave_id);

PRINT '✓ Performance indexes created';


------------------------------------------------------------
-- OPTIONAL: Add system notifications for testing UI
------------------------------------------------------------
INSERT INTO Notification (message_content, urgency, read_status, notification_type)
VALUES
('System initialized successfully', 'Low', 0, 'System'),
('New employees imported', 'Normal', 0, 'System');

PRINT '✓ Final notifications inserted';


------------------------------------------------------------
-- DONE
------------------------------------------------------------
PRINT '------------------------------------------------------------';
PRINT ' ALL DATA INSERTED + VALIDATED SUCCESSFULLY ';
PRINT ' HRMS DATABASE IS NOW FULLY READY FOR MILESTONE 3 ';
PRINT '------------------------------------------------------------';

------------------------------------------------------------
-- FINAL MANAGER NORMALIZATION (SOURCE OF TRUTH: HIERARCHY)
------------------------------------------------------------

-- 1️⃣ Clear Manager role from everyone (SAFE)
DELETE er
FROM Employee_Role er
JOIN Role r ON er.role_id = r.role_id
WHERE r.role_name = 'Manager';

------------------------------------------------------------

-- 2️⃣ Re-assign Manager role ONLY to real managers
INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
SELECT DISTINCT
    h.manager_id,
    r.role_id,
    GETDATE()
FROM EmployeeHierarchy h
JOIN Role r ON r.role_name = 'Manager'
WHERE h.manager_id IS NOT NULL;

------------------------------------------------------------

-- 3️⃣ Force Employee.manager_id to MATCH hierarchy (optional)
-- If you want to keep it consistent instead of ignoring it
UPDATE e
SET manager_id = h.manager_id
FROM Employee e
JOIN EmployeeHierarchy h ON e.employee_id = h.employee_id;

------------------------------------------------------------

-- 4️⃣ Rebuild LineManager table from hierarchy (optional)
TRUNCATE TABLE LineManager;

INSERT INTO LineManager (employee_id, team_size, supervised_departments, approval_limit)
SELECT
    h.manager_id,
    COUNT(*),
    NULL,
    0
FROM EmployeeHierarchy h
WHERE h.manager_id IS NOT NULL
GROUP BY h.manager_id;

------------------------------------------------------------
-- END OF MANAGER NORMALIZATION
------------------------------------------------------------


SET NOCOUNT ON;
------------------------------------------------------------
-- LEAVE ENTITLEMENT (UNCHANGED – SAFE)
------------------------------------------------------------

-- Vacation
INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
SELECT e.employee_id, l.leave_id, 21
FROM Employee e
JOIN [Leave] l ON l.leave_type = 'Vacation'
WHERE e.email IN (
    'mostafa.mohamed@company.com',
    'hasan.mahmoud@company.com',
    'mohamed.amr@company.com',
    'omar.khalaf@company.com',
    'aya.nabil@company.com'
)
AND NOT EXISTS (
    SELECT 1
    FROM LeaveEntitlement le
    WHERE le.employee_id = e.employee_id
      AND le.leave_type_id = l.leave_id
);

-- Sick
INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
SELECT e.employee_id, l.leave_id, 10
FROM Employee e
JOIN [Leave] l ON l.leave_type = 'Sick'
WHERE e.email IN (
    'mostafa.mohamed@company.com',
    'hasan.mahmoud@company.com',
    'mohamed.amr@company.com',
    'omar.khalaf@company.com',
    'aya.nabil@company.com'
)
AND NOT EXISTS (
    SELECT 1
    FROM LeaveEntitlement le
    WHERE le.employee_id = e.employee_id
      AND le.leave_type_id = l.leave_id
);

------------------------------------------------------------
-- FIX HIERARCHY (NO SELECT OUTPUT)
------------------------------------------------------------

TRUNCATE TABLE EmployeeHierarchy;

DECLARE @Mostafa INT = (SELECT employee_id FROM Employee WHERE email='mostafa.mohamed@company.com');
DECLARE @Amr     INT = (SELECT employee_id FROM Employee WHERE email='mohamed.amr@company.com');
DECLARE @Aya     INT = (SELECT employee_id FROM Employee WHERE email='aya.nabil@company.com');
DECLARE @Omar    INT = (SELECT employee_id FROM Employee WHERE email='omar.khalaf@company.com');

DECLARE @IT  INT = (SELECT department_id FROM Department WHERE department_name='IT');
DECLARE @HR  INT = (SELECT department_id FROM Department WHERE department_name='HR');
DECLARE @FIN INT = (SELECT department_id FROM Department WHERE department_name='Finance');

-- Level 1
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
VALUES (@Mostafa, NULL, 1);

-- Level 2
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
VALUES
(@Amr,  @Mostafa, 2),
(@Aya,  @Mostafa, 2),
(@Omar, @Mostafa, 2);

-- Level 3 – IT
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Amr, 3
FROM Employee
WHERE department_id = @IT
  AND employee_id NOT IN (@Mostafa, @Amr);

-- Level 3 – HR
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Aya, 3
FROM Employee
WHERE department_id = @HR
  AND employee_id <> @Aya;

-- Level 3 – Finance
INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
SELECT employee_id, @Omar, 3
FROM Employee
WHERE department_id = @FIN
  AND employee_id <> @Omar;

------------------------------------------------------------
-- ATTENDANCE GENERATION (SILENT)
------------------------------------------------------------

DECLARE @AmrId INT = @Amr;

DECLARE @MorningShift INT =
(
    SELECT TOP 1 shift_id
    FROM ShiftSchedule
    WHERE name = 'Morning'
);

DECLARE @BaseDate DATETIME = CAST(GETDATE() AS DATE);

-- LAST 7 DAYS
DECLARE @i INT = 1;
WHILE @i <= 7
BEGIN
    INSERT INTO Attendance (
        employee_id, shift_id, entry_time, exit_time, login_method, logout_method
    )
    SELECT 
        h.employee_id,
        @MorningShift,
        DATEADD(HOUR, 9, DATEADD(DAY, -@i, @BaseDate)),
        DATEADD(HOUR, 17, DATEADD(DAY, -@i, @BaseDate)),
        'Device', 'Device'
    FROM EmployeeHierarchy h
    WHERE h.manager_id = @AmrId;

    SET @i += 1;
END;

-- LAST 30 DAYS (excluding last 7)
DECLARE @d INT = 8;
WHILE @d <= 30
BEGIN
    INSERT INTO Attendance (
        employee_id, shift_id, entry_time, exit_time, login_method, logout_method
    )
    SELECT 
        h.employee_id,
        @MorningShift,
        DATEADD(MINUTE, 5, DATEADD(HOUR, 9, DATEADD(DAY, -@d, @BaseDate))),
        DATEADD(MINUTE, 5, DATEADD(HOUR, 17, DATEADD(DAY, -@d, @BaseDate))),
        'Device', 'Device'
    FROM EmployeeHierarchy h
    WHERE h.manager_id = @AmrId;

    SET @d += 1;
END;








