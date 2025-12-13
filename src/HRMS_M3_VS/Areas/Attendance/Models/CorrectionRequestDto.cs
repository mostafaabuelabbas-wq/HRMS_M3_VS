using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class CorrectionRequestDto
    {
        [Required]
        public int employee_id { get; set; }

        [Required]
        public DateTime date { get; set; } = DateTime.Today; // Matches @Date

        [Required]
        public string correction_type { get; set; } = "Missed Check-In"; // Matches @CorrectionType

        [Required]
        [StringLength(200)]
        public string reason { get; set; } = string.Empty; // Matches @Reason
    }
}