using System.Drawing;

namespace ApexToolbox;

internal enum PowerPlanRecoveryChoice
{
    Cancel,
    UseAvailable,
    RestoreCompatible
}

internal sealed class PowerPlanRecoveryForm : Form
{
    public PowerPlanRecoveryChoice Choice { get; private set; }

    public PowerPlanRecoveryForm(string requestedPlan, string details, bool lightTheme)
    {
        Text = "Power plan unavailable";
        Size = new Size(610, 350);
        MinimumSize = new Size(580, 330);
        MaximumSize = new Size(760, 420);
        StartPosition = FormStartPosition.CenterParent;
        BackColor = lightTheme ? Color.FromArgb(242, 245, 247) : Color.FromArgb(18, 22, 27);
        ForeColor = lightTheme ? Color.FromArgb(31, 39, 45) : Color.FromArgb(235, 239, 242);
        Font = new Font("Segoe UI", 9.5F);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), ColumnCount = 1, RowCount = 4 };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 50));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 46));
        Controls.Add(layout);
        layout.Controls.Add(new Label { Text = "Power plan unavailable", Dock = DockStyle.Fill, Font = new Font("Segoe UI Semibold", 18F), ForeColor = ForeColor }, 0, 0);
        layout.Controls.Add(new Label { Text = $"Windows could not apply {requestedPlan}. Select an installed fallback or return to a compatible Apex profile.", Dock = DockStyle.Fill, ForeColor = lightTheme ? Color.FromArgb(92, 105, 114) : Color.FromArgb(155, 168, 177) }, 0, 1);
        var advanced = new TextBox { Text = details, Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BorderStyle = BorderStyle.FixedSingle, BackColor = lightTheme ? Color.White : Color.FromArgb(27, 33, 40), ForeColor = lightTheme ? Color.FromArgb(70, 81, 89) : Color.FromArgb(185, 195, 202), Font = new Font("Consolas", 8.5F) };
        layout.Controls.Add(advanced, 0, 2);
        var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft, WrapContents = false };
        var cancel = MakeButton("Cancel", lightTheme);
        cancel.Click += (_, _) => { Choice = PowerPlanRecoveryChoice.Cancel; DialogResult = DialogResult.Cancel; Close(); };
        var compatible = MakeButton("Restore Compatible Plan", lightTheme);
        compatible.Click += (_, _) => { Choice = PowerPlanRecoveryChoice.RestoreCompatible; DialogResult = DialogResult.Retry; Close(); };
        var available = MakeButton("Use Available Plan", lightTheme, true);
        available.Click += (_, _) => { Choice = PowerPlanRecoveryChoice.UseAvailable; DialogResult = DialogResult.OK; Close(); };
        buttons.Controls.Add(cancel);
        buttons.Controls.Add(compatible);
        buttons.Controls.Add(available);
        layout.Controls.Add(buttons, 0, 3);
        CancelButton = cancel;
    }

    private static Button MakeButton(string text, bool lightTheme, bool primary = false)
    {
        var button = new Button { Text = text, AutoSize = true, Height = 32, FlatStyle = FlatStyle.Flat, BackColor = primary ? Color.FromArgb(76, 190, 155) : lightTheme ? Color.White : Color.FromArgb(34, 41, 48), ForeColor = primary ? Color.FromArgb(17, 34, 29) : lightTheme ? Color.FromArgb(31, 39, 45) : Color.FromArgb(235, 239, 242), Margin = new Padding(6, 0, 0, 0) };
        button.FlatAppearance.BorderSize = primary ? 0 : 1;
        return button;
    }
}