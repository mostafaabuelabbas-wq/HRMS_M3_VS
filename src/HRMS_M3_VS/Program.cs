using HRMS_M3_VS.Areas.Attendance.Services;
using HRMS_M3_VS.Areas.Employee.Services;
using HRMS_M3_VS.Services;
using Microsoft.Data.SqlClient;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);

// Add MVC support
builder.Services.AddControllersWithViews();

// Register database + application services
builder.Services.AddScoped<DbService>();
builder.Services.AddScoped<EmployeeService>();
builder.Services.AddScoped<RoleService>();
builder.Services.AddScoped<ContractService>();
builder.Services.AddScoped<ShiftService>();
builder.Services.AddScoped<TrackingService>();
// Optional: Test DB connection on startup
try
{
    using var conn = new SqlConnection(builder.Configuration.GetConnectionString("HRMS"));
    conn.Open();
    Console.WriteLine("DATABASE CONNECTION SUCCESSFUL ✔");
}
catch (Exception ex)
{
    Console.WriteLine("DATABASE CONNECTION FAILED ❌");
    Console.WriteLine(ex.Message);
}

var app = builder.Build();

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();


// -----------------------------------------------------------
// TEMPORARY MOCK LOGIN - MUST BE BEFORE UseAuthorization()
// -----------------------------------------------------------
app.Use(async (context, next) =>
{
    context.User = new ClaimsPrincipal(
        new ClaimsIdentity(new[]
        {
             new Claim(ClaimTypes.Name, "Dev SuperUser"),
            
            // Grant ALL roles for development
            new Claim(ClaimTypes.Role, "SystemAdmin"),
            new Claim(ClaimTypes.Role, "HRAdmin"),
            new Claim(ClaimTypes.Role, "Manager"),
            new Claim(ClaimTypes.Role, "Employee")
        }, "mock"));

    await next.Invoke();
});

// Authorization checks happen AFTER the mock user
app.UseAuthorization();


// -----------------------------------------------------------
// AREA ROUTE (must come BEFORE default route)
// -----------------------------------------------------------
app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");


// -----------------------------------------------------------
// DEFAULT ROUTE
// -----------------------------------------------------------
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
