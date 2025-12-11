using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Controllers
{
    public class DashboardController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}
