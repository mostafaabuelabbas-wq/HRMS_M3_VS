using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class CreateLeaveRequestDto
    {
        [Required]
        [Display(Name = "Leave Type")]
        public int LeaveTypeId { get; set; }

        [Required]
        [DataType(DataType.Date)]
        [Display(Name = "Start Date")]
        public DateTime StartDate { get; set; } = DateTime.Today;

        [Required]
        [DataType(DataType.Date)]
        [Display(Name = "End Date")]
        public DateTime EndDate { get; set; } = DateTime.Today;

        [Required]
        [StringLength(200, ErrorMessage = "Justification cannot be longer than 200 characters.")]
        public string Justification { get; set; } = string.Empty;

        [Display(Name = "Attachment (Optional)")]
        public IFormFile? Attachment { get; set; }
    }
}