using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class ShiftCycleDto
    {
        public int CycleId { get; set; } // For display/linking

        [Required]
        public string CycleName { get; set; } = string.Empty;

        public string Description { get; set; } = string.Empty;
    }
}