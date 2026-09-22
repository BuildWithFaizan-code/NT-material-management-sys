using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using MMSERP.Api.Common;
using MMSERP.Api.Middleware;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;
using MMSERP.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Load optional developer-local overrides (gitignored)
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

// ============================================================================
// 1. Secrets & Environment Validation
// ============================================================================
var dbConnectionString = DbConnectionHelper.ResolveConnectionString(builder.Configuration);

var jwtSigningKey = Environment.GetEnvironmentVariable("JWT_SIGNING_KEY")
    ?? builder.Configuration["JWT_SIGNING_KEY"];
if (string.IsNullOrWhiteSpace(jwtSigningKey))
{
    throw new InvalidOperationException(
        "FATAL STARTUP ERROR: Environment variable 'JWT_SIGNING_KEY' is missing. " +
        "A cryptographically secure secret of at least 256 bits (32 characters) must be configured.");
}

var keyBytes = Encoding.UTF8.GetBytes(jwtSigningKey);
if (keyBytes.Length < 32)
{
    throw new InvalidOperationException(
        $"FATAL STARTUP ERROR: 'JWT_SIGNING_KEY' is {keyBytes.Length * 8} bits. " +
        "HS256 requires a minimum of 256 bits (at least 32 UTF-8 characters).");
}

// ============================================================================
// 2. Controllers & JSON Options
// ============================================================================
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
    });

// ============================================================================
// 3. CORS Configuration (Explicit Allowlist + AllowCredentials)
// ============================================================================
var configuredOrigins = Environment.GetEnvironmentVariable("CORS_ALLOWED_ORIGINS");
var allowedOriginsList = new List<string>
{
    "https://nt-material-management-sys.netlify.app",
    "http://localhost:3000",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
    "http://127.0.0.1:8080"
};

if (!string.IsNullOrWhiteSpace(configuredOrigins))
{
    foreach (var origin in configuredOrigins.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
    {
        if (!allowedOriginsList.Contains(origin))
        {
            allowedOriginsList.Add(origin);
        }
    }
}

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(allowedOriginsList.ToArray())
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

// ============================================================================
// 4. IP-Based Rate Limiting for Auth Endpoints (5 attempts/minute/IP)
// ============================================================================
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("LoginRateLimit", httpContext =>
    {
        var clientIp = IpHelper.GetClientIp(httpContext);

        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: clientIp,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            });
    });

    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        context.HttpContext.Response.ContentType = "application/json";
        var response = ApiResponse<string>.Fail("Too many login attempts. Please wait a minute and try again.");
        await context.HttpContext.Response.WriteAsJsonAsync(response, cancellationToken: token);
    };
});

// ============================================================================
// 5. JWT Authentication (HS256, ClockSkew = TimeSpan.Zero)
// ============================================================================
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(keyBytes),
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero // Crucial: default 5 min skew is strictly disabled
    };
});

