namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AttendanceBreachDto
    {
        public int employee_id { get; set; }
        public string employee_name { get; set; }
        public string department_name { get; set; }

        public TimeSpan shift_start { get; set; }
        public TimeSpan shift_end { get; set; }
        public TimeSpan actual_in { get; set; }
        public TimeSpan? actual_out { get; set; }

        public int raw_late_minutes { get; set; }
        public int penalized_late_minutes { get; set; }
        public int early_leave_minutes { get; set; }
        public int grace_period_used { get; set; }

        // Logic: Short Time = Penalized Late + Early Leave
        public int TotalShortTime => penalized_late_minutes + early_leave_minutes;
    }
}