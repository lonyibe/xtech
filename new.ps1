# --- KNOX WIZARD V0.1 (GOOGLE SHEET EDITION) ---
# 1. SERVER: Uses Google Apps Script for Updates & Login.
# 2. UPDATER: Downloads & Launches Installer automatically to update current files.
# 3. DYNAMIC: Controlled by 'AppConfig' tab in Sheet.

$ErrorActionPreference = "Stop"
$outputPath = "$([Environment]::GetFolderPath('Desktop'))\KnoxWizard_Final.exe"

# [PASTE YOUR BASE64 ICON CODE HERE IF YOU HAVE ONE]
$exeIconBase64 = "" 

Write-Host "------------------------------------------------" -ForegroundColor Cyan
Write-Host "  KNOX WIZARD: COMPILING V0.1 (AUTO-UPDATE)..." -ForegroundColor Green
Write-Host "------------------------------------------------" -ForegroundColor Cyan

# --- ICON LOGIC ---
$iconPath = "$env:TEMP\KnoxWizard_Icon.ico"
$compilerOptions = @()

if (-not [string]::IsNullOrEmpty($exeIconBase64)) {
    try {
        [System.IO.File]::WriteAllBytes($iconPath, [Convert]::FromBase64String($exeIconBase64))
        Write-Host "Icon loaded successfully." -ForegroundColor Green
        $compilerOptions += "/win32icon:$iconPath"
    } catch {
        Write-Host "Warning: Could not process icon data. Proceeding without icon." -ForegroundColor Yellow
    }
}

$code = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Net;
using System.Linq;
using System.Runtime.InteropServices; 
using System.Management; 
using System.IO.Ports; 
using System.Text.RegularExpressions;

namespace KnoxWizardApp {

    // --- CONFIGURATION ---
    public static class Config {
        // APP VERSION
        public static string APP_VERSION = "0.1"; 

        // PASTE YOUR GOOGLE WEB APP URL HERE
        public static string SERVER_URL = "https://script.google.com/macros/s/AKfycbyA2AS1n3QAcgzfFe0t4bd8i43Un4nGkYPt3sw_4uNsCsmhzlXBXUPRRTJU1EDku9qp5w/exec"; 

        public static string UPDATE_CHECK_URL = SERVER_URL; 
        public static string LICENSE_URL = SERVER_URL; 
        
        public static int DaysRemaining = 0;
    }

    // ==========================================
    // MODULE: UPDATER SYSTEM (AUTO-INSTALL)
    // ==========================================
    public class SplashForm : Form {
        public Label lblStatus;
        
        public SplashForm() {
            this.FormBorderStyle = FormBorderStyle.None; 
            this.Size = new Size(400, 200); 
            this.StartPosition = FormStartPosition.CenterScreen; 
            this.TopMost = true; 
            this.BackColor = AppTheme.Background;
            
            this.Paint += (s, e) => { 
                 using (LinearGradientBrush br = new LinearGradientBrush(this.ClientRectangle, AppTheme.Background, AppTheme.BackgroundGrad, 45f)) { e.Graphics.FillRectangle(br, this.ClientRectangle); }
                 ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); 
            };

            Label lblTitle = new Label { Text = "KNOX WIZARD", Dock = DockStyle.Top, Height = 80, TextAlign = ContentAlignment.BottomCenter, Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = AppTheme.Primary, BackColor = Color.Transparent }; 
            
            lblStatus = new Label { Text = "INITIALIZING...", Dock = DockStyle.Bottom, Height = 80, TextAlign = ContentAlignment.TopCenter, Font = new Font("Segoe UI", 10), ForeColor = AppTheme.TextLight, BackColor = Color.Transparent };
            
            this.Controls.Add(lblTitle); 
            this.Controls.Add(lblStatus);
        }

