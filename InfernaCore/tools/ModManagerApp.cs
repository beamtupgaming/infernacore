using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Reflection;

public class ModInfo
{
    public string FolderPath { get; set; }
    public string Id { get; set; }
    public string Name { get; set; }
    public string Version { get; set; }
    public string Entry { get; set; }
    public bool Installed { get; set; }
    public bool SelectedForLaunch { get; set; }
}

public class AppMetadata
{
    public string Name { get; set; }
    public string Version { get; set; }
    public string Publisher { get; set; }
}

public class ModManagerForm : Form
{
    private readonly TextBox gameRootTextBox;
    private readonly TextBox gameModsPathTextBox;
    private readonly DataGridView modsGrid;
    private readonly Label statusLabel;
    private readonly Label gameRootValidLabel;
    private readonly Label gameModsValidLabel;

    private readonly string templateRoot;
    private readonly string modsSourceRoot;
    private readonly string settingsPath;

    public ModManagerForm()
    {
        this.Text = "InfernaCore - Into The Flames Mod Manager";
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Size = new Size(980, 680);
        this.MinimumSize = new Size(980, 640);

        try
        {
            this.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);
        }
        catch
        {
        }

        this.templateRoot = ResolveTemplateRoot();
        this.modsSourceRoot = Path.Combine(this.templateRoot, "modpacks");
        this.settingsPath = Path.Combine(this.templateRoot, "config.json");

        var settingsGroup = new GroupBox
        {
            Left = 8,
            Top = 6,
            Width = 958,
            Height = 86,
            Text = "Game Installation"
        };

        var rootLabel = new Label { Left = 10, Top = 22, Width = 120, Text = "Game Install Path:", TextAlign = ContentAlignment.MiddleRight };
        this.gameRootTextBox = new TextBox { Left = 136, Top = 20, Width = 650 };
        this.gameRootValidLabel = new Label { Left = 790, Top = 22, Width = 20, Text = "", Font = new Font("Segoe UI", 10f, FontStyle.Bold) };
        var browseRootButton = new Button { Left = 812, Top = 18, Width = 120, Text = "Browse..." };
        var saveSettingsButton = new Button { Left = 812, Top = 50, Width = 120, Text = "Save Settings" };

        var modsPathLabel = new Label { Left = 10, Top = 54, Width = 120, Text = "Mods Folder:", TextAlign = ContentAlignment.MiddleRight };
        this.gameModsPathTextBox = new TextBox { Left = 136, Top = 52, Width = 650 };
        this.gameModsValidLabel = new Label { Left = 790, Top = 54, Width = 20, Text = "", Font = new Font("Segoe UI", 10f, FontStyle.Bold) };
        var browseModsButton = new Button { Left = 812, Top = 50, Width = 120, Text = "Browse..." };

        settingsGroup.Controls.Add(rootLabel);
        settingsGroup.Controls.Add(this.gameRootTextBox);
        settingsGroup.Controls.Add(this.gameRootValidLabel);
        settingsGroup.Controls.Add(browseRootButton);
        settingsGroup.Controls.Add(saveSettingsButton);
        settingsGroup.Controls.Add(modsPathLabel);
        settingsGroup.Controls.Add(this.gameModsPathTextBox);
        settingsGroup.Controls.Add(this.gameModsValidLabel);
        settingsGroup.Controls.Add(browseModsButton);

        this.modsGrid = new DataGridView
        {
            Left = 12,
            Top = 100,
            Width = 942,
            Height = 420,
            AllowUserToAddRows = false,
            AllowUserToDeleteRows = false,
            ReadOnly = false,
            MultiSelect = false,
            SelectionMode = DataGridViewSelectionMode.FullRowSelect,
            AutoGenerateColumns = false
        };

