using System;

namespace NabuNet
{
    public class ServerSettings
    {
        public string ServerName { get; set; } = string.Empty;
        public string ServerTagLine { get; set; } = string.Empty;
        public bool EnableGustAccess { get; set; } = false;
        public TimeSpan GuestSessionTimeout { get; set; } = TimeSpan.FromHours(1);
        public bool EnableLogin { get; set; } = false;
        public bool EnableVirtualServers { get; set; } = false;
        public bool EnableSignup { get; set; } = false;
        public bool ReadOnlyMode { get; set; } = true;
        public bool EnableNewUsers { get; set; } = true;
        public bool RequireMailValidation { get; set; } = true;
        public string BaseUrl { get; set; } = "https://localhost:5001/";
        public int TZOffset { get; set; } = 0;
        public string TimeFormat { get; set; } = "yyyy-MM-dd HH:mm:ss";
        public bool UseLocalTime { get; set; } = false;
    }
}