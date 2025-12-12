using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AddToCycleDto
    {
        [Required]
        public int cycle_id { get; set; }

        [Required]
        public int shift_id { get; set; }

        [Required]
        public int order_number { get; set; }
    }
}