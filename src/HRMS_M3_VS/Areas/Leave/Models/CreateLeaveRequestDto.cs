using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class CreateLeaveRequestDto
    {
        [Required(ErrorMessage = "Please select a leave type.")]
        [Display(Name = "Leave Type")]
        public int LeaveTypeId { get; set; }

        [Required(ErrorMessage = "Start Date is required.")]
        [DataType(DataType.Date)]
        [Display(Name = "Start Date")]
        public DateTime StartDate { get; set; } = DateTime.Today;

        [Required(ErrorMessage = "End Date is required.")]
        [DataType(DataType.Date)]
        [Display(Name = "End Date")]
        public DateTime EndDate { get; set; } = DateTime.Today;

        [Required(ErrorMessage = "Please provide a reason.")]
        [StringLength(200, ErrorMessage = "Reason cannot exceed 200 characters.")]
        public string Justification { get; set; } = string.Empty;

        [Display(Name = "Attachment (Optional)")]
        public IFormFile? Attachment { get; set; }
    }
}