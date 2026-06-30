using System.Diagnostics;
using System.IO.Compression;

if(args.Length<3) return;

var zip=args[0];
var appDir=args[1];
var exe=args[2];

Thread.Sleep(2000);

var temp=Path.Combine(Path.GetTempPath(),""install_""+Guid.NewGuid().ToString(""N""));
Directory.CreateDirectory(temp);

ZipFile.ExtractToDirectory(zip,temp,true);

var payload=Path.Combine(temp,""payload"");

foreach(var file in Directory.GetFiles(payload,""*"",
SearchOption.AllDirectories))
{
    var rel=Path.GetRelativePath(payload,file);
    var dest=Path.Combine(appDir,rel);
    Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
    File.Copy(file,dest,true);
}

Process.Start(new ProcessStartInfo{
    FileName=Path.Combine(appDir,exe),
    UseShellExecute=true
});
