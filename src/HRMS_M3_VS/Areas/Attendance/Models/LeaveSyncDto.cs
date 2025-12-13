namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class LeaveSyncDto
    {
        public int request_id { get; set; }
        public int employee_id { get; set; }
        public string employee_name { get; set; }
        public string leave_type { get; set; }
        public DateTime start_date { get; set; }
        public DateTime end_date { get; set; }
        public string status { get; set; }
    }
}