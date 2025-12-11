/*
-- 20 ReviewLeaveRequest (BEFORE)
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;  -- example test ID
EXEC ReviewLeaveRequest
    @LeaveRequestID = 2,
    @ManagerID = 1,
    @Decision = 'Approved';
-- After ReviewLeaveRequest
SELECT request_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;
*/
/*
SELECT employee_id, full_name FROM Employee;
SELECT shift_id, name FROM ShiftSchedule;
SELECT * FROM ShiftAssignment;

EXEC AssignShift
    @EmployeeID = 1,
    @ShiftID = 2;

SELECT *
FROM ShiftAssignment
WHERE employee_id = 1
ORDER BY assignment_id DESC;
*/
/*
SELECT * FROM Attendance;
SELECT employee_id, full_name, manager_id FROM Employee;

EXEC ViewTeamAttendance
    @ManagerID = 1,
    @DateRangeStart = '2024-02-05',
    @DateRangeEnd   = '2024-02-05';

EXEC ViewTeamAttendance 1, '2024-02-05', '2024-02-05';
*/
/*
SELECT employee_id, full_name, manager_id FROM Employee;

SELECT * FROM Notification;
SELECT * FROM Employee_Notification;

EXEC SendTeamNotification
    @ManagerID = 1,
    @MessageContent = 'Team meeting at 10 AM.',
    @UrgencyLevel = 'High';

SELECT * FROM Notification ORDER BY notification_id DESC;
SELECT * FROM Employee_Notification WHERE employee_id IN (2,3);
*/
/*
SELECT mission_id, employee_id, manager_id, status
FROM Mission;

EXEC ApproveMissionCompletion
    @MissionID = 3,
    @ManagerID = 1,
    @Remarks = 'Employee successfully completed the mission.';

SELECT mission_id, status
FROM Mission
WHERE mission_id = 3;
*/
/*
SELECT employee_id, full_name FROM Employee;
SELECT * FROM HRAdministrator;
SELECT * FROM Notification;
SELECT * FROM Employee_Notification;

EXEC RequestReplacement
    @EmployeeID = 2,
    @Reason = 'Employee is unavailable due to emergency leave.';

SELECT * FROM Notification ORDER BY notification_id DESC;
SELECT * FROM HRAdministrator;
*/
/*

SELECT department_id, department_name FROM Department;

SELECT employee_id, full_name, department_id 
FROM Employee;

SELECT mission_id, employee_id, status 
FROM Mission;

EXEC ViewDepartmentSummary @DepartmentID = 3;
EXEC ViewDepartmentSummary @DepartmentID = 2;
EXEC ViewDepartmentSummary 3;

SELECT mission_id, employee_id, manager_id, status
FROM Mission;
*/
/*
SELECT *
FROM ShiftAssignment
WHERE employee_id = 1;
SELECT shift_id, name, type FROM ShiftSchedule;

EXEC ReassignShift
    @EmployeeID = 2,
    @OldShiftID = 2,
    @NewShiftID = 1;

SELECT *
FROM ShiftAssignment
WHERE employee_id = 2;
*/
/*

SELECT employee_id, full_name, manager_id FROM Employee;
SELECT * FROM LeaveRequest;

EXEC GetPendingLeaveRequests @ManagerID = 1;
*/
/*
SELECT employee_id, full_name, manager_id FROM Employee;
SELECT * FROM Payroll;

EXEC GetTeamStatistics @ManagerID = 1;
EXEC ViewTeamProfiles @ManagerID = 1;
*/
/*
SELECT * FROM Employee;
SELECT * FROM Employee_Skill;
SELECT * FROM Employee_Role;
SELECT * FROM Skill;
SELECT * FROM Role;

EXEC GetTeamSummary @ManagerID = 1;

EXEC FilterTeamProfiles @ManagerID = 1, @Skill = 'SQL', @RoleID = NULL;
EXEC FilterTeamProfiles @ManagerID = 1, @Skill = NULL, @RoleID = 2;
*/
/*
SELECT * FROM ManagerNotes;
SELECT * FROM Employee;

EXEC AddManagerNotes
    @EmployeeID = 2,
    @ManagerID = 1,
    @Note = 'Excellent improvement this quarter.';
SELECT * FROM ManagerNotes WHERE employee_id = 2;

EXEC ViewTeamCertifications @ManagerID = 1;
*/
/*
-- Check employee exists
SELECT employee_id, full_name FROM Employee;

-- Check existing attendance for employee 2 (example)
SELECT * FROM Attendance WHERE employee_id = 2;

-- Check attendance logs
SELECT * FROM AttendanceLog ORDER BY attendance_log_id DESC;

EXEC RecordManualAttendance
    @EmployeeID = 2,
    @Date = '2024-02-10',
    @ClockIn = '09:00',
    @ClockOut = '17:00',
    @Reason = 'Correcting missed punch for employee.',
    @RecordedBy = 1;

-- New attendance record created
SELECT * FROM Attendance WHERE employee_id = 2 ORDER BY attendance_id DESC;

-- New audit log entry referencing that attendance_id
SELECT * FROM AttendanceLog ORDER BY attendance_log_id DESC;
*/
/*
EXEC ReviewMissedPunches
    @ManagerID = 1,
    @Date = '2024-02-05';
*/
/*

EXEC ApproveTimeRequest
    @RequestID = 1,
    @ManagerID = 1,
    @Decision = 'Approved',
    @Comments = 'Validated with CCTV footage.';
*/
/*
EXEC ViewLeaveRequest
    @LeaveRequestID = 2,
    @ManagerID = 1;
*/
/*
SELECT request_id, employee_id, status FROM LeaveRequest;
SELECT * FROM Employee_Notification;
SELECT * FROM Notification;

EXEC ApproveLeaveRequest
    @LeaveRequestID = 2,
    @ManagerID = 1;

SELECT request_id, status, approval_timing
FROM LeaveRequest WHERE request_id = 2;
*/
/*
EXEC RejectLeaveRequest
    @LeaveRequestID = 2,
    @ManagerID = 1,
    @Reason = 'Insufficient leave balance';

SELECT request_id, status, approval_timing
FROM LeaveRequest WHERE request_id = 2;
*/
/*
EXEC DelegateLeaveApproval
    @ManagerID = 1,
    @DelegateID = 3,
    @StartDate = '2024-02-10',
    @EndDate = '2024-02-20';

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
*/
/*
SELECT employee_id, full_name FROM Employee;
SELECT * FROM HRAdministrator;
EXEC FlagIrregularLeave
    @EmployeeID = 2,
    @ManagerID = 1,
    @PatternDescription = 'Repeated sick leave on Mondays';
SELECT TOP 1 *
FROM Notification
ORDER BY notification_id DESC;
SELECT *
FROM Employee_Notification
WHERE notification_id = (SELECT MAX(notification_id) FROM Notification);
*/
/*
SELECT request_id, employee_id, status FROM LeaveRequest;
EXEC NotifyNewLeaveRequest
    @ManagerID = 1,
    @RequestID = 2;
SELECT TOP 1 *
FROM Notification
ORDER BY notification_id DESC;
*/