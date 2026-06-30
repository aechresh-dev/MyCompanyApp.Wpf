$programPath = "G:\Projects\Computer\MyProjects\MyCompanyApp.Wpf\MyCompanyApp.Updater\Program.cs"

Write-Host "[INFO] Updating Program.cs ..." -ForegroundColor Cyan

$programContent = @"
using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MyCompanyApp.Updater.Models;
using MyCompanyApp.Updater.Services;

namespace MyCompanyApp.Updater
{
    internal class Program
    {
        static async Task<int> Main(string[] args)
        {
            var services = new ServiceCollection();
            ConfigureServices(services);

            var provider = services.BuildServiceProvider();

            var logger = provider.GetRequiredService<ILogger<Program>>();
            var orchestrator = provider.GetRequiredService<SafeUpdateOrchestrator>();

            try
            {
                logger.LogInformation("Enterprise Updater starting...");

                var options = new UpdateOptions
                {
                    PackagePath = args.Length > 0 ? args[0] : "update.zip",
                    TargetDirectory = AppContext.BaseDirectory,
                    BackupDirectory = Path.Combine(AppContext.BaseDirectory, "_backup"),
                    ExpectedCustomerId = "CUSTOMER_001"
                };

                var result = await orchestrator.ExecuteUpdateAsync(options);

                if (result.IsSuccess)
                {
                    logger.LogInformation("Update successful. Version: {Version}", result.NewVersion);
                    return 0;
                }

                logger.LogError("Update failed: {Error}", result.ErrorMessage);
                return 1;
            }
            catch (Exception ex)
            {
                logger.LogCritical(ex, "Fatal updater error");
                return -1;
            }
        }

        static void ConfigureServices(IServiceCollection services)
        {
            services.AddLogging(cfg =>
            {
                cfg.AddConsole();
                cfg.SetMinimumLevel(LogLevel.Information);
            });

            services.AddSingleton<MetadataReader>();
            services.AddSingleton<ZipExtractor>();
            services.AddSingleton<ChecksumVerifier>();
            services.AddSingleton<CustomerValidationService>();
            services.AddSingleton<UpdateStateStore>();
            services.AddSingleton<SafeUpdateOrchestrator>();
        }
    }
}
"@

Set-Content -Path $programPath -Value $programContent -Encoding UTF8

Write-Host "[OK] Program.cs replaced successfully." -ForegroundColor Green
