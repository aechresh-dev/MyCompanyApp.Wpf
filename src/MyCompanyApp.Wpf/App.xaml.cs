using System;
using System.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using MyCompanyApp.Wpf.Startup;
using System.Threading.Tasks;

namespace MyCompanyApp.Wpf
{
    public partial class App : System.Windows.Application
    {
        private readonly IHost _host;

        public App()
        {
            _host = Host.CreateDefaultBuilder()
                .ConfigureServices((context, services) =>
                {
                    services.AddApplicationServices();
                    services.AddWpfShellServices();
                })
                .Build();
        }

        protected override async void OnStartup(StartupEventArgs e)
        {
            // Attach global handlers
            AppDomain.CurrentDomain.UnhandledException += (s, ev) => ShowFatal(ev.ExceptionObject as Exception);
            DispatcherUnhandledException += (s, ev) => { ShowFatal(ev.Exception); ev.Handled = true; };

            base.OnStartup(e);

            try
            {
                await _host.StartAsync();

                // Explicitly Resolve and Show AppShell
                var AppShell = _host.Services.GetRequiredService<AppShell>();
                AppShell.Show();
            }
            catch (Exception ex)
            {
                ShowFatal(ex);
            }
        }

        protected override async void OnExit(ExitEventArgs e)
        {
            using (_host)
            {
                await _host.StopAsync();
            }
            base.OnExit(e);
        }

        private void ShowFatal(Exception? ex)
        {
            MessageBox.Show(ex?.ToString() ?? "Unknown Error", "Fatal Error", MessageBoxButton.OK, MessageBoxImage.Error);
            System.Windows.Application.Current.Shutdown(-1);
        }
    }
}


