namespace Bestplus;

public static class AppPaths
{
    public static readonly string DataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "BESTPLUS");
    public static readonly string DbPath = Path.Combine(DataDir, "bestplus.db");
    public static readonly string BackupDir = Path.Combine(DataDir, "Backups");
    public static readonly string LogDir = Path.Combine(DataDir, "Logs");
    public static readonly string AssetDir = Path.Combine(DataDir, "Assets");

    public static void Ensure()
    {
        Directory.CreateDirectory(DataDir);
        Directory.CreateDirectory(BackupDir);
        Directory.CreateDirectory(LogDir);
        Directory.CreateDirectory(AssetDir);
    }
}
