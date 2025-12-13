using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class OfflineSyncDto
    {
        [Required]
        public int employee_id { get; set; }

        [Required]
        public int device_id { get; set; }

        [Required]
        public DateTime clock_time { get; set; } = DateTime.Now;

        [Required]
        public string type { get; set; } = "IN"; // 'IN' or 'OUT'
    }
}