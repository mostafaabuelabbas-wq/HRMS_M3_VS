--1 ViewEmployeeInfo
/*
EXEC ViewEmployeeInfo @EmployeeID = 1;
*/
--2 AddEmployee
/*
SELECT employee_id, full_name, email, national_id FROM Employee;

EXEC AddEmployee
    @FullName = 'John Snow',
    @NationalID = '30001011234567',
    @DateOfBirth = '1995-01-01',
    @CountryOfBirth = 'Egypt',
    @Phone = '01099999999',
    @Email = 'john.snow@example.com',
    @Address = 'New Cairo',
    @EmergencyContactName = 'Mary Snow',
    @EmergencyContactPhone = '01234567890',
    @Relationship = 'Mother',
    @Biography = 'New hire bio',
    @EmploymentProgress = 'Onboarding',
    @AccountStatus = 'Active',
    @EmploymentStatus = 'Full-time',
    @HireDate = '2025-01-01',
    @IsActive = 1,
    @ProfileCompletion = 80,
    @DepartmentID = 1,
    @PositionID = 1,
    @ManagerID = NULL,
    @ContractID = 1,
    @TaxFormID = 1,
    @SalaryTypeID = 1,
    @PayGrade = 1;
*/
--3 UpdateEmployeeInfo
/*
SELECT employee_id, full_name, email, phone, address
FROM Employee
WHERE employee_id = 2;
EXEC UpdateEmployeeInfo
    @EmployeeID = 2,
    @Email = 'sara.new@example.com',
    @Phone = '01555555555',
    @Address = 'New Cairo';
SELECT employee_id, full_name, email, phone, address
FROM Employee
WHERE employee_id = 2;
*/
--4 AssignRole
/*
SELECT employee_id, full_name, is_active FROM Employee;
SELECT role_id, role_name FROM Role;
SELECT role_id, role_name FROM Role;
EXEC AssignRole 
     @EmployeeID = 2,
     @RoleID = 2;
SELECT employee_id, role_id, assigned_date
FROM Employee_Role
WHERE employee_id = 2;
*/
--5 GetDepartmentEmployeeStats
/*
SELECT employee_id, full_name, department_id FROM Employee;
EXEC GetDepartmentEmployeeStats;
*/
--6 ReassignManager
/*
SELECT employee_id, full_name, manager_id FROM Employee;
SELECT * FROM EmployeeHierarchy;

EXEC ReassignManager
    @EmployeeID = 2,
    @NewManagerID = 3;

SELECT employee_id, full_name, manager_id
FROM Employee
WHERE employee_id = 2;
SELECT * FROM EmployeeHierarchy WHERE employee_id = 2;
*/
--7 ReassignHierarchy
/*
SELECT employee_id, full_name, department_id, manager_id 
FROM Employee WHERE employee_id = 2;
SELECT * FROM EmployeeHierarchy WHERE employee_id = 2;
EXEC ReassignHierarchy
    @EmployeeID = 2,
    @NewDepartmentID = 3,
    @NewManagerID = 3;
SELECT employee_id, full_name, department_id, manager_id
FROM Employee WHERE employee_id = 2;
SELECT * FROM EmployeeHierarchy WHERE employee_id = 2;
*/
--8 NotifyStructureChange
/*
SELECT COUNT(*) FROM Notification;
SELECT * FROM Employee_Notification;
EXEC NotifyStructureChange
    @AffectedEmployees = '1,2,3',
    @Message = 'Organizational structure updated.';
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT * FROM Employee_Notification WHERE notification_id = 1;
*/
--9 ViewOrgHierarchy
/*
SELECT employee_id, full_name, department_id, position_id, manager_id
FROM Employee;
SELECT * FROM EmployeeHierarchy;
EXEC ViewOrgHierarchy;
*/
--10 AssignShiftToEmployee
/*
SELECT employee_id, full_name, is_active FROM Employee WHERE employee_id = 2;
SELECT * FROM ShiftSchedule WHERE shift_id = 1;
SELECT * FROM ShiftAssignment WHERE employee_id = 2;

EXEC AssignShiftToEmployee 
    @EmployeeID = 2,
    @ShiftID = 1,
    @StartDate = '2024-03-01',
    @EndDate = '2024-03-31';

SELECT * FROM ShiftAssignment WHERE employee_id = 2;
*/

