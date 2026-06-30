namespace MyCompanyApp.Platform.Plugin;

public interface IPlugin
{
    string Name { get; }

    void Initialize();
}
