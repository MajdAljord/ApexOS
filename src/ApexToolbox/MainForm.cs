using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Win32;

namespace ApexToolbox;

internal sealed class MainForm : Form
{
    private static readonly (string Label, string Category, string Glyph)[] Sections =
    [
        ("Home", "HOME", "\uE80F"),
        ("General Configuration", "Performance", "\uE713"),
        ("Windows Settings", "Windows", "\uE774"),
        ("Security", "Security", "\uE72E"),
        ("Troubleshooting", "Repair", "\uE90F"),
        ("Performance", "Performance", "\uE945"),
        ("Gaming", "Gaming", "\uE7FC"),
        ("RAM Saver", "RAM Saver", "\uE950"),
        ("Power", "Power", "\uE7E8"),
        ("Drivers", "Drivers", "\uE839"),
        ("Network", "Network", "\uE774"),
        ("Interface Tweaks", "Personalization", "\uE790"),
        ("Explorer", "Explorer", "\uE8B7"),
        ("Privacy", "Privacy", "\uE72E"),
        ("Software", "Software", "\uE71D"),
        ("Storage", "Storage", "\uE7C3"),
        ("Startup", "Startup", "\uE777"),
        ("Diagnostics", "Diagnostics", "\uE9D9"),
        ("Advanced Configuration", "Advanced", "\uE713"),
        ("Backup & Restore", "Backup & Restore", "\uE8F1"),
        ("About", "About", "\uE946")
    ];
    private readonly string _root = AppContext.BaseDirectory;
    private readonly FlowLayoutPanel _actions = new();
    private readonly Label _heading = new();
    private readonly Label _footer = new();
    private readonly Panel _sidebar = new();
    private readonly PictureBox _brandIcon = new();
    private readonly TextBox _searchBox = new();
    private readonly ContextMenuStrip _searchResults = new();
    private readonly Dictionary<string, Panel> _navigationButtons = new(StringComparer.OrdinalIgnoreCase);
    private ToolboxConfiguration _config = new();
    private string _category = "HOME";
    private readonly bool _isWindows = OperatingSystem.IsWindows();
    private readonly WindowsDetails _windows = ReadWindowsDetails();
    private bool _lightTheme;
    private JsonElement? _homeSnapshot;

    private Color PageColor => _lightTheme ? Color.FromArgb(242, 245, 247) : Color.FromArgb(18, 22, 27);
    private Color SurfaceColor => _lightTheme ? Color.White : Color.FromArgb(27, 33, 40);
    private Color SidebarColor => _lightTheme ? Color.FromArgb(232, 237, 240) : Color.FromArgb(23, 28, 34);
    private Color TextColor => _lightTheme ? Color.FromArgb(31, 39, 45) : Color.FromArgb(235, 239, 242);
    private Color MutedColor => _lightTheme ? Color.FromArgb(92, 105, 114) : Color.FromArgb(155, 168, 177);
    private Color AccentColor => Color.FromArgb(76, 190, 155);

