using System.ComponentModel;

namespace DNSUpdaterTray
{
    public partial class SettingsForm : Form
    {
        private readonly DnsSettings currentSettings;
        private readonly ConfigurationManager configManager;
        
        // UI控件
        private TextBox txtSubDomain;
        private TextBox txtDomain;
        private NumericUpDown nudUpdateInterval;
        private CheckBox chkEnableUpdate;
        private TextBox txtApiUrl;
        private Button btnSave;
        private Button btnCancel;
        private Button btnReset;

        public SettingsForm(DnsSettings settings, ConfigurationManager configMgr)
        {
            currentSettings = settings;
            configManager = configMgr;
            InitializeComponent();
            LoadCurrentSettings();
        }

        private void InitializeComponent()
        {
            this.SuspendLayout();

            // 窗体设置
            this.Text = "DNS更新器设置";
            this.Size = new Size(450, 350);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;

            // 子域名
            var lblSubDomain = new Label
            {
                Text = "子域名:",
                Location = new Point(20, 20),
                Size = new Size(80, 23)
            };
            this.Controls.Add(lblSubDomain);

            txtSubDomain = new TextBox
            {
                Location = new Point(110, 18),
                Size = new Size(200, 23),
                PlaceholderText = "例如: 3950"
            };
            this.Controls.Add(txtSubDomain);

            // 域名
            var lblDomain = new Label
            {
                Text = "域名:",
                Location = new Point(20, 55),
                Size = new Size(80, 23)
            };
            this.Controls.Add(lblDomain);

            txtDomain = new TextBox
            {
                Location = new Point(110, 53),
                Size = new Size(200, 23),
                PlaceholderText = "例如: qsgl.net"
            };
            this.Controls.Add(txtDomain);

            // 更新间隔
            var lblUpdateInterval = new Label
            {
                Text = "更新间隔(秒):",
                Location = new Point(20, 90),
                Size = new Size(80, 23)
            };
            this.Controls.Add(lblUpdateInterval);

            nudUpdateInterval = new NumericUpDown
            {
                Location = new Point(110, 88),
                Size = new Size(100, 23),
                Minimum = 10,
                Maximum = 3600,
                Value = 60
            };
            this.Controls.Add(nudUpdateInterval);

            // 启用更新
            chkEnableUpdate = new CheckBox
            {
                Text = "启用自动DNS更新",
                Location = new Point(20, 125),
                Size = new Size(200, 23),
                Checked = true
            };
            this.Controls.Add(chkEnableUpdate);

            // API地址
            var lblApiUrl = new Label
            {
                Text = "API地址:",
                Location = new Point(20, 160),
                Size = new Size(80, 23)
            };
            this.Controls.Add(lblApiUrl);

            txtApiUrl = new TextBox
            {
                Location = new Point(20, 185),
                Size = new Size(390, 23),
                PlaceholderText = "https://tx.qsgl.net:5075/api/updatehosts"
            };
            this.Controls.Add(txtApiUrl);

            // 说明文字
            var lblInfo = new Label
            {
                Text = "注意：配置保存后将立即生效，无需重启程序。",
                Location = new Point(20, 220),
                Size = new Size(390, 40),
                ForeColor = Color.Gray,
                Font = new Font(this.Font.FontFamily, 8.5f)
            };
            this.Controls.Add(lblInfo);

            // 按钮
            btnSave = new Button
            {
                Text = "保存",
                Location = new Point(180, 270),
                Size = new Size(75, 30),
                DialogResult = DialogResult.OK
            };
            btnSave.Click += BtnSave_Click;
            this.Controls.Add(btnSave);

            btnCancel = new Button
            {
                Text = "取消",
                Location = new Point(265, 270),
                Size = new Size(75, 30),
                DialogResult = DialogResult.Cancel
            };
            this.Controls.Add(btnCancel);

            btnReset = new Button
            {
                Text = "恢复默认",
                Location = new Point(85, 270),
                Size = new Size(85, 30)
            };
            btnReset.Click += BtnReset_Click;
            this.Controls.Add(btnReset);

            this.AcceptButton = btnSave;
            this.CancelButton = btnCancel;

            this.ResumeLayout(false);
        }

        private void LoadCurrentSettings()
        {
            txtSubDomain.Text = currentSettings.SubDomain;
            txtDomain.Text = currentSettings.Domain;
            nudUpdateInterval.Value = Math.Max(10, Math.Min(3600, currentSettings.UpdateInterval));
            chkEnableUpdate.Checked = currentSettings.EnableUpdate;
            txtApiUrl.Text = currentSettings.ApiUrl;
        }

        private void BtnSave_Click(object sender, EventArgs e)
        {
            try
            {
                if (ValidateInput())
                {
                    SaveSettings();
                }
                else
                {
                    this.DialogResult = DialogResult.None; // 阻止关闭窗体
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"保存设置时发生错误: {ex.Message}", "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
                this.DialogResult = DialogResult.None;
            }
        }

        private void BtnReset_Click(object sender, EventArgs e)
        {
            var result = MessageBox.Show("确定要恢复默认设置吗？这将清除所有自定义配置。", "确认", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (result == DialogResult.Yes)
            {
                txtSubDomain.Text = "3950";
                txtDomain.Text = "qsgl.net";
                nudUpdateInterval.Value = 60;
                chkEnableUpdate.Checked = true;
                txtApiUrl.Text = "https://tx.qsgl.net:5075/api/updatehosts";
            }
        }

        private bool ValidateInput()
        {
            // 验证子域名
            if (string.IsNullOrWhiteSpace(txtSubDomain.Text))
            {
                MessageBox.Show("请输入子域名", "验证错误", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                txtSubDomain.Focus();
                return false;
            }

            // 验证域名
            if (string.IsNullOrWhiteSpace(txtDomain.Text))
            {
                MessageBox.Show("请输入域名", "验证错误", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                txtDomain.Focus();
                return false;
            }

            // 验证API地址
            if (string.IsNullOrWhiteSpace(txtApiUrl.Text))
            {
                MessageBox.Show("请输入API地址", "验证错误", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                txtApiUrl.Focus();
                return false;
            }

            if (!Uri.TryCreate(txtApiUrl.Text, UriKind.Absolute, out _))
            {
                MessageBox.Show("API地址格式不正确", "验证错误", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                txtApiUrl.Focus();
                return false;
            }

            return true;
        }

        private void SaveSettings()
        {
            var userSettings = new UserDnsSettings
            {
                SubDomain = txtSubDomain.Text.Trim(),
                Domain = txtDomain.Text.Trim(),
                UpdateInterval = (int)nudUpdateInterval.Value,
                EnableUpdate = chkEnableUpdate.Checked,
                ApiUrl = txtApiUrl.Text.Trim(),
                LastSaved = DateTime.Now
            };

            configManager.SaveUserConfiguration(userSettings);
        }
    }
}