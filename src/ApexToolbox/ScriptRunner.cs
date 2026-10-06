using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace ApexToolbox;

internal static class ScriptRunner
{
    public static async Task<ScriptResult> RunAsync(string script, IReadOnlyList<string> arguments, bool requiresAdmin)
    {
        if (!requiresAdmin || IsAdministrator())
            return await RunPowerShellAsync(script, arguments);

        var payload = Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new WorkerRequest(script, arguments))));
        var resultPath = Path.Combine(Path.GetTempPath(), $"Apex-{Guid.NewGuid():N}.json");
        var info = new ProcessStartInfo(Environment.ProcessPath!) { Verb = "runas", UseShellExecute = true };
        info.ArgumentList.Add("--run-script");
        info.ArgumentList.Add(payload);
        info.ArgumentList.Add(resultPath);
        try
        {
            using var elevated = Process.Start(info) ?? throw new InvalidOperationException("Windows did not start the elevated Apex worker.");
            await elevated.WaitForExitAsync();
            if (!File.Exists(resultPath))
                return new ScriptResult(elevated.ExitCode == 0 ? 1 : elevated.ExitCode, "", "Elevated worker returned no result; check the Apex log.");
            var result = JsonSerializer.Deserialize<ScriptResult>(await File.ReadAllTextAsync(resultPath));
            File.Delete(resultPath);
            return result ?? new ScriptResult(1, "", "Elevated worker returned invalid output.");
        }
        catch (System.ComponentModel.Win32Exception exception) when (exception.NativeErrorCode == 1223)
        {
            return new ScriptResult(1223, "", "Elevation was canceled by the user.");
        }
    }

    public static int RunElevatedWorker(string payload, string resultPath)
    {
        try
        {
            var request = JsonSerializer.Deserialize<WorkerRequest>(Encoding.UTF8.GetString(Convert.FromBase64String(payload)))
                ?? throw new InvalidDataException("Empty action request.");
            var result = RunPowerShellAsync(request.Script, request.Arguments).GetAwaiter().GetResult();
            File.WriteAllText(resultPath, JsonSerializer.Serialize(result));
            return result.ExitCode;
        }
        catch (Exception exception)
        {
            File.WriteAllText(resultPath, JsonSerializer.Serialize(new ScriptResult(1, "", exception.Message)));
            return 1;
        }
    }

    private static async Task<ScriptResult> RunPowerShellAsync(string script, IReadOnlyList<string> arguments)
    {
        var info = new ProcessStartInfo("powershell.exe") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (var value in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script }.Concat(arguments))
            info.ArgumentList.Add(value);
        using var process = Process.Start(info) ?? throw new InvalidOperationException("Windows PowerShell could not be started.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        return new ScriptResult(process.ExitCode, await stdout, await stderr);
    }

    private static bool IsAdministrator()
    {
        using var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
        return new System.Security.Principal.WindowsPrincipal(identity).IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
    }

    private sealed record WorkerRequest(string Script, IReadOnlyList<string> Arguments);
}