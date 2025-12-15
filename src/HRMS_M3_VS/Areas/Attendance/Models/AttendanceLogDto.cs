namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AttendanceLogDto
    {
        public int attendance_id { get; set; }
        public DateTime? entry_time { get; set; }
        public DateTime? exit_time { get; set; }
        public string shift_name { get; set; } = "Unknown";

        // Extra fields for logic
        public string login_method { get; set; } // Needed for badge color
        public string logout_method { get; set; }
        public int? exception_id { get; set; }

        // IMPROVED DURATION LOGIC
        public string duration
        {
            get
            {
                if (entry_time.HasValue && exit_time.HasValue)
                {
                    TimeSpan span = exit_time.Value - entry_time.Value;

                    // Round to 1 decimal place (e.g., 8.5 hours)
                    double totalHours = Math.Round(span.TotalHours, 1);

                    if (totalHours < 0) return "Error"; // Handle overnight logic if needed later

                    // Format: "8h 30m"
                    return $"{span.Hours}h {span.Minutes}m";
                }
                return "-";
            }
        }
    }
}