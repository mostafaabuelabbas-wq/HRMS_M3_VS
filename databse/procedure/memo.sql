SELECT *
FROM LeaveEntitlement
WHERE employee_id = (
    SELECT employee_id
    FROM Employee
    WHERE email = 'hasan.mahmoud@company.com'
);