using System;
using System.Diagnostics;
using System.IO;

namespace MyCompanyApp.Wpf
{
    public static class UpdateHelper
    {
        public static void UpdateFromFile()
        {
            var openFileDialog = new Microsoft.Win32.OpenFileDialog
            {
                Filter = "Update Packages (*.zip)|*.zip",
                Title = "انتخاب فایل بروزرسانی"
            };

            bool? result = openFileDialog.ShowDialog();

            if (result == true)
            {
                string updaterPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "MyCompanyApp.Updater.exe");

                if (!File.Exists(updaterPath))
                {
                    System.Windows.MessageBox.Show(
                        "فایل MyCompanyApp.Updater.exe پیدا نشد.",
                        "خطا",
                        System.Windows.MessageBoxButton.OK,
                        System.Windows.MessageBoxImage.Error);
                    return;
                }

                var startInfo = new ProcessStartInfo
                {
                    FileName = updaterPath,
                    Arguments = "\"" + openFileDialog.FileName + "\"",
                    UseShellExecute = true,
                    Verb = "runas"
                };

                Process.Start(startInfo);

                System.Windows.Application.Current.Shutdown();
            }
        }
    }
}
