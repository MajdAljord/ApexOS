using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Win32;

namespace ApexToolbox;

internal sealed class MainForm : Form
{
    private static readonly string[] Categories = ["Performance", "Gaming", "RAM Saver", "Power", "Drivers", "Network", "Windows", "Explorer", "Security", "Repair", "Diagnostics", "Privacy", "Personalization", "Advanced", "Backup & Restore"];
    private readonly string _root = AppContext.BaseDirectory;
    private readonly FlowLayoutPanel _actions = new();
    private readonly Label _heading = new();
    private readonly Label _footer = new();
    private ToolboxConfiguration _config = new();
    private string _category = "Performance";
    private readonly bool _isWindows = OperatingSystem.IsWindows();
    private readonly WindowsDetails _windows = ReadWindowsDetails();

    public MainForm()
    {
        Text = "Apex Toolbox";
        Size = new Size(1100, 740);
        MinimumSize = new Size(850, 560);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(19, 23, 28);
        ForeColor = Color.FromArgb(235, 239, 242);
        Font = new Font("Segoe UI", 9.5F);
        var shell = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
        shell.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 215));
        shell.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        Controls.Add(shell);
        var sidebar = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(25, 30, 36), Padding = new Padding(14) };
        shell.Controls.Add(sidebar, 0, 0);
        sidebar.Controls.Add(new Label { Text = "APEX\nTOOLBOX", Dock = DockStyle.Top, Height = 78, Font = new Font("Segoe UI Semibold", 16), ForeColor = Color.FromArgb(116, 219, 186) });
        var setupButton = new Button { Text = "Welcome setup", Dock = DockStyle.Top, Height = 36, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(49, 59, 66), ForeColor = Color.White };
        setupButton.FlatAppearance.BorderSize = 0;
        setupButton.Enabled = _windows.IsWindows11;
        setupButton.Click += async (_, _) => await ShowFirstRunSetupAsync();
        sidebar.Controls.Add(setupButton);
        var nav = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, Padding = new Padding(0, 8, 0, 0) };
        sidebar.Controls.Add(nav);
        foreach (var category in Categories)
        {
            var button = new Button { Text = category, Width = 180, Height = 34, TextAlign = ContentAlignment.MiddleLeft, FlatStyle = FlatStyle.Flat, BackColor = sidebar.BackColor, ForeColor = ForeColor, Padding = new Padding(8, 0, 0, 0), Tag = category, Margin = new Padding(0, 2, 0, 2) };
            button.FlatAppearance.BorderSize = 0;
            button.Click += (_, _) => _ = ShowCategoryAsync(category);
            nav.Controls.Add(button);
        }
        var body = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, Padding = new Padding(26, 22, 26, 12) };
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 56));
        body.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        shell.Controls.Add(body, 1, 0);
        _heading.Dock = DockStyle.Fill;
        _heading.Font = new Font("Segoe UI Semibold", 20);
        body.Controls.Add(_heading, 0, 0);
        _actions.Dock = DockStyle.Fill;
        _actions.FlowDirection = FlowDirection.TopDown;
        _actions.WrapContents = false;
        _actions.AutoScroll = true;
        body.Controls.Add(_actions, 0, 1);
        _footer.Dock = DockStyle.Fill;
        _footer.TextAlign = ContentAlignment.MiddleLeft;
        _footer.ForeColor = Color.FromArgb(150, 163, 171);
        body.Controls.Add(_footer, 0, 2);
        LoadConfig();
        UpdateFooter();
        Shown += async (_, _) =>
        {
            if (!_isWindows)
            {
                MessageBox.Show(this, "Apex Toolbox system actions are available only on Windows 11.", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            var message = _windows.IsWindows11
                ? $"Apex has not been validated on Windows build {_windows.Build} ({_windows.DisplayVersion}, {RuntimeInformation.OSArchitecture}). Test system changes in a disposable VM first. Continue?"
                : $"This Windows version is not supported by Apex. Detected: {_windows.Product}, build {_windows.Build}. No settings should be changed. Continue to view diagnostics only?";
            var choice = MessageBox.Show(this, message, "Apex compatibility notice", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (choice != DialogResult.Yes) { Close(); return; }
            if (_windows.IsWindows11 && !HasCompletedFirstRun()) await ShowFirstRunSetupAsync();
            await ShowCategoryAsync(_category);
        };
    }

    private string FirstRunMarkerPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ApexOS", "setup-completed.json");

    private bool HasCompletedFirstRun() => File.Exists(FirstRunMarkerPath);

    private void MarkFirstRunComplete()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FirstRunMarkerPath)!);
        File.WriteAllText(FirstRunMarkerPath, DateTimeOffset.Now.ToString("O"));
    }

    private async Task ShowFirstRunSetupAsync()
    {
        if (!_isWindows) return;
        using var dialog = new FirstRunForm(_root);
        var result = dialog.ShowDialog(this);
        MarkFirstRunComplete();
        if (result != DialogResult.OK) return;

        var selection = dialog.Selection;
        var tasks = new List<(ToolboxAction Action, IReadOnlyList<string> Arguments)>();
        void AddAction(string id, IReadOnlyList<string>? arguments = null)
        {
            var action = _config.Actions.FirstOrDefault(item => item.Id == id);
            if (action is not null) tasks.Add((action, arguments ?? action.ApplyArgs));
        }

        if (selection.CreateRestorePoint) AddAction("restore-point");
        var powerId = selection.PowerPlan switch
        {
            "Apex Balanced" => "power-balanced",
            "Apex Performance" => "power-performance",
            "Apex Ultimate Performance" => "power-ultimate",
            "Apex Power Saver" => "power-saver",
            "Apex Laptop Performance" => "power-laptop",
            _ => null
        };
        if (powerId is not null) AddAction(powerId);
        if (selection.Theme == "Dark") AddAction("theme-dark");
        if (selection.Theme == "Light") AddAction("theme-light");
        if (selection.RamMode == "BALANCED") AddAction("ram-saver-balanced");
        if (selection.RamMode == "AGGRESSIVE") AddAction("ram-saver-aggressive");
        if (selection.RamMode == "OFF / restore saved baseline")
        {
            var ram = _config.Actions.FirstOrDefault(item => item.Id == "ram-saver-balanced");
            if (ram is not null) AddAction(ram.Id, ram.RestoreArgs);
        }
        if (selection.ExplorerMenu == "Classic Windows context menu") AddAction("explorer-context");
        if (selection.ExplorerMenu == "Windows 11 context menu") AddAction("explorer-context-windows11");
        var wallpaperId = selection.Wallpaper switch
        {
            "Apex-Dark.png" => "wallpaper-dark",
            "Apex-Light.png" => "wallpaper-light",
            "Apex-Gaming.png" => "wallpaper-gaming",
            "Apex-Desktop.png" => "wallpaper-desktop",
            _ => null
        };
        if (wallpaperId is not null) AddAction(wallpaperId);
        if (selection.EnableGaming) AddAction("gaming-mode");
        if (selection.SetChromeDefault) AddAction("chrome-default");
        if (selection.ConfigureNanaZip) AddAction("nanazip-configure");

        if (tasks.Count == 0)
        {
            MessageBox.Show(this, "No settings were selected. You can open Welcome setup again from the sidebar.", "Apex first-run setup", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        _actions.Controls.Clear();
        _heading.Text = "Applying setup selections";
        var progress = new ProgressBar { Width = Math.Max(420, _actions.ClientSize.Width - 40), Height = 20, Style = ProgressBarStyle.Continuous, Maximum = tasks.Count, Value = 0 };
        var status = new Label { AutoSize = true, ForeColor = Color.FromArgb(190, 199, 205), Margin = new Padding(0, 8, 0, 10) };
        _actions.Controls.Add(status);
        _actions.Controls.Add(progress);
        var completed = 0;
        foreach (var task in tasks)
        {
            status.Text = $"Running {task.Action.Title} ({completed + 1} of {tasks.Count})...";
            var outcome = await ScriptRunner.RunAsync(ResolveScript(task.Action.Script), task.Arguments, task.Action.RequiresAdmin);
            var logPath = WriteLog($"First run | {task.Action.Title} | {task.Action.Script}", outcome.ExitCode, outcome.StandardError);
            if (outcome.ExitCode != 0)
            {
                status.Text = $"Setup stopped at {task.Action.Title}.";
                MessageBox.Show(this, $"Failed (exit code {outcome.ExitCode}).\n{outcome.StandardError.Trim()}\n{outcome.StandardOutput.Trim()}\n\nLog: {logPath}", "Apex first-run setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                await ShowCategoryAsync(_category);
                return;
            }
            completed++;
            progress.Value = completed;
            await Task.Yield();
        }
        MessageBox.Show(this, $"Completed {completed} selected setup actions. Review each action's output and log before continuing.", "Apex first-run setup", MessageBoxButtons.OK, MessageBoxIcon.Information);
        await ShowCategoryAsync(_category);
    }

    private void LoadConfig()
    {
        var path = Path.Combine(_root, "Toolbox", "config", "toolbox.json");
        try
        {
            _config = JsonSerializer.Deserialize<ToolboxConfiguration>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new ToolboxConfiguration();
        }
        catch (Exception exception)
        {
            MessageBox.Show(this, $"Cannot load Toolbox configuration: {exception.Message}", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private async Task ShowCategoryAsync(string category)
    {
        _category = category;
        _heading.Text = category;
        _actions.Controls.Clear();
        if (!_isWindows)
        {
            _actions.Controls.Add(new Label { Text = "Windows-only functionality unavailable on this operating system.", AutoSize = true, ForeColor = Color.FromArgb(240, 179, 120), Margin = new Padding(0, 12, 0, 0) });
            return;
        }
        var actions = _config.Actions.Where(action => action.Category == category).ToList();
        if (actions.Count == 0)
        {
            var text = category == "Advanced"
                ? "These settings can affect Windows compatibility. Only change them if you understand what they do.\n\nNot implemented yet"
                : "Not implemented yet";
            _actions.Controls.Add(new Label { Text = text, AutoSize = true, MaximumSize = new Size(Math.Max(400, _actions.ClientSize.Width - 40), 0), ForeColor = Color.FromArgb(150, 163, 171), Font = new Font("Segoe UI", 11), Margin = new Padding(0, 12, 0, 0) });
            return;
        }
        foreach (var action in actions)
        {
            var card = CreateCard(action);
            _actions.Controls.Add(card);
            await RefreshStatusAsync(action, card);
        }
    }

    private Control CreateCard(ToolboxAction action)
    {
        var card = new Panel { Width = Math.Max(480, _actions.ClientSize.Width - 34), Height = 142, BackColor = Color.FromArgb(29, 35, 41), Margin = new Padding(0, 0, 0, 12), Padding = new Padding(16) };
        card.Controls.Add(new Label { Text = action.Title, Dock = DockStyle.Top, Height = 30, Font = new Font("Segoe UI Semibold", 12) });
        card.Controls.Add(new Label { Text = action.Description, Dock = DockStyle.Top, Height = 48, ForeColor = Color.FromArgb(174, 184, 191) });
        var lower = new Panel { Dock = DockStyle.Bottom, Height = 38 };
        lower.Controls.Add(new Label { Name = "status", Text = "Status: checking...", Dock = DockStyle.Left, Width = 230, ForeColor = Color.FromArgb(116, 219, 186), TextAlign = ContentAlignment.MiddleLeft });
        var buttons = new FlowLayoutPanel { Dock = DockStyle.Right, Width = 220, FlowDirection = FlowDirection.RightToLeft, WrapContents = false };
        var progress = new ProgressBar { Name = "progress", Width = 84, Height = 20, Style = ProgressBarStyle.Marquee, Visible = false, MarqueeAnimationSpeed = 25, Margin = new Padding(6, 5, 0, 0) };
        buttons.Controls.Add(progress);
        var apply = ButtonFor(string.IsNullOrWhiteSpace(action.ApplyText) ? "Apply" : action.ApplyText, true);
        apply.Enabled = _windows.IsWindows11 || action.ReadOnly;
        apply.Click += async (_, _) => await RunActionAsync(action, action.ApplyArgs, card);
        buttons.Controls.Add(apply);
        if (action.RestoreArgs.Count > 0)
        {
            var restore = ButtonFor("Restore", false);
                        restore.Enabled = _windows.IsWindows11;
            restore.Click += async (_, _) => await RunActionAsync(action, action.RestoreArgs, card);
            buttons.Controls.Add(restore);
        }
        lower.Controls.Add(buttons);
        card.Controls.Add(lower);
        return card;
    }

    private static Button ButtonFor(string text, bool primary)
    {
        var button = new Button { Text = text, Width = 88, Height = 31, FlatStyle = FlatStyle.Flat, BackColor = primary ? Color.FromArgb(116, 219, 186) : Color.FromArgb(49, 59, 66), ForeColor = primary ? Color.FromArgb(18, 30, 27) : Color.White, Margin = new Padding(8, 0, 0, 0) };
        button.FlatAppearance.BorderSize = 0;
        return button;
    }

    private async Task RefreshStatusAsync(ToolboxAction action, Control card)
    {
        var label = card.Controls.Find("status", true).FirstOrDefault() as Label;
        if (label is null) return;
        try
        {
            var result = await ScriptRunner.RunAsync(ResolveScript(action.Script), action.StatusArgs, false);
            var state = result.StandardOutput.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries).LastOrDefault()?.Trim() ?? "Unknown";
            label.Text = result.ExitCode == 0 ? $"Status: {state}" : $"Status: unavailable (exit {result.ExitCode})";
            label.ForeColor = result.ExitCode == 0 ? Color.FromArgb(116, 219, 186) : Color.FromArgb(240, 147, 126);
        }
        catch { label.Text = "Status: unavailable"; label.ForeColor = Color.FromArgb(240, 147, 126); }
    }

    private async Task RunActionAsync(ToolboxAction action, IReadOnlyList<string> arguments, Control card)
    {
        if (!_windows.IsWindows11 && !action.ReadOnly)
        {
            MessageBox.Show(this, "System-changing actions are disabled on this unsupported Windows version.", "Apex compatibility notice", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        if (action.RequiresConfirmation && ReferenceEquals(arguments, action.ApplyArgs))
        {
            var choice = MessageBox.Show(this, $"{action.Description}\n\nContinue?", action.Title, MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (choice != DialogResult.Yes) return;
        }
        if (action.OfferRestorePoint && ReferenceEquals(arguments, action.ApplyArgs))
        {
            var choice = MessageBox.Show(this, "Create a Windows restore point before this change? Choose No to continue without one, or Cancel to stop.", action.Title, MessageBoxButtons.YesNoCancel, MessageBoxIcon.Warning);
            if (choice == DialogResult.Cancel) return;
            if (choice == DialogResult.Yes)
            {
                var restoreAction = _config.Actions.FirstOrDefault(item => item.Id == "restore-point");
                if (restoreAction is null) { MessageBox.Show(this, "Restore-point action is not configured; the requested change was not started.", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error); return; }
                card.Enabled = false;
                SetActionProgress(card, true);
                var restoreResult = await ScriptRunner.RunAsync(ResolveScript(restoreAction.Script), restoreAction.ApplyArgs, restoreAction.RequiresAdmin);
                var restoreLog = WriteLog($"Pre-change restore point | {restoreAction.Script}", restoreResult.ExitCode, restoreResult.StandardError);
                card.Enabled = true;
                SetActionProgress(card, false);
                if (restoreResult.ExitCode != 0)
                {
                    MessageBox.Show(this, $"Restore point creation failed (exit code {restoreResult.ExitCode}); the requested change was not started.\n{restoreResult.StandardError.Trim()}\nLog: {restoreLog}", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
            }
        }
        card.Enabled = false;
        SetActionProgress(card, true);
        try
        {
            var result = await ScriptRunner.RunAsync(ResolveScript(action.Script), arguments, action.RequiresAdmin);
            var logPath = WriteLog($"{action.Title} | {action.Script}", result.ExitCode, result.StandardError);
            var text = result.ExitCode == 0
                ? $"Completed successfully.\n\n{result.StandardOutput.Trim()}"
                : $"Failed (exit code {result.ExitCode}).\n{result.StandardError.Trim()}\n{result.StandardOutput.Trim()}\n\nLog: {logPath}";
            MessageBox.Show(this, text, "Apex Toolbox", MessageBoxButtons.OK, result.ExitCode == 0 ? MessageBoxIcon.Information : MessageBoxIcon.Error);
            await ShowCategoryAsync(_category);
        }
        catch (Exception exception)
        {
            var logPath = WriteLog($"{action.Title} | {action.Script}", 1, exception.ToString());
            MessageBox.Show(this, $"Failed (exit code 1). {exception.Message}\nLog: {logPath}", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally { card.Enabled = true; }
        SetActionProgress(card, false);
    }

    private static void SetActionProgress(Control card, bool running)
    {
        var label = card.Controls.Find("status", true).FirstOrDefault() as Label;
        if (label is not null && running)
        {
            label.Text = "Running...";
            label.ForeColor = Color.FromArgb(240, 179, 120);
        }
        var progress = card.Controls.Find("progress", true).FirstOrDefault() as ProgressBar;
        if (progress is not null) progress.Visible = running;
    }

    private string ResolveScript(string relative)
    {
        var path = Path.GetFullPath(Path.Combine(_root, relative.Replace('/', Path.DirectorySeparatorChar)));
        var rootPrefix = Path.GetFullPath(_root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (!path.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase) || !File.Exists(path))
            throw new FileNotFoundException("Configured script is missing or outside the Apex directory.", path);
        return path;
    }

    private string WriteLog(string action, int exitCode, string detail)
    {
        var line = $"{DateTimeOffset.Now:O} | {action} | {(exitCode == 0 ? "Success" : "Failed")} | exit={exitCode} | {detail}{Environment.NewLine}";
        var path = Path.Combine(_root, "Logs", "Toolbox.log");
        try
        {
            var directory = Path.GetDirectoryName(path)!;
            Directory.CreateDirectory(directory);
            File.AppendAllText(path, line);
            return path;
        }
        catch
        {
            path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ApexOS", "Logs", "Toolbox.log");
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.AppendAllText(path, line);
            return path;
        }
    }

    private void UpdateFooter()
    {
        _footer.Text = _isWindows
            ? $"Apex OS    |    {_windows.Product} {_windows.DisplayVersion} (build {_windows.Build}, {RuntimeInformation.OSArchitecture})    |    Power plan: checking..."
            : "Apex OS    |    Windows-only actions unavailable";
        if (!_isWindows || !_windows.IsWindows11) return;
        try
        {
            var info = new ProcessStartInfo("powercfg.exe", "/getactivescheme") { UseShellExecute = false, RedirectStandardOutput = true, CreateNoWindow = true };
            using var process = Process.Start(info);
            if (process is null) return;
            var output = process.StandardOutput.ReadToEnd().Trim();
            process.WaitForExit();
            var plan = output.Split('(', ')').ElementAtOrDefault(1) ?? "Unknown";
            _footer.Text = $"Apex OS    |    {_windows.Product} {_windows.DisplayVersion} (build {_windows.Build}, {RuntimeInformation.OSArchitecture})    |    Power plan: {plan}";
        }
        catch { _footer.Text = $"Apex OS    |    {_windows.Product} {_windows.DisplayVersion} (build {_windows.Build}, {RuntimeInformation.OSArchitecture})    |    Power plan: unavailable"; }
    }

    private static WindowsDetails ReadWindowsDetails()
    {
        if (!OperatingSystem.IsWindows())
            return new WindowsDetails("Non-Windows", Environment.OSVersion.Version.Build, "unsupported", false);
        using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
        var product = key?.GetValue("ProductName") as string ?? "Windows";
        var release = key?.GetValue("DisplayVersion") as string ?? "unknown release";
        var buildValue = key?.GetValue("CurrentBuildNumber") as string;
        var build = int.TryParse(buildValue, out var parsed) ? parsed : Environment.OSVersion.Version.Build;
        var isWindows11 = Environment.OSVersion.Version.Major >= 10 && build >= 22000 && !product.Contains("Server", StringComparison.OrdinalIgnoreCase);
        return new WindowsDetails(product, build, release, isWindows11);
    }

    private sealed record WindowsDetails(string Product, int Build, string DisplayVersion, bool IsWindows11);
}