    public MainForm()
    {
        Text = "Apex Toolbox";
        Size = new Size(1240, 820);
        MinimumSize = new Size(960, 640);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = PageColor;
        ForeColor = TextColor;
        Font = new Font("Segoe UI Variable Text", 9.5F);
        var iconPath = Path.Combine(_root, "Assets", "ApexToolboxApplication.ico");
        if (File.Exists(iconPath)) Icon = new Icon(iconPath);
        _lightTheme = ReadThemePreference();
        BackColor = PageColor;
        ForeColor = TextColor;
        var shell = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
        shell.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 236));
        shell.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        Controls.Add(shell);
        _sidebar.Dock = DockStyle.Fill;
        _sidebar.BackColor = SidebarColor;
        _sidebar.Padding = new Padding(14, 18, 12, 12);
        var sidebar = _sidebar;
        shell.Controls.Add(sidebar, 0, 0);
        var brand = new Panel { Dock = DockStyle.Top, Height = 70, BackColor = SidebarColor, Padding = new Padding(0, 0, 0, 10) };
        _brandIcon.Dock = DockStyle.Left;
        _brandIcon.Size = new Size(46, 46);
        _brandIcon.SizeMode = PictureBoxSizeMode.Zoom;
        brand.Controls.Add(_brandIcon);
        brand.Controls.Add(new Label { Text = "APEX\nTOOLBOX", Dock = DockStyle.Left, Width = 124, Font = new Font("Segoe UI Semibold", 12F), ForeColor = AccentColor, TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(10, 0, 0, 0) });
        sidebar.Controls.Add(brand);
        var setupButton = new Button { Text = "Welcome setup", Dock = DockStyle.Top, Height = 34, FlatStyle = FlatStyle.Flat, BackColor = SurfaceColor, ForeColor = TextColor };
        setupButton.FlatAppearance.BorderColor = _lightTheme ? Color.FromArgb(220, 226, 230) : Color.FromArgb(48, 57, 65);
        setupButton.FlatAppearance.BorderSize = 1;
        setupButton.Enabled = _windows.IsWindows11;
        setupButton.Click += async (_, _) => await ShowFirstRunSetupAsync();
        sidebar.Controls.Add(setupButton);
        var nav = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, Padding = new Padding(0, 10, 2, 0), BackColor = SidebarColor };
        sidebar.Controls.Add(nav);
        foreach (var section in Sections)
        {
            var item = new Panel { Width = 196, Height = 34, BackColor = SidebarColor, Tag = section.Category, Margin = new Padding(0, 1, 0, 1), Cursor = Cursors.Hand };
            var glyph = new Label { Text = section.Glyph, Dock = DockStyle.Left, Width = 31, TextAlign = ContentAlignment.MiddleCenter, ForeColor = MutedColor, Font = new Font("Segoe MDL2 Assets", 12F), BackColor = Color.Transparent };
            var label = new Label { Text = section.Label, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, ForeColor = MutedColor, Font = new Font("Segoe UI", 9F), BackColor = Color.Transparent, AutoEllipsis = true };
            async void Navigate(object? _, EventArgs __) => await NavigateAsync(section.Category);
            item.Click += Navigate;
            glyph.Click += Navigate;
            label.Click += Navigate;
            item.Controls.Add(label);
            item.Controls.Add(glyph);
            nav.Controls.Add(item);
            _navigationButtons[section.Category] = item;
        }
        var body = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, Padding = new Padding(26, 22, 26, 12) };
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 56));
        body.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        shell.Controls.Add(body, 1, 0);
        var toolbar = new Panel { Dock = DockStyle.Fill, BackColor = PageColor };
        _heading.Dock = DockStyle.Left;
        _heading.Width = 390;
        _heading.Font = new Font("Segoe UI Variable Display", 21F, FontStyle.Bold);
        _heading.ForeColor = TextColor;
        _heading.TextAlign = ContentAlignment.MiddleLeft;
        toolbar.Controls.Add(_heading);
        var themeButton = new Button { Name = "theme-button", Text = _lightTheme ? "\uE708  Light" : "\uE708  Dark", Dock = DockStyle.Right, Width = 96, FlatStyle = FlatStyle.Flat, BackColor = SurfaceColor, ForeColor = TextColor, Font = new Font("Segoe MDL2 Assets", 9F), UseCompatibleTextRendering = true };
        themeButton.FlatAppearance.BorderSize = 0;
        themeButton.Click += (_, _) => SetTheme(!_lightTheme);
        toolbar.Controls.Add(themeButton);
        _searchBox.Dock = DockStyle.Right;
        _searchBox.Width = 260;
        _searchBox.Font = new Font("Segoe UI", 10F);
        _searchBox.BorderStyle = BorderStyle.FixedSingle;
        _searchBox.Margin = new Padding(0, 8, 10, 8);
        _searchBox.TextChanged += (_, _) => UpdateSearchResults();
        _searchBox.KeyDown += SearchBoxKeyDown;
        toolbar.Controls.Add(_searchBox);
        body.Controls.Add(toolbar, 0, 0);
        _actions.Dock = DockStyle.Fill;
        _actions.FlowDirection = FlowDirection.TopDown;
        _actions.WrapContents = false;
        _actions.AutoScroll = true;
        _actions.BackColor = PageColor;
        body.Controls.Add(_actions, 0, 1);
        _footer.Dock = DockStyle.Fill;
        _footer.TextAlign = ContentAlignment.MiddleLeft;
        _footer.ForeColor = MutedColor;
        body.Controls.Add(_footer, 0, 2);
        _searchResults.ItemClicked += async (_, eventArgs) =>
        {
            if (eventArgs.ClickedItem?.Tag is ToolboxAction action)
            {
                _searchResults.Hide();
                _searchBox.Clear();
                await NavigateAsync(action.Category);
            }
            else if (eventArgs.ClickedItem?.Tag is ValueTuple<string, string, string> section)
            {
                _searchResults.Hide();
                _searchBox.Clear();
                await NavigateAsync(section.Item2);
            }
        };
        LoadConfig();
        UpdateBrandIcon();
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
            if (!_windows.IsWindows11) ApplyUnsupportedReadOnlyGate();
        };
    }

    private static bool ReadThemePreference()
    {
        var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ApexOS", "toolbox-theme.json");
        try { return File.Exists(path) && File.ReadAllText(path).Trim().Equals("light", StringComparison.OrdinalIgnoreCase); }
        catch { return false; }
    }

    private void SetTheme(bool light)
    {
        _lightTheme = light;
        var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ApexOS", "toolbox-theme.json");
        try { Directory.CreateDirectory(Path.GetDirectoryName(path)!); File.WriteAllText(path, light ? "light" : "dark"); }
        catch { }
        ApplyTheme(this);
        UpdateBrandIcon();
        UpdateFooter();
        foreach (var pair in _navigationButtons)
        {
            var selected = pair.Key.Equals(_category, StringComparison.OrdinalIgnoreCase);
            pair.Value.BackColor = selected ? AccentColor : SidebarColor;
            foreach (Control child in pair.Value.Controls) child.ForeColor = selected ? Color.FromArgb(17, 34, 29) : MutedColor;
        }
        var themeButton = Controls.Find("theme-button", true).FirstOrDefault() as Button;
        if (themeButton is not null) themeButton.Text = _lightTheme ? "\uE708  Light" : "\uE708  Dark";
    }

    private void ApplyTheme(Control parent)
    {
        parent.BackColor = parent == this ? PageColor : parent == _sidebar ? SidebarColor :
            parent == _actions ? PageColor : parent is Panel && parent.Tag?.ToString() == "card" ? SurfaceColor :
            parent is Panel ? (parent.Parent == _sidebar ? SidebarColor : PageColor) : parent.BackColor;
        if (parent is Label label) label.ForeColor = label.Name == "muted" ? MutedColor : TextColor;
        if (parent is Button button && button.Name != "theme-button")
        {
            button.ForeColor = TextColor;
            button.BackColor = SurfaceColor;
        }
        if (parent is TextBox textBox) { textBox.BackColor = SurfaceColor; textBox.ForeColor = TextColor; }
        foreach (Control child in parent.Controls) ApplyTheme(child);
    }

    private void UpdateBrandIcon()
    {
        var path = Path.Combine(_root, "Assets", _lightTheme ? "ApexMenuIcon.Light.png" : "ApexMenuIcon.Dark.png");
        if (!File.Exists(path)) return;
        var old = _brandIcon.Image;
        _brandIcon.Image = Image.FromFile(path);
        old?.Dispose();
    }

    private void ApplyUnsupportedReadOnlyGate()
    {
        var setupButton = _sidebar.Controls.OfType<Button>().FirstOrDefault(button => button.Text == "Welcome setup");
        if (setupButton is not null) setupButton.Enabled = false;
    }

    private async Task NavigateAsync(string category)
    {
        await ShowCategoryAsync(category);
        foreach (var pair in _navigationButtons)
        {
            var selected = pair.Key.Equals(category, StringComparison.OrdinalIgnoreCase);
            pair.Value.BackColor = selected ? AccentColor : SidebarColor;
            foreach (Control child in pair.Value.Controls) child.ForeColor = selected ? Color.FromArgb(17, 34, 29) : MutedColor;
        }
    }

    private void UpdateSearchResults()
    {
        var query = _searchBox.Text.Trim();
        _searchResults.Items.Clear();
        if (query.Length < 2) { _searchResults.Hide(); return; }
        foreach (var action in _config.Actions
                     .Where(item => item.Title.Contains(query, StringComparison.OrdinalIgnoreCase) || item.Description.Contains(query, StringComparison.OrdinalIgnoreCase) || item.Category.Contains(query, StringComparison.OrdinalIgnoreCase))
                     .Take(12))
        {
            var item = new ToolStripMenuItem($"{action.Title}    ·    {action.Category}") { Tag = action, ToolTipText = action.Description };
            _searchResults.Items.Add(item);
        }
        foreach (var section in Sections.Where(item => item.Label.Contains(query, StringComparison.OrdinalIgnoreCase)).Take(5))
            _searchResults.Items.Add(new ToolStripMenuItem($"{section.Glyph}   {section.Label}    ·    Section") { Tag = section });
        if (_searchResults.Items.Count == 0) _searchResults.Items.Add(new ToolStripMenuItem("No matching Apex settings") { Enabled = false });
        _searchResults.Show(_searchBox, new Point(0, _searchBox.Height));
    }

    private void SearchBoxKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Escape) { _searchBox.Clear(); _searchResults.Hide(); }
        if (e.KeyCode == Keys.Enter && _searchResults.Items.Count > 0 && _searchResults.Items[0].Enabled)
        {
            _searchResults.Items[0].PerformClick();
            e.Handled = true;
        }
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
        if (selection.Wallpaper != "None")
            AddAction("wallpaper-browser", ["-Mode", "Set", "-Name", selection.Wallpaper]);
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
            var detail = $"STDOUT:\n{outcome.StandardOutput}\nSTDERR:\n{outcome.StandardError}";
            var logPath = WriteLog($"First run | {task.Action.Title} | {task.Action.Script}", outcome.ExitCode, detail);
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
        var section = Sections.FirstOrDefault(item => item.Category.Equals(category, StringComparison.OrdinalIgnoreCase));
        _heading.Text = section.Label ?? category;
        _actions.Controls.Clear();
        if (!_isWindows)
        {
            _actions.Controls.Add(new Label { Text = "Windows-only functionality unavailable on this operating system.", AutoSize = true, ForeColor = Color.FromArgb(240, 179, 120), Margin = new Padding(0, 12, 0, 0) });
            return;
        }
        if (category.Equals("HOME", StringComparison.OrdinalIgnoreCase))
        {
            await RenderHomeAsync();
            return;
        }
        if (category.Equals("About", StringComparison.OrdinalIgnoreCase))
        {
            RenderAbout();
            return;
        }
        var actions = _config.Actions.Where(action => action.Category == category).ToList();
        if (category == "Personalization")
        {
            var wallpaperAction = actions.FirstOrDefault(action => action.Id == "wallpaper-browser");
            if (wallpaperAction is not null)
            {
                var browser = CreateWallpaperBrowser(wallpaperAction);
                _actions.Controls.Add(browser);
                await RefreshWallpaperListAsync(wallpaperAction, browser);
                actions.Remove(wallpaperAction);
            }
        }
        if (actions.Count == 0)
        {
            if (_actions.Controls.Count > 0) return;
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

    private async Task RenderHomeAsync()
    {
        _actions.Controls.Clear();
        var intro = new Panel { Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 106, BackColor = PageColor, Margin = new Padding(0, 0, 0, 12) };
        intro.Controls.Add(new Label { Text = "Apex OS", Dock = DockStyle.Top, Height = 42, Font = new Font("Segoe UI Variable Display", 25F, FontStyle.Bold), ForeColor = TextColor });
        intro.Controls.Add(new Label { Text = "Apex Playbook v0.3.0", Dock = DockStyle.Top, Height = 26, Font = new Font("Segoe UI", 11F), ForeColor = MutedColor });
        var refresh = ButtonFor("Refresh snapshot", true);
        refresh.Width = 142;
        refresh.Dock = DockStyle.Right;
        refresh.Click += async (_, _) => await RenderHomeAsync();
        intro.Controls.Add(refresh);
        _actions.Controls.Add(intro);

        var action = _config.Actions.FirstOrDefault(item => item.Id == "home-snapshot");
        if (action is null)
        {
            _actions.Controls.Add(CreateNotice("Home snapshot is not configured.", true));
            return;
        }
        _actions.Controls.Add(CreateNotice("Reading current system state...", false));
        var outcome = await ScriptRunner.RunAsync(ResolveScript(action.Script), action.ApplyArgs, false);
        _actions.Controls.RemoveAt(_actions.Controls.Count - 1);
        var logPath = WriteLog($"Home snapshot | {action.Script}", outcome.ExitCode, $"STDOUT:\n{outcome.StandardOutput}\nSTDERR:\n{outcome.StandardError}");
        if (outcome.ExitCode != 0)
        {
            _actions.Controls.Add(CreateNotice($"Apex could not read the system snapshot. See log: {logPath}", true));
            return;
        }
        try
        {
            using var document = JsonDocument.Parse(outcome.StandardOutput);
            _homeSnapshot = document.RootElement.Clone();
            RenderSnapshotCards(document.RootElement);
        }
        catch (JsonException exception)
        {
            var parseLog = WriteLog("Home snapshot JSON", 1, exception.ToString());
            _actions.Controls.Add(CreateNotice($"System snapshot was incomplete or invalid. See log: {parseLog}", true));
        }
    }

    private void RenderSnapshotCards(JsonElement snapshot)
    {
        var system = snapshot.GetProperty("Windows");
        var memory = snapshot.GetProperty("Memory");
        var storage = snapshot.GetProperty("Storage");
        var cpu = snapshot.GetProperty("Cpu");
        var gpu = snapshot.GetProperty("Gpu");
        var power = snapshot.GetProperty("Power");
        var status = snapshot.GetProperty("Status");
        var deviceType = snapshot.GetProperty("DeviceType").GetString() ?? "Unknown device";
        var systemSummary = new Label
        {
            Text = $"{deviceType}    ·    {system.GetProperty("Product").GetString()} {system.GetProperty("DisplayVersion").GetString()}  (build {system.GetProperty("Build").GetInt32()}, {system.GetProperty("Architecture").GetString()})\n{cpu.GetProperty("Name").GetString()}    ·    {gpu.GetProperty("Name").GetString()}    ·    {FormatBytes(memory.GetProperty("TotalBytes").GetInt64())} RAM",
            Width = Math.Max(620, _actions.ClientSize.Width - 36),
            Height = 58,
            ForeColor = MutedColor,
            Margin = new Padding(0, 0, 0, 10)
        };
        _actions.Controls.Add(systemSummary);

        var metrics = new FlowLayoutPanel { Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 112, WrapContents = false, FlowDirection = FlowDirection.LeftToRight, BackColor = PageColor, Margin = new Padding(0, 0, 0, 12) };
        AddMetric(metrics, "CPU", cpu.GetProperty("UsagePercent").ValueKind == JsonValueKind.Null ? "Unavailable" : $"{cpu.GetProperty("UsagePercent").GetInt32()}%", cpu.GetProperty("Name").GetString() ?? "Processor");
        AddMetric(metrics, "Memory", $"{memory.GetProperty("UsagePercent").GetDouble():0}% used", $"{FormatBytes(memory.GetProperty("AvailableBytes").GetInt64())} available · {memory.GetProperty("Pressure").GetString()} pressure");
        var gpuUsage = gpu.GetProperty("UsagePercent");
        AddMetric(metrics, "Graphics", gpuUsage.ValueKind == JsonValueKind.Null ? "Usage unavailable" : $"{gpuUsage.GetDouble():0}%", gpu.GetProperty("Name").GetString() ?? "Not detected");
        AddMetric(metrics, "Storage", $"{FormatBytes(storage.GetProperty("FreeBytes").GetInt64())} free", $"{storage.GetProperty("Drive").GetString()} · {FormatBytes(storage.GetProperty("TotalBytes").GetInt64())} total");
        _actions.Controls.Add(metrics);

        var planName = power.GetProperty("ActivePlan").GetString() ?? "Unknown";
        var startupCount = snapshot.GetProperty("StartupCount").GetInt32();
        var statusGrid = new FlowLayoutPanel { Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 142, WrapContents = true, FlowDirection = FlowDirection.LeftToRight, BackColor = PageColor, Margin = new Padding(0, 0, 0, 12) };
        AddStatus(statusGrid, "Optimization profile", "Individual settings", true);
        AddStatus(statusGrid, "Active power plan", planName, true);
        AddStatus(statusGrid, "RAM Saver", status.GetProperty("RamSaver").GetString() ?? "Unknown", true);
        AddStatus(statusGrid, "Gaming Mode", status.GetProperty("GameMode").GetBoolean() ? "On" : "Off", true);
        AddStatus(statusGrid, "Windows Update", status.GetProperty("WindowsUpdate").GetString() ?? "Unknown", true);
        AddStatus(statusGrid, "Windows Security", status.GetProperty("WindowsSecurity").GetString() ?? "Unknown", !string.Equals(status.GetProperty("WindowsSecurity").GetString(), "Real-time protection off", StringComparison.OrdinalIgnoreCase));
        var networkState = status.GetProperty("Network").GetString() ?? "Unknown";
        AddStatus(statusGrid, "Network", networkState, networkState.StartsWith("Internet reachable", StringComparison.OrdinalIgnoreCase));
        AddStatus(statusGrid, "Startup apps", startupCount.ToString(), true);
        AddStatus(statusGrid, "Restart Required", status.GetProperty("RestartRequired").GetBoolean() ? "Yes" : "No", !status.GetProperty("RestartRequired").GetBoolean());
        AddStatus(statusGrid, "Device errors", status.GetProperty("DeviceErrors").GetInt32().ToString(), status.GetProperty("DeviceErrors").GetInt32() == 0);
        _actions.Controls.Add(statusGrid);

        var quickTitle = new Label { Text = "Quick actions", Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 30, ForeColor = TextColor, Font = new Font("Segoe UI Semibold", 13F) };
        _actions.Controls.Add(quickTitle);
        var quick = new FlowLayoutPanel { Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 46, WrapContents = true, BackColor = PageColor };
        AddQuickAction(quick, "Performance", "power-performance");
        AddQuickAction(quick, "Gaming Mode", "gaming-mode");
        AddQuickAction(quick, "RAM Saver", "ram-saver-balanced");
        AddQuickAction(quick, "Network Repair", "network-repair");
        AddQuickAction(quick, "Windows Update", "windows-update-settings");
        AddQuickAction(quick, "Storage Cleanup", "storage-settings");
        _actions.Controls.Add(quick);
    }

    private void AddMetric(FlowLayoutPanel row, string title, string value, string detail)
    {
        var panel = new Panel { Width = Math.Max(150, (row.ClientSize.Width - 30) / 4), Height = 98, BackColor = SurfaceColor, Margin = new Padding(0, 0, 10, 0), Padding = new Padding(13), Tag = "card" };
        panel.Controls.Add(new Label { Text = detail, Dock = DockStyle.Bottom, Height = 33, ForeColor = MutedColor, Font = new Font("Segoe UI", 8.5F) });
        panel.Controls.Add(new Label { Text = value, Dock = DockStyle.Top, Height = 30, ForeColor = TextColor, Font = new Font("Segoe UI Semibold", 14F) });
        panel.Controls.Add(new Label { Text = title.ToUpperInvariant(), Dock = DockStyle.Top, Height = 19, ForeColor = AccentColor, Font = new Font("Segoe UI Semibold", 8F) });
        row.Controls.Add(panel);
    }

    private void AddStatus(FlowLayoutPanel row, string title, string value, bool healthy)
    {
        var panel = new Panel { Width = Math.Max(180, (row.ClientSize.Width - 18) / 3), Height = 56, BackColor = SurfaceColor, Margin = new Padding(0, 0, 8, 7), Padding = new Padding(10, 7, 8, 5), Tag = "card" };
        panel.Controls.Add(new Label { Text = value, Dock = DockStyle.Right, Width = 104, ForeColor = healthy ? AccentColor : Color.FromArgb(226, 124, 104), TextAlign = ContentAlignment.MiddleRight, AutoEllipsis = true });
        panel.Controls.Add(new Label { Text = title, Dock = DockStyle.Fill, ForeColor = MutedColor, TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true });
        row.Controls.Add(panel);
    }

    private void AddQuickAction(FlowLayoutPanel row, string label, string actionId)
    {
        var button = ButtonFor(label, false);
        button.Width = label.Length > 13 ? 136 : 118;
        var action = _config.Actions.FirstOrDefault(item => item.Id == actionId);
        button.Enabled = action is not null && (_windows.IsWindows11 || action.ReadOnly);
        button.Click += async (_, _) =>
        {
            if (action is not null) await RunActionAsync(action, action.ApplyArgs, _actions);
        };
        row.Controls.Add(button);
    }

    private Control CreateNotice(string message, bool error)
    {
        return new Label { Text = message, Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 58, BackColor = SurfaceColor, ForeColor = error ? Color.FromArgb(226, 124, 104) : MutedColor, Padding = new Padding(16), Margin = new Padding(0, 10, 0, 12), Tag = "card" };
    }

    private void RenderAbout()
    {
        var panel = new Panel { Width = Math.Max(620, _actions.ClientSize.Width - 36), Height = 180, BackColor = SurfaceColor, Padding = new Padding(22), Tag = "card" };
        panel.Controls.Add(new Label { Text = "Apex OS", Dock = DockStyle.Top, Height = 44, Font = new Font("Segoe UI Variable Display", 24F, FontStyle.Bold), ForeColor = TextColor });
        panel.Controls.Add(new Label { Text = $"Apex Playbook v0.3.0\n{_windows.Product} · build {_windows.Build} · {RuntimeInformation.OSArchitecture}\nAME Wizard deployment · Apex Toolbox and reversible Windows configuration tools", Dock = DockStyle.Fill, ForeColor = MutedColor });
        _actions.Controls.Add(panel);
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return $"{value:0.#} {units[unit]}";
    }

    private Control CreateWallpaperBrowser(ToolboxAction action)
        {
            var card = new Panel { Width = Math.Max(480, _actions.ClientSize.Width - 34), Height = 248, BackColor = Color.FromArgb(29, 35, 41), Margin = new Padding(0, 0, 0, 12), Padding = new Padding(16) };
            card.Controls.Add(new Label { Text = action.Title, Dock = DockStyle.Top, Height = 30, Font = new Font("Segoe UI Semibold", 12) });
            card.Controls.Add(new Label { Text = $"{action.Description} Supported formats: JPG, JPEG, PNG, BMP, and WebP where Windows supports it.", Dock = DockStyle.Top, Height = 44, ForeColor = Color.FromArgb(174, 184, 191) });

            var wallpaperChoice = new ComboBox { Name = "wallpaper-choice", Dock = DockStyle.Top, DropDownStyle = ComboBoxStyle.DropDownList, BackColor = Color.FromArgb(25, 30, 36), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Height = 32 };
            wallpaperChoice.SelectedIndexChanged += async (_, _) => await RefreshWallpaperStatusAsync(action, card);
            card.Controls.Add(wallpaperChoice);

            var status = new Label { Name = "wallpaper-status", Text = "Status: scanning wallpaper folder...", Dock = DockStyle.Top, Height = 30, ForeColor = Color.FromArgb(116, 219, 186), TextAlign = ContentAlignment.MiddleLeft };
            card.Controls.Add(status);
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 74, FlowDirection = FlowDirection.LeftToRight, WrapContents = true };
            var refresh = ButtonFor("Refresh", false);
            refresh.Width = 90;
            refresh.Enabled = _windows.IsWindows11;
            refresh.Click += async (_, _) => await RefreshWallpaperListAsync(action, card);
            buttons.Controls.Add(refresh);

            var apply = ButtonFor("Set desktop", true);
            apply.Width = 110;
            apply.Enabled = _windows.IsWindows11;
            apply.Click += async (_, _) => await RunSelectedWallpaperAsync(action, card, "Set");
            buttons.Controls.Add(apply);

            var setDefault = ButtonFor("Apex default", false);
            setDefault.Width = 110;
            setDefault.Enabled = _windows.IsWindows11;
            setDefault.Click += async (_, _) => await RunWallpaperAsync(action, card, "Set", "Apex-Default-Dark.jpg");
            buttons.Controls.Add(setDefault);

            var lockScreen = ButtonFor("Lock screen...", false);
            lockScreen.Width = 120;
            lockScreen.Enabled = _windows.IsWindows11;
            lockScreen.Click += async (_, _) => await RunSelectedWallpaperAsync(action, card, "OpenLockScreen");
            buttons.Controls.Add(lockScreen);

            var apexLockScreen = ButtonFor("Apex lock screen", false);
            apexLockScreen.Width = 130;
            apexLockScreen.Enabled = _windows.IsWindows11;
            apexLockScreen.Click += async (_, _) => await RunWallpaperAsync(action, card, "OpenLockScreen", "Apex-LockScreen-Dark.jpg");
            buttons.Controls.Add(apexLockScreen);

            var restore = ButtonFor("Restore previous", false);
            restore.Width = 130;
            restore.Enabled = _windows.IsWindows11;
            restore.Click += async (_, _) => await RunActionAsync(action, ["-Mode", "Restore"], card);
            buttons.Controls.Add(restore);
            card.Controls.Add(buttons);
            return card;
        }

        private async Task RefreshWallpaperListAsync(ToolboxAction action, Control card)
        {
            var choice = card.Controls.Find("wallpaper-choice", true).FirstOrDefault() as ComboBox;
            var status = card.Controls.Find("wallpaper-status", true).FirstOrDefault() as Label;
            if (choice is null || status is null) return;
            try
            {
                var selected = choice.SelectedItem as string;
                var result = await ScriptRunner.RunAsync(ResolveScript(action.Script), ["-Mode", "List"], false);
                if (result.ExitCode != 0) throw new InvalidOperationException(result.StandardError.Trim());
                var wallpapers = result.StandardOutput.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToArray();
                choice.BeginUpdate();
                choice.Items.Clear();
                choice.Items.AddRange(wallpapers);
                var index = Array.FindIndex(wallpapers, name => string.Equals(name, selected, StringComparison.OrdinalIgnoreCase));
                if (index < 0) index = Array.FindIndex(wallpapers, name => string.Equals(name, "Apex-Default-Dark.jpg", StringComparison.OrdinalIgnoreCase));
                choice.SelectedIndex = index >= 0 ? index : wallpapers.Length > 0 ? 0 : -1;
                choice.EndUpdate();
                if (wallpapers.Length == 0) status.Text = "No supported image files found in the Wallpapers folder.";
                else await RefreshWallpaperStatusAsync(action, card);
            }
            catch (Exception exception)
            {
                status.Text = "Status: wallpaper scan failed.";
                status.ForeColor = Color.FromArgb(240, 147, 126);
                var logPath = WriteLog("Wallpaper library refresh", 1, exception.ToString());
                MessageBox.Show(this, $"Could not scan the Apex Wallpapers folder. {exception.Message}\nLog: {logPath}", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private async Task RefreshWallpaperStatusAsync(ToolboxAction action, Control card)
        {
            var choice = card.Controls.Find("wallpaper-choice", true).FirstOrDefault() as ComboBox;
            var status = card.Controls.Find("wallpaper-status", true).FirstOrDefault() as Label;
            if (choice?.SelectedItem is not string name || status is null) return;
            try
            {
                var result = await ScriptRunner.RunAsync(ResolveScript(action.Script), ["-Mode", "Status", "-Name", name], false);
                var state = result.StandardOutput.Trim();
                status.Text = result.ExitCode == 0 ? $"Status: {state}" : $"Status: unavailable — {result.StandardError.Trim()}";
                status.ForeColor = result.ExitCode == 0 ? Color.FromArgb(116, 219, 186) : Color.FromArgb(240, 147, 126);
            }
            catch (Exception exception)
            {
                status.Text = $"Status: unavailable — {exception.Message}";
                status.ForeColor = Color.FromArgb(240, 147, 126);
            }
        }

        private async Task RunSelectedWallpaperAsync(ToolboxAction action, Control card, string mode)
        {
            var choice = card.Controls.Find("wallpaper-choice", true).FirstOrDefault() as ComboBox;
            if (choice?.SelectedItem is not string name)
            {
                MessageBox.Show(this, "Select an image from the wallpaper library first.", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            await RunWallpaperAsync(action, card, mode, name);
        }

        private async Task RunWallpaperAsync(ToolboxAction action, Control card, string mode, string name)
        {
            await RunActionAsync(action, ["-Mode", mode, "-Name", name], card);
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
            var restore = ButtonFor(string.IsNullOrWhiteSpace(action.RestoreText) ? "Restore" : action.RestoreText, false);
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
            if (result.ExitCode == 0 && action.Category == "Power")
            {
                try
                {
                    using var json = JsonDocument.Parse(result.StandardOutput);
                    var root = json.RootElement;
                    if (root.TryGetProperty("Profile", out var profile))
                    {
                        var available = root.GetProperty("Available").GetBoolean();
                        var active = root.GetProperty("Active").GetBoolean();
                        state = available ? $"{(active ? "Active" : "Available")}: {profile.GetString()}" : $"Power plan unavailable: {profile.GetString()}";
                    }
                    else if (root.TryGetProperty("CurrentPlan", out var current))
                    {
                        var currentName = current.GetString() ?? "Unknown";
                        state = $"Active: {currentName}";
                    }
                }
                catch (JsonException) { }
            }
            label.Text = result.ExitCode == 0 ? $"Status: {state}" : $"Status: unavailable (exit {result.ExitCode})";
            label.ForeColor = result.ExitCode != 0 || state.StartsWith("Power plan unavailable", StringComparison.OrdinalIgnoreCase)
                ? Color.FromArgb(240, 147, 126)
                : Color.FromArgb(116, 219, 186);
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
            var detail = $"STDOUT:\n{result.StandardOutput}\nSTDERR:\n{result.StandardError}";
            var logPath = WriteLog($"{action.Title} | {action.Script}", result.ExitCode, detail);
            if (result.ExitCode == 0 && action.Category == "Drivers")
            {
                RenderDriverResults(action, result.StandardOutput, logPath);
                return;
            }
            var text = result.ExitCode == 0
                ? $"Completed successfully.\n\n{result.StandardOutput.Trim()}"
                : $"Failed (exit code {result.ExitCode}).\n{result.StandardError.Trim()}\n{result.StandardOutput.Trim()}\n\nLog: {logPath}";
            if (result.ExitCode != 0 && action.Category == "Power" && arguments.Contains("Select"))
            {
                using var recovery = new PowerPlanRecoveryForm(action.Title, $"Exit code: {result.ExitCode}\nLog: {logPath}\n\n{result.StandardError.Trim()}\n{result.StandardOutput.Trim()}", _lightTheme);
                recovery.ShowDialog(this);
                if (recovery.Choice == PowerPlanRecoveryChoice.UseAvailable)
                    await RunPowerFallbackAsync("power-use-available");
                else if (recovery.Choice == PowerPlanRecoveryChoice.RestoreCompatible)
                    await RunPowerFallbackAsync("power-use-available");
            }
            else
            {
                MessageBox.Show(this, text, "Apex Toolbox", MessageBoxButtons.OK, result.ExitCode == 0 ? MessageBoxIcon.Information : MessageBoxIcon.Error);
            }
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

    private async Task RunPowerFallbackAsync(string actionId)
    {
        var action = _config.Actions.FirstOrDefault(item => item.Id == actionId);
        if (action is null)
        {
            MessageBox.Show(this, "The selected power recovery action is not configured.", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        try
        {
            var result = await ScriptRunner.RunAsync(ResolveScript(action.Script), action.ApplyArgs, action.RequiresAdmin);
            var detail = $"STDOUT:\n{result.StandardOutput}\nSTDERR:\n{result.StandardError}";
            var log = WriteLog($"{action.Title} | {action.Script}", result.ExitCode, detail);
            var message = result.ExitCode == 0
                ? result.StandardOutput.Trim()
                : $"A compatible power plan could not be selected.\nExit code: {result.ExitCode}\n{result.StandardError.Trim()}\nLog: {log}";
            MessageBox.Show(this, message, "Apex Toolbox", MessageBoxButtons.OK, result.ExitCode == 0 ? MessageBoxIcon.Information : MessageBoxIcon.Error);
        }
        catch (Exception exception)
        {
            var log = WriteLog($"{action.Title} | {action.Script}", 1, exception.ToString());
            MessageBox.Show(this, $"Power plan recovery failed. {exception.Message}\nLog: {log}", "Apex Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void RenderDriverResults(ToolboxAction action, string json, string logPath)
    {
        _actions.Controls.Clear();
        _heading.Text = action.Title;
        try
        {
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;
            if (action.Id == "driver-problems")
            {
                var problems = root.GetProperty("Problems");
                if (problems.GetArrayLength() == 0)
                    _actions.Controls.Add(CreateNotice("No devices are reporting a PnP driver error.", false));
                else
                    foreach (var problem in problems.EnumerateArray())
                    {
                        var friendlyName = GetJsonString(problem, "Name", "Device requiring attention");
                        var code = problem.TryGetProperty("ConfigManagerErrorCode", out var errorCode) ? errorCode.ToString() : "Unknown";
                        var instance = GetJsonString(problem, "PNPDeviceID", "Unavailable");
                        _actions.Controls.Add(CreateDriverCard(friendlyName, $"Device status: {GetJsonString(problem, "Status", "Unknown")} · Configuration code: {code}", instance));
                    }
            }
            else
            {
                var entries = root.ValueKind == JsonValueKind.Array ? root.EnumerateArray().ToList() : [];
                if (entries.Count == 0)
                    _actions.Controls.Add(CreateNotice("Windows did not return driver entries for this view.", false));
                foreach (var entry in entries)
                {
                    var name = GetJsonString(entry, "Name", GetJsonString(entry, "Device", "Unknown device"));
                    var provider = GetJsonString(entry, "Provider", GetJsonString(entry, "DriverProviderName", "Provider unavailable"));
                    var version = GetJsonString(entry, "Version", GetJsonString(entry, "DriverVersion", "Version unavailable"));
                    var date = GetJsonString(entry, "Date", GetJsonString(entry, "DriverDate", "Date unavailable"));
                    var status = GetJsonString(entry, "Status", "Unknown status");
                    var code = entry.TryGetProperty("ErrorCode", out var error) && error.ValueKind != JsonValueKind.Null ? $" · Error {error}" : "";
                    var instance = GetJsonString(entry, "InstanceId", GetJsonString(entry, "DeviceID", "Unavailable"));
                    var inf = GetJsonString(entry, "InfName", "Unavailable");
                    var signed = GetJsonString(entry, "IsSigned", "Unknown");
                    var details = $"Device instance: {instance}\nINF: {inf}\nSigned: {signed}\nDriver date: {date}";
                    _actions.Controls.Add(CreateDriverCard(name, $"{status}{code} · {provider} · {version}", details));
                }
            }
            _actions.Controls.Add(new Label { Text = $"Detailed output is logged at {logPath}", AutoSize = true, ForeColor = MutedColor, Margin = new Padding(0, 8, 0, 12) });
        }
        catch (Exception exception)
        {
            var parseLog = WriteLog("Driver results parsing", 1, exception.ToString());
            _actions.Controls.Add(CreateNotice($"Driver results could not be displayed. See log: {parseLog}", true));
        }
    }

    private Panel CreateDriverCard(string name, string summary, string details)
    {
        var card = new Panel { Width = Math.Max(620, _actions.ClientSize.Width - 42), Height = 92, BackColor = SurfaceColor, Padding = new Padding(15, 10, 15, 8), Margin = new Padding(0, 0, 0, 8), Tag = "card" };
        var heading = new Label { Text = name, Dock = DockStyle.Top, Height = 25, ForeColor = TextColor, Font = new Font("Segoe UI Semibold", 11F), AutoEllipsis = true };
        var description = new Label { Text = summary, Dock = DockStyle.Top, Height = 23, ForeColor = MutedColor, AutoEllipsis = true };
        var advanced = new TextBox { Text = details, Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, Visible = false, BorderStyle = BorderStyle.None, BackColor = SurfaceColor, ForeColor = MutedColor, Font = new Font("Consolas", 8.5F) };
        var toggle = new LinkLabel { Text = "Advanced details", Dock = DockStyle.Bottom, Height = 18, LinkColor = AccentColor, ActiveLinkColor = AccentColor };
        toggle.Click += (_, _) =>
        {
            advanced.Visible = !advanced.Visible;
            card.Height = advanced.Visible ? 154 : 92;
            toggle.Text = advanced.Visible ? "Hide advanced details" : "Advanced details";
        };
        card.Controls.Add(advanced);
        card.Controls.Add(toggle);
        card.Controls.Add(description);
        card.Controls.Add(heading);
        return card;
    }

    private static string GetJsonString(JsonElement element, string property, string fallback)
    {
        if (!element.TryGetProperty(property, out var value) || value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return fallback;
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? fallback : value.ToString();
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
        if (isWindows11 && product.StartsWith("Windows 10", StringComparison.OrdinalIgnoreCase))
            product = "Windows 11" + product["Windows 10".Length..];
        return new WindowsDetails(product, build, release, isWindows11);
    }

    private sealed record WindowsDetails(string Product, int Build, string DisplayVersion, bool IsWindows11);
}