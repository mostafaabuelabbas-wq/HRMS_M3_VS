SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE HRMS;
GO
/* Corrected HRMS schema
   - No GO separators
   - Proper ordering to avoid FK errors
   - Department ↔ Employee circular FK resolved via ALTER TABLE after Employee creation
   - CurrencyCode used as currency FK
   - Bracketed reserved names
*/

/* 0. Create supporting lookup tables first */
CREATE TABLE Currency (
    CurrencyCode VARCHAR(10) PRIMARY KEY,
    CurrencyName VARCHAR(100),
    ExchangeRate DECIMAL(18,6),
    CreatedDate DATETIME DEFAULT GETDATE(),
    LastUpdated DATETIME DEFAULT GETDATE()
);

CREATE TABLE Position (
    position_id INT IDENTITY(1,1) PRIMARY KEY,
    position_title VARCHAR(100) NOT NULL,
    responsibilities VARCHAR(MAX),
    status VARCHAR(50)
);

CREATE TABLE Role (
    role_id INT IDENTITY(1,1) PRIMARY KEY,
    role_name VARCHAR(100) NOT NULL,
    purpose VARCHAR(255)
);

CREATE TABLE Skill (
    skill_id INT IDENTITY(1,1) PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE Verification (
    verification_id INT IDENTITY(1,1) PRIMARY KEY,
    verification_type VARCHAR(100),
    issuer VARCHAR(100),
    issue_date DATE,
    expiry_period INT
);

CREATE TABLE PayGrade (
    pay_grade_id INT IDENTITY(1,1) PRIMARY KEY,
    grade_name VARCHAR(50),
    min_salary DECIMAL(10,2),
    max_salary DECIMAL(10,2)
);

CREATE TABLE TaxForm (
    tax_form_id INT IDENTITY(1,1) PRIMARY KEY,
    jurisdiction VARCHAR(100),
    validity_period INT,
    form_content VARCHAR(MAX)
);

CREATE TABLE PayrollPolicy (
    policy_id INT IDENTITY(1,1) PRIMARY KEY,
    effective_date DATE,
    [type] VARCHAR(100),
    [description] VARCHAR(500)
);

/* SalaryType references Currency.CurrencyCode */
CREATE TABLE SalaryType (
    salary_type_id INT IDENTITY(1,1) PRIMARY KEY,
    [type] VARCHAR(50),
    payment_frequency VARCHAR(50),
    currency_code VARCHAR(10) NULL,
    CONSTRAINT FK_SalaryType_Currency
        FOREIGN KEY (currency_code) REFERENCES Currency(CurrencyCode)
);

/* Basic contract & related tables */
CREATE TABLE Contract (
    contract_id INT IDENTITY(1,1) PRIMARY KEY,
    [type] VARCHAR(50),
    start_date DATE,
    end_date DATE,
    current_state VARCHAR(50)
);


CREATE TABLE Insurance (
    insurance_id INT IDENTITY(1,1) PRIMARY KEY,
    [type] VARCHAR(50),
    contribution_rate DECIMAL(5,2),
    coverage VARCHAR(255)
);

/* Department created without department_head FK to avoid circularity.
   We'll add the FK after Employee exists using ALTER TABLE.
*/
CREATE TABLE Department (
    department_id INT IDENTITY(1,1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    purpose VARCHAR(255),
    department_head_id INT NULL -- FK added later
);

/* Employee (references many objects already created above) */
CREATE TABLE Employee (
    employee_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    full_name AS (first_name + ' ' + last_name) PERSISTED,
    national_id VARCHAR(20),
    date_of_birth DATE,
    country_of_birth VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    address VARCHAR(200),
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    relationship VARCHAR(50),
    biography VARCHAR(MAX),
    profile_image VARBINARY(MAX),
    employment_progress VARCHAR(50),
    account_status VARCHAR(50),
    employment_status VARCHAR(50),
    hire_date DATE,
    is_active BIT,
    profile_completion INT,

    department_id INT NULL,
    position_id INT NULL,
    manager_id INT NULL,
    contract_id INT NULL,
    tax_form_id INT NULL,
    salary_type_id INT NULL,
    pay_grade INT NULL,

    CONSTRAINT FK_Employee_Department FOREIGN KEY (department_id)
        REFERENCES Department(department_id),

    CONSTRAINT FK_Employee_Position FOREIGN KEY (position_id)
        REFERENCES Position(position_id),

    CONSTRAINT FK_Employee_Manager FOREIGN KEY (manager_id)
        REFERENCES Employee(employee_id),

    CONSTRAINT FK_Employee_Contract FOREIGN KEY (contract_id)
        REFERENCES Contract(contract_id),

    CONSTRAINT FK_Employee_TaxForm FOREIGN KEY (tax_form_id)
        REFERENCES TaxForm(tax_form_id),

    CONSTRAINT FK_Employee_SalaryType FOREIGN KEY (salary_type_id)
        REFERENCES SalaryType(salary_type_id),

    CONSTRAINT FK_Employee_PayGrade FOREIGN KEY (pay_grade)
        REFERENCES PayGrade(pay_grade_id)
);

/* Now that Employee exists, add department_head_id FK (resolves circular dependency) */
ALTER TABLE Department
    ADD CONSTRAINT FK_Department_DepartmentHead
    FOREIGN KEY (department_head_id) REFERENCES Employee(employee_id);

/* Contract subtypes referencing Contract */
CREATE TABLE FullTimeContract (
    contract_id INT PRIMARY KEY,
    leave_entitlement INT,
    insurance_eligibility BIT,
    weekly_working_hours INT,
    FOREIGN KEY (contract_id) REFERENCES Contract(contract_id)
);

CREATE TABLE PartTimeContract (
    contract_id INT PRIMARY KEY,
    working_hours INT,
    hourly_rate DECIMAL(10,2),
    FOREIGN KEY (contract_id) REFERENCES Contract(contract_id)
);

CREATE TABLE ConsultantContract (
    contract_id INT PRIMARY KEY,
    project_scope VARCHAR(255),
    fees DECIMAL(10,2),
    payment_schedule VARCHAR(255),
    FOREIGN KEY (contract_id) REFERENCES Contract(contract_id)
);

CREATE TABLE InternshipContract (
    contract_id INT PRIMARY KEY,
    mentoring VARCHAR(255),
    evaluation VARCHAR(255),
    stipend_related VARCHAR(255),
    FOREIGN KEY (contract_id) REFERENCES Contract(contract_id)
);

/* Employee relationships tables */
CREATE TABLE Employee_Skill (
    employee_id INT,
    skill_id INT,
    proficiency_level VARCHAR(50),
    PRIMARY KEY (employee_id, skill_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (skill_id) REFERENCES Skill(skill_id)
);

CREATE TABLE Employee_Verification (
    employee_id INT,
    verification_id INT,
    PRIMARY KEY (employee_id, verification_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (verification_id) REFERENCES Verification(verification_id)
);

CREATE TABLE Employee_Role (
    employee_id INT,
    role_id INT,
    assigned_date DATE,
    PRIMARY KEY (employee_id, role_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (role_id) REFERENCES Role(role_id)
);

CREATE TABLE RolePermission (
    role_id INT,
    permission_name VARCHAR(100),
    allowed_action VARCHAR(100),
    FOREIGN KEY (role_id) REFERENCES Role(role_id)
);

/* HR-specific / administrative role tables */
CREATE TABLE Termination (
    termination_id INT IDENTITY(1,1) PRIMARY KEY,
    [date] DATE,
    reason VARCHAR(255),
    contract_id INT,
    FOREIGN KEY (contract_id) REFERENCES Contract(contract_id)
);

CREATE TABLE Reimbursement (
    reimbursement_id INT IDENTITY(1,1) PRIMARY KEY,
    [type] VARCHAR(50),
    claim_type VARCHAR(50),
    approval_date DATE,
    current_status VARCHAR(50),
    employee_id INT,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);

CREATE TABLE Mission (
    mission_id INT IDENTITY(1,1) PRIMARY KEY,
    destination VARCHAR(100),
    description VARCHAR(200),
    start_date DATE,
    end_date DATE,
    status VARCHAR(50),
    employee_id INT,
    manager_id INT,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (manager_id) REFERENCES Employee(employee_id)
);

/* Leave domain (use [Leave] because LEAVE is a keyword) */
CREATE TABLE [Leave] (
    leave_id INT IDENTITY(1,1) PRIMARY KEY,
    leave_type VARCHAR(50),
    leave_description VARCHAR(255)
);

CREATE TABLE VacationLeave (
    leave_id INT PRIMARY KEY,
    carry_over_days INT,
    approving_manager INT,
    FOREIGN KEY (leave_id) REFERENCES [Leave](leave_id)
);

CREATE TABLE SickLeave (
    leave_id INT PRIMARY KEY,
    medical_cert_required BIT,
    physician_id INT,
    FOREIGN KEY (leave_id) REFERENCES [Leave](leave_id)
);

CREATE TABLE ProbationLeave (
    leave_id INT PRIMARY KEY,
    eligibility_start_date DATE,
    probation_period INT,
    FOREIGN KEY (leave_id) REFERENCES [Leave](leave_id)
);

CREATE TABLE HolidayLeave (
    leave_id INT PRIMARY KEY,
    holiday_name VARCHAR(100),
    official_recognition VARCHAR(100),
    regional_scope VARCHAR(100),
    FOREIGN KEY (leave_id) REFERENCES [Leave](leave_id)
);

CREATE TABLE LeavePolicy (
    policy_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100),
    purpose VARCHAR(255),
    eligibility_rules VARCHAR(255),
    notice_period INT,
    special_leave_type VARCHAR(50),
    reset_on_new_year BIT
);

CREATE TABLE LeaveRequest (
    request_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT,
    leave_id INT,
    justification VARCHAR(255),
    duration INT,
    approval_timing DATE,
    status VARCHAR(50),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (leave_id) REFERENCES [Leave](leave_id)
);

CREATE TABLE LeaveEntitlement (
    employee_id INT,
    leave_type_id INT,
    entitlement DECIMAL(5,2),
    PRIMARY KEY (employee_id, leave_type_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (leave_type_id) REFERENCES [Leave](leave_id)
);

CREATE TABLE LeaveDocument (
    document_id INT IDENTITY(1,1) PRIMARY KEY,
    leave_request_id INT NOT NULL,
    file_path VARCHAR(500),
    uploaded_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (leave_request_id) REFERENCES LeaveRequest(request_id)
);

/* Attendance & shift domain - bracket Exception because it's a keyword? We'll use [Exception] */
CREATE TABLE [Exception] (
    exception_id INT IDENTITY(1,1) PRIMARY KEY,
    [name] VARCHAR(100),
    category VARCHAR(100),
    [date] DATE,
    status VARCHAR(50)
);

CREATE TABLE ShiftSchedule (
    shift_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100),
    type VARCHAR(50),
    start_time TIME,
    end_time TIME,
    break_duration INT,
    shift_date DATE NULL,
    status VARCHAR(50)
);

CREATE TABLE Attendance (
    attendance_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    shift_id INT NULL,
    entry_time DATETIME,
    exit_time DATETIME,
    duration AS DATEDIFF(MINUTE, entry_time, exit_time) PERSISTED,
    login_method VARCHAR(50),
    logout_method VARCHAR(50),
    exception_id INT NULL,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (shift_id) REFERENCES ShiftSchedule(shift_id),
    FOREIGN KEY (exception_id) REFERENCES [Exception](exception_id)
);

CREATE TABLE AttendanceLog (
    attendance_log_id INT IDENTITY(1,1) PRIMARY KEY,
    attendance_id INT NOT NULL,
    actor INT,
    [timestamp] DATETIME DEFAULT GETDATE(),
    reason VARCHAR(500),
    FOREIGN KEY (attendance_id) REFERENCES Attendance(attendance_id),
    FOREIGN KEY (actor) REFERENCES Employee(employee_id)
);

CREATE TABLE AttendanceCorrectionRequest (
    request_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    [date] DATE,
    correction_type VARCHAR(100),
    reason VARCHAR(500),
    status VARCHAR(50),
    recorded_by INT NULL,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (recorded_by) REFERENCES Employee(employee_id)
);

CREATE TABLE ShiftAssignment (
    assignment_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    shift_id INT NOT NULL,
    start_date DATE,
    end_date DATE,
    status VARCHAR(50),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (shift_id) REFERENCES ShiftSchedule(shift_id)
);

CREATE TABLE Employee_Exception (
    employee_id INT,
    exception_id INT,
    PRIMARY KEY (employee_id, exception_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (exception_id) REFERENCES [Exception](exception_id)
);

/* Payroll and related tables */
CREATE TABLE Payroll (
    payroll_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    taxes DECIMAL(10,2),
    period_start DATE,
    period_end DATE,
    base_amount DECIMAL(18,2),
    adjustments DECIMAL(18,2),
    contributions DECIMAL(18,2),
    actual_pay DECIMAL(18,2),
    net_salary DECIMAL(18,2),
    payment_date DATE,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);

CREATE TABLE AllowanceDeduction (
    ad_id INT IDENTITY(1,1) PRIMARY KEY,
    payroll_id INT NULL,
    employee_id INT NULL,
    [type] VARCHAR(100),
    amount DECIMAL(18,2),
    currency_code VARCHAR(10) NULL,
    duration VARCHAR(50),
    timezone VARCHAR(50),
    FOREIGN KEY (payroll_id) REFERENCES Payroll(payroll_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    CONSTRAINT FK_AllowanceDeduction_Currency FOREIGN KEY (currency_code) REFERENCES Currency(CurrencyCode)
);

/* SalaryType specializations */
CREATE TABLE HourlySalaryType (
    salary_type_id INT PRIMARY KEY,
    hourly_rate DECIMAL(18,2),
    max_monthly_hours INT,
    FOREIGN KEY (salary_type_id) REFERENCES SalaryType(salary_type_id)
);

CREATE TABLE MonthlySalaryType (
    salary_type_id INT PRIMARY KEY,
    tax_rule VARCHAR(255),
    contribution_scheme VARCHAR(255),
    FOREIGN KEY (salary_type_id) REFERENCES SalaryType(salary_type_id)
);

CREATE TABLE ContractSalaryType (
    salary_type_id INT PRIMARY KEY,
    contract_value DECIMAL(18,2),
    installment_details VARCHAR(500),
    FOREIGN KEY (salary_type_id) REFERENCES SalaryType(salary_type_id)
);

/* Payroll policy specializations */
CREATE TABLE OvertimePolicy (
    policy_id INT PRIMARY KEY,
    weekday_rate_multiplier DECIMAL(5,2),
    weekend_rate_multiplier DECIMAL(5,2),
    max_hours_per_month INT,
    FOREIGN KEY (policy_id) REFERENCES PayrollPolicy(policy_id)
);

CREATE TABLE LatenessPolicy (
    policy_id INT PRIMARY KEY,
    grace_period_mins INT,
    deduction_rate DECIMAL(5,2),
    FOREIGN KEY (policy_id) REFERENCES PayrollPolicy(policy_id)
);

CREATE TABLE BonusPolicy (
    policy_id INT PRIMARY KEY,
    bonus_type VARCHAR(100),
    eligibility_criteria VARCHAR(500),
    FOREIGN KEY (policy_id) REFERENCES PayrollPolicy(policy_id)
);

CREATE TABLE DeductionPolicy (
    policy_id INT PRIMARY KEY,
    deduction_reason VARCHAR(255),
    calculation_mode VARCHAR(100),
    FOREIGN KEY (policy_id) REFERENCES PayrollPolicy(policy_id)
);

CREATE TABLE PayrollPolicy_ID (
    payroll_id INT,
    policy_id INT,
    PRIMARY KEY (payroll_id, policy_id),
    FOREIGN KEY (payroll_id) REFERENCES Payroll(payroll_id),
    FOREIGN KEY (policy_id) REFERENCES PayrollPolicy(policy_id)
);

CREATE TABLE Payroll_Log (
    payroll_log_id INT IDENTITY(1,1) PRIMARY KEY,
    payroll_id INT NOT NULL,
    actor INT,
    change_date DATETIME DEFAULT GETDATE(),
    modification_type VARCHAR(100),
    FOREIGN KEY (payroll_id) REFERENCES Payroll(payroll_id),
    FOREIGN KEY (actor) REFERENCES Employee(employee_id)
);

CREATE TABLE PayrollPeriod (
    payroll_period_id INT IDENTITY(1,1) PRIMARY KEY,
    payroll_id INT NULL,
    start_date DATE,
    end_date DATE,
    status VARCHAR(50),
    FOREIGN KEY (payroll_id) REFERENCES Payroll(payroll_id)
);

/* Notifications */
CREATE TABLE Notification (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    message_content VARCHAR(1000),
    [timestamp] DATETIME DEFAULT GETDATE(),
    urgency VARCHAR(50),
    read_status BIT DEFAULT 0,
    notification_type VARCHAR(50)
);

CREATE TABLE Employee_Notification (
    employee_id INT,
    notification_id INT,
    delivery_status VARCHAR(50),
    delivered_at DATETIME,
    PRIMARY KEY (employee_id, notification_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (notification_id) REFERENCES Notification(notification_id)
);

/* EmployeeHierarchy */
CREATE TABLE EmployeeHierarchy (
    employee_id INT PRIMARY KEY,
    manager_id INT,
    hierarchy_level INT,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (manager_id) REFERENCES Employee(employee_id)
);

/* Devices & AttendanceSource */
CREATE TABLE Device (
    device_id INT IDENTITY(1,1) PRIMARY KEY,
    device_type VARCHAR(100),
    terminal_id VARCHAR(100),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    employee_id INT NULL,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);

CREATE TABLE AttendanceSource (
    attendance_source_id INT IDENTITY(1,1) PRIMARY KEY,
    attendance_id INT,
    device_id INT,
    source_type VARCHAR(50),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    recorded_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (attendance_id) REFERENCES Attendance(attendance_id),
    FOREIGN KEY (device_id) REFERENCES Device(device_id)
);

/* Shift cycles */
CREATE TABLE ShiftCycle (
    cycle_id INT IDENTITY(1,1) PRIMARY KEY,
    cycle_name VARCHAR(100),
    description VARCHAR(255)
);

CREATE TABLE ShiftCycleAssignment (
    cycle_id INT,
    shift_id INT,
    order_number INT,
    PRIMARY KEY (cycle_id, shift_id),
    FOREIGN KEY (cycle_id) REFERENCES ShiftCycle(cycle_id),
    FOREIGN KEY (shift_id) REFERENCES ShiftSchedule(shift_id)
);

/* Approval workflow */
CREATE TABLE ApprovalWorkflow (
    workflow_id INT IDENTITY(1,1) PRIMARY KEY,
    workflow_type VARCHAR(100),
    threshold_amount DECIMAL(18,2),
    approver_role INT,
    created_by INT,
    status VARCHAR(50),
    FOREIGN KEY (approver_role) REFERENCES Role(role_id),
    FOREIGN KEY (created_by) REFERENCES Employee(employee_id)
);

CREATE TABLE ApprovalWorkflowStep (
    workflow_id INT,
    step_number INT,
    role_id INT,
    action_required VARCHAR(255),
    PRIMARY KEY (workflow_id, step_number),
    FOREIGN KEY (workflow_id) REFERENCES ApprovalWorkflow(workflow_id),
    FOREIGN KEY (role_id) REFERENCES Role(role_id)
);

/* Manager notes and admin role specializations */
CREATE TABLE ManagerNotes (
    note_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT,
    manager_id INT,
    note_content VARCHAR(1000),
    created_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (manager_id) REFERENCES Employee(employee_id)
);

CREATE TABLE HRAdministrator (
    employee_id INT PRIMARY KEY,
    approval_level INT,
    record_access_scope VARCHAR(255),
    document_validation_rights BIT,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);

CREATE TABLE SystemAdministrator (
    employee_id INT PRIMARY KEY,
    system_privilege_level INT,
    configurable_fields VARCHAR(500),
    audit_visibility_scope VARCHAR(255),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);

CREATE TABLE PayrollSpecialist (
    employee_id INT PRIMARY KEY,
    assigned_region VARCHAR(100),
    processing_frequency VARCHAR(50),
    last_processed_period DATE,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);

CREATE TABLE LineManager (
    employee_id INT PRIMARY KEY,
    team_size INT,
    supervised_departments VARCHAR(255),
    approval_limit DECIMAL(18,2),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);
ALTER TABLE Contract
ADD employee_id INT NULL;
ALTER TABLE Contract
ADD CONSTRAINT FK_Contract_Employee
FOREIGN KEY (employee_id) REFERENCES Employee(employee_id);
SELECT name FROM sys.tables ORDER BY name;



--ALTER TABLE Contract ADD employee_id INT;
--ALTER TABLE Contract ADD CONSTRAINT FK_Contract_Employee FOREIGN KEY (employee_id) REFERENCES Employee(employee_id);