        this.modsGrid.Columns.Add(new DataGridViewCheckBoxColumn { Name = "Load", HeaderText = "Load On Launch", Width = 110 });
        this.modsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Id", HeaderText = "Mod Id", Width = 180, ReadOnly = true });
        this.modsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Name", HeaderText = "Name", Width = 260, ReadOnly = true });
        this.modsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Version", HeaderText = "Version", Width = 90, ReadOnly = true });
        this.modsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Status", HeaderText = "Status", Width = 110, ReadOnly = true });
        this.modsGrid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Folder", HeaderText = "Folder", Width = 170, ReadOnly = true });

        var refreshButton = new Button { Left = 12, Top = 540, Width = 90, Text = "Refresh" };
        var addButton = new Button { Left = 110, Top = 540, Width = 90, Text = "Add Mod" };
        var removeButton = new Button { Left = 208, Top = 540, Width = 110, Text = "Remove Mod" };
        var enableButton = new Button { Left = 326, Top = 540, Width = 120, Text = "Enable Selected" };
        var disableButton = new Button { Left = 454, Top = 540, Width = 120, Text = "Disable Selected" };
        var aboutButton = new Button { Left = 582, Top = 540, Width = 90, Text = "About" };
        var launchButton = new Button { Left = 744, Top = 540, Width = 210, Height = 34, Text = "Start Game With Selected Mods" };

        this.statusLabel = new Label { Left = 12, Top = 582, Width = 940, Height = 24, Text = "InfernaCore ready." };

        browseRootButton.Click += (s, e) => BrowseGameRoot();
        browseModsButton.Click += (s, e) => BrowseModsPath();
        saveSettingsButton.Click += (s, e) => SaveSettings();
        refreshButton.Click += (s, e) => RefreshModList();
        addButton.Click += (s, e) => AddMod();
        removeButton.Click += (s, e) => RemoveSelectedMod();
        enableButton.Click += (s, e) => EnableSelectedMod();
        disableButton.Click += (s, e) => DisableSelectedMod();
        aboutButton.Click += (s, e) => ShowAboutDialog();
        launchButton.Click += (s, e) => LaunchGameWithSelectedMods();

        this.Controls.Add(settingsGroup);
        this.Controls.Add(this.modsGrid);
        this.Controls.Add(refreshButton);
        this.Controls.Add(addButton);
        this.Controls.Add(removeButton);
        this.Controls.Add(enableButton);
        this.Controls.Add(disableButton);
        this.Controls.Add(aboutButton);
        this.Controls.Add(launchButton);
        this.Controls.Add(this.statusLabel);

        var saved = LoadSettings();
        this.gameRootTextBox.Text = saved.ContainsKey("gameRoot") && !string.IsNullOrWhiteSpace(Convert.ToString(saved["gameRoot"]))
            ? Convert.ToString(saved["gameRoot"])
            : @"D:\SteamLibrary\steamapps\common\Into The Flames";
        this.gameModsPathTextBox.Text = saved.ContainsKey("gameModsPath") && !string.IsNullOrWhiteSpace(Convert.ToString(saved["gameModsPath"]))
            ? Convert.ToString(saved["gameModsPath"])
            : ResolveGameModsPath(this.gameRootTextBox.Text);

        this.gameRootTextBox.TextChanged += (s, e) => ValidatePaths();
        this.gameRootTextBox.Leave += (s, e) =>
        {
            var autoMods = ResolveGameModsPath(this.gameRootTextBox.Text.Trim());
            if (!string.IsNullOrWhiteSpace(autoMods))
            {
                this.gameModsPathTextBox.Text = autoMods;
            }
            ValidatePaths();
            RefreshModList();
        };

        this.gameModsPathTextBox.TextChanged += (s, e) => ValidatePaths();
        this.gameModsPathTextBox.Leave += (s, e) => { ValidatePaths(); RefreshModList(); };

