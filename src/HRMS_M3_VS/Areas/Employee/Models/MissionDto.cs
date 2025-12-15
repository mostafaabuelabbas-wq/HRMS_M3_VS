using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class MissionDto
    {
        public int Mission_Id { get; set; }
        public string Destination { get; set; }
        public string Description { get; set; }
        public DateTime Start_Date { get; set; }
        public DateTime End_Date { get; set; }
        public string Status { get; set; } // Pending, Approved, Rejected

        // Display Info
        public string EmployeeName { get; set; }
        public string ManagerName { get; set; }
    }
}