--11 UpdateShiftStatus
/*
SELECT * FROM ShiftAssignment WHERE assignment_id = 2;

EXEC UpdateShiftStatus 
    @ShiftAssignmentID = 2,
    @Status = 'Approved';

SELECT * FROM ShiftAssignment WHERE assignment_id = 2;
*/
--12 AssignShiftToDepartment
/*
SELECT employee_id, full_name, is_active 
FROM Employee 
WHERE department_id = 2;
SELECT * FROM ShiftAssignment WHERE employee_id = 2;
EXEC AssignShiftToDepartment
    @DepartmentID = 2,
    @ShiftID = 1,
    @StartDate = '2024-03-01',
    @EndDate = '2024-03-31';

SELECT * FROM ShiftAssignment WHERE employee_id = 2;
*/
--13 AssignCustomShift
/*
SELECT employee_id, full_name, is_active FROM Employee WHERE employee_id = 3;
SELECT * FROM ShiftAssignment WHERE employee_id = 3;
EXEC AssignCustomShift
    @EmployeeID = 3,
    @ShiftName = 'Consulting Block',
    @ShiftType = 'Custom',
    @StartTime = '10:00',
    @EndTime = '18:00',
    @StartDate = '2024-03-01',
    @EndDate = '2024-03-15';
SELECT * FROM ShiftAssignment WHERE employee_id = 3;
*/
--14 ConfigureSplitShift
/*
SELECT * FROM ShiftSchedule WHERE name LIKE 'TechSplit%';
EXEC ConfigureSplitShift
    @ShiftName = 'TechSplit',
    @FirstSlotStart = '08:00',
    @FirstSlotEnd = '12:00',
    @SecondSlotStart = '16:00',
    @SecondSlotEnd = '20:00';
SELECT * FROM ShiftSchedule WHERE name LIKE 'TechSplit%';
*/
/*--15
SELECT * FROM PayrollPolicy WHERE [type] = 'Attendance Processing';
EXEC EnableFirstInLastOut @Enable = 1;
EXEC EnableFirstInLastOut @Enable = 0;
SELECT * FROM PayrollPolicy WHERE [type] = 'Attendance Processing';
*/
--16 TagAttendanceSource
/*
SELECT * FROM Attendance WHERE attendance_id = 1;
SELECT * FROM AttendanceSource WHERE attendance_id = 1;
EXEC TagAttendanceSource
    @AttendanceID = 1,
    @SourceType = 'GPS',
    @DeviceID = NULL,
    @Latitude = 30.0444000,
    @Longitude = 31.2357000;
SELECT * FROM AttendanceSource WHERE attendance_id = 1;
*/
--17 SyncOfflineAttendance
/*
SELECT * FROM Attendance WHERE employee_id = 1;
SELECT * FROM AttendanceSource;

EXEC SyncOfflineAttendance
    @DeviceID = 1,
    @EmployeeID = 1,
    @ClockTime = '2024-02-10 09:05',
    @Type = 'IN';

SELECT TOP 1 * 
FROM Attendance
WHERE employee_id = 1
ORDER BY attendance_id DESC;

SELECT * FROM AttendanceSource WHERE attendance_id = 1;
*/


/*
EXEC LogAttendanceEdit 
    @AttendanceID = 1,
    @EditedBy = 1,
    @OldValue = '2024-02-05 09:01',
    @NewValue = '2024-02-05 09:10',
    @EditTimestamp = '2025-01-01 10:00:00'

*/
/*
SELECT * FROM HolidayLeave;
SELECT * FROM [Leave];
EXEC ApplyHolidayOverrides
    @HolidayID = 4,   -- the ID created above
    @EmployeeID = 2;
SELECT * FROM Employee_Exception WHERE employee_id = 2;
*/
/*
SELECT * FROM Employee_Role WHERE employee_id = 3;
SELECT role_id, role_name FROM Role;

SELECT * FROM Employee_Role WHERE employee_id = 3;
EXEC ManageUserAccounts
    @UserID = 3,
    @Role = 'PayrollOfficer',
    @Action = 'Remove';
SELECT * FROM Employee_Role WHERE employee_id = 3;
*/