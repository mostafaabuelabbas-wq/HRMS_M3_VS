namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class EmployeeEditViewModel
    {
        public int EmployeeId { get; set; }   // Used for UpdateEmployeeInfo SP

        public string Email { get; set; }
        public string Phone { get; set; }

        public string Address { get; set; }

        public string? EmergencyContactName { get; set; }
        public string? EmergencyRelationship { get; set; }
        public string? EmergencyContactPhone { get; set; }

        // For profile images (optional)
        public IFormFile? ProfileImage { get; set; }

        // Keeps the existing image path if no new image is uploaded
        public byte[]? ExistingImageBytes { get; set; }
        public bool RemoveImage { get; set; }
    }
}
