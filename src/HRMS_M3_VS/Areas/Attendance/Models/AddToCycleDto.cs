using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AddToCycleDto
    {
        [Required]
        public int CycleId { get; set; }

        [Required]
        public int ShiftId { get; set; }

        [Required]
        public int OrderNumber { get; set; }
    }
}