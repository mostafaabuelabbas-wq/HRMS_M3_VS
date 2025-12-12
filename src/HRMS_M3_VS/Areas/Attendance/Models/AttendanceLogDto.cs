namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AttendanceLogDto
    {
        public int attendance_id { get; set; }
        public DateTime? entry_time { get; set; }
        public DateTime? exit_time { get; set; }
        public string shift_name { get; set; } = "Unknown";

        // Helper to show duration
        public string duration
        {
            get
            {
                if (entry_time.HasValue && exit_time.HasValue)
                {
                    var span = exit_time.Value - entry_time.Value;
                    return $"{span.Hours}h {span.Minutes}m";
                }
                return "-";
            }
        }
    }
}