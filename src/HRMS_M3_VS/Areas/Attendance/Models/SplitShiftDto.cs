using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class SplitShiftDto
    {
        [Required]
        public string Name { get; set; } = string.Empty;

        // Slot 1
        [Required]
        public TimeSpan FirstSlotStart { get; set; }
        [Required]
        public TimeSpan FirstSlotEnd { get; set; }

        // Slot 2
        [Required]
        public TimeSpan SecondSlotStart { get; set; }
        [Required]
        public TimeSpan SecondSlotEnd { get; set; }
    }
}