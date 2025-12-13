using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Models
{
    public class LoginViewModel
    {
        [Required(ErrorMessage = "Please enter your email.")]
        [EmailAddress(ErrorMessage = "Invalid email format.")]
        public string Email { get; set; }

        // We make it required so the user types *something*, 
        // even though our logic ignores what it is.
        [Required(ErrorMessage = "Enter any password.")]
        [DataType(DataType.Password)]
        public string Password { get; set; }
    }
}