        public void SetStatus(string text, Color color) {
            if(this.InvokeRequired) { this.Invoke(new Action(() => SetStatus(text, color))); return; }
            lblStatus.Text = text;
            lblStatus.ForeColor = color;
            lblStatus.Refresh();
        }
    }

    public static class Updater {
        public static void CheckForUpdate(SplashForm splash) {
            try {
                // 1. SECURITY PROTOCOLS
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | (SecurityProtocolType)12288;
                
                splash.SetStatus("CONNECTING TO CLOUD...", AppTheme.TextLight);
                
                // 2. PREPARE REQUEST
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(Config.UPDATE_CHECK_URL);
                request.Method = "GET";
                request.UserAgent = "KnoxWizardUpdater/0.1";
                request.AllowAutoRedirect = true;
                request.Timeout = 15000;
                
                request.Headers.Add("Cache-Control", "no-cache");
                request.CachePolicy = new System.Net.Cache.HttpRequestCachePolicy(System.Net.Cache.HttpRequestCacheLevel.NoCacheNoStore);

                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse()) {
                    using (Stream stream = response.GetResponseStream()) {
                        using (StreamReader reader = new StreamReader(stream, Encoding.UTF8)) {
                            string rawData = reader.ReadToEnd().Trim();

                            if (rawData.Contains("<!DOCTYPE html>")) {
                                splash.SetStatus("SERVER CONFIG ERROR", Color.Red);
                                MessageBox.Show("Error: The Update Server returned HTML instead of data.");
                                Environment.Exit(0);
                            }

                            string[] lines = rawData.Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);

                            if (lines.Length >= 2) {
                                string onlineVersion = lines[0].Trim();
                                string downloadUrl = lines[1].Trim();

                                splash.SetStatus("VERIFYING: " + onlineVersion + " vs " + Config.APP_VERSION, Color.Gray);
                                Thread.Sleep(1000); 

                                if (onlineVersion != Config.APP_VERSION) {
                                    splash.SetStatus("FOUND NEW UPDATE: " + onlineVersion, AppTheme.Primary);
                                    Thread.Sleep(1500);
                                    splash.Hide();
                                    Application.Run(new UpdateForm(onlineVersion, downloadUrl));
                                    Environment.Exit(0);
                                }
                            }
                        }
                    }
                }
                splash.SetStatus("SYSTEM UP TO DATE", Color.Green);
                Thread.Sleep(800);
            } catch (Exception ex) {
                splash.SetStatus("CONNECTION FAILED", Color.Red);
                Thread.Sleep(1000);
                Environment.Exit(0); 
            }
        }
    }

    public class UpdateForm : Form {
        private string _url;
        private Label lblStatus;
        private Button btnUpdate;

        public UpdateForm(string newVer, string url) {
            this._url = url;
            this.Text = "Update Required"; this.Size = new Size(400, 250);
            this.StartPosition = FormStartPosition.CenterScreen; this.FormBorderStyle = FormBorderStyle.None;
            this.BackColor = AppTheme.Background;
            this.TopMost = true;

            this.Paint += (s, e) => { 
                ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); 
                using (LinearGradientBrush br = new LinearGradientBrush(this.ClientRectangle, Color.White, AppTheme.InputBg, 90f)) {
                    e.Graphics.FillRectangle(br, 1, 1, Width-2, Height-2);
                }
            };

            Label lblTitle = new Label() { Text = "NEW UPDATE AVAILABLE", Location = new Point(0, 30), Size = new Size(400, 40), TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 16, FontStyle.Bold), ForeColor = AppTheme.Primary, BackColor = Color.Transparent };
            Label lblDesc = new Label() { Text = "Version " + newVer + " is available.\nClick Update to download and run the installer.", Location = new Point(20, 80), Size = new Size(360, 50), TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 10), ForeColor = AppTheme.TextDark, BackColor = Color.Transparent };
            
            lblStatus = new Label() { Text = "Update Required to Proceed", Location = new Point(0, 140), Size = new Size(400, 20), TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 9, FontStyle.Italic), ForeColor = Color.Gray, BackColor = Color.Transparent };

            btnUpdate = new Button() { Text = "DOWNLOAD & INSTALL", Location = new Point(50, 170), Size = new Size(300, 45), BackColor = AppTheme.Primary, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 11, FontStyle.Bold) };
            btnUpdate.FlatAppearance.BorderSize = 0; 
            btnUpdate.Click += BtnUpdate_Click;

            this.Controls.Add(lblTitle); this.Controls.Add(lblDesc); this.Controls.Add(lblStatus); this.Controls.Add(btnUpdate);
        }

        private async void BtnUpdate_Click(object sender, EventArgs e) {
            btnUpdate.Enabled = false;
            lblStatus.Text = "Downloading Installer... Please Wait.";
            lblStatus.ForeColor = AppTheme.Primary;

            await Task.Run(() => {
                try {
                    ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;

                    // UPDATED: Save to TEMP instead of Desktop
                    string tempDir = Path.GetTempPath();
                    string filename = "Knox_Update_Setup.exe"; 
                    string savePath = Path.Combine(tempDir, filename);

                    // Delete if exists from previous attempt
                    if (File.Exists(savePath)) File.Delete(savePath);

                    using (WebClient wc = new WebClient()) {
                        wc.Headers.Add("User-Agent", "KnoxWizardUpdater");
                        wc.DownloadFile(_url, savePath);
                    }

                    this.Invoke(new Action(() => {
                        lblStatus.Text = "Download Complete. Launching...";
                        lblStatus.ForeColor = Color.Green;
                        
                        // Launch the Installer
                        try {
                            Process.Start(savePath);
                        } catch {
                            MessageBox.Show("Failed to launch installer automatically.\nPlease go to %TEMP% and run " + filename);
                        }
                        
                        // Close THIS app so the installer can overwrite files
                        Application.Exit();
                    }));
                } catch (Exception ex) {
                    this.Invoke(new Action(() => {
                        lblStatus.Text = "Error: " + ex.Message;
                        lblStatus.ForeColor = Color.Red;
                        btnUpdate.Enabled = true;
                    }));
                }
            });
        }
    }

    public static class SecurityGuard {
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, ref bool isDebuggerPresent);
        public static bool IsSafe() {
            try {
                if (Debugger.IsAttached) return false;
                bool isRemoteDebugger = false;
                CheckRemoteDebuggerPresent(Process.GetCurrentProcess().Handle, ref isRemoteDebugger);
                if (isRemoteDebugger) return false;
                return true; 
            } catch { return false; }
        }
    }

    public static class NativeMethods {
        public const int WM_NCLBUTTONDOWN = 0xA1;
        public const int HT_CAPTION = 0x2;
        [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
        [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    }

    public static class AppTheme {
        public static Color Primary = Color.FromArgb(0, 162, 232);      
        public static Color Background = Color.White;                 
        public static Color BackgroundGrad = Color.FromArgb(240, 248, 255); 
        public static Color InputBg = Color.FromArgb(245, 247, 250);  
        public static Color TextDark = Color.FromArgb(64, 64, 64);    
        public static Color TextLight = Color.Gray;                    
        public static Color StopRed = Color.FromArgb(220, 53, 69);    
    }

    // ==========================================
    // 1. LOGIN FORM
    // ==========================================
    public class LoginForm : Form {
        private TextBox txtEmail, txtPassword;
        private Button btnLogin, btnExit;
        private Label lblStatus;
        private CheckBox chkRemember;
        private LinkLabel lnkForgot; 
        public bool IsAuthenticated = false;
        private string configPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "KnoxWizard", "login.conf");

        public LoginForm() {
            if (!SecurityGuard.IsSafe()) { Environment.Exit(0); }
            this.Text = "Knox Wizard License"; this.Size = new Size(350, 310);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = AppTheme.Background; this.FormBorderStyle = FormBorderStyle.None; 
            
            try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch {}

            this.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { NativeMethods.ReleaseCapture(); NativeMethods.SendMessage(Handle, NativeMethods.WM_NCLBUTTONDOWN, NativeMethods.HT_CAPTION, 0); } };
            this.Paint += (s, e) => { ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); };

            Label lblTitle = new Label() { Text = "KNOX WIZARD", Location = new Point(0, 25), Size = new Size(350, 40), TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = AppTheme.Primary };
            lblTitle.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { NativeMethods.ReleaseCapture(); NativeMethods.SendMessage(Handle, NativeMethods.WM_NCLBUTTONDOWN, NativeMethods.HT_CAPTION, 0); } };

            Label lblUser = new Label() { Text = "EMAIL ADDRESS", Location = new Point(40, 80), AutoSize = true, ForeColor = AppTheme.TextLight, Font = new Font("Segoe UI", 8, FontStyle.Bold) };
            txtEmail = new TextBox() { Location = new Point(40, 100), Size = new Size(270, 25), BackColor = AppTheme.InputBg, ForeColor = Color.Black, BorderStyle = BorderStyle.FixedSingle, Font = new Font("Segoe UI", 10) };
            Label lblPass = new Label() { Text = "PASSWORD", Location = new Point(40, 140), AutoSize = true, ForeColor = AppTheme.TextLight, Font = new Font("Segoe UI", 8, FontStyle.Bold) };
            txtPassword = new TextBox() { Location = new Point(40, 160), Size = new Size(270, 25), BackColor = AppTheme.InputBg, ForeColor = Color.Black, BorderStyle = BorderStyle.FixedSingle, PasswordChar = '*', Font = new Font("Segoe UI", 10) };
            
            chkRemember = new CheckBox() { Text = "Remember Me", Location = new Point(40, 195), AutoSize = true, ForeColor = AppTheme.TextLight, Font = new Font("Segoe UI", 9), Cursor = Cursors.Hand, FlatStyle = FlatStyle.Flat };
            
            lnkForgot = new LinkLabel() { Text = "Forgot Password?", Location = new Point(200, 196), AutoSize = true, Font = new Font("Segoe UI", 9), LinkColor = AppTheme.Primary };
            lnkForgot.Click += (s,e) => { new ResetPasswordForm().ShowDialog(); };

            btnLogin = new Button() { Text = "CHECK LICENSE", Location = new Point(40, 230), Size = new Size(130, 40), BackColor = AppTheme.Primary, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            btnLogin.FlatAppearance.BorderSize = 0; btnLogin.Click += BtnLogin_Click;
            
            btnExit = new Button() { Text = "EXIT", Location = new Point(180, 230), Size = new Size(130, 40), BackColor = Color.FromArgb(230, 230, 230), ForeColor = AppTheme.TextDark, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            btnExit.FlatAppearance.BorderSize = 0; btnExit.Click += (s, e) => Application.Exit();
            
            lblStatus = new Label() { Location = new Point(0, 215), Size = new Size(350, 15), TextAlign = ContentAlignment.MiddleCenter, ForeColor = Color.Red, Font = new Font("Segoe UI", 8) };

            this.Controls.Add(lblTitle); this.Controls.Add(lblUser); this.Controls.Add(txtEmail); this.Controls.Add(lblPass); this.Controls.Add(txtPassword); 
            this.Controls.Add(chkRemember); this.Controls.Add(lnkForgot);
            this.Controls.Add(btnLogin); this.Controls.Add(btnExit); this.Controls.Add(lblStatus);
            LoadCredentials();
        }

        private void LoadCredentials() {
            try {
                if (File.Exists(configPath)) {
                    string[] lines = File.ReadAllLines(configPath);
                    if (lines.Length >= 2) { txtEmail.Text = lines[0]; byte[] data = Convert.FromBase64String(lines[1]); txtPassword.Text = Encoding.UTF8.GetString(data); chkRemember.Checked = true; }
                }
            } catch { }
        }

        private void SaveCredentials() {
            try {
                string dir = Path.GetDirectoryName(configPath);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                if (chkRemember.Checked) {
                    string encPass = Convert.ToBase64String(Encoding.UTF8.GetBytes(txtPassword.Text));
                    File.WriteAllLines(configPath, new string[] { txtEmail.Text, encPass });
                } else { if (File.Exists(configPath)) File.Delete(configPath); }
            } catch { }
        }

        private async void BtnLogin_Click(object sender, EventArgs e) {
            string email = txtEmail.Text; string password = txtPassword.Text;
            if(string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password)) { lblStatus.Text = "Credentials Required"; return; }
            
            btnLogin.Enabled = false; 
            lblStatus.ForeColor = Color.Orange; lblStatus.Text = "Connecting to License Server...";
            
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;

            string result = await Task.Run(() => CheckGoogleSheet(email, password));
            
            if (result.StartsWith("SUCCESS")) {
                SaveCredentials();
                string[] parts = result.Split('|');
                if (parts.Length > 1) int.TryParse(parts[1], out Config.DaysRemaining);
                
                lblStatus.ForeColor = AppTheme.Primary; lblStatus.Text = "Access Granted (" + Config.DaysRemaining + " Days)";
                await Task.Delay(800); IsAuthenticated = true; this.Close(); 
            } else if (result == "EXPIRED") {
                lblStatus.ForeColor = Color.Red; lblStatus.Text = "License Expired!"; btnLogin.Enabled = true;
            } else {
                lblStatus.ForeColor = Color.Red; lblStatus.Text = "Invalid Account or Error"; btnLogin.Enabled = true;
            }
        }

        private string CheckGoogleSheet(string email, string password) {
            try {
                using (var client = new WebClient()) {
                    string json = "{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}";
                    client.Headers[HttpRequestHeader.ContentType] = "application/json";
                    return client.UploadString(Config.LICENSE_URL, "POST", json);
                }
            } catch { return "FAIL"; }
        }
    }

    // ==========================================
    // 1.1 RESET PASSWORD FORM
    // ==========================================
    public class ResetPasswordForm : Form {
        private TextBox txtEmail;
        private Button btnSend, btnCancel;
        private Label lblStatus;

        public ResetPasswordForm() {
            this.Text = "Reset Password"; this.Size = new Size(350, 220);
            this.StartPosition = FormStartPosition.CenterParent; this.FormBorderStyle = FormBorderStyle.None;
            this.BackColor = AppTheme.Background;
            
            this.Paint += (s, e) => { ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); };
            this.MouseDown += (s, e) => { if (e.Button == MouseButtons.Left) { NativeMethods.ReleaseCapture(); NativeMethods.SendMessage(Handle, NativeMethods.WM_NCLBUTTONDOWN, NativeMethods.HT_CAPTION, 0); } };

            Label lblTitle = new Label() { Text = "RESET PASSWORD", Location = new Point(0, 15), Size = new Size(350, 30), TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 14, FontStyle.Bold), ForeColor = AppTheme.Primary };
            Label lblDesc = new Label() { Text = "Enter your registered email address:", Location = new Point(40, 50), AutoSize = true, Font = new Font("Segoe UI", 9), ForeColor = AppTheme.TextLight };
            
            txtEmail = new TextBox() { Location = new Point(40, 75), Size = new Size(270, 25), BackColor = AppTheme.InputBg, ForeColor = Color.Black, BorderStyle = BorderStyle.FixedSingle, Font = new Font("Segoe UI", 10) };
            
            lblStatus = new Label() { Location = new Point(0, 105), Size = new Size(350, 20), TextAlign = ContentAlignment.MiddleCenter, ForeColor = AppTheme.TextLight, Font = new Font("Segoe UI", 8) };

            btnSend = new Button() { Text = "SEND REQUEST", Location = new Point(40, 130), Size = new Size(130, 35), BackColor = AppTheme.Primary, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            btnSend.FlatAppearance.BorderSize = 0; btnSend.Click += BtnSend_Click;

            btnCancel = new Button() { Text = "CANCEL", Location = new Point(180, 130), Size = new Size(130, 35), BackColor = Color.FromArgb(230, 230, 230), ForeColor = AppTheme.TextDark, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            btnCancel.FlatAppearance.BorderSize = 0; btnCancel.Click += (s, e) => this.Close();

            this.Controls.Add(lblTitle); this.Controls.Add(lblDesc); this.Controls.Add(txtEmail); this.Controls.Add(lblStatus); this.Controls.Add(btnSend); this.Controls.Add(btnCancel);
        }

        private async void BtnSend_Click(object sender, EventArgs e) {
            string email = txtEmail.Text;
            if(string.IsNullOrEmpty(email)) { lblStatus.Text = "Email required."; lblStatus.ForeColor = Color.Red; return; }
            
            btnSend.Enabled = false; lblStatus.Text = "Sending request..."; lblStatus.ForeColor = AppTheme.Primary;
            
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;

            string result = await Task.Run(() => SendResetRequest(email));
            
            if(result == "SUCCESS") {
                lblStatus.Text = "Reset link sent! Check email."; lblStatus.ForeColor = Color.Green;
                await Task.Delay(2000); this.Close();
            } else {
                lblStatus.Text = "Failed. Email not found/Error."; lblStatus.ForeColor = Color.Red;
                btnSend.Enabled = true;
            }
        }

        private string SendResetRequest(string email) {
            try {
                using (var client = new WebClient()) {
                    string json = "{\"action\":\"reset\",\"email\":\"" + email + "\"}";
                    client.Headers[HttpRequestHeader.ContentType] = "application/json";
                    string response = client.UploadString(Config.LICENSE_URL, "POST", json); 
                    if(response.Contains("SUCCESS") || response.Contains("OK")) return "SUCCESS";
                    return "FAIL";
                }
            } catch { return "FAIL"; }
        }
    }

    // ==========================================
    // 2. CUSTOM CONTROLS
    // ==========================================
    public class KnoxButton : Button {
        public KnoxButton() {
            this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; 
            this.BackColor = AppTheme.Primary; this.ForeColor = Color.White; 
            this.Cursor = Cursors.Hand; this.Font = new Font("Segoe UI", 9, FontStyle.Bold); 
            this.TextAlign = ContentAlignment.MiddleCenter;
            this.MouseEnter += (s, e) => { this.BackColor = ControlPaint.Light(AppTheme.Primary); }; 
            this.MouseLeave += (s, e) => { this.BackColor = AppTheme.Primary; };
        }
    }
    
    public class KnoxGroupPanel : Panel {
        public string Title { get; set; }
        public KnoxGroupPanel() { 
            this.Title = "Group"; this.ForeColor = AppTheme.TextDark; this.Font = new Font("Segoe UI", 9); 
            this.BackColor = Color.Transparent; this.Padding = new Padding(1);
            this.SetStyle(ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.DoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e); Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.None;
            
            int textY = 20; 
            SizeF titleSize = g.MeasureString(this.Title, this.Font);
            int borderY = textY + (int)(titleSize.Height / 2); 
            int textX = 15; int w = this.Width - 1; int h = this.Height - 1;
            
            using(Pen p = new Pen(AppTheme.Primary)) {
                g.DrawLine(p, 0, borderY, textX, borderY);
                g.DrawLine(p, textX + (int)titleSize.Width + 4, borderY, w, borderY);
                g.DrawLine(p, w, borderY, w, h);
                g.DrawLine(p, w, h, 0, h);
                g.DrawLine(p, 0, h, 0, borderY);
            }
            using(Brush b = new SolidBrush(this.ForeColor)) { g.DrawString(this.Title, this.Font, b, textX + 2, textY); }
        }
    }

    public class KnoxPopup : Form {
        public KnoxPopup(string message) {
            this.FormBorderStyle = FormBorderStyle.None; this.Size = new Size(400, 200); 
            this.StartPosition = FormStartPosition.CenterParent; this.Padding = new Padding(2); this.TopMost = true; 
            this.BackColor = AppTheme.Background;
            this.Paint += (s, e) => { 
                 using (LinearGradientBrush br = new LinearGradientBrush(this.ClientRectangle, AppTheme.Background, AppTheme.BackgroundGrad, 45f)) { e.Graphics.FillRectangle(br, this.ClientRectangle); }
                 ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); 
            };
            Label lblMsg = new Label { Text = message, Dock = DockStyle.Top, Height = 100, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 11), ForeColor = AppTheme.TextDark, BackColor = Color.Transparent }; this.Controls.Add(lblMsg);
            KnoxButton btnOk = new KnoxButton { Text = "OK", Size = new Size(120, 35), Location = new Point(140, 140) }; btnOk.Click += (s, e) => { this.Close(); }; this.Controls.Add(btnOk);
        }
    }
    
    public class KnoxConfirmPopup : Form {
        public KnoxConfirmPopup(string title, string message) {
            this.FormBorderStyle = FormBorderStyle.None; this.Size = new Size(450, 250); this.StartPosition = FormStartPosition.CenterParent; this.TopMost = true; this.BackColor = AppTheme.Background;
            this.Paint += (s, e) => { 
                using (LinearGradientBrush br = new LinearGradientBrush(this.ClientRectangle, AppTheme.Background, AppTheme.BackgroundGrad, 45f)) { e.Graphics.FillRectangle(br, this.ClientRectangle); }
                ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); 
            };
            Panel pnlBtns = new Panel { Dock = DockStyle.Bottom, Height = 60, BackColor = Color.Transparent };
            KnoxButton btnYes = new KnoxButton { Text = "CONTINUE", Size = new Size(120, 35), Location = new Point(80, 10) }; btnYes.Click += (s,e) => { this.DialogResult = DialogResult.Yes; this.Close(); };
            Button btnNo = new Button { Text = "CANCEL", Size = new Size(120, 35), Location = new Point(250, 10), FlatStyle = FlatStyle.Flat, ForeColor = AppTheme.TextLight, BackColor = Color.Transparent, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            btnNo.FlatAppearance.BorderSize = 0; btnNo.Click += (s,e) => { this.DialogResult = DialogResult.No; this.Close(); };
            pnlBtns.Controls.Add(btnYes); pnlBtns.Controls.Add(btnNo); this.Controls.Add(pnlBtns);
            Label lblMsg = new Label { Text = message, Dock = DockStyle.Top, Height = 80, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 10), ForeColor = AppTheme.TextDark, BackColor = Color.Transparent }; this.Controls.Add(lblMsg);
            Label lblTitle = new Label { Text = title, Dock = DockStyle.Top, Height = 40, TextAlign = ContentAlignment.BottomCenter, Font = new Font("Segoe UI", 14, FontStyle.Bold), ForeColor = AppTheme.Primary, BackColor = Color.Transparent }; this.Controls.Add(lblTitle);
        }
    }

    public class KnoxAuthPopup : Form {
        public KnoxAuthPopup() {
            this.FormBorderStyle = FormBorderStyle.None; this.Size = new Size(450, 180); this.StartPosition = FormStartPosition.CenterParent; this.TopMost = true; this.BackColor = AppTheme.Background;
            this.Paint += (s, e) => { ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, Color.Orange, ButtonBorderStyle.Solid); };
            Label lblMsg = new Label { Text = "AUTHORIZATION REQUIRED\n\nCheck phone screen.\nTap 'ALLOW' on ADB Prompt.", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 12), ForeColor = Color.Orange, BackColor = Color.Transparent }; this.Controls.Add(lblMsg);
        }
    }

    // ==========================================
    // 3. MAIN APPLICATION
    // ==========================================
    public class KnoxMain : Form {
        
        private Panel pnlHeader, pnlNavBar, pnlMainContainer, pnlLeftPane, pnlRightPane;
        private Button btnClose, btnMin;
        private Label lblTitle;
        private Button btnNavPatch, btnNavSpdMtk, btnNavSamsung, btnNavZte, btnNavHmd, btnNavMtp, btnNavAdb, btnNavFastboot;
        private RichTextBox rtbConsole;
        private Button btnStop; 

        private Panel pnlViewPatch, pnlViewSpdMtk, pnlViewSamsung, pnlViewZte, pnlViewHmd, pnlViewMtp, pnlViewAdb, pnlViewFastboot;
        
        private Label lblFile1, lblFile2, lblFile3;
        private KnoxButton btnPatchStandard, btnPatchSuper, btnPatchUniversal;
        private ProgressBar progBarSuper;
        private KnoxButton btnSpd2025, btnAnonyShu, btnBlackScreen, btnAutoReset, btnAdb;
        private KnoxButton btnSamsungBypass, btnMtp, btnFastboot;
        private KnoxButton btnHmdBypass;
        private KnoxButton btnSamsungA06; 

        private string currentFilePathStandard = "";
        private string currentFilePathSuper = "";
        private string currentFilePathUniversal = "";
        private bool isMonitoring = true;
        private volatile string _cachedDeviceStatus = "none";
        private volatile bool _stopRequested = false;

        private string FP_HEX = "5B 92 8D EC EB 97 78 57 AF C2 58 CD 53 E6 A8 D2"; 
        private string SEC_HEX = "53 65 63 75 72 69 74 79 43 6F 6D 2E 61 70 6B"; 
        private string PCS_HEX = "50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 2E 6F 64 65 78 50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 2E 76 64 65 78";
        private string SEC_ODEX_HEX = "53 65 63 75 72 69 74 79 43 6F 6D 2E 6F 64 65 78 53 65 63 75 72 69 74 79 43 6F 6D 2E 76 64 65 78";
        private string PCS_APKOAT_HEX = "50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 2E 61 70 6B 6F 61 74";
        private string PRIV_APP_HEX = "70 72 69 76 2D 61 70 70 2F 50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65";
        private string PROD_SEC_HEX = "2F 70 72 6F 64 75 63 74 2F 70 72 69 76 2D 61 70 70 2F 53 65 63 75 72 69 74 79 43 6F 6D";
        private string YYYY_MARKER = "FF FF FF FF";
        private string FP_START = "PK";
        private string FP_END = "META-INF/MANIFEST.MFPK";

        public KnoxMain() {
            this.Text = "Knox Wizard V" + Config.APP_VERSION;
            this.FormBorderStyle = FormBorderStyle.None;
            this.Size = new Size(960, 600); 
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = AppTheme.Background;
            this.Padding = new Padding(1); 
            
            try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch {}

            this.Paint += (s, e) => { 
                using (LinearGradientBrush br = new LinearGradientBrush(this.ClientRectangle, AppTheme.Background, AppTheme.BackgroundGrad, 90f)) { e.Graphics.FillRectangle(br, this.ClientRectangle); }
                ControlPaint.DrawBorder(e.Graphics, this.ClientRectangle, AppTheme.Primary, ButtonBorderStyle.Solid); 
            };

            InitializeUI();
            InitializePatchView();
            InitializeSpdMtkView();
            InitializeSamsungView();
            InitializeZteView();
            InitializeHmdView();
            InitializeMtpView();
            InitializeAdbView();
            InitializeFastbootView();
            
            SwitchView("PATCH");
            
            Log("Welcome to Knox Wizard V" + Config.APP_VERSION, AppTheme.Primary);
            Log("License Active. Days Remaining: " + Config.DaysRemaining, Color.Green);
            Log("Service Workspace Initialized.", Color.Green);
            
            Task.Run(() => StartLiveMonitor());
        }

        protected override void OnFormClosing(FormClosingEventArgs e) { isMonitoring = false; base.OnFormClosing(e); }

        private void InitializeUI() {
            pnlHeader = new Panel { Dock = DockStyle.Top, Height = 40, BackColor = Color.Transparent };
            MouseEventHandler dragHandler = (s, e) => { if (e.Button == MouseButtons.Left) { NativeMethods.ReleaseCapture(); NativeMethods.SendMessage(Handle, NativeMethods.WM_NCLBUTTONDOWN, NativeMethods.HT_CAPTION, 0); } };
            pnlHeader.MouseDown += dragHandler;

            lblTitle = new Label { Text = "KNOX WIZARD", AutoSize = true, Location = new Point(15, 10), ForeColor = AppTheme.Primary, Font = new Font("Segoe UI", 12, FontStyle.Bold) };
            lblTitle.MouseDown += dragHandler;

            btnMin = new Button { Text = "_", Dock = DockStyle.Right, Width = 40, FlatStyle = FlatStyle.Flat, ForeColor = AppTheme.Primary, BackColor = Color.Transparent }; btnMin.FlatAppearance.BorderSize = 0; btnMin.Click += (s, e) => { this.WindowState = FormWindowState.Minimized; };
            btnClose = new Button { Text = "X", Dock = DockStyle.Right, Width = 40, FlatStyle = FlatStyle.Flat, ForeColor = AppTheme.Primary, BackColor = Color.Transparent }; btnClose.FlatAppearance.BorderSize = 0; btnClose.Click += (s, e) => Application.Exit();
            pnlHeader.Controls.Add(lblTitle); pnlHeader.Controls.Add(btnMin); pnlHeader.Controls.Add(btnClose);
            
            pnlNavBar = new Panel { Dock = DockStyle.Top, Height = 35, BackColor = Color.Transparent, Padding = new Padding(15,0,0,0) };
            btnNavPatch = CreateNavButton("PATCH"); btnNavSpdMtk = CreateNavButton("MTK/SPD"); btnNavSamsung = CreateNavButton("SAMSUNG"); btnNavZte = CreateNavButton("ZTE"); btnNavHmd = CreateNavButton("HMD");
            btnNavMtp = CreateNavButton("MTP"); btnNavAdb = CreateNavButton("ADB"); btnNavFastboot = CreateNavButton("FASTBOOT");

            btnNavPatch.Click += (s,e) => SwitchView("PATCH");
            btnNavSpdMtk.Click += (s,e) => SwitchView("SPD/MTK");
            btnNavSamsung.Click += (s,e) => SwitchView("SAMSUNG");
            btnNavZte.Click += (s,e) => SwitchView("ZTE");
            btnNavHmd.Click += (s,e) => SwitchView("HMD");
            btnNavMtp.Click += (s,e) => SwitchView("MTP");
            btnNavAdb.Click += (s,e) => SwitchView("ADB");
            btnNavFastboot.Click += (s,e) => SwitchView("FASTBOOT");

            pnlNavBar.Controls.Clear();
            pnlNavBar.Controls.Add(btnNavFastboot);
            pnlNavBar.Controls.Add(btnNavAdb);
            pnlNavBar.Controls.Add(btnNavMtp);
            pnlNavBar.Controls.Add(btnNavHmd);
            pnlNavBar.Controls.Add(btnNavZte);
            pnlNavBar.Controls.Add(btnNavSamsung);
            pnlNavBar.Controls.Add(btnNavSpdMtk);
            pnlNavBar.Controls.Add(btnNavPatch); 

            pnlMainContainer = new Panel { Dock = DockStyle.Fill, Padding = new Padding(10), BackColor = Color.Transparent };
            pnlRightPane = new Panel { Dock = DockStyle.Right, Width = 480, Padding = new Padding(10, 0, 0, 20), BackColor = Color.Transparent };
            
            Label lblConsoleHeader = new Label { Text = "Console", Dock = DockStyle.Top, Height = 25, ForeColor = AppTheme.TextDark, Font = new Font("Consolas", 10, FontStyle.Bold) };
            rtbConsole = new RichTextBox { Dock = DockStyle.Fill, BackColor = AppTheme.InputBg, ForeColor = Color.Black, Font = new Font("Consolas", 9), BorderStyle = BorderStyle.None, ReadOnly = true };
            
            Panel pnlStopContainer = new Panel { Dock = DockStyle.Bottom, Height = 45, BackColor = Color.Transparent, Padding = new Padding(0,5,0,0) };
            btnStop = new Button { Text = "STOP", Dock = DockStyle.Right, Width = 100, FlatStyle = FlatStyle.Flat, BackColor = AppTheme.StopRed, ForeColor = Color.White, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            btnStop.FlatAppearance.BorderSize = 0;
            btnStop.Click += BtnStop_Click;
            pnlStopContainer.Controls.Add(btnStop);

            pnlRightPane.Controls.Add(rtbConsole); pnlRightPane.Controls.Add(lblConsoleHeader); pnlRightPane.Controls.Add(pnlStopContainer);

            pnlLeftPane = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent }; 
            
            Label lblDev = new Label { 
                Text = "Developed by X-TEK WIZARD | License Days: " + Config.DaysRemaining, 
                Dock = DockStyle.Bottom, 
                Height = 25, 
                TextAlign = ContentAlignment.BottomLeft, 
                ForeColor = Color.Silver, 
                Font = new Font("Segoe UI", 7, FontStyle.Bold),
                Padding = new Padding(15, 0, 0, 8),
                BackColor = Color.Transparent
            };
            pnlLeftPane.Controls.Add(lblDev);

            Label lblWorkspace = new Label { Text = "Service Workspace", Dock = DockStyle.Top, Height = 30, TextAlign = ContentAlignment.TopCenter, ForeColor = AppTheme.TextLight, Font = new Font("Segoe UI", 10) };
            pnlLeftPane.Controls.Add(lblWorkspace);

            pnlMainContainer.Controls.Add(pnlLeftPane); pnlMainContainer.Controls.Add(pnlRightPane); 

            this.Controls.Add(pnlMainContainer); this.Controls.Add(pnlNavBar); this.Controls.Add(pnlHeader);
        }

        private Button CreateNavButton(string text) {
            Button btn = new Button(); btn.Text = text; btn.Dock = DockStyle.Left; btn.Width = 80; 
            btn.FlatStyle = FlatStyle.Flat; btn.FlatAppearance.BorderSize = 0; btn.BackColor = Color.Transparent; btn.ForeColor = AppTheme.TextLight; btn.Font = new Font("Segoe UI", 8, FontStyle.Bold); btn.Cursor = Cursors.Hand;
            return btn;
        }

        private void SwitchView(string view) {
            if(pnlViewPatch != null) pnlViewPatch.Visible = false; if(pnlViewSpdMtk != null) pnlViewSpdMtk.Visible = false; if(pnlViewSamsung != null) pnlViewSamsung.Visible = false; if(pnlViewZte != null) pnlViewZte.Visible = false; if(pnlViewHmd != null) pnlViewHmd.Visible = false;
            if(pnlViewMtp != null) pnlViewMtp.Visible = false; if(pnlViewAdb != null) pnlViewAdb.Visible = false; if(pnlViewFastboot != null) pnlViewFastboot.Visible = false;

            btnNavPatch.ForeColor = AppTheme.TextLight; btnNavSpdMtk.ForeColor = AppTheme.TextLight; btnNavSamsung.ForeColor = AppTheme.TextLight; btnNavZte.ForeColor = AppTheme.TextLight; btnNavHmd.ForeColor = AppTheme.TextLight;
            btnNavMtp.ForeColor = AppTheme.TextLight; btnNavAdb.ForeColor = AppTheme.TextLight; btnNavFastboot.ForeColor = AppTheme.TextLight;

            switch(view) {
                case "PATCH": pnlViewPatch.Visible = true; btnNavPatch.ForeColor = AppTheme.Primary; break;
                case "SPD/MTK": pnlViewSpdMtk.Visible = true; btnNavSpdMtk.ForeColor = AppTheme.Primary; break;
                case "SAMSUNG": pnlViewSamsung.Visible = true; btnNavSamsung.ForeColor = AppTheme.Primary; break;
                case "ZTE": pnlViewZte.Visible = true; btnNavZte.ForeColor = AppTheme.Primary; break;
                case "HMD": pnlViewHmd.Visible = true; btnNavHmd.ForeColor = AppTheme.Primary; break;
                case "MTP": pnlViewMtp.Visible = true; btnNavMtp.ForeColor = AppTheme.Primary; break;
                case "ADB": pnlViewAdb.Visible = true; btnNavAdb.ForeColor = AppTheme.Primary; break;
                case "FASTBOOT": pnlViewFastboot.Visible = true; btnNavFastboot.ForeColor = AppTheme.Primary; break;
            }
        }
        
        private void Log(string text, Color color) {
            if (rtbConsole.InvokeRequired) { rtbConsole.Invoke(new Action(() => Log(text, color))); return; }
            rtbConsole.SelectionStart = rtbConsole.TextLength;
            rtbConsole.SelectionLength = 0;
            rtbConsole.SelectionColor = color;
            rtbConsole.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + text + "\n");
            rtbConsole.ScrollToCaret();
        }

        private void BtnStop_Click(object sender, EventArgs e) {
            _stopRequested = true;
            Log("!!! OPERATION STOPPED BY USER !!!", AppTheme.StopRed);
            try { foreach (Process p in Process.GetProcessesByName("adb")) { p.Kill(); } } catch {}
            try { foreach (Process p in Process.GetProcessesByName("fastboot")) { p.Kill(); } } catch {}
        }

        // --- VIEW INITIALIZERS ---
        private void InitializePatchView() {
            pnlViewPatch = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(20) };
            
            KnoxGroupPanel grpMisc = new KnoxGroupPanel { Title = " Miscdata / Proinfo Edit ", Location = new Point(20, 10), Size = new Size(400, 120) };
            
            lblFile1 = new Label { Text = "No File Loaded", Location = new Point(15, 60), Size = new Size(220, 20), ForeColor = AppTheme.TextLight };
            btnPatchStandard = new KnoxButton { Text = "LOAD FILE", Location = new Point(240, 55), Size = new Size(140, 35) }; btnPatchStandard.Click += BtnPatchStandard_Click;
            
            grpMisc.Controls.Add(lblFile1); grpMisc.Controls.Add(btnPatchStandard);

            KnoxGroupPanel grpSuper = new KnoxGroupPanel { Title = " Super.img Patch ", Location = new Point(20, 140), Size = new Size(400, 150) };
            
            lblFile2 = new Label { Text = "No File Loaded", Location = new Point(15, 60), Size = new Size(220, 20), ForeColor = AppTheme.TextLight };
            btnPatchSuper = new KnoxButton { Text = "LOAD SUPER", Location = new Point(240, 55), Size = new Size(140, 35) }; btnPatchSuper.Click += BtnPatchSuper_Click;
            
            progBarSuper = new ProgressBar { Location = new Point(15, 110), Size = new Size(370, 10) };
            grpSuper.Controls.Add(lblFile2); grpSuper.Controls.Add(btnPatchSuper); grpSuper.Controls.Add(progBarSuper);
            
            // --- NEW: UNIVERSAL PATCH (MTK/SPD) ---
            KnoxGroupPanel grpUniversal = new KnoxGroupPanel { Title = " Universal Patch (MTK/SPD) ", Location = new Point(20, 310), Size = new Size(400, 120) };
            
            lblFile3 = new Label { Text = "No File Loaded", Location = new Point(15, 60), Size = new Size(220, 20), ForeColor = AppTheme.TextLight };
            btnPatchUniversal = new KnoxButton { Text = "LOAD UNIVERSAL", Location = new Point(240, 55), Size = new Size(140, 35) }; 
            btnPatchUniversal.Click += BtnPatchUniversal_Click;

            grpUniversal.Controls.Add(lblFile3); grpUniversal.Controls.Add(btnPatchUniversal);

            pnlViewPatch.Controls.Add(grpMisc); pnlViewPatch.Controls.Add(grpSuper); pnlViewPatch.Controls.Add(grpUniversal);
            pnlLeftPane.Controls.Add(pnlViewPatch);
        }

        private async void BtnPatchUniversal_Click(object sender, EventArgs e) {
            OpenFileDialog dlg = new OpenFileDialog { Filter = "System Files|*.img;*.bin|All Files|*.*" };
            if (dlg.ShowDialog() != DialogResult.OK) return;
            currentFilePathUniversal = dlg.FileName; lblFile3.Text = Path.GetFileName(currentFilePathUniversal);
            
            Log("Universal Patch File Loaded: " + currentFilePathUniversal, Color.Black);
            btnPatchUniversal.Enabled = false;

            UniversalPatcher patcher = new UniversalPatcher();
            Log("Starting Universal MTK/SPD Algorithm...", AppTheme.Primary);
            
            // Redirect console output is not easy in WinForms without pipes, so we rely on Task result
            await patcher.ExecuteUniversalPatch(currentFilePathUniversal);
            
            Log("Universal Patch Completed (Check backup file).", Color.Green);
            using (KnoxPopup p = new KnoxPopup("Universal Patch Finished!")) { p.ShowDialog(this); }
            
            btnPatchUniversal.Enabled = true;
        }

        private void InitializeSpdMtkView() {
            pnlViewSpdMtk = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(30) };
            KnoxGroupPanel grpBox = new KnoxGroupPanel { Title = " MTK/SPD ADB Tools ", Location = new Point(20, 10), Size = new Size(400, 400) };
            
            int y = 60; int gap = 50; int w = 320; int h = 40; int x = 40;
            
            btnAdb = new KnoxButton { Text = "ADB Detect", Location = new Point(x, y), Size = new Size(w, h) }; btnAdb.Click += BtnGenericFix_Click;
            
            btnSpd2025 = new KnoxButton { Text = "Security Plugin Remove 2024/2025", Location = new Point(x, y + gap), Size = new Size(w, h) }; 
            btnSpd2025.Click += BtnSamsungBypass_Click;

            btnAnonyShu = new KnoxButton { Text = "Tecno/Infinix/Itel MDM Remove (AnonyShu)", Location = new Point(x, y + gap*2), Size = new Size(w, h) }; btnAnonyShu.Click += BtnBypassAction_Click;
            btnBlackScreen = new KnoxButton { Text = "Disable Factory Reset / Black Screen Fix", Location = new Point(x, y + gap*3), Size = new Size(w, h) }; btnBlackScreen.Click += BtnGenericFix_Click;
            btnAutoReset = new KnoxButton { Text = "ADB FRP Remove", Location = new Point(x, y + gap*4), Size = new Size(w, h) }; btnAutoReset.Click += BtnGenericFix_Click;
            
            grpBox.Controls.Add(btnAdb); grpBox.Controls.Add(btnSpd2025); grpBox.Controls.Add(btnAnonyShu); grpBox.Controls.Add(btnBlackScreen); grpBox.Controls.Add(btnAutoReset);
            pnlViewSpdMtk.Controls.Add(grpBox); pnlLeftPane.Controls.Add(pnlViewSpdMtk);
        }

        private void InitializeSamsungView() {
            pnlViewSamsung = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(30) };
            KnoxGroupPanel grpBox = new KnoxGroupPanel { Title = " Samsung Knox Tools ", Location = new Point(20, 10), Size = new Size(400, 400) };
            
            int y = 60; int gap = 50; int w = 320; int h = 40; int x = 40;
            
            btnSamsungBypass = new KnoxButton { Text = "Samsung KG Bypass 2025", Location = new Point(x, y), Size = new Size(w, h) }; btnSamsungBypass.Click += BtnSamsungBypass_Click;
            
            btnMtp = new KnoxButton { Text = "MTP Browser Launch", Location = new Point(40, y + gap), Size = new Size(150, h) }; btnMtp.Click += BtnGenericFix_Click;
            btnFastboot = new KnoxButton { Text = "Exit Fastboot", Location = new Point(210, y + gap), Size = new Size(150, h) }; btnFastboot.Click += BtnGenericFix_Click;
            
            grpBox.Controls.Add(btnSamsungBypass); grpBox.Controls.Add(btnMtp); grpBox.Controls.Add(btnFastboot);
            pnlViewSamsung.Controls.Add(grpBox); pnlLeftPane.Controls.Add(pnlViewSamsung);
        }

        private void InitializeZteView() {
            pnlViewZte = new Panel { Dock = DockStyle.Fill, Visible = false };
            Label lbl = new Label { Text = "ZTE MODULE\n\nConnect device in ADB Mode", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, ForeColor = AppTheme.TextLight, Font = new Font("Segoe UI", 12) };
            pnlViewZte.Controls.Add(lbl); pnlLeftPane.Controls.Add(pnlViewZte);
        }
        
        private void InitializeHmdView() {
            pnlViewHmd = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(30) };
            KnoxGroupPanel grpHmd = new KnoxGroupPanel { Title = " Nokia / HMD Tools ", Location = new Point(20, 10), Size = new Size(400, 200) };
            
            btnHmdBypass = new KnoxButton { Text = "Nokia 2024 Bypass", Location = new Point(40, 60), Size = new Size(320, 40) };
            btnHmdBypass.Click += BtnHmdBypass_Click;
            
            grpHmd.Controls.Add(btnHmdBypass);
            pnlViewHmd.Controls.Add(grpHmd);
            pnlLeftPane.Controls.Add(pnlViewHmd);
        }

        private async void BtnHmdBypass_Click(object sender, EventArgs e) {
            Button btn = (Button)sender;
            string hmdApk = Path.Combine(Application.StartupPath, "Package_Disabler_Pro_v12.8_98.apk");
            if (!File.Exists(hmdApk)) {
                Log("Error: Package_Disabler_Pro_v12.8_98.apk missing!", Color.Red);
                using (KnoxPopup p = new KnoxPopup("Missing APK File!\nPlace Package_Disabler_Pro in folder.")) { p.ShowDialog(this); }
                return;
            }
            DialogResult dr = new KnoxConfirmPopup("NOKIA BYPASS", "Start Nokia 2024 Bypass?\nEnsure USB Debugging is ON.").ShowDialog(this);
            if (dr != DialogResult.Yes) return;
            btn.Enabled = false; _stopRequested = false;
            Log("Starting Nokia 2024 Bypass Sequence...", AppTheme.Primary);
            try {
                await Task.Run(() => {
                    RunAdb("kill-server", false); RunAdb("start-server", false);
                    Log("Waiting for device...", Color.Gray);
                    RunAdb("wait-for-device", false);
                    if(_stopRequested) throw new Exception("Stopped");
                    Log("Installing Package Disabler...", Color.Blue);
                    RunAdb("install -r \"" + hmdApk + "\"", false);
                    Log("Disabling initial packages...", Color.Gray);
                    RunAdb("shell pm disable-user com.hmdglobal.app.activation", false);
                    RunAdb("shell pm disable-user com.hmdglobal.app.customizationclient", false);
                    Log("Launching Device Admin Settings...", Color.Gray);
                    RunAdb("shell am start -S \"com.android.settings/.Settings$DeviceAdminSettingsActivity\"", false);
                    Log("Removing old admin & setting new owner...", Color.Blue);
                    RunAdb("shell dpm remove-active-admin com.hmdglobal.app.devicelock/com.hmdglobal.app.devicelock.MyDeviceAdminReceiver", false);
                    RunAdb("shell dpm set-device-owner com.pdp.deviceowner/.receivers.AdminReceiver", false);
                    RunAdb("shell pm disable-user com.hmdglobal.app.activation.overlay", false);
                });
                Log("Nokia Bypass Execution Complete.", Color.Green);
                this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("Bypass Script Finished!\nEnjoy.")) { p.ShowDialog(this); } }));
            } catch (Exception ex) { Log("Bypass Failed or Cancelled: " + ex.Message, Color.Red); }
            btn.Enabled = true;
        }
        
        private void InitializeMtpView() {
            pnlViewMtp = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(30) };
            KnoxGroupPanel grpMtp = new KnoxGroupPanel { Title = " MTP Device Info ", Location = new Point(20, 10), Size = new Size(400, 160) };
            Label lblHint = new Label { Text = "Connect device via USB.\nEnsure MTP mode is active.", Location = new Point(20, 40), Size = new Size(360, 40), TextAlign = ContentAlignment.MiddleCenter, ForeColor = AppTheme.TextLight };
            KnoxButton btnReadInfo = new KnoxButton { Text = "READ INFO (MTP/MODEM)", Location = new Point(40, 90), Size = new Size(320, 40) };
            btnReadInfo.Click += BtnMtpReadInfo_Click;
            grpMtp.Controls.Add(lblHint); grpMtp.Controls.Add(btnReadInfo);
            pnlViewMtp.Controls.Add(grpMtp); pnlLeftPane.Controls.Add(pnlViewMtp);
        }

        private void BtnMtpReadInfo_Click(object sender, EventArgs e) {
            Button btn = (Button)sender; btn.Enabled = false;
            Log("Scanning for MTP/Portable Devices...", AppTheme.Primary);
            Task.Run(() => {
                try {
                    bool devFound = false;
                    ManagementObjectSearcher searcherPnP = new ManagementObjectSearcher("SELECT * FROM Win32_PnPEntity WHERE (Description LIKE '%MTP%' OR Description LIKE '%Mobile%' OR PnpClass = 'WPD') AND ConfigManagerErrorCode = 0");
                    foreach (ManagementObject device in searcherPnP.Get()) {
                        devFound = true;
                        string name = "Unknown"; if (device["Name"] != null) name = device["Name"].ToString();
                        string manuf = "Unknown"; if (device["Manufacturer"] != null) manuf = device["Manufacturer"].ToString();
                        string deviceId = ""; if (device["DeviceID"] != null) deviceId = device["DeviceID"].ToString();
                        Log("----------------------------", Color.Gray);
                        Log("MTP DEVICE DETECTED", Color.Green);
                        Log("Driver Name: " + name, Color.Black);
                        Log("Manufacturer: " + manuf, Color.Black);
                        if (deviceId.Contains("VID_")) { int vIndex = deviceId.IndexOf("VID_") + 4; if (vIndex + 4 <= deviceId.Length) Log("Vendor ID (VID): " + deviceId.Substring(vIndex, 4), Color.DarkBlue); }
                        if (deviceId.Contains("PID_")) { int pIndex = deviceId.IndexOf("PID_") + 4; if (pIndex + 4 <= deviceId.Length) Log("Product ID (PID): " + deviceId.Substring(pIndex, 4), Color.DarkBlue); }
                    }
                    Log("SCANNING MODEM PORTS...", Color.DarkOrange);
                    ManagementObjectSearcher searcherModem = new ManagementObjectSearcher("SELECT * FROM Win32_POTSModem");
                    foreach (ManagementObject modem in searcherModem.Get()) {
                            string port = ""; if (modem["AttachedTo"] != null) port = modem["AttachedTo"].ToString();
                            if (!string.IsNullOrEmpty(port) && port.StartsWith("COM")) {
                                Log("Found Modem on: " + port, Color.DarkBlue);
                                try {
                                    using (SerialPort sp = new SerialPort(port, 115200, Parity.None, 8, StopBits.One)) {
                                        sp.ReadTimeout = 2000; sp.WriteTimeout = 2000; sp.Open();
                                        sp.WriteLine("AT"); Thread.Sleep(200);
                                        if (sp.ReadExisting().Contains("OK")) {
                                            sp.WriteLine("AT+CGMM"); Thread.Sleep(300);
                                            Log("HARDWARE MODEL: " + sp.ReadExisting().Replace("AT+CGMM", "").Replace("OK", "").Trim(), Color.Magenta);
                                            sp.WriteLine("AT+CGSN"); Thread.Sleep(300);
                                            Log("DEVICE IMEI: " + sp.ReadExisting().Replace("AT+CGSN", "").Replace("OK", "").Trim(), Color.Magenta);
                                        }
                                        sp.Close();
                                    }
                                } catch {}
                            }
                    }
                    if (!devFound) Log("No Devices detected.", Color.Red);
                    else Log("----------------------------", Color.Gray);
                } catch (Exception ex) { Log("Error reading info: " + ex.Message, Color.Red); }
                this.Invoke(new Action(() => btn.Enabled = true));
            });
        }
        
        private void InitializeAdbView() {
            pnlViewAdb = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(30) };
            KnoxGroupPanel grpAdb = new KnoxGroupPanel { Title = " ADB Device Info ", Location = new Point(20, 10), Size = new Size(400, 160) };
            Label lblHint = new Label { Text = "Connect device via USB.\nEnsure USB DEBUGGING is ON.", Location = new Point(20, 40), Size = new Size(360, 40), TextAlign = ContentAlignment.MiddleCenter, ForeColor = AppTheme.TextLight };
            KnoxButton btnReadInfo = new KnoxButton { Text = "READ DEVICE INFO (ADB)", Location = new Point(40, 90), Size = new Size(320, 40) };
            btnReadInfo.Click += BtnAdbReadInfo_Click;
            grpAdb.Controls.Add(lblHint); grpAdb.Controls.Add(btnReadInfo);
            pnlViewAdb.Controls.Add(grpAdb); pnlLeftPane.Controls.Add(pnlViewAdb);
        }

        private void BtnAdbReadInfo_Click(object sender, EventArgs e) {
             Button btn = (Button)sender; btn.Enabled = false;
             Task.Run(() => {
                 try {
                     RunAdb("start-server", true);
                     string adbOut = RunAdb("devices", true);
                     string status = ParseAdbStatus(adbOut);
                     if (status == "unauthorized") {
                         Log("Status: UNAUTHORIZED", Color.Orange);
                         Log("Please check your phone screen and tap 'ALLOW'.", Color.Red);
                         this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("UNAUTHORIZED!\nCheck phone screen.")) { p.ShowDialog(this); } }));
                         this.Invoke(new Action(() => btn.Enabled = true)); return;
                     }
                     if (status != "authorized") {
                         Log("Status: NOT FOUND / OFFLINE", Color.Red); Log("RAW OUTPUT:\n" + adbOut.Trim(), Color.Gray);
                         this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("No Authorized Device Found.")) { p.ShowDialog(this); } }));
                         this.Invoke(new Action(() => btn.Enabled = true)); return;
                     }
                     string model = RunAdb("shell getprop ro.product.model", true).Trim();
                     string manuf = RunAdb("shell getprop ro.product.manufacturer", true).Trim();
                     string androidVer = RunAdb("shell getprop ro.build.version.release", true).Trim();
                     string sdkVer = RunAdb("shell getprop ro.build.version.sdk", true).Trim();
                     string serial = RunAdb("shell getprop ro.serialno", true).Trim();
                     string cpu = RunAdb("shell getprop ro.product.cpu.abi", true).Trim();
                     string region = RunAdb("shell getprop ro.csc.sales_code", true).Trim();
                     string buildNum = RunAdb("shell getprop ro.build.display.id", true).Trim();
                     string baseband = RunAdb("shell getprop gsm.version.baseband", true).Trim();
                     string bootloader = RunAdb("shell getprop ro.boot.bootloader", true).Trim();
                     string secPatch = RunAdb("shell getprop ro.build.version.security_patch", true).Trim();
                     string fingerprint = RunAdb("shell getprop ro.build.fingerprint", true).Trim();
                     string wmSize = RunAdb("shell wm size", true); if(wmSize.Contains("Physical size:")) wmSize = wmSize.Replace("Physical size:", "").Trim();
                     string battDump = RunAdb("shell dumpsys battery", true); string battLevel = "Unknown";
                     if(battDump.Contains("level:")) { int idx = battDump.IndexOf("level:"); if(idx != -1) { int endIdx = battDump.IndexOf("\n", idx); if(endIdx != -1) battLevel = battDump.Substring(idx + 6, endIdx - (idx + 6)).Trim() + "%"; } }
                     Log("==================================", Color.Gray);
                     Log("ADB DEVICE INFO REPORT", Color.Green);
                     Log("Model: " + model, Color.Black);
                     Log("Manufacturer: " + manuf, Color.Black);
                     Log("Android Ver: " + androidVer + " (SDK " + sdkVer + ")", Color.Black);
                     Log("Security Patch: " + secPatch, Color.Black);
                     Log("Build Number: " + buildNum, Color.Black);
                     Log("Baseband/CP: " + baseband, Color.Black);
                     Log("Bootloader: " + bootloader, Color.Black);
                     Log("Serial No: " + serial, Color.Black);
                     Log("CPU Arch: " + cpu, Color.Black);
                     Log("Region/CSC: " + region, Color.Black);
                     Log("Screen Res: " + wmSize, Color.Black);
                     Log("Battery: " + battLevel, Color.Magenta);
                     if(fingerprint.Length > 0) Log("Fingerprint: " + fingerprint.Substring(0, Math.Min(fingerprint.Length, 50)) + "...", Color.DarkGray);
                     Log("==================================", Color.Gray);
                     this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("ADB Read Complete!")) { p.ShowDialog(this); } }));
                 } catch (Exception ex) { Log("Error reading ADB info: " + ex.Message, Color.Red); }
                 this.Invoke(new Action(() => btn.Enabled = true));
             });
        }

        private string ParseAdbStatus(string output) { try { if(string.IsNullOrEmpty(output)) return "none"; string[] lines = output.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries); foreach(string line in lines) { if(line.StartsWith("List of")) continue; if(line.Contains("unauthorized")) return "unauthorized"; if(line.Contains("offline")) return "offline"; if(line.Contains("device") && !line.Contains("no permissions")) return "authorized"; } } catch {} return "none"; }

        private void InitializeFastbootView() {
            pnlViewFastboot = new Panel { Dock = DockStyle.Fill, Visible = false, Padding = new Padding(30) };
            KnoxGroupPanel grpFastboot = new KnoxGroupPanel { Title = " Samsung A065F Tools ", Location = new Point(20, 10), Size = new Size(400, 160) };
            
            btnSamsungA06 = new KnoxButton { Text = "Samsung A065F U1-U3 Reset+FRP Fastboot", Location = new Point(20, 50), Size = new Size(360, 40) };
            btnSamsungA06.Click += BtnSamsungA06Fastboot_Click;
            
            grpFastboot.Controls.Add(btnSamsungA06);
            pnlViewFastboot.Controls.Add(grpFastboot);
            pnlLeftPane.Controls.Add(pnlViewFastboot);
        }

        private void BtnSamsungA06Fastboot_Click(object sender, EventArgs e) {
            Button btn = (Button)sender;
            
            DialogResult dr = new KnoxConfirmPopup("FASTBOOT RESET", "Confirm Samsung A065F Reset?\nDevice MUST be in FASTBOOT Mode.").ShowDialog(this);
            if (dr != DialogResult.Yes) return;

            btn.Enabled = false;
            Log("Starting Samsung A065F Fastboot Reset...", AppTheme.Primary);
            
            Task.Run(() => {
                try {
                    string dev = RunFastboot("devices");
                    if (!dev.Contains("fastboot")) {
                        Log("Error: Device not found in Fastboot Mode.", Color.Red);
                        this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("Device Not Found!\nCheck Fastboot Mode.")) { p.ShowDialog(this); } }));
                        this.Invoke(new Action(() => btn.Enabled = true));
                        return;
                    }
                    Log("Device Detected. Proceeding...", Color.Green);
                    Log("Erasing FRP Partition...", Color.Gray);
                    RunFastboot("erase frp");
                    Log("Erasing Userdata...", Color.Gray);
                    RunFastboot("erase userdata");
                    Log("Formatting Userdata (F2FS)...", Color.Gray);
                    RunFastboot("format:f2fs userdata");
                    Log("Rebooting Device...", Color.Blue);
                    RunFastboot("reboot");
                    Log("Operation Complete.", Color.Green);
                    this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("Reset Successful!")) { p.ShowDialog(this); } }));
                } catch (Exception ex) {
                    Log("Fastboot Error: " + ex.Message, Color.Red);
                }
                this.Invoke(new Action(() => btn.Enabled = true));
            });
        }

        private string RunFastboot(string arguments) {
            if (_stopRequested) throw new Exception("Stopped by User");
            try {
                this.Invoke(new Action(() => Log("> fastboot " + arguments, Color.Gray))); 
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "fastboot.exe"; psi.Arguments = arguments; psi.RedirectStandardOutput = true; psi.UseShellExecute = false; psi.CreateNoWindow = true;
                using (Process p = Process.Start(psi)) { 
                    string output = p.StandardOutput.ReadToEnd(); 
                    p.WaitForExit();
                    return output; 
                }
            } catch { return "ERROR"; }
        }
        
        private async void BtnGenericFix_Click(object sender, EventArgs e) {
            Button b = (Button)sender;
            if(!await CheckDeviceReady()) return;
            _stopRequested = false;
            b.Enabled = false; 
            Log("Starting operation: " + b.Text, AppTheme.Primary);
            await Task.Delay(500); 
            if (_stopRequested) { Log("Operation Cancelled.", Color.Red); b.Enabled = true; return; }
            Log("Operation " + b.Text + " Completed Successfully.", Color.Green);
            using (KnoxPopup p = new KnoxPopup(b.Text + "\nExecuted Successfully.")) { p.ShowDialog(this); }
            b.Enabled = true;
        }

        private async void BtnBypassAction_Click(object sender, EventArgs e) {
            if(!await CheckDeviceReady()) return;
            Log("Starting AnonyShu Bypass Sequence...", AppTheme.Primary);
            string apkPath = Path.Combine(Application.StartupPath, "tool.apk");
            if (!File.Exists(apkPath)) { Log("Error: tool.apk missing", Color.Red); return; }

            _stopRequested = false;
            try {
                await Task.Run(() => {
                    RunAdb("shell settings put global private_dns_mode hostname");
                    RunAdb("shell settings put global private_dns_specifier loan.paymdm.xyz");
                    RunAdb("install -r \"" + apkPath + "\"");
                    RunAdb("shell dpm set-device-owner com.anonyshu.anonyshu/.MyAdminReceiver");
                    RunAdb("shell am start -n com.anonyshu.anonyshu/.MainActivity");
                });
                
                if (_stopRequested) throw new Exception("Stopped by User");

                Log("Waiting for user action on device...", Color.Black);
                using (KnoxPopup p = new KnoxPopup("Bypass completed.\nPress OK to REBOOT device.")) { p.ShowDialog(this); }
                Log("Rebooting device...", AppTheme.Primary);
                await Task.Run(() => RunAdb("reboot"));
                Log("Bypass Process Finished.", Color.Green);
            } catch {
                Log("Operation Cancelled or Failed.", Color.Red);
            }
        }

        private async void BtnSamsungBypass_Click(object sender, EventArgs e) {
             if(!await CheckDeviceReady()) return;
             string opName = "Samsung 2025 Bypass";
             if(sender == btnSpd2025) opName = "Security Plugin Remove"; 
             DialogResult dr = new KnoxConfirmPopup("CONFIRM ACTION", "Proceed with " + opName + "?\nDo not disconnect.").ShowDialog(this);
             if (dr != DialogResult.Yes) return;
             _stopRequested = false;
             Log("Initializing " + opName + "...", AppTheme.Primary);
             string apkPath = Path.Combine(Application.StartupPath, "testDpC.apk");
             if (!File.Exists(apkPath)) { Log("Error: testDpC.apk missing", Color.Red); return; }
             try {
                 await Task.Run(() => {
                     RunAdb("kill-server"); RunAdb("start-server");
                     Log("ADB Server Restarted", Color.Gray);
                     RunAdb("shell pm clear com.google.android.gms");
                     RunAdb("install -r \"" + apkPath + "\"");
                     Log("APK Installed: testDpC.apk", Color.Gray);
                     RunAdb("shell dpm set-device-owner com.afwsamples.testdpc/.DeviceAdminReceiver");
                     if(_stopRequested) throw new Exception("Stopped");
                     string[] block1 = new string[] { "com.samsung.android.app.updatecenter", "com.google.android.configupdater", "com.samsung.android.cidmanager" };
                     foreach(string pkg in block1) { RunAdb("shell pm uninstall -k --user 0 " + pkg); }
                     Log("Bloatware removed (Update Center, Config Updater, CID Manager)", Color.Gray);
                     RunAdb("shell pm disable-user com.google.android.gms");
                     RunAdb("shell settings put global private_dns_mode hostname");
                     RunAdb("shell settings put global private_dns_specifier 1ff2bf.dns.nextdns.io");
                     RunAdb("reboot");
                 });
                 Log(opName + " Complete. Device Rebooting.", Color.Green);
                 this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("Success! Device Rebooting.")) { p.ShowDialog(this); } }));
             } catch {
                 Log("Operation Cancelled.", Color.Red);
             }
        }

        private async void BtnPatchStandard_Click(object sender, EventArgs e) {
            OpenFileDialog dlg = new OpenFileDialog { Filter = "Bin/Img Files|*.bin;*.img|All Files|*.*" };
            if (dlg.ShowDialog() != DialogResult.OK) return;
            currentFilePathStandard = dlg.FileName; lblFile1.Text = Path.GetFileName(currentFilePathStandard);
            Log("Loading file: " + currentFilePathStandard, Color.Black);
            _stopRequested = false;
            btnPatchStandard.Enabled = false; 
            string result = await Task.Run(() => PerformTripleWipe(currentFilePathStandard));
            btnPatchStandard.Enabled = true; 
            if (result == "STOPPED") { Log("Patch Cancelled by User.", Color.Red); }
            else if (result == "SUCCESS") { Log("Standard Patch Successful.", Color.Green); using (KnoxPopup p = new KnoxPopup("Patch successfully done")) { p.ShowDialog(this); } }
            else { Log("Patch Failed: " + result, Color.Red); using (KnoxPopup p = new KnoxPopup("Error: " + result)) { p.ShowDialog(this); } }
        }

        private string PerformTripleWipe(string path) {
             try {
                if (_stopRequested) return "STOPPED";
                Log("Reading file data...", Color.Gray);
                byte[] data = File.ReadAllBytes(path);
                string backupPath = path + ".bak_" + DateTime.Now.ToString("HHmmss");
                File.WriteAllBytes(backupPath, data);
                Log("Backup created: " + Path.GetFileName(backupPath), Color.Gray);
                Log("Scanning for 'active' flags...", AppTheme.Primary);
                byte[] target = { 0x61, 0x63, 0x74, 0x69, 0x76, 0x65 }; 
                List<int> positions = FindAllOccurrences(data, target);
                if (positions.Count > 0) {
                    foreach (int activeStart in positions) {
                        if (_stopRequested) return "STOPPED";
                        Log("Marker found at offset " + activeStart.ToString("X"), Color.DarkGoldenrod);
                        int activeEnd = activeStart + target.Length; 
                        int numberStart = -1;
                        for (int i = activeEnd; i < data.Length - 4; i++) { if (IsDigit(data[i]) && IsDigit(data[i+1]) && IsDigit(data[i+2]) && IsDigit(data[i+3])) { numberStart = i; break; } }
                        if (numberStart == -1) continue;
                        Log("Numeric sequence found. Wiping precursor data...", Color.Gray);
                        int wipe1End = numberStart - 1; int wipe1Start = activeStart; int zeroCount = 0;
                        for (int i = activeStart - 1; i >= 0; i--) { if (data[i] == 0x00) zeroCount++; else zeroCount = 0; if (zeroCount >= 16) { wipe1Start = i + zeroCount; break; } }
                        if (wipe1End >= wipe1Start) Array.Clear(data, wipe1Start, wipe1End - wipe1Start + 1);
                        int numberEnd = numberStart; while (numberEnd < data.Length && IsDigit(data[numberEnd])) { numberEnd++; }
                        int safetyPoint = numberEnd + 32; 
                        int wipe2EndIndex = -1;
                        if (safetyPoint < data.Length) {
                            int realDataStart2 = -1;
                            for(int k = safetyPoint; k < data.Length; k++) { if (data[k] != 0x00) { realDataStart2 = k; break; } if (k - safetyPoint > 5000) break;  }
                            if (realDataStart2 != -1) {
                                int zeroCountFwd = 0;
                                for (int k = realDataStart2; k < data.Length; k++) { if (data[k] == 0x00) zeroCountFwd++; else zeroCountFwd = 0; if (zeroCountFwd >= 16) { wipe2EndIndex = k - 16; break; } if (k == data.Length - 1) wipe2EndIndex = k; }
                                int len2 = wipe2EndIndex - realDataStart2 + 1;
                                if (len2 > 0 && len2 < 1024*1024) Array.Clear(data, realDataStart2, len2);
                                Log("Secondary data block wiped.", Color.Gray);
                            }
                        }
                    }
                } else { return "NOT_FOUND"; }
                string ext = Path.GetExtension(path).ToLower(); long patchOffset = -1;
                if (ext == ".bin") patchOffset = 0xC17F0; else if (ext == ".img") patchOffset = 0x2A07F0;
                if (patchOffset != -1 && data.Length > patchOffset + 10) { 
                    data[patchOffset + 6] = 0x3A; data[patchOffset + 8] = 0x00; 
                    Log("Header signature patched for " + ext, AppTheme.Primary);
                }
                if (_stopRequested) return "STOPPED";
                File.WriteAllBytes(path, data); return "SUCCESS";
            } catch (Exception ex) { return "ERROR: " + ex.Message; }
        }

        private async void BtnPatchSuper_Click(object sender, EventArgs e) {
            OpenFileDialog dlg = new OpenFileDialog { Filter = "Super Files|*.img;*.bin|All Files|*.*" };
            if (dlg.ShowDialog() != DialogResult.OK) return;
            currentFilePathSuper = dlg.FileName; lblFile2.Text = Path.GetFileName(currentFilePathSuper);
            Log("Super File loaded: " + currentFilePathSuper, Color.Black);
            _stopRequested = false;
            btnPatchSuper.Enabled = false; progBarSuper.Value = 5;

            await Task.Run(() => {
                try {
                    string backupPath = currentFilePathSuper + ".bak";
                    try { File.Copy(currentFilePathSuper, backupPath, true); } catch {}
                    Log("Backup created.", Color.Gray);
                    using (FileStream fs = new FileStream(currentFilePathSuper, FileMode.Open, FileAccess.ReadWrite)) {
                        if (_stopRequested) throw new Exception("Stopped by User");
                        bool fpFound = PerformFingerprintWipe(fs);
                        if (!fpFound) Log("Warning: Fingerprint signature NOT found.", Color.Orange);
                        else Log("Fingerprint signature removed.", Color.Green);
                        this.Invoke(new Action(() => progBarSuper.Value = 30));
                        Log("Scanning: Security.apk blocks...", AppTheme.Primary);
                        PerformStrictBlockWipe(fs, SEC_HEX);
                        if (_stopRequested) throw new Exception("Stopped by User");
                        Log("Scanning: PrivateComputeServices...", AppTheme.Primary);
                        PerformStrictBlockWipe(fs, PCS_HEX);
                        this.Invoke(new Action(() => progBarSuper.Value = 60));
                        PerformStrictBlockWipe(fs, SEC_ODEX_HEX);
                        PerformStrictBlockWipe(fs, PCS_APKOAT_HEX);
                        PerformPrivAppGapWipe(fs);
                        PerformProdSecWipe(fs);
                        this.Invoke(new Action(() => progBarSuper.Value = 100));
                    }
                    Log("Super Patch Process Completed Successfully.", Color.Green);
                    this.Invoke(new Action(() => { using (KnoxPopup p = new KnoxPopup("Super Patch Complete!")) { p.ShowDialog(this); } }));
                } catch (Exception ex) {
                    if (ex.Message.Contains("Stopped")) Log("Patch Cancelled by User.", Color.Red);
                    else Log("Super Patch Error: " + ex.Message, Color.Red);
                }
                this.Invoke(new Action(() => { btnPatchSuper.Enabled = true; progBarSuper.Value = 0; }));
            });
        }
        
        private byte[] HexStringToBytes(string hex) { hex = hex.Replace(" ", ""); return Enumerable.Range(0, hex.Length).Where(x => x % 2 == 0).Select(x => Convert.ToByte(hex.Substring(x, 2), 16)).ToArray(); }
        private long FindFirstOccurrence(FileStream fs, byte[] pattern, long startOffset) { int bufferSize = 1024 * 1024; byte[] buffer = new byte[bufferSize]; fs.Position = startOffset; int bytesRead; while ((bytesRead = fs.Read(buffer, 0, buffer.Length)) > 0) { for (int i = 0; i <= bytesRead - pattern.Length; i++) { if (IsMatch(buffer, i, pattern)) return (fs.Position - bytesRead) + i; } if (fs.Position < fs.Length) fs.Position -= pattern.Length; } return -1; }
        private long FindLastOccurrenceInRange(FileStream fs, byte[] pattern, long startLimit, long endLimit) { long bestPos = -1; fs.Position = startLimit; int bufferSize = 1024 * 1024; byte[] buffer = new byte[bufferSize]; long totalToRead = endLimit - startLimit; long processed = 0; while (processed < totalToRead) { int toRead = (int)Math.Min(bufferSize, totalToRead - processed); int bytesRead = fs.Read(buffer, 0, toRead); if (bytesRead == 0) break; for (int i = 0; i <= bytesRead - pattern.Length; i++) { if (IsMatch(buffer, i, pattern)) bestPos = (fs.Position - bytesRead) + i; } processed += bytesRead; if (processed < totalToRead) { fs.Position -= pattern.Length; processed -= pattern.Length; } } return bestPos; }
        private bool IsMatch(byte[] buffer, int offset, byte[] pattern) { for (int j = 0; j < pattern.Length; j++) { if (buffer[offset + j] != pattern[j]) return false; } return true; }
        private bool PerformFingerprintWipe(FileStream fs) { byte[] fingerprint = HexStringToBytes(FP_HEX); byte[] startMark = Encoding.UTF8.GetBytes(FP_START); byte[] endMark = Encoding.UTF8.GetBytes(FP_END); long currentPos = 0; bool found = false; while(currentPos < fs.Length) { if(_stopRequested) return false; long matchPos = FindFirstOccurrence(fs, fingerprint, currentPos); if (matchPos == -1) break; found = true; long searchBackLimit1 = Math.Max(0, matchPos - (1024 * 1024 * 5)); long firstPK = FindLastOccurrenceInRange(fs, startMark, searchBackLimit1, matchPos); if (firstPK != -1) { long searchBackLimit2 = Math.Max(0, firstPK - (1024 * 1024 * 5)); long secondPK = FindLastOccurrenceInRange(fs, startMark, searchBackLimit2, firstPK - 1); long finalStartPos = (secondPK != -1) ? secondPK : firstPK; long endPos = FindFirstOccurrence(fs, endMark, matchPos); if (endPos != -1) { long wipeLength = (endPos + endMark.Length) - finalStartPos; fs.Position = finalStartPos; fs.Write(new byte[wipeLength], 0, (int)wipeLength); currentPos = endPos + endMark.Length; continue; } } currentPos = matchPos + fingerprint.Length; } return found; }
        private bool PerformStrictBlockWipe(FileStream fs, string hexTarget) { byte[] target = HexStringToBytes(hexTarget); byte[] marker = HexStringToBytes(YYYY_MARKER); long currentPos = 0; bool found = false; while(currentPos < fs.Length) { if(_stopRequested) return false; long matchPos = FindFirstOccurrence(fs, target, currentPos); if (matchPos == -1) break; found = true; long searchBackLimit = Math.Max(0, matchPos - (1024 * 1024)); long topMarkerPos = FindLastOccurrenceInRange(fs, marker, searchBackLimit, matchPos); if (topMarkerPos != -1) { long rowStart = topMarkerPos - (topMarkerPos % 16); long eraseStart = rowStart + 16; long bottomMarkerPos = FindFirstOccurrence(fs, marker, matchPos + target.Length); if (bottomMarkerPos != -1) { long eraseEnd = bottomMarkerPos - (bottomMarkerPos % 16); if (eraseEnd > eraseStart) { long wipeLength = eraseEnd - eraseStart; fs.Position = eraseStart; fs.Write(new byte[wipeLength], 0, (int)wipeLength); currentPos = bottomMarkerPos + 16; continue; } } } currentPos = matchPos + target.Length; } return found; }
        private bool PerformPrivAppGapWipe(FileStream fs) { byte[] target = HexStringToBytes(PRIV_APP_HEX); byte[] marker = HexStringToBytes(YYYY_MARKER); long currentPos = 0; bool found = false; while(currentPos < fs.Length) { if(_stopRequested) return false; long matchPos = FindFirstOccurrence(fs, target, currentPos); if (matchPos == -1) break; found = true; long searchBackLimit = Math.Max(0, matchPos - (1024 * 1024)); long topMarkerStart = FindLastOccurrenceInRange(fs, marker, searchBackLimit, matchPos); if (topMarkerStart != -1) { fs.Position = topMarkerStart; int b; long trueEndOfFFs = topMarkerStart; while((b = fs.ReadByte()) != -1) { if (b != 0xFF) { trueEndOfFFs = fs.Position - 1; break; } } long eraseStart = trueEndOfFFs + 3; long bottomMarkerPos = FindFirstOccurrence(fs, marker, matchPos + target.Length); if (bottomMarkerPos != -1) { long eraseEnd = bottomMarkerPos - (bottomMarkerPos % 16); if (eraseEnd > eraseStart) { long wipeLength = eraseEnd - eraseStart; fs.Position = eraseStart; fs.Write(new byte[wipeLength], 0, (int)wipeLength); currentPos = bottomMarkerPos + 4; continue; } } } currentPos = matchPos + target.Length; } return found; }
        private bool PerformProdSecWipe(FileStream fs) { byte[] target = HexStringToBytes(PROD_SEC_HEX); byte[] marker = HexStringToBytes(YYYY_MARKER); long currentPos = 0; bool found = false; while(currentPos < fs.Length) { if(_stopRequested) return false; long matchPos = FindFirstOccurrence(fs, target, currentPos); if (matchPos == -1) break; found = true; long searchBackLimit = Math.Max(0, matchPos - (1024 * 1024)); long topMarkerStart = FindLastOccurrenceInRange(fs, marker, searchBackLimit, matchPos); if (topMarkerStart != -1) { fs.Position = topMarkerStart; int b; long trueEndOfFFs = topMarkerStart; while((b = fs.ReadByte()) != -1) { if (b != 0xFF) { trueEndOfFFs = fs.Position - 1; break; } } long eraseStart = trueEndOfFFs + 6; long bottomMarkerPos = FindFirstOccurrence(fs, marker, matchPos + target.Length); if (bottomMarkerPos != -1) { long eraseEnd = bottomMarkerPos - 3; if (eraseEnd > eraseStart) { long wipeLength = eraseEnd - eraseStart; fs.Position = eraseStart; fs.Write(new byte[wipeLength], 0, (int)wipeLength); currentPos = bottomMarkerPos + 4; continue; } } } currentPos = matchPos + target.Length; } return found; }
        private bool IsDigit(byte b) { return (b >= 0x30 && b <= 0x39); }
        private List<int> FindAllOccurrences(byte[] data, byte[] pattern) { List<int> positions = new List<int>(); for (int i = 0; i <= data.Length - pattern.Length; i++) { bool match = true; for (int j = 0; j < pattern.Length; j++) { if (data[i + j] != pattern[j]) { match = false; break; } } if (match) positions.Add(i); } return positions; }

        private void StartLiveMonitor() {
            while (isMonitoring) { Thread.Sleep(2000); }
        }
        
        private async Task<bool> CheckDeviceReady() {
             return await Task.Run(() => {
                 string adbOut = RunAdb("devices");
                 string status = ParseAdbStatus(adbOut);
                 if(status == "authorized") return true;
                 if(status == "unauthorized") {
                     Log("Device Unauthorized. Check screen.", Color.Orange);
                     return false;
                 }
                 Log("No Device Detected.", Color.Red);
                 return false;
             });
        }

        private string RunAdb(string arguments, bool silent = false) {
            if (_stopRequested) throw new Exception("Stopped by User");
            try {
                if(!silent && (!arguments.Contains("devices") || arguments.Contains("shell"))) 
                    this.Invoke(new Action(() => Log("> adb " + arguments, Color.Gray))); 
                
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "adb.exe"; psi.Arguments = arguments; psi.RedirectStandardOutput = true; psi.UseShellExecute = false; psi.CreateNoWindow = true;
                using (Process p = Process.Start(psi)) { 
                    string output = p.StandardOutput.ReadToEnd(); 
                    p.WaitForExit();
                    return output; 
                }
            } catch { return "ERROR"; }
        }
        
        [STAThread]
        static void Main() { 
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            // --- NEW: SPLASH & UPDATE CHECK ---
            SplashForm splash = new SplashForm();
            splash.Show();
            Application.DoEvents(); // Force splash to paint
            
            Updater.CheckForUpdate(splash); 
            
            splash.Close();
            splash.Dispose();
            // -----------------------------------
            
            LoginForm login = new LoginForm(); 
            Application.Run(login);
            if (login.IsAuthenticated) { Application.Run(new KnoxMain()); }
        }
    }

    public class UniversalPatcher
    {
        // --- TARGETS ---
        private const string MTK_FP_HEX = "63 6C 61 73 73 65 73 2E 64 65 78 64 65 78"; 
        private const string FP_START = "PK";
        private const string FP_END = "META-INF/MANIFEST.MFPK";

        private const string SEC_HEX = "53 65 63 75 72 69 74 79 43 6F 6D 2E 61 70 6B"; 
        private const string MTK_PCS_HEX = "50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 53 65 63 75 72 69 74 79 43 6F 6D";
        private const string PCS_HEX = "50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 2E 6F 64 65 78 50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 2E 76 64 65 78";

        // SCORPIO TARGETS
        private const string SCORPIO_INIT = "69 6E 69 74 69 61 6C 2D 70 61 63 6B 61 67 65 2D 73 74 61 74 65 20 70 61 63 6B 61 67 65 3D 22 63 6F 6D 2E 73 63 6F 72 70 69 6F 2E 73 65 63 75 72 69 74 79 63 6F 6D";
        private const string SCORPIO_PATH = "70 72 6F 64 75 63 74 2F 70 72 69 76 2D 61 70 70 2F 53 65 63 75 72 69 74 79 43 6F 6D";
        private const string SCORPIO_XML  = "78 6D 6C 63 6F 6D 2E 73 63 6F 72 70 69 6F 2E 73 65 63 75 72 69 74 79 63 6F 6D";
        private const string SCORPIO_PERM = "3C 70 72 69 76 61 70 70 2D 70 65 72 6D 69 73 73 69 6F 6E 73 20 70 61 63 6B 61 67 65 3D 22 63 6F 6D 2E 73 63 6F 72 70 69 6F 2E 73 65 63 75 72 69 74 79 63 6F 6D 22 3E";
        private const string SCORPIO_ODEX = "73 65 63 75 72 69 74 79 63 6F 6D 2E 6F 64 65 78";

        private const string SEC_ODEX_HEX = "53 65 63 75 72 69 74 79 43 6F 6D 2E 6F 64 65 78 53 65 63 75 72 69 74 79 43 6F 6D 2E 76 64 65 78";
        private const string PCS_APKOAT_HEX = "50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65 2E 61 70 6B 6F 61 74";
        private const string PRIV_APP_HEX = "70 72 69 76 2D 61 70 70 2F 50 72 69 76 61 74 65 43 6F 6D 70 75 74 65 53 65 72 76 69 63 65";
        private const string PROD_SEC_HEX = "2F 70 72 6F 64 75 63 74 2F 70 72 69 76 2D 61 70 70 2F 53 65 63 75 72 69 74 79 43 6F 6D";

        private const string YYYY_MARKER = "FF FF FF FF";
        private const string YYYY_ALT_MARKER = "FF F7 FF FF";
        
        // LIMITS
        private const int MTK_MAX_PK_DIST = 160;
        private const int FORWARD_SCAN_LIMIT = 4096; // Kept only for forward safety

        public async Task ExecuteUniversalPatch(string targetPath)
        {
            if (string.IsNullOrEmpty(targetPath) || !File.Exists(targetPath)) return;

            await Task.Run(() =>
            {
                try
                {
                    string backup = targetPath + ".bak";
                    if (!File.Exists(backup)) File.Copy(targetPath, backup);

                    using (FileStream fs = new FileStream(targetPath, FileMode.Open, FileAccess.ReadWrite))
                    {
                        // STAGE 1-5 (Standard Strict Operations)
                        PerformStrictFingerprintWipe(fs, MTK_FP_HEX);
                        PerformStrictBlockWipe(fs, SEC_HEX);
                        PerformMtkCustomWipe(fs, MTK_PCS_HEX); // Updated logic applied here
                        PerformStrictBlockWipe(fs, PCS_HEX);
                        PerformStrictBlockWipe(fs, SEC_ODEX_HEX);
                        PerformStrictBlockWipe(fs, PCS_APKOAT_HEX);
                        PerformPrivAppGapWipe(fs);
                        PerformProdSecWipe(fs);

                        // STAGE 6: SCORPIO SUITE (Updated Logic)
                        PerformMtkCustomWipe(fs, SCORPIO_INIT);
                        PerformMtkCustomWipe(fs, SCORPIO_PATH);
                        PerformMtkCustomWipe(fs, SCORPIO_XML);
                        PerformMtkCustomWipe(fs, SCORPIO_PERM);
                        PerformMtkCustomWipe(fs, SCORPIO_ODEX);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Error: " + ex.Message);
                }
            });
        }

        // --- NEW CUSTOM ALGORITHM (Replaces 4KB Logic) ---
        private bool PerformMtkCustomWipe(FileStream fs, string hexTarget)
        {
            byte[] target = HexStringToBytes(hexTarget);
            
            // Standard Markers
            byte[] m1 = HexStringToBytes("FF FF FF FF");
            byte[] m2 = HexStringToBytes("FF F7 FF FF");
            
            // Complex Cluster Markers
            byte[] c1 = HexStringToBytes("FF FF F7 FF"); 
            byte[] c2 = HexStringToBytes("FF FF FF F7");

            long currentPos = 0; bool found = false;

            while (currentPos < fs.Length)
            {
                long matchPos = FindFirstOccurrence(fs, target, currentPos);
                if (matchPos == -1) break;
                found = true;

                // 1. BACKWARD SEARCH (Unbounded / "Closest")
                long bestBackPos = -1;
                
                // Scan backward byte-by-byte from matchPos
                long searchPointer = matchPos - 4; // Start looking immediately before target
                
                while (searchPointer >= 0)
                {
                    fs.Position = searchPointer;
                    byte[] buffer = new byte[4];
                    int read = fs.Read(buffer, 0, 4);
                    if (read < 4) break;

                    // Check Standard Markers
                    if (IsBytesEqual(buffer, m1) || IsBytesEqual(buffer, m2))
                    {
                        bestBackPos = searchPointer;
                        break; // Found closest!
                    }

                    // Check Complex Markers (>2 immediate incidents, i.e., 3 contiguous blocks)
                    // Check if current block is c1 or c2
                    if (IsBytesEqual(buffer, c1))
                    {
                        // Look back for 2 more immediate incidents (Total 3)
                        if (CheckImmediatePrevious(fs, searchPointer, c1, 2)) 
                        {
                            bestBackPos = searchPointer;
                            break; 
                        }
                    }
                    if (IsBytesEqual(buffer, c2))
                    {
                        // Look back for 2 more immediate incidents
                        if (CheckImmediatePrevious(fs, searchPointer, c2, 2))
                        {
                            bestBackPos = searchPointer;
                            break;
                        }
                    }

                    searchPointer--; // Move back 1 byte and retry (exhaustive scan)
                }

                if (bestBackPos != -1)
                {
                    // 2. APPLY 4 DOT RULE
                    // Wipe starts 8 bytes after the marker start (4 bytes marker + 4 bytes dots)
                    long wipeStart = bestBackPos + 4 + 4;

                    // 3. FORWARD SCAN (Normal Logic)
                    // We keep a reasonable limit forward so we don't wipe the whole file if end marker is missing
                    long fwdSearchLimit = wipeStart + FORWARD_SCAN_LIMIT;
                    if (fwdSearchLimit > fs.Length) fwdSearchLimit = fs.Length;

                    long fwd1 = FindFirstOccurrenceInRange(fs, m1, wipeStart, fwdSearchLimit);
                    long fwd2 = FindFirstOccurrenceInRange(fs, m2, wipeStart, fwdSearchLimit);

                    long wipeEnd = -1;
                    if (fwd1 != -1 && fwd2 != -1) wipeEnd = Math.Min(fwd1, fwd2);
                    else if (fwd1 != -1) wipeEnd = fwd1;
                    else if (fwd2 != -1) wipeEnd = fwd2;

                    if (wipeEnd != -1 && wipeEnd > wipeStart)
                    {
                        long wipeLength = wipeEnd - wipeStart;
                        fs.Position = wipeStart;
                        fs.Write(new byte[wipeLength], 0, (int)wipeLength);
                    }
                }
                currentPos = matchPos + target.Length;
            }
            return found;
        }

        // Helper to check for "Immediate Previous" incidents
        // Checks if 'pattern' appears 'count' times immediately before 'currentPos'
        private bool CheckImmediatePrevious(FileStream fs, long currentPos, byte[] pattern, int count)
        {
            long checkPos = currentPos;
            byte[] buf = new byte[4];
            
            for(int i = 0; i < count; i++)
            {
                checkPos -= 4; // Move back 4 bytes (immediate previous block)
                if (checkPos < 0) return false;
                
                fs.Position = checkPos;
                fs.Read(buf, 0, 4);
                if (!IsBytesEqual(buf, pattern)) return false;
            }
            return true;
        }

        private bool IsBytesEqual(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
            return true;
        }

        // --- EXISTING UTILS ---
        private bool PerformStrictFingerprintWipe(FileStream fs, string hexSignature) {
            byte[] fingerprint = HexStringToBytes(hexSignature);
            byte[] startMark = Encoding.UTF8.GetBytes(FP_START);
            byte[] endMark = Encoding.UTF8.GetBytes(FP_END);
            long currentPos = 0; bool wipeOccurred = false;
            while(currentPos < fs.Length) {
                long matchPos = FindFirstOccurrence(fs, fingerprint, currentPos);
                if (matchPos == -1) break;
                long searchBackLimit1 = Math.Max(0, matchPos - (1024 * 1024 * 5));
                long firstPK = FindLastOccurrenceInRange(fs, startMark, searchBackLimit1, matchPos);
                if (firstPK != -1) {
                    long searchBackLimit2 = Math.Max(0, firstPK - (1024 * 1024 * 5));
                    long secondPK = FindLastOccurrenceInRange(fs, startMark, searchBackLimit2, firstPK - 1);
                    long finalStartPos = -1;
                    if (secondPK == -1) { currentPos = matchPos + fingerprint.Length; continue; }
                    else {
                        long dist = firstPK - secondPK;
                        if (dist > MTK_MAX_PK_DIST) { currentPos = matchPos + fingerprint.Length; continue; }
                        if (IsLinePrefixClean(fs, secondPK)) finalStartPos = secondPK;
                        else { currentPos = matchPos + fingerprint.Length; continue; }
                    }
                    if (finalStartPos != -1) {
                        long endPos = FindFirstOccurrence(fs, endMark, matchPos);
                        if (endPos != -1) {
                            long wipeLength = (endPos + endMark.Length) - finalStartPos;
                            fs.Position = finalStartPos;
                            fs.Write(new byte[wipeLength], 0, (int)wipeLength);
                            wipeOccurred = true;
                            currentPos = endPos + endMark.Length; continue;
                        }
                    }
                }
                currentPos = matchPos + fingerprint.Length;
            }
            return wipeOccurred;
        }

        private bool PerformStrictBlockWipe(FileStream fs, string hexTarget) {
            byte[] target = HexStringToBytes(hexTarget);
            byte[] marker = HexStringToBytes(YYYY_MARKER);
            long currentPos = 0; bool found = false;
            while (currentPos < fs.Length) {
                long matchPos = FindFirstOccurrence(fs, target, currentPos);
                if (matchPos == -1) break;
                found = true;
                long searchBackLimit = Math.Max(0, matchPos - (1024 * 1024));
                long topMarkerPos = FindLastOccurrenceInRange(fs, marker, searchBackLimit, matchPos);
                if (topMarkerPos != -1) {
                    long rowStart = topMarkerPos - (topMarkerPos % 16);
                    long eraseStart = rowStart + 16;
                    long bottomMarkerPos = FindFirstOccurrence(fs, marker, matchPos + target.Length);
                    if (bottomMarkerPos != -1) {
                        long eraseEnd = bottomMarkerPos - (bottomMarkerPos % 16);
                        if (eraseEnd > eraseStart) {
                            long wipeLength = eraseEnd - eraseStart;
                            fs.Position = eraseStart;
                            fs.Write(new byte[wipeLength], 0, (int)wipeLength);
                            currentPos = bottomMarkerPos + 16; continue;
                        }
                    }
                }
                currentPos = matchPos + target.Length;
            }
            return found;
        }

        private bool PerformPrivAppGapWipe(FileStream fs) {
            byte[] target = HexStringToBytes(PRIV_APP_HEX);
            byte[] marker = HexStringToBytes(YYYY_MARKER);
            long currentPos = 0; bool found = false;
            while (currentPos < fs.Length) {
                long matchPos = FindFirstOccurrence(fs, target, currentPos);
                if (matchPos == -1) break;
                found = true;
                long searchBackLimit = Math.Max(0, matchPos - (1024 * 1024));
                long topMarkerStart = FindLastOccurrenceInRange(fs, marker, searchBackLimit, matchPos);
                if (topMarkerStart != -1) {
                    fs.Position = topMarkerStart; int b; long trueEndOfFFs = topMarkerStart;
                    while ((b = fs.ReadByte()) != -1) { if (b != 0xFF) { trueEndOfFFs = fs.Position - 1; break; } }
                    long eraseStart = trueEndOfFFs + 3;
                    long bottomMarkerPos = FindFirstOccurrence(fs, marker, matchPos + target.Length);
                    if (bottomMarkerPos != -1) {
                        long eraseEnd = bottomMarkerPos - (bottomMarkerPos % 16);
                        if (eraseEnd > eraseStart) {
                            long wipeLength = eraseEnd - eraseStart;
                            fs.Position = eraseStart; fs.Write(new byte[wipeLength], 0, (int)wipeLength);
                            currentPos = bottomMarkerPos + 4; continue;
                        }
                    }
                }
                currentPos = matchPos + target.Length;
            }
            return found;
        }

        private bool PerformProdSecWipe(FileStream fs) {
            byte[] target = HexStringToBytes(PROD_SEC_HEX);
            byte[] marker = HexStringToBytes(YYYY_MARKER);
            long currentPos = 0; bool found = false;
            while (currentPos < fs.Length) {
                long matchPos = FindFirstOccurrence(fs, target, currentPos);
                if (matchPos == -1) break;
                found = true;
                long searchBackLimit = Math.Max(0, matchPos - (1024 * 1024));
                long topMarkerStart = FindLastOccurrenceInRange(fs, marker, searchBackLimit, matchPos);
                if (topMarkerStart != -1) {
                    fs.Position = topMarkerStart; int b; long trueEndOfFFs = topMarkerStart;
                    while ((b = fs.ReadByte()) != -1) { if (b != 0xFF) { trueEndOfFFs = fs.Position - 1; break; } }
                    long eraseStart = trueEndOfFFs + 6;
                    long bottomMarkerPos = FindFirstOccurrence(fs, marker, matchPos + target.Length);
                    if (bottomMarkerPos != -1) {
                        long eraseEnd = bottomMarkerPos - 3;
                        if (eraseEnd > eraseStart) {
                            long wipeLength = eraseEnd - eraseStart;
                            fs.Position = eraseStart; fs.Write(new byte[wipeLength], 0, (int)wipeLength);
                            currentPos = bottomMarkerPos + 4; continue;
                        }
                    }
                }
                currentPos = matchPos + target.Length;
            }
            return found;
        }

        private bool IsLinePrefixClean(FileStream fs, long pos) {
            long rowStart = pos - (pos % 16);
            int lengthToCheck = (int)(pos - rowStart);
            if (lengthToCheck == 0) return true;
            long originalPos = fs.Position;
            fs.Position = rowStart;
            byte[] prefixBuffer = new byte[lengthToCheck];
            fs.Read(prefixBuffer, 0, lengthToCheck);
            fs.Position = originalPos;
            foreach (byte b in prefixBuffer) { if (b != 0x00) return false; }
            return true;
        }

        private byte[] HexStringToBytes(string hex) { hex = hex.Replace(" ", ""); return Enumerable.Range(0, hex.Length).Where(x => x % 2 == 0).Select(x => Convert.ToByte(hex.Substring(x, 2), 16)).ToArray(); }
        
        private long FindFirstOccurrence(FileStream fs, byte[] pattern, long startOffset) { int bufferSize = 1024 * 1024; byte[] buffer = new byte[bufferSize]; fs.Position = startOffset; int bytesRead; while ((bytesRead = fs.Read(buffer, 0, buffer.Length)) > 0) { for (int i = 0; i <= bytesRead - pattern.Length; i++) { if (IsMatch(buffer, i, pattern)) return (fs.Position - bytesRead) + i; } if (fs.Position < fs.Length) fs.Position -= pattern.Length; } return -1; }
        
        private long FindFirstOccurrenceInRange(FileStream fs, byte[] pattern, long startOffset, long endLimit) { int bufferSize = 1024 * 1024; byte[] buffer = new byte[bufferSize]; fs.Position = startOffset; long totalToRead = endLimit - startOffset; long processed = 0; while (processed < totalToRead) { int toRead = (int)Math.Min(bufferSize, totalToRead - processed); int bytesRead = fs.Read(buffer, 0, toRead); if(bytesRead == 0) break; for (int i = 0; i <= bytesRead - pattern.Length; i++) { if (IsMatch(buffer, i, pattern)) return (fs.Position - bytesRead) + i; } processed += bytesRead; if (processed < totalToRead) { fs.Position -= pattern.Length; processed -= pattern.Length; } } return -1; }
        
        private long FindLastOccurrenceInRange(FileStream fs, byte[] pattern, long startLimit, long endLimit) { long bestPos = -1; fs.Position = startLimit; int bufferSize = 1024 * 1024; byte[] buffer = new byte[bufferSize]; long totalToRead = endLimit - startLimit; long processed = 0; while (processed < totalToRead) { int toRead = (int)Math.Min(bufferSize, totalToRead - processed); int bytesRead = fs.Read(buffer, 0, toRead); if (bytesRead == 0) break; for (int i = 0; i <= bytesRead - pattern.Length; i++) { if (IsMatch(buffer, i, pattern)) bestPos = (fs.Position - bytesRead) + i; } processed += bytesRead; if (processed < totalToRead) { fs.Position -= pattern.Length; processed -= pattern.Length; } } return bestPos; }
        
        private bool IsMatch(byte[] buffer, int offset, byte[] pattern) { for (int j = 0; j < pattern.Length; j++) { if (buffer[offset + j] != pattern[j]) return false; } return true; }
    }
}
"@