// ============================================================================
// 6. Global Authorization Policy & Option A Development Bypass
// ============================================================================
builder.Services.AddAuthorization(options =>
{
    // Global fallback policy: every endpoint requires authentication unless marked [AllowAnonymous]
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

// Register Option A Development Bypass ONLY in Development environment
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddSingleton<IAuthorizationHandler, AllowAnonymousInDevelopmentHandler>();
}

// ============================================================================
// 7. Dependency Injection - Repositories & Services
// ============================================================================
builder.Services.AddScoped<IAuthRepository, AuthRepository>();
builder.Services.AddScoped<IAuthService, AuthService>();

builder.Services.AddScoped<IDashboardRepository, SqlDashboardRepository>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<IProjectMasterRepository, ProjectMasterRepository>();
builder.Services.AddScoped<IProjectMasterService, ProjectMasterService>();
builder.Services.AddScoped<ILocationMasterRepository, LocationMasterRepository>();
builder.Services.AddScoped<ILocationMasterService, LocationMasterService>();
builder.Services.AddScoped<IStoreMasterRepository, StoreMasterRepository>();
builder.Services.AddScoped<IStoreMasterService, StoreMasterService>();
builder.Services.AddScoped<IOperatorMasterRepository, OperatorMasterRepository>();
builder.Services.AddScoped<IOperatorMasterService, OperatorMasterService>();
builder.Services.AddScoped<IOperationMasterRepository, OperationMasterRepository>();
builder.Services.AddScoped<IOperationMasterService, OperationMasterService>();
builder.Services.AddScoped<IDepartmentMasterRepository, DepartmentMasterRepository>();
builder.Services.AddScoped<IDepartmentMasterService, DepartmentMasterService>();
builder.Services.AddScoped<ISubDepartmentMasterRepository, SubDepartmentMasterRepository>();
builder.Services.AddScoped<ISubDepartmentMasterService, SubDepartmentMasterService>();
builder.Services.AddScoped<IHeadMasterRepository, HeadMasterRepository>();
builder.Services.AddScoped<IHeadMasterService, HeadMasterService>();
builder.Services.AddScoped<IBookMasterRepository, BookMasterRepository>();
builder.Services.AddScoped<IBookMasterService, BookMasterService>();
builder.Services.AddScoped<INonStockableItemRepository, NonStockableItemRepository>();
builder.Services.AddScoped<INonStockableItemService, NonStockableItemService>();
builder.Services.AddScoped<IChargesMasterRepository, ChargesMasterRepository>();
builder.Services.AddScoped<IChargesMasterService, ChargesMasterService>();
builder.Services.AddScoped<IFabricSizeMasterRepository, FabricSizeMasterRepository>();
builder.Services.AddScoped<IFabricSizeMasterService, FabricSizeMasterService>();
builder.Services.AddScoped<IMakersMasterRepository, MakersMasterRepository>();
builder.Services.AddScoped<IMakersMasterService, MakersMasterService>();
builder.Services.AddScoped<ICapitalConsumableMasterRepository, CapitalConsumableMasterRepository>();
builder.Services.AddScoped<ICapitalConsumableMasterService, CapitalConsumableMasterService>();
builder.Services.AddScoped<IGradeMasterRepository, GradeMasterRepository>();
builder.Services.AddScoped<IGradeMasterService, GradeMasterService>();
builder.Services.AddScoped<IMainGroupMasterRepository, MainGroupMasterRepository>();
builder.Services.AddScoped<IMainGroupMasterService, MainGroupMasterService>();
builder.Services.AddScoped<IGroupMasterRepository, GroupMasterRepository>();
builder.Services.AddScoped<IGroupMasterService, GroupMasterService>();
builder.Services.AddScoped<IGroupMasterDefinitionRepository, GroupMasterDefinitionRepository>();
builder.Services.AddScoped<IGroupMasterDefinitionService, GroupMasterDefinitionService>();

var app = builder.Build();

// ============================================================================
// 7.5 One-Time Admin Account Provisioning (CLI Flag or Environment Variable)
// ============================================================================
if (await HandleAdminProvisioningAsync(args, app.Services, app.Logger))
{
    return;
}

// ============================================================================
// 8. Production Startup Guard & Development Warning Logging
// ============================================================================
if (app.Environment.IsProduction())
{
    // Fail-fast guard: ensure bypass handler is NEVER registered in production
    var handlers = app.Services.GetServices<IAuthorizationHandler>();
    if (handlers.Any(h => h is AllowAnonymousInDevelopmentHandler))
    {
        throw new InvalidOperationException(
            "FATAL SECURITY FAILURE: AllowAnonymousInDevelopmentHandler is registered in a PRODUCTION environment! " +
            "Refusing to start.");
    }
}
else if (app.Environment.IsDevelopment())
{
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogWarning("*******************************************************************************");
    logger.LogWarning("⚠️  AUTH BYPASS ACTIVE — DEVELOPMENT ONLY — DO NOT DEPLOY THIS BUILD.  ⚠️");
    logger.LogWarning("*******************************************************************************");
}

// ============================================================================
// 9. HTTP Request Pipeline
// ============================================================================
app.UseMiddleware<ExceptionMiddleware>();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
    app.UseHsts();
}

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();

