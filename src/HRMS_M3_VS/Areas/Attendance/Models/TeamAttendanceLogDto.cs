namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class TeamAttendanceLogDto
    {
        public int attendance_id { get; set; }
        public int employee_id { get; set; }
        public string full_name { get; set; } // Matches SQL e.full_name
        public int? shift_id { get; set; }

        public DateTime? entry_time { get; set; }
        public DateTime? exit_time { get; set; }

        public int? duration { get; set; } // Matches SQL duration

        public string login_method { get; set; }
        public string logout_method { get; set; }
        public int? exception_id { get; set; }
    }
}