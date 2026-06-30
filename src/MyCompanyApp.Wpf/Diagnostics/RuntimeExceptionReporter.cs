using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;

namespace MyCompanyApp.Wpf.Diagnostics;

public static class RuntimeExceptionReporter
{
    private static readonly object Sync = new();

    public static string LogDirectory { get; private set; } = Path.Combine(AppContext.BaseDirectory, "logs");

    public static string LogFilePath => Path.Combine(LogDirectory, "runtime-errors.log");

    public static void Configure(string? logDirectory = null)
    {
        if (!string.IsNullOrWhiteSpace(logDirectory))
        {
            LogDirectory = logDirectory;
        }

        Directory.CreateDirectory(LogDirectory);
    }

    public static void RegisterGlobalHandlers(System.Windows.Application app)
    {
        if (app is null)
        {
            throw new ArgumentNullException(nameof(app));
        }

        app.DispatcherUnhandledException += OnDispatcherUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += OnAppDomainUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;

        WriteInfo("Runtime exception handlers registered successfully.");
    }

    private static void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        WriteException("DispatcherUnhandledException", e.Exception);

        try
        {
            MessageBox.Show(
                "یک خطای Runtime در رابط کاربری رخ داد و در فایل لاگ ذخیره شد." +
                Environment.NewLine +
                Environment.NewLine +
                e.Exception.Message +
                Environment.NewLine +
                Environment.NewLine +
                "مسیر لاگ:" +
                Environment.NewLine +
                LogFilePath,
                "MyCompanyApp - Runtime Error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
        catch
        {
            // ignored deliberately: never throw from global exception handler
        }

        e.Handled = true;
    }

    private static void OnAppDomainUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        if (e.ExceptionObject is Exception exception)
        {
            WriteException("AppDomainUnhandledException", exception);
        }
        else
        {
            WriteInfo("AppDomainUnhandledException: " + Convert.ToString(e.ExceptionObject));
        }
    }

    private static void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
    {
        WriteException("TaskScheduler.UnobservedTaskException", e.Exception);
        e.SetObserved();
    }

    public static void WriteInfo(string message)
    {
        WriteBlock("INFO", message);
    }

    public static void WriteException(string source, Exception exception)
    {
        var builder = new StringBuilder();

        builder.AppendLine("Source: " + source);
        builder.AppendLine("Exception Type: " + exception.GetType().FullName);
        builder.AppendLine("Message: " + exception.Message);
        builder.AppendLine("StackTrace:");
        builder.AppendLine(exception.StackTrace);

        var inner = exception.InnerException;
        var depth = 1;

        while (inner is not null)
        {
            builder.AppendLine();
            builder.AppendLine("Inner Exception #" + depth);
            builder.AppendLine("Type: " + inner.GetType().FullName);
            builder.AppendLine("Message: " + inner.Message);
            builder.AppendLine("StackTrace:");
            builder.AppendLine(inner.StackTrace);

            inner = inner.InnerException;
            depth++;
        }

        WriteBlock("ERROR", builder.ToString());
    }

    private static void WriteBlock(string level, string content)
    {
        try
        {
            Directory.CreateDirectory(LogDirectory);

            var block =
                "============================================================" + Environment.NewLine +
                "Timestamp: " + DateTimeOffset.Now.ToString("yyyy-MM-dd HH:mm:ss.fff zzz") + Environment.NewLine +
                "Level: " + level + Environment.NewLine +
                content + Environment.NewLine;

            lock (Sync)
            {
                File.AppendAllText(LogFilePath, block, Encoding.UTF8);
            }
        }
        catch
        {
            // ignored deliberately: logging must not crash the app
        }
    }
}

