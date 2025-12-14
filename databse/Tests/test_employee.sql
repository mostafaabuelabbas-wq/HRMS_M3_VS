/*
EXEC SubmitLeaveRequest
    @EmployeeID = 2,
    @LeaveTypeID = 2,
    @StartDate = '2024-03-10',
    @EndDate = '2024-03-12',
    @Reason = 'Family trip';
SELECT * FROM LeaveEntitlement WHERE employee_id = 2;
*/
/*
EXEC GetLeaveBalance @EmployeeID = 2;
*/
/*
EXEC RecordAttendance
    @EmployeeID = 2,
    @ShiftID = 1,
    @EntryTime = '09:00',
    @ExitTime = '17:00';
SELECT * FROM Attendance ORDER BY attendance_id DESC;

EXEC SubmitReimbursement
    @EmployeeID = 2,
    @ExpenseType = 'Travel',
    @Amount = 150.75;
*/
/*
EXEC AddEmployeeSkill 
    @EmployeeID = 2,
    @SkillName = 'Python';
EXEC ViewAssignedShifts @EmployeeID = 2;
*/
/*
EXEC ViewMyContracts @EmployeeID = 1;

EXEC ViewMyPayroll @EmployeeID = 1;
EXEC ViewMyPayroll @EmployeeID = 5;
*/
/*
EXEC UpdatePersonalDetails
    @EmployeeID = 2,
    @Phone = '01155588877',
    @Address = 'New Cairo – District 5';
SELECT employee_id, full_name, phone, address
FROM Employee
WHERE employee_id = 2;

EXEC ViewMyMissions @EmployeeID = 2;
*/
/*
EXEC ViewEmployeeProfile @EmployeeID = 1;

EXEC UpdateContactInformation 
    @EmployeeID = 2,
    @RequestType = 'Phone',
    @NewValue = '01234567890';

EXEC UpdateContactInformation 
    @EmployeeID = 2,
    @RequestType = 'Address',
    @NewValue = 'New Cairo, District 5';

EXEC UpdateContactInformation 1, 'Email', 'test@example.com';
*/
/*
EXEC ViewEmploymentTimeline @EmployeeID = 1;

EXEC UpdateEmergencyContact
    @EmployeeID = 2,
    @ContactName = 'Mona Ali',
    @Relation = 'Sister',
    @Phone = '01055577788';

SELECT emergency_contact_name, relationship, emergency_contact_phone
FROM Employee WHERE employee_id = 2;
*/
/*
EXEC RequestHRDocument 
    @EmployeeID = 2, 
    @DocumentType = 'Employment Verification';

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT TOP 1 * FROM Employee_Notification ORDER BY delivered_at DESC;

EXEC NotifyProfileUpdate 
    @EmployeeID = 3,
    @notificationType = 'Address updated';

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT TOP 1 * FROM Employee_Notification ORDER BY delivered_at DESC;
*/
/*
EXEC LogFlexibleAttendance
    @EmployeeID = 2,
    @Date = '2025-01-10',
    @CheckIn = '08:45',
    @CheckOut = '16:30';

EXEC NotifyMissedPunch
    @EmployeeID = 2,
    @Date = '2025-01-10';

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT TOP 1 * FROM Employee_Notification ORDER BY delivered_at DESC;
*/
/*
EXEC RecordMultiplePunches
    @EmployeeID = 2,
    @ClockInOutTime = '2025-01-10 08:30',
    @Type = 'ClockIn';

SELECT * FROM Attendance WHERE employee_id = 2 ORDER BY attendance_id DESC;
SELECT * FROM AttendanceLog ORDER BY attendance_log_id DESC;

EXEC RecordMultiplePunches
    @EmployeeID = 2,
    @ClockInOutTime = '2025-01-10 12:15',
    @Type = 'ClockOut';

SELECT * FROM Attendance WHERE employee_id = 2 ORDER BY attendance_id DESC;
*/
/*
EXEC SubmitCorrectionRequest
    @EmployeeID = 2,
    @Date = '2025-01-10',
    @CorrectionType = 'MissedClockOut',
    @Reason = 'Forgot to clock out';
SELECT * FROM AttendanceCorrectionRequest ORDER BY request_id DESC;

SELECT TOP 1 *
FROM Notification
ORDER BY notification_id DESC;

SELECT TOP 1 *
FROM Employee_Notification
ORDER BY delivered_at DESC;

EXEC SubmitCorrectionRequest
    @EmployeeID = 999,
    @Date = '2025-01-12',
    @CorrectionType = 'MissedClockIn',
    @Reason = 'Invalid employee test';


EXEC ViewRequestStatus @EmployeeID = 2;
EXEC ViewRequestStatus @EmployeeID = 3;
EXEC ViewRequestStatus @EmployeeID = 999;
*/
/*
EXEC AttachLeaveDocuments
    @LeaveRequestID = 2,
    @FilePath = 'docs/sick_note_sara.pdf';
SELECT * FROM LeaveDocument ORDER BY document_id DESC;

EXEC ModifyLeaveRequest
    @LeaveRequestID = 2,
    @StartDate = '2024-06-01',
    @EndDate = '2024-06-03',
    @Reason = 'Extended sick leave';
EXEC ModifyLeaveRequest
    @LeaveRequestID = 1,
    @StartDate = '2024-05-10',
    @EndDate = '2024-05-12',
    @Reason = 'Attempt modify'

EXEC CancelLeaveRequest @LeaveRequestID = 2;
SELECT request_id, status FROM LeaveRequest WHERE request_id = 2;
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT TOP 1 * FROM Employee_Notification ORDER BY delivered_at DESC;
*/
/*
-- BEFORE (show entitlement & leave types)
SELECT * FROM LeaveEntitlement WHERE employee_id = 1;
SELECT * FROM LeaveRequest WHERE employee_id = 1;

-- TEST
EXEC ViewLeaveBalance @EmployeeID = 1;

-- EXPECTED:
-- Vacation remaining = 21 - 5 = 16

EXEC ViewLeaveBalance @EmployeeID = 999;



-- BEFORE
SELECT * FROM LeaveRequest WHERE employee_id = 1;

-- TEST
EXEC ViewLeaveHistory @EmployeeID = 1;

EXEC ViewLeaveHistory @EmployeeID = 2;

-- EXPECTED:
-- 2+ rows depending on current data

-- BEFORE
SELECT * FROM LeaveRequest WHERE employee_id = 2;

-- TEST
EXEC SubmitLeaveAfterAbsence
    @EmployeeID = 2,
    @LeaveTypeID = 2,       -- Sick Leave
    @StartDate = '2025-01-10',
    @EndDate = '2025-01-10',
    @Reason = 'Flu - absence recorded after return';

-- AFTER
SELECT * FROM LeaveRequest WHERE employee_id = 2 ORDER BY request_id DESC;
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT TOP 1 * FROM Employee_Notification ORDER BY delivered_at DESC;

-- EXPECTED:
-- New row in LeaveRequest with status Pending
-- Manager receives a notification
*/
/*
EXEC NotifyLeaveStatusChange
    @EmployeeID = 1,
    @RequestID = 1,
    @Status = 'Approved';
SELECT * FROM Notification ORDER BY notification_id DESC;
SELECT * FROM Employee_Notification ORDER BY delivered_at DESC;

EXEC NotifyLeaveStatusChange
    @EmployeeID = 999,
    @RequestID = 1,
    @Status = 'Rejected';

EXEC NotifyLeaveStatusChange
    @EmployeeID = 2,
    @RequestID = 1,
    @Status = 'Returned';
*/

---- run thissssss for managerss


-- 1. Set the ID of the Manager you want to assign the team to
-- (Make sure this matches the user you are logging in as!)
SELECT *
FROM EmployeeHierarchy
WHERE manager_id = 6;
SELECT e.employee_id, e.first_name, e.last_name
FROM EmployeeHierarchy h
JOIN Employee e ON e.employee_id = h.employee_id
WHERE h.manager_id = 6;