        ValidatePaths();
        RefreshModList();
    }

    private string ResolveTemplateRoot()
    {
        var exeDir = AppDomain.CurrentDomain.BaseDirectory
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        // Exe is at the repo root — modpacks/ is right here
        if (Directory.Exists(Path.Combine(exeDir, "modpacks")))
        {
            return exeDir;
        }
        // Legacy: exe was inside tools/, so walk up one level
        var parent = Directory.GetParent(exeDir);
        return parent != null ? parent.FullName : exeDir;
    }

    private Dictionary<string, object> LoadSettings()
    {
        if (!File.Exists(this.settingsPath))
        {
            return new Dictionary<string, object>();
        }
        try
        {
            var json = File.ReadAllText(this.settingsPath);
            var serializer = new JavaScriptSerializer();
            return serializer.Deserialize<Dictionary<string, object>>(json) ?? new Dictionary<string, object>();
        }
        catch
        {
            return new Dictionary<string, object>();
        }
    }

    private void SaveSettings()
    {
        try
        {
            var settings = new Dictionary<string, object>
            {
                { "gameRoot", this.gameRootTextBox.Text.Trim() },
                { "gameModsPath", this.gameModsPathTextBox.Text.Trim() }
            };
            var serializer = new JavaScriptSerializer();
            var json = serializer.Serialize(settings);
            var dir = Path.GetDirectoryName(this.settingsPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
            File.WriteAllText(this.settingsPath, json);
            SetStatus("Settings saved.");
        }
        catch (Exception ex)
        {
            MessageBox.Show("Could not save settings: " + ex.Message, "Save Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void ValidatePaths()
    {
        var gameRoot = this.gameRootTextBox.Text.Trim();
        var gameRootValid = !string.IsNullOrWhiteSpace(gameRoot) && Directory.Exists(gameRoot);
        this.gameRootValidLabel.Text = gameRootValid ? "\u2714" : "\u2718";
        this.gameRootValidLabel.ForeColor = gameRootValid ? Color.Green : Color.Red;

        var modsPath = this.gameModsPathTextBox.Text.Trim();
        var modsPathValid = !string.IsNullOrWhiteSpace(modsPath) &&
            (Directory.Exists(modsPath) || Directory.Exists(Path.GetDirectoryName(modsPath) ?? string.Empty));
        this.gameModsValidLabel.Text = modsPathValid ? "\u2714" : "\u2718";
        this.gameModsValidLabel.ForeColor = modsPathValid ? Color.Green : Color.Red;
    }

    private static string ResolveGameModsPath(string gameRoot)
    {
        if (string.IsNullOrWhiteSpace(gameRoot))
        {
            return string.Empty;
        }

        var candidate1 = Path.Combine(gameRoot, "Mods");
        var candidate2 = Path.Combine(gameRoot, "IntoTheFlames", "Mods");

        if (Directory.Exists(candidate1))
        {
            return candidate1;
        }

        if (Directory.Exists(candidate2))
        {
            return candidate2;
        }

        return candidate2;
    }

    private static string ResolveGameExePath(string gameRoot)
    {
        var candidate1 = Path.Combine(gameRoot, "Project_Flames.exe");
        var candidate2 = Path.Combine(gameRoot, "IntoTheFlames", "Binaries", "Win64", "Project_Flames-Win64-Shipping.exe");

        if (File.Exists(candidate1))
        {
            return candidate1;
        }

        if (File.Exists(candidate2))
        {
            return candidate2;
        }

        throw new InvalidOperationException("Could not find game executable in the configured game root.");
    }

    private static Dictionary<string, object> ParseManifest(string manifestPath)
    {
        var json = File.ReadAllText(manifestPath);
        var serializer = new JavaScriptSerializer();
        return serializer.Deserialize<Dictionary<string, object>>(json);
    }

    private static string GetString(Dictionary<string, object> map, string key)
    {
        object value;
        if (!map.TryGetValue(key, out value) || value == null)
        {
            return string.Empty;
        }
        return Convert.ToString(value);
    }

    private HashSet<string> GetInstalledIds(string gameModsPath)
    {
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (!Directory.Exists(gameModsPath))
        {
            return result;
        }

        foreach (var dir in Directory.GetDirectories(gameModsPath))
        {
            var name = Path.GetFileName(dir);
            var dash = name.LastIndexOf('-');
            if (dash > 0)
            {
                result.Add(name.Substring(0, dash));
            }
        }

        return result;
    }

    private List<ModInfo> LoadMods()
    {
        var mods = new List<ModInfo>();
        if (!Directory.Exists(this.modsSourceRoot))
        {
            return mods;
        }

        var installedIds = GetInstalledIds(this.gameModsPathTextBox.Text.Trim());

        foreach (var modFolder in Directory.GetDirectories(this.modsSourceRoot))
        {
            var manifestPath = Path.Combine(modFolder, "mod.json");
            if (!File.Exists(manifestPath))
            {
                continue;
            }

            try
            {
                var manifest = ParseManifest(manifestPath);
                var id = GetString(manifest, "id");
                if (string.IsNullOrWhiteSpace(id))
                {
                    continue;
                }

                var mod = new ModInfo
                {
                    FolderPath = modFolder,
                    Id = id,
                    Name = GetString(manifest, "name"),
                    Version = GetString(manifest, "version"),
                    Entry = GetString(manifest, "entry"),
                    Installed = installedIds.Contains(id),
                    SelectedForLaunch = installedIds.Contains(id)
                };

                mods.Add(mod);
            }
            catch
            {
            }
        }

        return mods.OrderBy(m => m.Id).ToList();
    }

    private void RefreshModList()
    {
        try
        {
            EnsureModsPathExists();

            var mods = LoadMods();
            this.modsGrid.Rows.Clear();

            foreach (var mod in mods)
            {
                var rowIndex = this.modsGrid.Rows.Add(
                    mod.SelectedForLaunch,
                    mod.Id,
                    mod.Name,
                    mod.Version,
                    mod.Installed ? "ENABLED" : "disabled",
                    Path.GetFileName(mod.FolderPath)
                );
                this.modsGrid.Rows[rowIndex].Tag = mod;
            }

            SetStatus("Loaded " + mods.Count + " mod(s).");
        }
        catch (Exception ex)
        {
            SetStatus("Refresh failed: " + ex.Message);
            MessageBox.Show(ex.Message, "Refresh Failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void EnsureModsPathExists()
    {
        var modsPath = this.gameModsPathTextBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(modsPath))
        {
            throw new InvalidOperationException("Mods path is empty.");
        }

        if (!Directory.Exists(modsPath))
        {
            Directory.CreateDirectory(modsPath);
        }
    }

    private void BrowseGameRoot()
    {
        using (var dialog = new FolderBrowserDialog())
        {
            dialog.Description = "Select Into The Flames game root";
            dialog.SelectedPath = this.gameRootTextBox.Text;
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                this.gameRootTextBox.Text = dialog.SelectedPath;
                this.gameModsPathTextBox.Text = ResolveGameModsPath(dialog.SelectedPath);
                RefreshModList();
            }
        }
    }

    private void BrowseModsPath()
    {
        using (var dialog = new FolderBrowserDialog())
        {
            dialog.Description = "Select Into The Flames Mods folder";
            dialog.SelectedPath = this.gameModsPathTextBox.Text;
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                this.gameModsPathTextBox.Text = dialog.SelectedPath;
                RefreshModList();
            }
        }
    }

    private ModInfo GetSelectedRowMod()
    {
        if (this.modsGrid.SelectedRows.Count == 0)
        {
            return null;
        }

        var row = this.modsGrid.SelectedRows[0];
        return row.Tag as ModInfo;
    }

    private void CopyDirectory(string sourceDir, string targetDir)
    {
        if (!Directory.Exists(targetDir))
        {
            Directory.CreateDirectory(targetDir);
        }

        foreach (var file in Directory.GetFiles(sourceDir))
        {
            var fileName = Path.GetFileName(file);
            var targetFile = Path.Combine(targetDir, fileName);
            File.Copy(file, targetFile, true);
        }

        foreach (var dir in Directory.GetDirectories(sourceDir))
        {
            var name = Path.GetFileName(dir);
            var nextTarget = Path.Combine(targetDir, name);
            CopyDirectory(dir, nextTarget);
        }
    }

    private void AddMod()
    {
        using (var dialog = new FolderBrowserDialog())
        {
            dialog.Description = "Select a mod folder that contains mod.json";
            if (dialog.ShowDialog(this) != DialogResult.OK)
            {
                return;
            }

            var source = dialog.SelectedPath;
            var manifest = Path.Combine(source, "mod.json");
            if (!File.Exists(manifest))
            {
                MessageBox.Show("Selected folder does not contain mod.json", "Invalid Mod Folder", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var folderName = Path.GetFileName(source.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            var target = Path.Combine(this.modsSourceRoot, folderName);

            if (Directory.Exists(target))
            {
                var overwrite = MessageBox.Show("A mod folder with this name already exists. Overwrite it?", "Confirm Overwrite", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                if (overwrite != DialogResult.Yes)
                {
                    return;
                }
                Directory.Delete(target, true);
            }

            CopyDirectory(source, target);
            RefreshModList();
            SetStatus("Added mod folder: " + folderName);
        }
    }

    private void RemoveSelectedMod()
    {
        var mod = GetSelectedRowMod();
        if (mod == null)
        {
            MessageBox.Show("Select a mod first.", "No Selection", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        var confirm = MessageBox.Show("Remove mod source folder for '" + mod.Id + "'?", "Confirm Remove", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
        if (confirm != DialogResult.Yes)
        {
            return;
        }

        DisableModById(mod.Id);

        if (Directory.Exists(mod.FolderPath))
        {
            Directory.Delete(mod.FolderPath, true);
        }

        RefreshModList();
        SetStatus("Removed mod: " + mod.Id);
    }

    private void EnableSelectedMod()
    {
        var mod = GetSelectedRowMod();
        if (mod == null)
        {
            MessageBox.Show("Select a mod first.", "No Selection", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        EnableMod(mod);
        RefreshModList();
    }

    private void DisableSelectedMod()
    {
        var mod = GetSelectedRowMod();
        if (mod == null)
        {
            MessageBox.Show("Select a mod first.", "No Selection", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        DisableModById(mod.Id);
        RefreshModList();
    }

    private void EnableMod(ModInfo mod)
    {
        if (string.IsNullOrWhiteSpace(mod.Entry))
        {
            throw new InvalidOperationException("Mod entry is missing for " + mod.Id);
        }

        var entryPath = Path.Combine(mod.FolderPath, mod.Entry.Replace('/', Path.DirectorySeparatorChar));
        if (!File.Exists(entryPath))
        {
            throw new InvalidOperationException("Entrypoint not found: " + entryPath);
        }

        EnsureModsPathExists();
        var gameModsPath = this.gameModsPathTextBox.Text.Trim();

        DisableModById(mod.Id);

        var target = Path.Combine(gameModsPath, mod.Id + "-" + mod.Version);
        CopyDirectory(mod.FolderPath, target);

        var markerPath = Path.Combine(target, ".managed-by-app");
        File.WriteAllText(markerPath, "managed=true" + Environment.NewLine);

        SetStatus("Enabled mod: " + mod.Id);
    }

    private void DisableModById(string modId)
    {
        var gameModsPath = this.gameModsPathTextBox.Text.Trim();
        if (!Directory.Exists(gameModsPath))
        {
            return;
        }

        foreach (var dir in Directory.GetDirectories(gameModsPath, modId + "-*"))
        {
            Directory.Delete(dir, true);
        }

        SetStatus("Disabled mod: " + modId);
    }

    private void DisableManagedNotSelected(HashSet<string> selectedIds)
    {
        var gameModsPath = this.gameModsPathTextBox.Text.Trim();
        if (!Directory.Exists(gameModsPath))
        {
            return;
        }

        foreach (var dir in Directory.GetDirectories(gameModsPath))
        {
            var marker = Path.Combine(dir, ".managed-by-app");
            if (!File.Exists(marker))
            {
                continue;
            }

            var folderName = Path.GetFileName(dir);
            var dash = folderName.LastIndexOf('-');
            if (dash <= 0)
            {
                continue;
            }

            var id = folderName.Substring(0, dash);
            if (!selectedIds.Contains(id))
            {
                Directory.Delete(dir, true);
            }
        }
    }

    private List<ModInfo> GetCheckedMods()
    {
        var checkedMods = new List<ModInfo>();
        foreach (DataGridViewRow row in this.modsGrid.Rows)
        {
            var isCheckedObj = row.Cells[0].Value;
            var isChecked = isCheckedObj is bool && (bool)isCheckedObj;
            if (!isChecked)
            {
                continue;
            }

            var mod = row.Tag as ModInfo;
            if (mod != null)
            {
                checkedMods.Add(mod);
            }
        }
        return checkedMods;
    }

    private void LaunchGameWithSelectedMods()
    {
        try
        {
            var checkedMods = GetCheckedMods();
            var selectedIds = new HashSet<string>(checkedMods.Select(m => m.Id), StringComparer.OrdinalIgnoreCase);

            DisableManagedNotSelected(selectedIds);

            foreach (var mod in checkedMods)
            {
                EnableMod(mod);
            }

            var gameRoot = this.gameRootTextBox.Text.Trim();
            var exe = ResolveGameExePath(gameRoot);
            var workingDir = Path.GetDirectoryName(exe);

            Process.Start(new ProcessStartInfo
            {
                FileName = exe,
                WorkingDirectory = workingDir,
                UseShellExecute = true
            });

            SetStatus("Game launched with selected mods.");
            RefreshModList();
        }
        catch (Exception ex)
        {
            SetStatus("Launch failed: " + ex.Message);
            MessageBox.Show(ex.Message, "Launch Failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void SetStatus(string message)
    {
        this.statusLabel.Text = message;
    }

    private void ShowAboutDialog()
    {
        var meta = GetAppMetadata();
        var lines = new[]
        {
            meta.Name + " " + meta.Version,
            "Publisher: " + meta.Publisher,
            "Privacy-first, non-invasive mod manager.",
            "No telemetry. No background services."
        };

        MessageBox.Show(
            string.Join(Environment.NewLine, lines),
            "About " + meta.Name,
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }

    private static AppMetadata GetAppMetadata()
    {
        try
        {
            var asmPath = Assembly.GetExecutingAssembly().Location;
            var fileInfo = FileVersionInfo.GetVersionInfo(asmPath);
            var name = string.IsNullOrWhiteSpace(fileInfo.ProductName) ? "InfernaCore" : fileInfo.ProductName;
            var version = string.IsNullOrWhiteSpace(fileInfo.ProductVersion) ? "1.0.0" : fileInfo.ProductVersion;
            var publisher = string.IsNullOrWhiteSpace(fileInfo.CompanyName) ? "InfernaCore Contributors" : fileInfo.CompanyName;
            return new AppMetadata
            {
                Name = name.Trim(),
                Version = version.Trim(),
                Publisher = publisher.Trim()
            };
        }
        catch
        {
            return new AppMetadata
            {
                Name = "InfernaCore",
                Version = "1.0.0",
                Publisher = "InfernaCore Contributors"
            };
        }
    }
}

public static class Program
{
    [STAThread]
    public static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new ModManagerForm());
    }
}