static async Task<bool> HandleAdminProvisioningAsync(string[] args, IServiceProvider services, ILogger logger)
{
    string? adminUsername = null;
    string? adminEmail = null;
    string? adminPassword = null;
    bool isCliCommand = false;

    // Check CLI argument: --provision-admin <username> <email> <password>
    for (int i = 0; i < args.Length; i++)
    {
        if (args[i] == "--provision-admin")
        {
            isCliCommand = true;
            if (i + 3 < args.Length)
            {
                adminUsername = args[i + 1];
                adminEmail = args[i + 2];
                adminPassword = args[i + 3];
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Error: --provision-admin requires 3 arguments: <username> <email> <password>");
                Console.ResetColor();
                return true; // Stop execution
            }
            break;
        }
    }

    // Check environment variable fallback
    if (string.IsNullOrWhiteSpace(adminPassword))
    {
        adminPassword = Environment.GetEnvironmentVariable("INITIAL_ADMIN_PASSWORD");
        if (!string.IsNullOrWhiteSpace(adminPassword))
        {
            adminUsername = Environment.GetEnvironmentVariable("INITIAL_ADMIN_USERNAME") ?? "admin";
            adminEmail = Environment.GetEnvironmentVariable("INITIAL_ADMIN_EMAIL") ?? "admin@newtechmms.com";
        }
    }

    if (string.IsNullOrWhiteSpace(adminPassword))
    {
        return false; // No provisioning requested, continue regular startup
    }

    // Validate password complexity
    if (adminPassword.Length < 10 || long.TryParse(adminPassword, out _))
    {
        const string errorMsg = "Provisioning error: Password must be at least 10 characters long and cannot be purely numeric.";
        if (isCliCommand)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine(errorMsg);
            Console.ResetColor();
        }
        else
        {
            logger.LogError(errorMsg);
        }
        return isCliCommand;
    }

    try
    {
        using var scope = services.CreateScope();
        var authRepo = scope.ServiceProvider.GetRequiredService<IAuthRepository>();

        var existing = await authRepo.GetUserByUsernameAsync(adminUsername!);
        if (!isCliCommand && existing != null && existing.IsActive && existing.PasswordHash != "LOCKED_PENDING_PROVISIONING")
        {
            var existsMsg = $"Admin user '{adminUsername}' already exists and is active. Skipping provisioning.";
            logger.LogInformation(existsMsg);
            return false;
        }

        var hash = BCrypt.Net.BCrypt.HashPassword(adminPassword, workFactor: 11);
        int userId;

        if (existing != null)
        {
            existing.PasswordHash = hash;
            existing.IsActive = true;
            existing.IsAdmin = true;
            existing.MustChangePassword = true;
            existing.FailedLoginCount = 0;
            existing.LockedUntil = null;
            await authRepo.UpdateUserAsync(existing);
            userId = existing.UserId;
        }
        else
        {
            var newUser = new User
            {
                Username = adminUsername!,
                Email = adminEmail ?? $"{adminUsername}@newtechmms.com",
                PasswordHash = hash,
                IsActive = true,
                IsAdmin = true,
                MustChangePassword = true,
                CreatedAt = DateTime.UtcNow
            };
            userId = await authRepo.CreateUserAsync(newUser);
        }

        await authRepo.WriteAuditLogAsync(new AuthAuditLog
        {
            UserId = userId,
            EventType = "AdminProvisioned",
            Success = true,
            Detail = $"Initial admin user '{adminUsername}' provisioned via {(isCliCommand ? "CLI command" : "environment variable")}.",
            Timestamp = DateTime.UtcNow
        });

        var successMsg = $"Admin user '{adminUsername}' successfully provisioned with MustChangePassword = true.";
        if (isCliCommand)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"✔ {successMsg}");
            Console.ResetColor();
        }
        else
        {
            logger.LogInformation(successMsg);
        }
    }
    catch (Exception ex)
    {
        var failMsg = $"Failed to provision admin: {ex.Message}";
        if (isCliCommand)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine(failMsg);
            Console.ResetColor();
        }
        else
        {
            logger.LogError(ex, failMsg);
        }
    }

    return isCliCommand;
}

