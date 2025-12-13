using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using HRMS_M3_VS.Services;
using HRMS_M3_VS.Models; // Ensure you have the LoginViewModel here
using Dapper;

namespace HRMS_M3_VS.Controllers
{
    public class AccountController : Controller
    {
        private readonly DbService _db;

        public AccountController(DbService db)
        {
            _db = db;
        }

        [HttpGet]
        public IActionResult Login()
        {
            if (User.Identity!.IsAuthenticated) return RedirectToAction("Index", "Dashboard");
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            // Note: We ignored ModelState.IsValid for password length to allow "anything"
            if (string.IsNullOrEmpty(model.Email)) return View(model);

            // CALL THE PROCEDURE
            // We pass whatever password the user typed, but SQL ignores it.
            var user = (await _db.QueryAsync<dynamic>("UserLogin", new
            {
                Email = model.Email,
                Password = model.Password ?? "dummy"
            })).FirstOrDefault();

            if (user == null)
            {
                TempData["Error"] = "Email not found in system.";
                return View(model);
            }

            // CREATE SESSION
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, ((int)user.employee_id).ToString()),
                new Claim(ClaimTypes.Name, (string)user.full_name),
                new Claim(ClaimTypes.Role, (string)user.role_name ?? "Employee")
            };

            var claimsIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(claimsIdentity));

            return RedirectToAction("Index", "Dashboard"); // Or Home/Index
        }

        
        // GET: /Account/Logout
        public async Task<IActionResult> Logout()
        {
            // 1. Delete the Cookie
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            // 2. Redirect to Login Page
            return RedirectToAction("Login", "Account");
        }
    }
}