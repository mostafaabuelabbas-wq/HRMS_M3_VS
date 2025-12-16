using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Leave.Models
{
   
    
    

    // Existing DTOs below (keep all your existing ones)

    public class LeaveApplyDto
    {
        [Required]
        public int leave_id { get; set; }

        [Required]
        public DateTime start_date { get; set; } = DateTime.Today;

        [Required]
        public DateTime end_date { get; set; } = DateTime.Today.AddDays(1);

        [Required(ErrorMessage = "Reason is required")]
        public string justification { get; set; } = string.Empty;

        // ✅ File upload property
        public IFormFile? attachment { get; set; }
    }

    

    
    

   


  
   
}