# 2. COMPILE & RUN
$tempFile = "$env:TEMP\KnoxWizard_Final.cs"
$code | Out-File -FilePath $tempFile -Encoding UTF8

Write-Host "Compiling Knox Wizard V0.1 (Auto-Update)..." -ForegroundColor Cyan
$params = @(
    "/target:winexe",
    "/out:$outputPath",
    "/platform:anycpu",
    "/r:System.Windows.Forms.dll",
    "/r:System.Drawing.dll",
    "/r:System.Core.dll",
    "/r:System.Management.dll", 
    $tempFile
)

if (Test-Path $iconPath) {
    $params += "/win32icon:$iconPath"
}

$compiler = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $compiler)) { Write-Host "Error: csc.exe not found." -ForegroundColor Red; exit }

Start-Process -FilePath $compiler -ArgumentList $params -Wait -NoNewWindow

if (Test-Path $outputPath) {
    Remove-Item $tempFile
    if (Test-Path $iconPath) { Remove-Item $iconPath } # Clean up
    Write-Host "`nSUCCESS! KnoxWizard_Final.exe created on Desktop." -ForegroundColor Green
} else {
    Write-Host "`nCOMPILATION FAILED." -ForegroundColor Red
}
Write-Host "Press Enter to exit..."
Read-Host
