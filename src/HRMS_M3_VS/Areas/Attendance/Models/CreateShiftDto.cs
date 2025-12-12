namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class CreateShiftDto
    {
        public string name { get; set; } = string.Empty;
        public string type { get; set; } = string.Empty;
        public TimeSpan start_time { get; set; }
        public TimeSpan end_time { get; set; }
        public int break_duration { get; set; }
        public DateTime? shift_date { get; set; }
        public string status { get; set; } = "Active";
    }
}
